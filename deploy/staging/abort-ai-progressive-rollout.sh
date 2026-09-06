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
  echo "Rollout abort requires staging.env and rollout-state.json." >&2
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
print(state.get("stable_release_id") or "")
print(state.get("candidate_release_id") or "")
print(state.get("candidate_replicas") or 1)
PY
)
rollout_status="${rollout_values[0]}"
stable_release="${rollout_values[1]}"
candidate_release="${rollout_values[2]}"
candidate_replicas="${rollout_values[3]}"
drain_seconds="${AI_ROLLOUT_DRAIN_SECONDS:-$(get_env AI_ROLLOUT_DRAIN_SECONDS)}"
drain_seconds="${drain_seconds:-86400}"
if [[ ! "${rollout_status}" =~ ^(active|draining|promoting)$ ]]; then
  echo "Only an active, draining, or promoting rollout can be aborted." >&2
  exit 1
fi
if [[ -z "${stable_release}" || -z "${candidate_release}" ]]; then
  echo "Rollout state is missing stable or candidate release identity." >&2
  exit 1
fi
if ! [[ "${drain_seconds}" =~ ^[0-9]+$ ]] || ((drain_seconds < 60)); then
  echo "AI_ROLLOUT_DRAIN_SECONDS must be an integer of at least 60 seconds." >&2
  exit 2
fi

export MYAPP_AI_STABLE_TAG="${stable_release}"
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
if [[ -z "${backend_container}" || -z "${router_container}" ]]; then
  echo "Backend and AI Router must be running before rollout abort." >&2
  exit 1
fi

# Keep current routed traffic on candidate while the previous stable image is
# restored. HAProxy readiness fallback prevents fresh-request downtime.
compose pull ai-orchestrator
compose up -d --no-deps --force-recreate ai-orchestrator
expected_stable_replicas="$(get_env MYAPP_AI_ORCHESTRATOR_REPLICAS)"
expected_stable_replicas="${expected_stable_replicas:-1}"
for _attempt in {1..60}; do
  mapfile -t stable_container_ids < <(compose ps -q ai-orchestrator)
  ready_count=0
  for container_id in "${stable_container_ids[@]}"; do
    health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "${container_id}")"
    [[ "${health_status}" == "healthy" ]] && ready_count=$((ready_count + 1))
  done
  [[ "${#stable_container_ids[@]}" -eq "${expected_stable_replicas}" && "${ready_count}" -eq "${expected_stable_replicas}" ]] && break
  sleep 2
done
if [[ "${ready_count:-0}" -ne "${expected_stable_replicas}" ]]; then
  echo "Previous stable replicas did not recover within 120 seconds." >&2
  exit 1
fi

stable_report="$(${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh \
  "${backend_container}" "http://ai-orchestrator:4010/readyz" \
  "${expected_stable_replicas}" "${stable_container_ids[@]}")"
stable_runtime_release="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["identity"]["release_id"] or "")' <<<"${stable_report}")"
if [[ "${stable_runtime_release}" != "${stable_release}" ]]; then
  echo "Recovered stable pool does not match ${stable_release}." >&2
  exit 1
fi

python3 "${ROOT_DIR}/deploy/staging/set-ai-rollout.py" \
  --router-container "${router_container}" \
  --map-path "${MAP_PATH}" \
  --affinity-map-path "${AFFINITY_MAP_PATH}" \
  --state-path "${STATE_PATH}" \
  --candidate-percent 0 \
  --stable-release-id "${stable_release}" \
  --stable-pool-release-id "${stable_release}" \
  --candidate-replicas "${candidate_replicas}" \
  --final-status draining \
  --drain-action retire_candidate \
  --drain-seconds "${drain_seconds}" >/dev/null

echo "AI rollout aborted. Fresh traffic is restored to ${stable_release}."
echo "Candidate ${candidate_release} remains online only for release-affined resumes until drain completion."
