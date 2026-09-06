#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
BACKEND_CONTAINER="${AI_CANARY_BACKEND_CONTAINER:-}"
REPORT_ROOT="${AI_CANARY_REPORT_ROOT:-${ROOT_DIR}/artifacts/staging/ai-canary}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

get_env() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
}

release_id="$(get_env MYAPP_AI_TAG)"
backend_tag="$(get_env CUSTOM_TAG)"
if [[ -z "${release_id}" || -z "${backend_tag}" || "${release_id}" != "${backend_tag}" ]]; then
  echo "AI canary requires matching non-empty CUSTOM_TAG and MYAPP_AI_TAG." >&2
  exit 1
fi
expected_release_id="${release_id}"
if [[ -v AI_CANARY_EXPECTED_RELEASE_ID_OVERRIDE ]]; then
  expected_release_id="${AI_CANARY_EXPECTED_RELEASE_ID_OVERRIDE}"
  if [[ "${expected_release_id}" != "${release_id}" && "${AI_CANARY_ALLOW_CANDIDATE_RELEASE:-0}" != "1" ]]; then
    echo "A different canary release ID requires AI_CANARY_ALLOW_CANDIDATE_RELEASE=1." >&2
    exit 1
  fi
fi
report_label="${AI_CANARY_REPORT_LABEL:-${expected_release_id:-mixed-runtime}}"

canary_model_alias="${AI_CANARY_MODEL_ALIAS:-$(get_env AI_CANARY_MODEL_ALIAS)}"
canary_company="${AI_CANARY_COMPANY:-$(get_env AI_CANARY_COMPANY)}"
canary_scenarios="${AI_CANARY_SCENARIOS:-$(get_env AI_CANARY_SCENARIOS)}"
canary_timeout="${AI_CANARY_TIMEOUT_SECONDS:-$(get_env AI_CANARY_TIMEOUT_SECONDS)}"
canary_retries="${AI_CANARY_TRANSIENT_RETRIES:-$(get_env AI_CANARY_TRANSIENT_RETRIES)}"
canary_base_url="${AI_CANARY_BASE_URL:-$(get_env MYAPP_AI_ORCHESTRATOR_URL)}"
REQUIRE_PASS="${AI_CANARY_REQUIRE_PASS:-$(get_env AI_CANARY_REQUIRE_PASS)}"
canary_timeout="${canary_timeout:-60}"
canary_retries="${canary_retries:-1}"
canary_base_url="${canary_base_url:-http://ai-router:4010}"
REQUIRE_PASS="${REQUIRE_PASS:-0}"

if [[ -z "${BACKEND_CONTAINER}" ]]; then
  echo "AI_CANARY_BACKEND_CONTAINER is required." >&2
  exit 1
fi

backend_revision="$(docker inspect --format '{{ index .Config.Labels "org.rgc.myapp_revision" }}' "${BACKEND_CONTAINER}" 2>/dev/null || true)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "${REPORT_ROOT}"
report_path="${AI_CANARY_REPORT_PATH:-${REPORT_ROOT}/${report_label}-${timestamp}.json}"
gate_state_path="${AI_CANARY_GATE_STATE_PATH:-${REPORT_ROOT}/current-gate-state.json}"
mkdir -p "$(dirname "${report_path}")" "$(dirname "${gate_state_path}")"
tmp_report="$(mktemp "${REPORT_ROOT}/.ai-canary.XXXXXX")"
trap 'rm -f "${tmp_report}"' EXIT

set +e
docker exec -i \
  -e AI_CANARY_BASE_URL="${canary_base_url}" \
  -e AI_CANARY_EXPECTED_RELEASE_ID="${expected_release_id}" \
  -e AI_CANARY_BACKEND_REVISION="${backend_revision}" \
  -e AI_CANARY_MODEL_ALIAS="${canary_model_alias}" \
  -e AI_CANARY_COMPANY="${canary_company}" \
  -e AI_CANARY_SCENARIOS="${canary_scenarios}" \
  -e AI_CANARY_TIMEOUT_SECONDS="${canary_timeout}" \
  -e AI_CANARY_TRANSIENT_RETRIES="${canary_retries}" \
  "${BACKEND_CONTAINER}" bash -lc \
  'cd /home/frappe/frappe-bench && env/bin/python -' \
  <"${ROOT_DIR}/deploy/staging/run-ai-canary.py" >"${tmp_report}"
runner_status=$?
set -e

if ! report_status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "${tmp_report}" 2>/dev/null)"; then
  echo "AI canary did not produce a valid JSON report." >&2
  exit 1
fi

install -m 0640 "${tmp_report}" "${report_path}"
install -m 0640 "${tmp_report}" "${gate_state_path}"
echo "AI canary report: ${report_path}"
echo "AI canary status: ${report_status}"

case "${report_status}" in
passed)
  exit 0
  ;;
partial)
  if [[ "${REQUIRE_PASS}" == "1" ]]; then
    echo "AI canary partial result is blocking because AI_CANARY_REQUIRE_PASS=1." >&2
    exit 1
  fi
  echo "AI canary recorded an external/transient partial result after its bounded retry." >&2
  exit 0
  ;;
failed)
  echo "AI canary found a deterministic failure; release progression is blocked." >&2
  exit 1
  ;;
*)
  echo "AI canary returned an unsupported status: ${report_status} (runner=${runner_status})." >&2
  exit 1
  ;;
esac
