#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"
COMPOSE_PROFILE_ARGS=()
ROLLOUT_ACTIVE=0
ROLLOUT_PERCENT=0
ROLLOUT_STATE_PATH="${AI_ROUTER_ROLLOUT_STATE_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/rollout-state.json}"
ROLLOUT_MAP_PATH="${AI_ROUTER_MAP_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/rollout.map}"
ROLLOUT_AFFINITY_MAP_PATH="${AI_ROUTER_AFFINITY_MAP_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/release-affinity.map}"
ROLLOUT_CANDIDATE_REPLICAS=1

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Copy deploy/staging/staging.env.example to deploy/staging/staging.env first."
  exit 1
fi

ENV_FILE="${ENV_FILE}" "${ROOT_DIR}/deploy/staging/validate-staging-env.sh"

PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"
if [[ "${STAGING_MODE}" == "https" ]]; then
  PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.https.yaml"
fi

compose() {
  docker compose \
    "${COMPOSE_PROFILE_ARGS[@]}" \
    --env-file "${ENV_FILE}" \
    -f "${COMPOSE_BASE}" \
    -f "${ROOT_DIR}/overrides/compose.redis.yaml" \
    -f "${ROOT_DIR}/deploy/staging/compose.mariadb.staging.yaml" \
    -f "${PROXY_OVERRIDE}" \
    "$@"
}

get_env() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
}

"${ROOT_DIR}/deploy/staging/ensure-ai-router-state.sh"
if [[ -f "${ROLLOUT_STATE_PATH}" ]]; then
  readarray -t rollout_values < <(
    python3 - "${ROLLOUT_STATE_PATH}" <<'PY'
import json
import sys

state = json.load(open(sys.argv[1], encoding="utf-8"))
print(state.get("status") or "")
print(state.get("candidate_percent") or 0)
print(state.get("stable_pool_release_id") or state.get("stable_release_id") or "")
print(state.get("candidate_release_id") or "")
print(state.get("candidate_replicas") or 1)
PY
  )
  if [[ "${rollout_values[0]}" =~ ^(active|draining|promoting)$ ]] && \
    [[ "${rollout_values[1]}" != "0" || "${rollout_values[0]}" != "active" ]]; then
    ROLLOUT_ACTIVE=1
    ROLLOUT_PERCENT="${rollout_values[1]}"
    export MYAPP_AI_STABLE_TAG="${rollout_values[2]}"
    export MYAPP_AI_CANDIDATE_TAG="${rollout_values[3]}"
    export MYAPP_AI_CANDIDATE_REPLICAS="${rollout_values[4]}"
    ROLLOUT_CANDIDATE_REPLICAS="${rollout_values[4]}"
    COMPOSE_PROFILE_ARGS=(--profile ai-rollout)
  fi
fi
compose up -d

AI_GATEWAY_CONTAINER_IDS=()
for service in backend queue-short queue-long queue-ai-vector scheduler; do
  container_id="$(compose ps -q "${service}")"
  if [[ -z "${container_id}" ]]; then
    echo "AI gateway runtime configuration check failed: ${service} is not running." >&2
    exit 1
  fi
  AI_GATEWAY_CONTAINER_IDS+=("${container_id}")
done
"${ROOT_DIR}/verify-ai-gateway-runtime-env.sh" \
  "${ENV_FILE}" "${AI_GATEWAY_CONTAINER_IDS[@]}"
AI_ORCHESTRATOR_URL="$(get_env MYAPP_AI_ORCHESTRATOR_URL)"
AI_ORCHESTRATOR_URL="${AI_ORCHESTRATOR_URL:-http://ai-router:4010}"
EXPECTED_AI_REPLICAS="$(get_env MYAPP_AI_ORCHESTRATOR_REPLICAS)"
EXPECTED_AI_REPLICAS="${EXPECTED_AI_REPLICAS:-1}"
mapfile -t AI_ORCHESTRATOR_CONTAINER_IDS < <(compose ps -q ai-orchestrator)
"${ROOT_DIR}/verify-ai-runtime-compatibility.sh" \
  "${AI_GATEWAY_CONTAINER_IDS[0]}" "${AI_ORCHESTRATOR_URL%/}/readyz"
if [[ "${ROLLOUT_ACTIVE}" == "1" ]]; then
  "${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh" \
    "${AI_GATEWAY_CONTAINER_IDS[0]}" "http://ai-orchestrator:4010/readyz" \
    "${EXPECTED_AI_REPLICAS}" "${AI_ORCHESTRATOR_CONTAINER_IDS[@]}"
  EXPECTED_CANDIDATE_REPLICAS="${ROLLOUT_CANDIDATE_REPLICAS}"
  mapfile -t AI_CANDIDATE_CONTAINER_IDS < <(compose ps -q ai-orchestrator-candidate)
  "${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh" \
    "${AI_GATEWAY_CONTAINER_IDS[0]}" "http://ai-orchestrator-candidate:4010/readyz" \
    "${EXPECTED_CANDIDATE_REPLICAS}" "${AI_CANDIDATE_CONTAINER_IDS[@]}"
  "${ROOT_DIR}/deploy/staging/verify-ai-router-rollout.sh" \
    "${AI_GATEWAY_CONTAINER_IDS[0]}" "${AI_ORCHESTRATOR_URL%/}/readyz" \
    "${ROLLOUT_MAP_PATH}" "${ROLLOUT_STATE_PATH}" "${ROLLOUT_AFFINITY_MAP_PATH}"
  echo "Resumed managed AI rollout at ${ROLLOUT_PERCENT}% candidate traffic."
else
  "${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh" \
    "${AI_GATEWAY_CONTAINER_IDS[0]}" "${AI_ORCHESTRATOR_URL%/}/readyz" \
    "${EXPECTED_AI_REPLICAS}" "${AI_ORCHESTRATOR_CONTAINER_IDS[@]}"
fi
