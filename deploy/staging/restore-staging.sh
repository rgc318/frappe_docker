#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"

SITE_NAME="${SITE_NAME:-}"
RESTORE_DIR="${RESTORE_DIR:-${ROOT_DIR}/tmp/restore}"
RESTORE_PREFIX="${RESTORE_PREFIX:-}"
SAFETY_BACKUP="${SAFETY_BACKUP:-1}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Run ./deploy/staging/init-staging-server.sh first."
  exit 1
fi

if [[ -z "${SITE_NAME}" ]]; then
  echo "SITE_NAME is required."
  echo "Example: SITE_NAME=staging.example.com RESTORE_DIR=/srv/frappe_docker/tmp/restore-localhost ./deploy/staging/restore-staging.sh"
  exit 1
fi

if [[ ! -d "${RESTORE_DIR}" ]]; then
  echo "Restore directory does not exist: ${RESTORE_DIR}"
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

if [[ -n "${RESTORE_PREFIX}" ]]; then
  if [[ "${RESTORE_PREFIX}" = /* ]]; then
    restore_base="${RESTORE_PREFIX}"
  else
    restore_base="${RESTORE_DIR}/${RESTORE_PREFIX}"
  fi
  db_backup="${restore_base}-database.sql.gz"
  public_backup="${restore_base}-files.tar"
  private_backup="${restore_base}-private-files.tar"
else
  db_backup="$(find "${RESTORE_DIR}" -maxdepth 1 -type f -name '*-database.sql.gz' | sort | tail -n 1)"
  if [[ -z "${db_backup}" ]]; then
    echo "No database backup found in ${RESTORE_DIR}"
    exit 1
  fi
  RESTORE_PREFIX="${db_backup%-database.sql.gz}"
  public_backup="${RESTORE_PREFIX}-files.tar"
  private_backup="${RESTORE_PREFIX}-private-files.tar"
fi

for path in "${db_backup}" "${public_backup}" "${private_backup}"; do
  if [[ ! -f "${path}" ]]; then
    echo "Missing restore artifact: ${path}"
    exit 1
  fi
done

db_backup_name="$(basename "${db_backup}")"
public_backup_name="$(basename "${public_backup}")"
private_backup_name="$(basename "${private_backup}")"

echo "Ensuring staging services are up..."
compose up -d backend db redis-cache redis-queue

if [[ "${SAFETY_BACKUP}" == "1" ]]; then
  echo "Creating safety backup for ${SITE_NAME} before restore..."
  SITE_NAME="${SITE_NAME}" "${ROOT_DIR}/deploy/staging/backup-staging.sh"
fi

backend_container="$(compose ps -q backend)"
if [[ -z "${backend_container}" ]]; then
  echo "Could not resolve backend container ID."
  exit 1
fi

echo "Copying restore artifacts into backend container..."
docker cp "${db_backup}" "${backend_container}:/tmp/${db_backup_name}"
docker cp "${public_backup}" "${backend_container}:/tmp/${public_backup_name}"
docker cp "${private_backup}" "${backend_container}:/tmp/${private_backup_name}"

restore_cmd="$(
  cat <<EOF
set -euo pipefail
cd /home/frappe/frappe-bench
bench --site ${SITE_NAME} set-maintenance-mode on || true
bench --site ${SITE_NAME} restore --force --mariadb-root-password '${db_password}' --with-public-files /tmp/${public_backup_name} --with-private-files /tmp/${private_backup_name} /tmp/${db_backup_name}
bench --site ${SITE_NAME} migrate
bench --site ${SITE_NAME} clear-cache
bench --site ${SITE_NAME} set-maintenance-mode off
rm -f /tmp/${db_backup_name} /tmp/${public_backup_name} /tmp/${private_backup_name}
EOF
)"

echo "Restoring ${SITE_NAME} from ${db_backup_name}..."
compose exec backend bash -lc "${restore_cmd}"

echo "Restore completed: ${SITE_NAME}"
