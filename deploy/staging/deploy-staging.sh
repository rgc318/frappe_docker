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

SITE_NAME="${SITE_NAME:-}"
SKIP_MIGRATE="${SKIP_MIGRATE:-0}"
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

echo "Pulling latest staging images..."
compose pull

echo "Restarting staging stack..."
compose up -d

if [[ -n "${SITE_NAME}" && "${SKIP_MIGRATE}" != "1" ]]; then
  echo "Checking site before migrate: ${SITE_NAME}"
  if compose exec backend bash -lc "bench --site ${SITE_NAME} list-apps >/dev/null 2>&1"; then
    echo "Running bench migrate for site: ${SITE_NAME}"
    compose exec backend bash -lc "bench --site ${SITE_NAME} migrate"
  else
    echo "Skipping migrate because site does not exist yet: ${SITE_NAME}"
    echo "Initialize the site first by following deploy/staging/INIT_SITE.zh-CN.md"
  fi
else
  echo "Skipping migrate."
  echo "Set SITE_NAME=<your-site> to run bench migrate automatically."
fi

echo "Staging deploy completed."
