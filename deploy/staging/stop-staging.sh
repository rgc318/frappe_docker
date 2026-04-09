#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"

PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"
if [[ "${STAGING_MODE}" == "https" ]]; then
  PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.https.yaml"
fi

docker compose \
  --env-file "${ENV_FILE}" \
  -f "${ROOT_DIR}/compose.yaml" \
  -f "${ROOT_DIR}/overrides/compose.redis.yaml" \
  -f "${ROOT_DIR}/overrides/compose.mariadb.yaml" \
  -f "${PROXY_OVERRIDE}" \
  down "$@"
