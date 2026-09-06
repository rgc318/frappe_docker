#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"
STATE_ROOT="${AI_ROUTER_STATE_ROOT:-${ROOT_DIR}/artifacts/staging/ai-router}"
MAP_PATH="${AI_ROUTER_MAP_PATH:-${STATE_ROOT}/rollout.map}"
AFFINITY_MAP_PATH="${AI_ROUTER_AFFINITY_MAP_PATH:-${STATE_ROOT}/release-affinity.map}"
STATE_PATH="${AI_ROUTER_ROLLOUT_STATE_PATH:-${STATE_ROOT}/rollout-state.json}"
REPORT_ROOT="${AI_ROLLOUT_REPORT_ROOT:-${ROOT_DIR}/artifacts/staging/ai-rollout}"
PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi
ENV_FILE="${ENV_FILE}" "${ROOT_DIR}/deploy/staging/validate-staging-env.sh"
if [[ "${STAGING_MODE}" == "https" ]]; then
  PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.https.yaml"
fi

compose() {
  docker compose \
    --profile ai-rollout \
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

stable_release_id="$(get_env MYAPP_AI_TAG)"
backend_release_id="$(get_env CUSTOM_TAG)"
candidate_release_id="${AI_ROLLOUT_CANDIDATE_TAG:-$(get_env MYAPP_AI_CANDIDATE_TAG)}"
candidate_replicas="${AI_ROLLOUT_CANDIDATE_REPLICAS:-$(get_env MYAPP_AI_CANDIDATE_REPLICAS)}"
stages_csv="${AI_ROLLOUT_STAGES:-$(get_env AI_ROLLOUT_STAGES)}"
dwell_seconds="${AI_ROLLOUT_DWELL_SECONDS:-$(get_env AI_ROLLOUT_DWELL_SECONDS)}"
sample_count="${AI_ROLLOUT_SAMPLE_COUNT:-$(get_env AI_ROLLOUT_SAMPLE_COUNT)}"
require_slo_pass="${AI_ROLLOUT_REQUIRE_SLO_PASS:-$(get_env AI_ROLLOUT_REQUIRE_SLO_PASS)}"
drain_seconds="${AI_ROLLOUT_DRAIN_SECONDS:-$(get_env AI_ROLLOUT_DRAIN_SECONDS)}"
candidate_replicas="${candidate_replicas:-1}"
stages_csv="${stages_csv:-5,25,50,100}"
dwell_seconds="${dwell_seconds:-30}"
sample_count="${sample_count:-500}"
require_slo_pass="${require_slo_pass:-0}"
drain_seconds="${drain_seconds:-86400}"
resume_percent=0
if [[ -f "${STATE_PATH}" ]]; then
  readarray -t existing_rollout < <(
    python3 - "${STATE_PATH}" <<'PY'
import json
import sys

state = json.load(open(sys.argv[1], encoding="utf-8"))
print(state.get("status") or "")
print(state.get("candidate_percent") or 0)
print(state.get("stable_release_id") or "")
print(state.get("candidate_release_id") or "")
PY
  )
  if [[ "${existing_rollout[0]}" =~ ^(draining|promoting)$ ]]; then
    echo "The previous AI rollout is ${existing_rollout[0]}; complete its drain before starting another rollout." >&2
    exit 2
  fi
  if [[ "${existing_rollout[0]}" == "active" && "${existing_rollout[1]}" != "0" ]]; then
    if [[ "${existing_rollout[2]}" != "${stable_release_id}" || "${existing_rollout[3]}" != "${candidate_release_id}" ]]; then
      echo "A different AI rollout is already active; finalize or reset it first." >&2
      exit 2
    fi
    resume_percent="${existing_rollout[1]}"
    echo "Resuming AI rollout at ${resume_percent}% candidate traffic."
  fi
fi

if [[ -z "${candidate_release_id}" || "${candidate_release_id}" == "${stable_release_id}" ]]; then
  echo "AI_ROLLOUT_CANDIDATE_TAG must identify a non-empty release different from MYAPP_AI_TAG." >&2
  exit 2
fi
if [[ -z "${stable_release_id}" || "${stable_release_id}" != "${backend_release_id}" ]]; then
  echo "The active Backend/AI release pair must be aligned before a progressive rollout." >&2
  exit 2
fi
if ! [[ "${candidate_replicas}" =~ ^[1-9]$|^10$ ]]; then
  echo "AI rollout candidate replicas must be between 1 and 10." >&2
  exit 2
fi
if ! [[ "${dwell_seconds}" =~ ^[0-9]+$ ]]; then
  echo "AI_ROLLOUT_DWELL_SECONDS must be a non-negative integer." >&2
  exit 2
fi
if ! [[ "${sample_count}" =~ ^[0-9]+$ ]] || ((sample_count < 100)); then
  echo "AI_ROLLOUT_SAMPLE_COUNT must be at least 100." >&2
  exit 2
fi
if ! [[ "${drain_seconds}" =~ ^[0-9]+$ ]] || ((drain_seconds < 60)); then
  echo "AI_ROLLOUT_DRAIN_SECONDS must be an integer of at least 60 seconds." >&2
  exit 2
fi

IFS=',' read -r -a rollout_stages <<<"${stages_csv}"
previous_stage=0
for stage in "${rollout_stages[@]}"; do
  if ! [[ "${stage}" =~ ^[0-9]+$ ]] || ((stage < 1 || stage > 100 || stage <= previous_stage)); then
    echo "AI_ROLLOUT_STAGES must be strictly increasing integers between 1 and 100." >&2
    exit 2
  fi
  previous_stage="${stage}"
done

"${ROOT_DIR}/deploy/staging/ensure-ai-router-state.sh"
mkdir -p "${REPORT_ROOT}"

backend_container="$(compose ps -q backend)"
router_container="$(compose ps -q ai-router)"
if [[ -z "${backend_container}" || -z "${router_container}" ]]; then
  echo "The active Backend and AI Router must be running before rollout." >&2
  exit 1
fi

rollback_rollout() {
  local exit_status=$?
  trap - ERR INT TERM
  set +e
  echo "AI rollout failed; restoring stable traffic to 100%." >&2
  python3 "${ROOT_DIR}/deploy/staging/set-ai-rollout.py" \
    --router-container "${router_container}" \
    --map-path "${MAP_PATH}" \
    --affinity-map-path "${AFFINITY_MAP_PATH}" \
    --state-path "${STATE_PATH}" \
    --candidate-percent 0 \
    --stable-release-id "${stable_release_id}" \
    --candidate-release-id "${candidate_release_id}" \
    --candidate-replicas "${candidate_replicas}" \
    --final-status draining \
    --drain-action retire_candidate \
    --drain-seconds "${drain_seconds}"
  echo "Candidate remains online only for release-affined resumes until drain completion." >&2
  exit "${exit_status}"
}
trap rollback_rollout ERR INT TERM

echo "Starting candidate Orchestrator release ${candidate_release_id}..."
MYAPP_AI_CANDIDATE_TAG="${candidate_release_id}" \
  MYAPP_AI_CANDIDATE_REPLICAS="${candidate_replicas}" \
  compose pull ai-orchestrator-candidate
MYAPP_AI_CANDIDATE_TAG="${candidate_release_id}" \
  MYAPP_AI_CANDIDATE_REPLICAS="${candidate_replicas}" \
  compose up -d --no-deps ai-orchestrator-candidate

mapfile -t candidate_container_ids < <(
  MYAPP_AI_CANDIDATE_TAG="${candidate_release_id}" \
    MYAPP_AI_CANDIDATE_REPLICAS="${candidate_replicas}" \
    compose ps -q ai-orchestrator-candidate
)
if [[ "${#candidate_container_ids[@]}" -ne "${candidate_replicas}" ]]; then
  echo "Candidate replica count did not converge." >&2
  false
fi

for _attempt in {1..60}; do
  ready_count=0
  for container_id in "${candidate_container_ids[@]}"; do
    health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "${container_id}")"
    [[ "${health_status}" == "healthy" ]] && ready_count=$((ready_count + 1))
  done
  [[ "${ready_count}" -eq "${candidate_replicas}" ]] && break
  sleep 2
done
if [[ "${ready_count:-0}" -ne "${candidate_replicas}" ]]; then
  echo "Candidate replicas did not become healthy within 120 seconds." >&2
  false
fi

candidate_readiness_url="http://ai-orchestrator-candidate:4010/readyz"
"${ROOT_DIR}/verify-ai-runtime-compatibility.sh" \
  "${backend_container}" "${candidate_readiness_url}"
"${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh" \
  "${backend_container}" "${candidate_readiness_url}" \
  "${candidate_replicas}" "${candidate_container_ids[@]}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
candidate_report="${REPORT_ROOT}/${candidate_release_id}-${timestamp}-candidate.json"
AI_CANARY_BACKEND_CONTAINER="${backend_container}" \
  AI_CANARY_BASE_URL="http://ai-orchestrator-candidate:4010" \
  AI_CANARY_EXPECTED_RELEASE_ID_OVERRIDE="${candidate_release_id}" \
  AI_CANARY_ALLOW_CANDIDATE_RELEASE=1 \
  AI_CANARY_REQUIRE_PASS=1 \
  AI_CANARY_REPORT_PATH="${candidate_report}" \
  "${ROOT_DIR}/deploy/staging/run-ai-canary.sh"

for stage in "${rollout_stages[@]}"; do
  if ((stage <= resume_percent)); then
    continue
  fi
  echo "Advancing AI candidate traffic to ${stage}%..."
  python3 "${ROOT_DIR}/deploy/staging/set-ai-rollout.py" \
    --router-container "${router_container}" \
    --map-path "${MAP_PATH}" \
    --affinity-map-path "${AFFINITY_MAP_PATH}" \
    --state-path "${STATE_PATH}" \
    --candidate-percent "${stage}" \
    --stable-release-id "${stable_release_id}" \
    --candidate-release-id "${candidate_release_id}" \
    --candidate-replicas "${candidate_replicas}"
  if ((dwell_seconds > 0)); then
    sleep "${dwell_seconds}"
  fi
  "${ROOT_DIR}/deploy/staging/verify-ai-router-rollout.sh" \
    "${backend_container}" "http://ai-router:4010/readyz" \
    "${MAP_PATH}" "${STATE_PATH}" "${AFFINITY_MAP_PATH}" "${sample_count}"
  stage_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  stage_report="${REPORT_ROOT}/${candidate_release_id}-${stage_timestamp}-stage-${stage}.json"
  AI_CANARY_BACKEND_CONTAINER="${backend_container}" \
    AI_CANARY_EXPECTED_RELEASE_ID_OVERRIDE="" \
    AI_CANARY_ALLOW_CANDIDATE_RELEASE=1 \
    AI_CANARY_REPORT_LABEL="${candidate_release_id}-stage-${stage}" \
    AI_CANARY_REQUIRE_PASS=1 \
    AI_CANARY_REPORT_PATH="${stage_report}" \
    "${ROOT_DIR}/deploy/staging/run-ai-canary.sh"
  AI_SLO_CANARY_REPORT_PATH="${stage_report}" \
    AI_SLO_REPORT_PATH="${REPORT_ROOT}/${candidate_release_id}-${stage_timestamp}-stage-${stage}-slo.json" \
    AI_SLO_REQUIRE_PASS="${require_slo_pass}" \
    "${ROOT_DIR}/deploy/staging/run-ai-slo-gate.sh"
done

trap - ERR INT TERM
echo "AI progressive rollout completed at ${previous_stage}% candidate traffic."
echo "The stable pool remains online; finalize the paired Backend/AI release before removing it."
