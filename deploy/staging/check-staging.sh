#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  exit 1
fi

compose() {
  docker compose \
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

echo
echo "Staging health check completed."
