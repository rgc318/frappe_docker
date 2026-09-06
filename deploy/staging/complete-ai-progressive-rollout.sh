#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
STATE_ROOT="${AI_ROUTER_STATE_ROOT:-${ROOT_DIR}/artifacts/staging/ai-router}"
MAP_PATH="${AI_ROUTER_MAP_PATH:-${STATE_ROOT}/rollout.map}"
AFFINITY_MAP_PATH="${AI_ROUTER_AFFINITY_MAP_PATH:-${STATE_ROOT}/release-affinity.map}"
STATE_PATH="${AI_ROUTER_ROLLOUT_STATE_PATH:-${STATE_ROOT}/rollout-state.json}"
FORCE_COMPLETE="${AI_ROLLOUT_FORCE_COMPLETE:-0}"
PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"

if [[ ! -f "${ENV_FILE}" || ! -f "${STATE_PATH}" ]]; then
  echo "Drain completion requires staging.env and rollout-state.json." >&2
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
print(state.get("drain_started_at") or "")
print(state.get("drain_deadline") or "")
print(state.get("drain_action") or "")
PY
)
rollout_status="${rollout_values[0]}"
candidate_percent="${rollout_values[1]}"
previous_stable_release="${rollout_values[2]}"
candidate_release="${rollout_values[3]}"
candidate_replicas="${rollout_values[4]}"
drain_started_at="${rollout_values[5]}"
drain_deadline="${rollout_values[6]}"
drain_action="${rollout_values[7]}"

if [[ ! "${rollout_status}" =~ ^(draining|promoting)$ ]]; then
  echo "Only a draining or promoting rollout can be completed." >&2
  exit 1
fi
if [[ -z "${previous_stable_release}" || -z "${candidate_release}" || -z "${drain_deadline}" ]]; then
  echo "The rollout state is missing drain or release identity." >&2
  exit 1
fi
if [[ "${drain_action}" == "promote_candidate" && "${candidate_percent}" != "100" ]]; then
  echo "Candidate promotion requires 100% candidate traffic." >&2
  exit 1
fi
if [[ "${drain_action}" == "retire_candidate" && "${candidate_percent}" != "0" ]]; then
  echo "Candidate retirement requires 0% candidate traffic." >&2
  exit 1
fi
if [[ ! "${drain_action}" =~ ^(promote_candidate|retire_candidate)$ ]]; then
  echo "The rollout state has an invalid drain action." >&2
  exit 1
fi
expected_active_release="${candidate_release}"
if [[ "${drain_action}" == "retire_candidate" ]]; then
  expected_active_release="${previous_stable_release}"
fi
if [[ "$(get_env CUSTOM_TAG)" != "${expected_active_release}" || "$(get_env MYAPP_AI_TAG)" != "${expected_active_release}" ]]; then
  echo "The active Backend/AI tags no longer match ${expected_active_release}." >&2
  exit 1
fi
if [[ "${FORCE_COMPLETE}" != "1" ]]; then
  if ! python3 - "${drain_deadline}" <<'PY'
from datetime import UTC, datetime
import sys

deadline = datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
raise SystemExit(0 if datetime.now(UTC) >= deadline else 1)
PY
  then
    echo "AI release drain is still active until ${drain_deadline}." >&2
    echo "Use AI_ROLLOUT_FORCE_COMPLETE=1 only for documented emergency retirement." >&2
    exit 2
  fi
fi

export MYAPP_AI_CANDIDATE_TAG="${candidate_release}"
export MYAPP_AI_CANDIDATE_REPLICAS="${candidate_replicas}"
if [[ "${rollout_status}" == "promoting" ]]; then
  export MYAPP_AI_STABLE_TAG="${candidate_release}"
else
  export MYAPP_AI_STABLE_TAG="${previous_stable_release}"
fi

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
mapfile -t candidate_container_ids < <(compose ps -q ai-orchestrator-candidate)
if [[ -z "${backend_container}" || -z "${router_container}" ]]; then
  echo "Backend and AI Router must be running before drain completion." >&2
  exit 1
fi
backend_runtime_release="$(docker inspect --format '{{index .Config.Labels "org.rgc.release_id"}}' "${backend_container}")"
if [[ "${backend_runtime_release}" != "${expected_active_release}" ]]; then
  echo "Backend runtime release does not match ${expected_active_release}." >&2
  exit 1
fi

if [[ "${drain_action}" == "retire_candidate" ]]; then
  expected_stable_replicas="$(get_env MYAPP_AI_ORCHESTRATOR_REPLICAS)"
  expected_stable_replicas="${expected_stable_replicas:-1}"
  mapfile -t stable_container_ids < <(compose ps -q ai-orchestrator)
  stable_report="$(${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh \
    "${backend_container}" "http://ai-orchestrator:4010/readyz" \
    "${expected_stable_replicas}" "${stable_container_ids[@]}")"
  stable_runtime_release="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["identity"]["release_id"] or "")' <<<"${stable_report}")"
  if [[ "${stable_runtime_release}" != "${previous_stable_release}" ]]; then
    echo "Stable pool did not remain on ${previous_stable_release}." >&2
    exit 1
  fi
  python3 "${ROOT_DIR}/deploy/staging/set-ai-rollout.py" \
    --router-container "${router_container}" \
    --map-path "${MAP_PATH}" \
    --affinity-map-path "${AFFINITY_MAP_PATH}" \
    --state-path "${STATE_PATH}" \
    --candidate-percent 0 \
    --stable-release-id "${previous_stable_release}" \
    --stable-pool-release-id "${previous_stable_release}" \
    --candidate-replicas "${candidate_replicas}" \
    --retired-release-id "${candidate_release}" \
    --final-status completed >/dev/null
  compose stop ai-orchestrator-candidate
  "${ROOT_DIR}/verify-ai-runtime-compatibility.sh" \
    "${backend_container}" "http://ai-router:4010/readyz"
  echo "AI rollback drain completed. Stable serves ${previous_stable_release}; ${candidate_release} is retired."
  exit 0
fi

candidate_report="$(${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh \
  "${backend_container}" "http://ai-orchestrator-candidate:4010/readyz" \
  "${candidate_replicas}" "${candidate_container_ids[@]}")"
candidate_runtime_release="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["identity"]["release_id"] or "")' <<<"${candidate_report}")"
if [[ "${candidate_runtime_release}" != "${candidate_release}" ]]; then
  echo "Candidate runtime identity drifted before promotion." >&2
  exit 1
fi

if [[ "${rollout_status}" == "draining" ]]; then
  python3 "${ROOT_DIR}/deploy/staging/set-ai-rollout.py" \
    --router-container "${router_container}" \
    --map-path "${MAP_PATH}" \
    --affinity-map-path "${AFFINITY_MAP_PATH}" \
    --state-path "${STATE_PATH}" \
    --candidate-percent 100 \
    --stable-release-id "${previous_stable_release}" \
    --candidate-release-id "${candidate_release}" \
    --stable-pool-release-id "${candidate_release}" \
    --candidate-replicas "${candidate_replicas}" \
    --disable-stable-affinity \
    --drain-started-at "${drain_started_at}" \
    --drain-deadline "${drain_deadline}" \
    --drain-action promote_candidate \
    --final-status promoting >/dev/null
fi

# From this point onward, old-release affinity fails closed. Candidate remains the
# sole fresh/resume target while the stable service converges to the new release.
export MYAPP_AI_STABLE_TAG="${candidate_release}"
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
  echo "Promoted stable replicas did not become healthy within 120 seconds." >&2
  exit 1
fi

stable_report="$(${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh \
  "${backend_container}" "http://ai-orchestrator:4010/readyz" \
  "${expected_stable_replicas}" "${stable_container_ids[@]}")"
stable_runtime_release="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["identity"]["release_id"] or "")' <<<"${stable_report}")"
if [[ "${stable_runtime_release}" != "${candidate_release}" ]]; then
  echo "Promoted stable pool did not converge to ${candidate_release}." >&2
  exit 1
fi

python3 "${ROOT_DIR}/deploy/staging/set-ai-rollout.py" \
  --router-container "${router_container}" \
  --map-path "${MAP_PATH}" \
  --affinity-map-path "${AFFINITY_MAP_PATH}" \
  --state-path "${STATE_PATH}" \
  --candidate-percent 0 \
  --stable-release-id "${candidate_release}" \
  --stable-pool-release-id "${candidate_release}" \
  --candidate-replicas "${candidate_replicas}" \
  --retired-release-id "${previous_stable_release}" \
  --final-status completed >/dev/null

compose stop ai-orchestrator-candidate
"${ROOT_DIR}/verify-ai-runtime-compatibility.sh" \
  "${backend_container}" "http://ai-router:4010/readyz"
echo "AI rollout completed. Stable serves ${candidate_release}; ${previous_stable_release} is retired."
