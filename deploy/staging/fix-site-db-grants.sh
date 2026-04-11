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
DB_GRANT_HOST="${DB_GRANT_HOST:-%}"
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

if [[ -z "${SITE_NAME}" ]]; then
  echo "SITE_NAME is required."
  echo "Example: SITE_NAME=staging.example.com ./deploy/staging/fix-site-db-grants.sh"
  exit 1
fi

if ! compose exec backend bash -lc "test -f sites/${SITE_NAME}/site_config.json"; then
  echo "Skipping DB grant fix because site_config.json does not exist yet: ${SITE_NAME}"
  exit 0
fi

read_site_value() {
  local key="$1"
  compose exec -T backend bash -lc "python - <<'PY'
import json
from pathlib import Path

site_name = '${SITE_NAME}'
key = '${key}'
path = Path('/home/frappe/frappe-bench/sites') / site_name / 'site_config.json'
data = json.loads(path.read_text())
value = data.get(key, '')
print(value if value is not None else '')
PY"
}

DB_NAME="$(read_site_value "db_name" | tr -d '\r')"
DB_USER="$(read_site_value "db_user" | tr -d '\r')"
DB_PASSWORD="$(read_site_value "db_password" | tr -d '\r')"

if [[ -z "${DB_NAME}" || -z "${DB_USER}" || -z "${DB_PASSWORD}" ]]; then
  echo "site_config.json is missing db_name/db_user/db_password for site: ${SITE_NAME}"
  exit 1
fi

DB_ROOT_PASSWORD="$(
  grep -E '^DB_PASSWORD=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
)"

if [[ -z "${DB_ROOT_PASSWORD}" ]]; then
  echo "DB_PASSWORD is missing in ${ENV_FILE}"
  exit 1
fi

echo "Ensuring MariaDB user grant for site ${SITE_NAME}: ${DB_USER}@${DB_GRANT_HOST}"
compose exec -T db sh -lc "MYSQL_PWD='${DB_ROOT_PASSWORD}' mariadb -uroot -e \"CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_GRANT_HOST}' IDENTIFIED BY '${DB_PASSWORD}'; ALTER USER '${DB_USER}'@'${DB_GRANT_HOST}' IDENTIFIED BY '${DB_PASSWORD}'; GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${DB_GRANT_HOST}'; FLUSH PRIVILEGES;\""

echo "DB grant reconciliation completed for site: ${SITE_NAME}"
