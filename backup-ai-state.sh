#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AI_ENV_FILE="${AI_ENV_FILE:-${ROOT_DIR}/.env.ai.local}"
LANGFUSE_ENV_FILE="${LANGFUSE_ENV_FILE:-${ROOT_DIR}/.env.langfuse.local}"
BACKUP_ROOT="${BACKUP_ROOT:-${ROOT_DIR}/backups/ai}"
TIMESTAMP="${TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
BACKUP_DIR="${BACKUP_DIR:-${BACKUP_ROOT}/${TIMESTAMP}}"
QDRANT_COLLECTION="${QDRANT_COLLECTION:-myapp-products-v1}"
AI_TOOL_IMAGE="${AI_TOOL_IMAGE:-frappe_docker-ai-orchestrator}"
DOCKER_CONFIG="${DOCKER_CONFIG:-/tmp/myapp-docker-config}"

for file in "${ROOT_DIR}/.env" "${AI_ENV_FILE}" "${LANGFUSE_ENV_FILE}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing required env file: ${file}" >&2
    exit 1
  fi
done
LANGFUSE_ENV_FILE="${LANGFUSE_ENV_FILE}" "${ROOT_DIR}/sync-langfuse-runtime-env.sh" >/dev/null

compose() {
  DOCKER_CONFIG="${DOCKER_CONFIG}" docker compose \
    --env-file "${ROOT_DIR}/.env" \
    --env-file "${AI_ENV_FILE}" \
    --env-file "${LANGFUSE_ENV_FILE}" \
    -f "${ROOT_DIR}/compose.yaml" \
    -f "${ROOT_DIR}/overrides/compose.langfuse.yaml" \
    "$@"
}

mkdir -p "${DOCKER_CONFIG}" "${BACKUP_DIR}"
chmod 700 "${BACKUP_DIR}"
config_file="$(mktemp)"
trap 'rm -f "${config_file}"' EXIT
compose config --format json >"${config_file}"

config_value() {
  python3 - "$config_file" "$1" "$2" <<'PY'
import json
import sys

config = json.load(open(sys.argv[1], encoding="utf-8"))
section, key = sys.argv[2], sys.argv[3]
print(config[section][key]["name"])
PY
}

network_name="$(config_value networks default)"
postgres_volume="$(config_value volumes langfuse-postgres-data)"
clickhouse_volume="$(config_value volumes langfuse-clickhouse-data)"
minio_volume="$(config_value volumes langfuse-minio-data)"
redis_volume="$(config_value volumes langfuse-redis-data)"

postgres_container="$(compose ps -q langfuse-postgres)"
clickhouse_container="$(compose ps -q langfuse-clickhouse)"
minio_container="$(compose ps -q langfuse-minio)"
if [[ -z "${postgres_container}" || -z "${clickhouse_container}" || -z "${minio_container}" ]]; then
  echo "Langfuse dependency containers must be running before backup." >&2
  exit 1
fi

postgres_projects="$(docker exec "${postgres_container}" sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select count(*) from projects"')"
clickhouse_traces="$(docker exec "${clickhouse_container}" sh -lc 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM traces"')"
clickhouse_observations="$(docker exec "${clickhouse_container}" sh -lc 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM observations"')"
minio_objects="$(docker exec "${minio_container}" sh -lc 'mc alias set local http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && mc ls --recursive local/langfuse | wc -l')"

docker run --rm --network "${network_name}" --user "$(id -u):$(id -g)" \
  -v "${ROOT_DIR}/services/myapp-ai/scripts:/scripts:ro" \
  -v "${BACKUP_DIR}:/backup" \
  "${AI_TOOL_IMAGE}" python /scripts/qdrant_snapshot.py backup \
  --url http://ai-vector:6333 \
  --collection "${QDRANT_COLLECTION}" \
  --output "/backup/${QDRANT_COLLECTION}.snapshot" \
  >"${BACKUP_DIR}/qdrant.json"

stack_stopped=0
restart_stack() {
  if [[ "${stack_stopped}" == "1" ]]; then
    compose up -d \
      langfuse-postgres langfuse-clickhouse langfuse-redis langfuse-minio \
      langfuse-web langfuse-worker >/dev/null
  fi
}
trap 'restart_stack; rm -f "${config_file}"' EXIT

compose stop langfuse-web langfuse-worker
compose stop langfuse-postgres langfuse-clickhouse langfuse-redis langfuse-minio
stack_stopped=1

archive_volume() {
  local volume_name="$1"
  local archive_name="$2"
  docker run --rm --user 0:0 \
    -v "${volume_name}:/source:ro" \
    -v "${BACKUP_DIR}:/backup" \
    "${AI_TOOL_IMAGE}" \
    tar -C /source -czf "/backup/${archive_name}" .
}

archive_volume "${postgres_volume}" langfuse-postgres.tar.gz
archive_volume "${clickhouse_volume}" langfuse-clickhouse.tar.gz
archive_volume "${minio_volume}" langfuse-minio.tar.gz
archive_volume "${redis_volume}" langfuse-redis.tar.gz

restart_stack
stack_stopped=0

env_fingerprint="$(sha256sum "${LANGFUSE_ENV_FILE}" | awk '{print $1}')"
python3 - "${BACKUP_DIR}" "${TIMESTAMP}" "${QDRANT_COLLECTION}" \
  "${postgres_projects}" "${clickhouse_traces}" "${clickhouse_observations}" \
  "${minio_objects}" "${env_fingerprint}" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

backup_dir = Path(sys.argv[1])
files = {}
for path in sorted(backup_dir.iterdir()):
    if path.name == "manifest.json" or not path.is_file():
        continue
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    files[path.name] = {"sha256": digest, "bytes": path.stat().st_size}
qdrant = json.loads((backup_dir / "qdrant.json").read_text(encoding="utf-8"))
manifest = {
    "schema": "myapp-ai-backup-manifest-v1",
    "created_at": sys.argv[2],
    "consistency": "Langfuse Web/Worker and PostgreSQL/ClickHouse/Redis/MinIO stopped cleanly during volume archive",
    "qdrant": qdrant,
    "source_counts": {
        "postgres_projects": int(sys.argv[4]),
        "clickhouse_traces": int(sys.argv[5]),
        "clickhouse_observations": int(sys.argv[6]),
        "minio_objects": int(sys.argv[7]),
    },
    "langfuse_secret_file_sha256": sys.argv[8],
    "secrets_included": False,
    "files": files,
}
(backup_dir / "manifest.json").write_text(
    json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
PY

echo "AI backup completed: ${BACKUP_DIR}"
echo "Secrets were not copied; restore requires the matching external Langfuse secret file."
