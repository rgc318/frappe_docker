#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
STATE_ROOT="${AI_ROUTER_STATE_ROOT:-${ROOT_DIR}/artifacts/staging/ai-router}"
MAP_PATH="${AI_ROUTER_MAP_PATH:-${STATE_ROOT}/rollout.map}"
AFFINITY_MAP_PATH="${AI_ROUTER_AFFINITY_MAP_PATH:-${STATE_ROOT}/release-affinity.map}"
STATE_PATH="${AI_ROUTER_ROLLOUT_STATE_PATH:-${STATE_ROOT}/rollout-state.json}"
PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"

if [[ ! -f "${ENV_FILE}" || ! -f "${STATE_PATH}" ]]; then
  echo "Finalization requires staging.env and an active rollout-state.json." >&2
  exit 1
fi
if [[ "${STAGING_MODE}" == "https" ]]; then
  PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.https.yaml"
fi

get_env() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
}

readarray -t rollout_values < <(
  python3 - "${STATE_PATH}" <<'PY'
import json
import sys

state = json.load(open(sys.argv[1], encoding="utf-8"))
print(state.get("status") or "")
print(state.get("candidate_percent") or 0)
print(state.get("stable_release_id") or "")
print(state.get("candidate_release_id") or "")
print(state.get("candidate_replicas") or 1)
PY
)
rollout_status="${rollout_values[0]}"
candidate_percent="${rollout_values[1]}"
previous_stable_release="${rollout_values[2]}"
candidate_release="${rollout_values[3]}"
candidate_replicas="${rollout_values[4]}"
current_backend_release="$(get_env CUSTOM_TAG)"
current_ai_release="$(get_env MYAPP_AI_TAG)"
drain_seconds="${AI_ROLLOUT_DRAIN_SECONDS:-$(get_env AI_ROLLOUT_DRAIN_SECONDS)}"
drain_seconds="${drain_seconds:-86400}"

if [[ "${rollout_status}" != "active" || "${candidate_percent}" != "100" ]]; then
  echo "Only an active rollout at 100% candidate traffic can enter draining." >&2
  exit 1
fi
if [[ -z "${previous_stable_release}" || -z "${candidate_release}" ]]; then
  echo "The rollout state is missing stable or candidate release identity." >&2
  exit 1
fi
if [[ "${current_backend_release}" != "${candidate_release}" || "${current_ai_release}" != "${candidate_release}" ]]; then
  echo "Deploy the qualified Backend/AI candidate pair before entering draining." >&2
  exit 1
fi
if ! [[ "${drain_seconds}" =~ ^[0-9]+$ ]] || ((drain_seconds < 60)); then
  echo "AI_ROLLOUT_DRAIN_SECONDS must be an integer of at least 60 seconds." >&2
  exit 2
fi

export MYAPP_AI_STABLE_TAG="${previous_stable_release}"
export MYAPP_AI_CANDIDATE_TAG="${candidate_release}"
export MYAPP_AI_CANDIDATE_REPLICAS="${candidate_replicas}"

compose() {
  docker compose \
    --profile ai-rollout \
    --env-file "${ENV_FILE}" \
    -f "${ROOT_DIR}/deploy/staging/compose.staging.yaml" \
    -f "${ROOT_DIR}/overrides/compose.redis.yaml" \
    -f "${ROOT_DIR}/deploy/staging/compose.mariadb.staging.yaml" \
    -f "${PROXY_OVERRIDE}" \
    "$@"
}

backend_container="$(compose ps -q backend)"
router_container="$(compose ps -q ai-router)"
expected_stable_replicas="$(get_env MYAPP_AI_ORCHESTRATOR_REPLICAS)"
expected_stable_replicas="${expected_stable_replicas:-1}"
mapfile -t stable_container_ids < <(compose ps -q ai-orchestrator)
mapfile -t candidate_container_ids < <(compose ps -q ai-orchestrator-candidate)
if [[ -z "${backend_container}" || -z "${router_container}" ]]; then
  echo "Backend and AI Router must be running before entering draining." >&2
  exit 1
fi

backend_runtime_release="$(docker inspect --format '{{index .Config.Labels "org.rgc.release_id"}}' "${backend_container}")"
if [[ "${backend_runtime_release}" != "${candidate_release}" ]]; then
  echo "Backend container release ${backend_runtime_release:-unknown} does not match candidate ${candidate_release}." >&2
  exit 1
fi

stable_report="$(${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh \
  "${backend_container}" "http://ai-orchestrator:4010/readyz" \
  "${expected_stable_replicas}" "${stable_container_ids[@]}")"
candidate_report="$(${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh \
  "${backend_container}" "http://ai-orchestrator-candidate:4010/readyz" \
  "${candidate_replicas}" "${candidate_container_ids[@]}")"
stable_runtime_release="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["identity"]["release_id"] or "")' <<<"${stable_report}")"
candidate_runtime_release="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["identity"]["release_id"] or "")' <<<"${candidate_report}")"
if [[ "${stable_runtime_release}" != "${previous_stable_release}" || "${candidate_runtime_release}" != "${candidate_release}" ]]; then
  echo "Stable/candidate runtime identity drifted before drain activation." >&2
  exit 1
fi

state_json="$(python3 "${ROOT_DIR}/deploy/staging/set-ai-rollout.py" \
  --router-container "${router_container}" \
  --map-path "${MAP_PATH}" \
  --affinity-map-path "${AFFINITY_MAP_PATH}" \
  --state-path "${STATE_PATH}" \
  --candidate-percent 100 \
  --stable-release-id "${previous_stable_release}" \
  --candidate-release-id "${candidate_release}" \
  --stable-pool-release-id "${previous_stable_release}" \
  --candidate-replicas "${candidate_replicas}" \
  --final-status draining \
  --drain-action promote_candidate \
  --drain-seconds "${drain_seconds}")"

drain_deadline="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["drain_deadline"])' <<<"${state_json}")"
echo "AI rollout entered draining. Fresh traffic remains 100% on ${candidate_release}."
echo "Release-affined resumes for ${previous_stable_release} remain on the old stable pool until ${drain_deadline}."
