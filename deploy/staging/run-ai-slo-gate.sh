#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
CANARY_REPORT="${AI_SLO_CANARY_REPORT_PATH:-}"
REPORT_ROOT="${AI_SLO_REPORT_ROOT:-${ROOT_DIR}/artifacts/staging/ai-slo}"

if [[ ! -f "${ENV_FILE}" || ! -f "${CANARY_REPORT}" ]]; then
  echo "AI SLO gate requires ENV_FILE and AI_SLO_CANARY_REPORT_PATH." >&2
  exit 1
fi

get_env() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
}

min_success_rate="${AI_SLO_MIN_SUCCESS_RATE:-$(get_env AI_SLO_MIN_SUCCESS_RATE)}"
min_samples="${AI_SLO_MIN_SAMPLES:-$(get_env AI_SLO_MIN_SAMPLES)}"
max_p95_ms="${AI_SLO_MAX_P95_MS:-$(get_env AI_SLO_MAX_P95_MS)}"
require_pass="${AI_SLO_REQUIRE_PASS:-$(get_env AI_SLO_REQUIRE_PASS)}"
load_report="${AI_SLO_LOAD_REPORT_PATH:-$(get_env AI_SLO_LOAD_REPORT_PATH)}"
webhook_url="${AI_SLO_ALERT_WEBHOOK_URL:-$(get_env AI_SLO_ALERT_WEBHOOK_URL)}"
delivery_required="${AI_SLO_ALERT_DELIVERY_REQUIRED:-$(get_env AI_SLO_ALERT_DELIVERY_REQUIRED)}"
min_success_rate="${min_success_rate:-0.995}"
min_samples="${min_samples:-20}"
max_p95_ms="${max_p95_ms:-30000}"
require_pass="${require_pass:-0}"
delivery_required="${delivery_required:-0}"

mkdir -p "${REPORT_ROOT}"
release_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("release_id") or "unversioned")' "${CANARY_REPORT}")"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
report_path="${AI_SLO_REPORT_PATH:-${REPORT_ROOT}/${release_id}-${timestamp}.json}"
alert_state_path="${AI_SLO_ALERT_STATE_PATH:-${REPORT_ROOT}/current-alert-state.json}"
tmp_report="$(mktemp "${REPORT_ROOT}/.ai-slo.XXXXXX")"
trap 'rm -f "${tmp_report}"' EXIT

command=(
  python3 "${ROOT_DIR}/deploy/staging/evaluate-ai-slo.py"
  --canary "${CANARY_REPORT}"
  --min-success-rate "${min_success_rate}"
  --min-samples "${min_samples}"
  --max-p95-ms "${max_p95_ms}"
)
if [[ -n "${load_report}" ]]; then
  if [[ ! -f "${load_report}" ]]; then
    echo "Configured AI SLO load report does not exist: ${load_report}" >&2
    exit 1
  fi
  command+=(--load-report "${load_report}")
fi

set +e
"${command[@]}" >"${tmp_report}"
evaluator_status=$?
set -e
report_status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "${tmp_report}")"
mkdir -p "$(dirname "${report_path}")" "$(dirname "${alert_state_path}")"
install -m 0640 "${tmp_report}" "${report_path}"
install -m 0640 "${tmp_report}" "${alert_state_path}"
echo "AI SLO report: ${report_path}"
echo "AI SLO status: ${report_status}"

if [[ "${report_status}" != "passed" && -n "${webhook_url}" ]]; then
  if ! curl -fsS \
    -H 'Content-Type: application/json' \
    --data-binary "@${report_path}" \
    "${webhook_url}" >/dev/null; then
    echo "AI SLO alert webhook delivery failed." >&2
    if [[ "${delivery_required}" == "1" ]]; then
      exit 1
    fi
  else
    echo "AI SLO alert webhook delivered."
  fi
fi

case "${report_status}" in
passed)
  exit 0
  ;;
warning)
  if [[ "${require_pass}" == "1" ]]; then
    echo "AI SLO warning is blocking because AI_SLO_REQUIRE_PASS=1." >&2
    exit 1
  fi
  exit 0
  ;;
failed)
  exit 1
  ;;
*)
  echo "Unsupported AI SLO status: ${report_status} (evaluator=${evaluator_status})." >&2
  exit 1
  ;;
esac
