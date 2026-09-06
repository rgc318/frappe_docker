#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"
ROLLOUT_STATE_PATH="${AI_ROUTER_ROLLOUT_STATE_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/rollout-state.json}"
ROLLOUT_MAP_PATH="${AI_ROUTER_MAP_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/rollout.map}"
ROLLOUT_AFFINITY_MAP_PATH="${AI_ROUTER_AFFINITY_MAP_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/release-affinity.map}"
ROLLOUT_ACTIVE=0
ROLLOUT_PERCENT=0
ROLLOUT_CANDIDATE_REPLICAS=1

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  exit 1
fi

ENV_FILE="${ENV_FILE}" "${ROOT_DIR}/deploy/staging/validate-staging-env.sh"

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
  fi
fi

HOSTS="$(get_env NGINX_PROXY_HOSTS)"
HTTPS_PORT="$(get_env HTTPS_PUBLISH_PORT)"
HTTP_PORT="$(get_env HTTP_PUBLISH_PORT)"
BASE_URL="${STAGING_BASE_URL:-}"
PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"

if [[ "${STAGING_MODE}" == "https" ]]; then
  PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.https.yaml"
fi

if [[ -z "${BASE_URL}" ]]; then
  PRIMARY_HOST="${HOSTS%%,*}"
  PRIMARY_HOST="${PRIMARY_HOST%% *}"
  if [[ "${STAGING_MODE}" == "https" && -n "${PRIMARY_HOST}" ]]; then
    if [[ "${HTTPS_PORT}" == "443" || -n "${HTTPS_PORT}" ]]; then
      BASE_URL="https://${PRIMARY_HOST}"
    elif [[ -n "${HTTP_PORT}" ]]; then
      BASE_URL="http://${PRIMARY_HOST}:${HTTP_PORT}"
    else
      BASE_URL="http://${PRIMARY_HOST}"
    fi
  elif [[ -n "${HTTP_PORT}" ]]; then
    BASE_URL="http://127.0.0.1:${HTTP_PORT}"
  fi
fi

echo "== Docker services =="
compose ps

echo
echo "== AI service checks =="
LANGFUSE_REQUIRED=0
if [[ -n "$(get_env MYAPP_AI_LANGFUSE_HOST)" && -n "$(get_env MYAPP_AI_LANGFUSE_PUBLIC_KEY)" && -n "$(get_env MYAPP_AI_LANGFUSE_SECRET_KEY)" ]]; then
  LANGFUSE_REQUIRED=1
fi
mapfile -t AI_CONTAINER_IDS < <(compose ps -q ai-orchestrator)
EXPECTED_AI_REPLICAS="$(get_env MYAPP_AI_ORCHESTRATOR_REPLICAS)"
EXPECTED_AI_REPLICAS="${EXPECTED_AI_REPLICAS:-1}"
AI_ORCHESTRATOR_URL="$(get_env MYAPP_AI_ORCHESTRATOR_URL)"
AI_ORCHESTRATOR_URL="${AI_ORCHESTRATOR_URL:-http://ai-router:4010}"
for ai_container_id in "${AI_CONTAINER_IDS[@]}"; do
  docker exec -e MYAPP_AI_REQUIRE_LANGFUSE="${LANGFUSE_REQUIRED}" "${ai_container_id}" python -c \
    'import json, os, urllib.request; data=json.load(urllib.request.urlopen("http://127.0.0.1:4010/health", timeout=5)); delivery=data.get("langfuse_delivery") or {}; required=os.environ.get("MYAPP_AI_REQUIRE_LANGFUSE") == "1"; assert data.get("status") == "ok", data; assert not required or (data.get("langfuse_configured") is True and delivery.get("enabled") is True), data; summary={key: data.get(key) for key in ("status", "litellm_configured", "runtime_governance_configured", "vector_search_configured", "langfuse_configured")}; summary["langfuse_delivery_enabled"]=delivery.get("enabled"); print(json.dumps(summary, sort_keys=True))'
done

compose exec -T backend bash -lc \
  './env/bin/python -c '\''import os, urllib.request; token=os.environ["MYAPP_AI_SERVICE_TOKEN"]; base=os.environ["MYAPP_AI_ORCHESTRATOR_URL"].rstrip("/"); request=urllib.request.Request(f"{base}/internal/v1/vector/products/status", data=b"", headers={"Authorization": f"Bearer {token}"}, method="POST"); response=urllib.request.urlopen(request, timeout=10); assert response.status == 200; print("Backend to AI Router authentication: OK")'\'''

BACKEND_CONTAINER_ID="$(compose ps -q backend)"
"${ROOT_DIR}/verify-ai-runtime-compatibility.sh" \
  "${BACKEND_CONTAINER_ID}" "${AI_ORCHESTRATOR_URL%/}/readyz"
if [[ "${ROLLOUT_ACTIVE}" == "1" ]]; then
  "${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh" \
    "${BACKEND_CONTAINER_ID}" "http://ai-orchestrator:4010/readyz" \
    "${EXPECTED_AI_REPLICAS}" "${AI_CONTAINER_IDS[@]}"
  EXPECTED_CANDIDATE_REPLICAS="${ROLLOUT_CANDIDATE_REPLICAS}"
  mapfile -t AI_CANDIDATE_CONTAINER_IDS < <(compose ps -q ai-orchestrator-candidate)
  "${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh" \
    "${BACKEND_CONTAINER_ID}" "http://ai-orchestrator-candidate:4010/readyz" \
    "${EXPECTED_CANDIDATE_REPLICAS}" "${AI_CANDIDATE_CONTAINER_IDS[@]}"
  "${ROOT_DIR}/deploy/staging/verify-ai-router-rollout.sh" \
    "${BACKEND_CONTAINER_ID}" "${AI_ORCHESTRATOR_URL%/}/readyz" \
    "${ROLLOUT_MAP_PATH}" "${ROLLOUT_STATE_PATH}" "${ROLLOUT_AFFINITY_MAP_PATH}"
else
  "${ROOT_DIR}/deploy/staging/verify-ai-replica-set.sh" \
    "${BACKEND_CONTAINER_ID}" "${AI_ORCHESTRATOR_URL%/}/readyz" \
    "${EXPECTED_AI_REPLICAS}" "${AI_CONTAINER_IDS[@]}"
fi

AGENT_RUNTIME_ENABLED="$(get_env MYAPP_AI_AGENT_RUNTIME_ENABLED)"
AGENT_RUNTIME_ENABLED="${AGENT_RUNTIME_ENABLED:-1}"
if [[ "${AGENT_RUNTIME_ENABLED,,}" =~ ^(1|true|yes)$ ]]; then
  POLICY_SITE_HOST="$(get_env MYAPP_AI_FRAPPE_SITE_HOST)"
  compose exec -T -e MYAPP_AI_POLICY_SITE_HOST="${POLICY_SITE_HOST}" backend bash -lc \
    './env/bin/python -' <"${ROOT_DIR}/deploy/staging/check-ai-runtime-policy.py"
fi

AI_CONTAINER_ID=""
canary_report=""
canary_status=""
slo_status=""
if [[ "${RUN_AI_STAGING_CANARY:-0}" == "1" ]]; then
  echo
  echo "== AI scenario canary =="
  AI_CONTAINER_ID="${AI_CONTAINER_IDS[0]}"
  release_id="$(get_env MYAPP_AI_TAG)"
  canary_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
  canary_report="${AI_CANARY_REPORT_PATH:-${ROOT_DIR}/artifacts/staging/ai-canary/${release_id}-${canary_timestamp}.json}"
  set +e
  if [[ "${ROLLOUT_ACTIVE}" == "1" ]]; then
    AI_CANARY_BACKEND_CONTAINER="${BACKEND_CONTAINER_ID}" \
      AI_CANARY_EXPECTED_RELEASE_ID_OVERRIDE="" \
      AI_CANARY_ALLOW_CANDIDATE_RELEASE=1 \
      AI_CANARY_REPORT_LABEL="rollout-stage-${ROLLOUT_PERCENT}" \
      AI_CANARY_REPORT_PATH="${canary_report}" \
      "${ROOT_DIR}/deploy/staging/run-ai-canary.sh"
  else
    AI_CANARY_BACKEND_CONTAINER="${BACKEND_CONTAINER_ID}" \
      AI_CANARY_REPORT_PATH="${canary_report}" \
      "${ROOT_DIR}/deploy/staging/run-ai-canary.sh"
  fi
  canary_gate_exit=$?
  set -e
  canary_status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "${canary_report}")"
  slo_alert_state="${AI_SLO_ALERT_STATE_PATH:-${ROOT_DIR}/artifacts/staging/ai-slo/current-alert-state.json}"
  set +e
  AI_SLO_CANARY_REPORT_PATH="${canary_report}" \
    AI_SLO_ALERT_STATE_PATH="${slo_alert_state}" \
    "${ROOT_DIR}/deploy/staging/run-ai-slo-gate.sh"
  slo_gate_exit=$?
  set -e
  slo_status="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["status"])' "${slo_alert_state}")"
  if [[ "${canary_gate_exit}" -ne 0 || "${slo_gate_exit}" -ne 0 ]]; then
    echo "AI release gate blocked: canary=${canary_status}, slo=${slo_status}." >&2
    exit 1
  fi
  if [[ "${canary_status}" != "passed" ]]; then
    echo "AI canary status is ${canary_status}; this candidate is not recorded as a rollback target."
  fi
else
  echo
  echo "Skipping AI scenario canary. Set RUN_AI_STAGING_CANARY=1 to enable it."
fi

if [[ -z "${BASE_URL}" ]]; then
  echo
  echo "Skipping HTTP checks because no base URL could be inferred."
  echo "Set STAGING_BASE_URL explicitly if needed."
  exit 0
fi

echo
echo "== HTTP checks =="
echo "Base URL: ${BASE_URL}"

set +e
homepage_status="$(curl -ksS -o /dev/null -w '%{http_code}' "${BASE_URL}")"
ping_status="$(curl -ksS -o /dev/null -w '%{http_code}' "${BASE_URL}/api/method/ping")"
set -e

if [[ "${homepage_status}" == "404" && "${ping_status}" == "404" ]]; then
  echo "HTTP endpoint is reachable, but the staging site is not initialized yet."
  echo "Finish first-time site creation by following deploy/staging/INIT_SITE.zh-CN.md"
  exit 0
fi

if [[ "${homepage_status}" =~ ^[23] ]]; then
  echo "Homepage: OK (${homepage_status})"
else
  echo "Homepage check failed with status ${homepage_status}"
  exit 1
fi

if [[ "${ping_status}" =~ ^[23] ]]; then
  echo "Ping API: OK (${ping_status})"
else
  echo "Ping API check failed with status ${ping_status}"
  exit 1
fi

if [[ "${RUN_STAGING_HTTP_REGRESSION:-0}" == "1" ]]; then
  echo
  ./deploy/staging/run-critical-http-regression.sh
else
  echo
  echo "Skipping critical HTTP regression. Set RUN_STAGING_HTTP_REGRESSION=1 to enable it."
fi

if [[ "${canary_status}" == "passed" && "${ROLLOUT_ACTIVE}" != "1" ]]; then
  echo
  echo "== Qualify immutable Backend/AI release pair =="
  RELEASE_PAIR_BACKEND_CONTAINER="${BACKEND_CONTAINER_ID}" \
    RELEASE_PAIR_AI_CONTAINER="${AI_CONTAINER_ID}" \
    AI_CANARY_REPORT_PATH="${canary_report}" \
    "${ROOT_DIR}/deploy/staging/record-staging-release-pair.sh"
fi

echo
echo "Staging health check completed."
