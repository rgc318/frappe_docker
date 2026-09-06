#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"
COMPOSE_PROFILE_ARGS=()
ROLLOUT_STATE_PATH="${AI_ROUTER_ROLLOUT_STATE_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/rollout-state.json}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Copy deploy/staging/staging.env.example to deploy/staging/staging.env first."
  exit 1
fi

ENV_FILE="${ENV_FILE}" "${ROOT_DIR}/deploy/staging/validate-staging-env.sh"

SITE_NAME="${SITE_NAME:-}"
SKIP_MIGRATE="${SKIP_MIGRATE:-0}"
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
    export MYAPP_AI_STABLE_TAG="${rollout_values[2]}"
    export MYAPP_AI_CANDIDATE_TAG="${rollout_values[3]}"
    export MYAPP_AI_CANDIDATE_REPLICAS="${rollout_values[4]}"
    COMPOSE_PROFILE_ARGS=(--profile ai-rollout)
    echo "Preserving ${rollout_values[0]} AI rollout at ${rollout_values[1]}% candidate traffic."
  fi
fi
echo "Pulling latest staging images..."
compose pull

echo "Restarting staging stack..."
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

if [[ -n "${SITE_NAME}" ]]; then
  echo "Reconciling site database grants for: ${SITE_NAME}"
  SITE_NAME="${SITE_NAME}" ENV_FILE="${ENV_FILE}" STAGING_MODE="${STAGING_MODE}" \
    bash "${ROOT_DIR}/deploy/staging/fix-site-db-grants.sh"
fi

if [[ -n "${SITE_NAME}" && "${SKIP_MIGRATE}" != "1" ]]; then
  echo "Checking site before migrate: ${SITE_NAME}"
  if compose exec backend bash -lc "bench --site ${SITE_NAME} list-apps >/dev/null 2>&1"; then
    echo "Running bench migrate for site: ${SITE_NAME}"
    compose exec backend bash -lc "bench --site ${SITE_NAME} migrate"
  else
    echo "Skipping migrate because site does not exist yet: ${SITE_NAME}"
    echo "Initialize the site first by following deploy/staging/INIT_SITE.zh-CN.md"
  fi
else
  echo "Skipping migrate."
  echo "Set SITE_NAME=<your-site> to run bench migrate automatically."
fi

echo "Staging deploy completed."
