#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
STAGING_MODE="${STAGING_MODE:-${DEPLOY_MODE:-internal}}"
COMPOSE_BASE="${ROOT_DIR}/deploy/staging/compose.staging.yaml"
SITE_NAME="${SITE_NAME:-all}"
BACKUP_ROOT="${BACKUP_ROOT:-${ROOT_DIR}/backups/staging}"
TIMESTAMP="${TIMESTAMP:-$(date +%Y%m%d-%H%M%S)}"
ARCHIVE_NAME="${ARCHIVE_NAME:-staging-backup-${SITE_NAME}-${TIMESTAMP}.tar.gz}"
PROXY_OVERRIDE="${ROOT_DIR}/overrides/compose.noproxy.yaml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Run ./deploy/staging/init-staging-server.sh first."
  exit 1
fi

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

mkdir -p "${BACKUP_ROOT}"

echo "Ensuring staging services are up..."
compose up -d backend db redis-cache redis-queue

echo "Running bench backup for site: ${SITE_NAME}"
if [[ "${SITE_NAME}" == "all" ]]; then
  compose exec backend bash -lc "bench --site all backup --with-files"
  archive_cmd="$(cat <<EOF
set -euo pipefail
cd /home/frappe/frappe-bench
shopt -s nullglob
paths=(sites/apps.txt sites/common_site_config.json)
for site_dir in sites/*; do
  [ -d "\$site_dir" ] || continue
  site_name="\${site_dir#sites/}"
  [ "\$site_name" = assets ] && continue
  paths+=("\$site_dir/site_config.json")
  if [ -d "\$site_dir/private/backups" ]; then
    paths+=("\$site_dir/private/backups")
  fi
done
if [ "\${#paths[@]}" -eq 0 ]; then
  echo "No backup paths found."
  exit 1
fi
tar -czf "/tmp/${ARCHIVE_NAME}" "\${paths[@]}"
EOF
)"
else
  compose exec backend bash -lc "bench --site ${SITE_NAME} backup --with-files"
  archive_cmd="$(cat <<EOF
set -euo pipefail
cd /home/frappe/frappe-bench
paths=("sites/${SITE_NAME}/site_config.json" "sites/${SITE_NAME}/private/backups")
for path in "\${paths[@]}"; do
  if [ ! -e "\$path" ]; then
    echo "Missing backup path: \$path"
    exit 1
  fi
done
tar -czf "/tmp/${ARCHIVE_NAME}" -C /home/frappe/frappe-bench "sites/${SITE_NAME}/site_config.json" "sites/${SITE_NAME}/private/backups"
EOF
)"
fi

echo "Packaging backup artifacts inside backend container..."
compose exec backend bash -lc "${archive_cmd}"

backend_container="$(compose ps -q backend)"
if [[ -z "${backend_container}" ]]; then
  echo "Could not resolve backend container ID."
  exit 1
fi

echo "Copying backup archive to host: ${BACKUP_ROOT}/${ARCHIVE_NAME}"
docker cp "${backend_container}:/tmp/${ARCHIVE_NAME}" "${BACKUP_ROOT}/${ARCHIVE_NAME}"
compose exec backend bash -lc "rm -f /tmp/${ARCHIVE_NAME}"

cat > "${BACKUP_ROOT}/${ARCHIVE_NAME%.tar.gz}.metadata" <<EOF
timestamp=${TIMESTAMP}
site_name=${SITE_NAME}
archive_name=${ARCHIVE_NAME}
custom_image=$(grep -E '^CUSTOM_IMAGE=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true)
custom_tag=$(grep -E '^CUSTOM_TAG=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true)
EOF

echo "Backup completed:"
echo "${BACKUP_ROOT}/${ARCHIVE_NAME}"
