#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Run ./deploy/staging/init-staging-server.sh first."
  exit 1
fi

SITE_NAME="${SITE_NAME:-}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
INSTALL_ERPNext="${INSTALL_ERPNEXT:-1}"
INSTALL_MYAPP="${INSTALL_MYAPP:-1}"
SET_DEFAULT_SITE="${SET_DEFAULT_SITE:-1}"

if [[ -z "${SITE_NAME}" ]]; then
  echo "SITE_NAME is required."
  echo "Example: SITE_NAME=staging.example.com ADMIN_PASSWORD='<password>' ./deploy/staging/init-site.sh"
  exit 1
fi

if [[ -z "${ADMIN_PASSWORD}" ]]; then
  echo "ADMIN_PASSWORD is required."
  exit 1
fi

db_password="$(
  grep -E '^DB_PASSWORD=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
)"

if [[ -z "${db_password}" ]]; then
  echo "DB_PASSWORD is missing in ${ENV_FILE}"
  exit 1
fi

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

echo "Ensuring staging services are up..."
compose up -d

echo "Checking whether site already exists: ${SITE_NAME}"
if compose exec backend bash -lc "bench --site ${SITE_NAME} list-apps >/dev/null 2>&1"; then
  echo "Site already exists: ${SITE_NAME}"
else
  echo "Creating site: ${SITE_NAME}"
  compose exec backend bash -lc "bench new-site ${SITE_NAME} --admin-password '${ADMIN_PASSWORD}' --db-root-password '${db_password}'"
fi

if [[ "${INSTALL_ERPNext}" == "1" ]]; then
  echo "Ensuring erpnext is installed on ${SITE_NAME}"
  if compose exec backend bash -lc "bench --site ${SITE_NAME} list-apps | grep -qx erpnext"; then
    echo "erpnext already installed."
  else
    compose exec backend bash -lc "bench --site ${SITE_NAME} install-app erpnext"
  fi
fi

if [[ "${INSTALL_MYAPP}" == "1" ]]; then
  echo "Ensuring myapp is installed on ${SITE_NAME}"
  if compose exec backend bash -lc "bench --site ${SITE_NAME} list-apps | grep -qx myapp"; then
    echo "myapp already installed."
  else
    compose exec backend bash -lc "bench --site ${SITE_NAME} install-app myapp"
  fi
fi

echo "Running migrate for ${SITE_NAME}"
compose exec backend bash -lc "bench --site ${SITE_NAME} migrate"

echo "Reconciling DB grants for ${SITE_NAME}"
SITE_NAME="${SITE_NAME}" ENV_FILE="${ENV_FILE}" STAGING_MODE="${STAGING_MODE}" \
  "${ROOT_DIR}/deploy/staging/fix-site-db-grants.sh"

if [[ "${SET_DEFAULT_SITE}" == "1" ]]; then
  echo "Setting default bench site to ${SITE_NAME}"
  compose exec backend bash -lc "bench use ${SITE_NAME}"
fi

echo "Site initialization completed: ${SITE_NAME}"
