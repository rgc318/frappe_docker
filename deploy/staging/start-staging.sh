#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"

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
    --env-file "${ENV_FILE}" \
    -f "${COMPOSE_BASE}" \
    -f "${ROOT_DIR}/overrides/compose.redis.yaml" \
    -f "${ROOT_DIR}/deploy/staging/compose.mariadb.staging.yaml" \
    -f "${PROXY_OVERRIDE}" \
    "$@"
}

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
