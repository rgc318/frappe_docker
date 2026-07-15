#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AI_ENV_FILE="${AI_ENV_FILE:-${ROOT_DIR}/.env.ai.local}"
LANGFUSE_ENV_FILE="${LANGFUSE_ENV_FILE:-${ROOT_DIR}/.env.langfuse.local}"
BACKUP_DIR="${1:-}"
REPORT_DIR="${REPORT_DIR:-${ROOT_DIR}/ai-recovery-reports}"
TIMESTAMP="${TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"
PROJECT="${RESTORE_PROJECT:-myapp-ai-restore-${TIMESTAMP,,}}"
LANGFUSE_PORT="${RESTORE_LANGFUSE_PORT:-13001}"
MINIO_PORT="${RESTORE_MINIO_PORT:-19091}"
AI_TOOL_IMAGE="${AI_TOOL_IMAGE:-frappe_docker-ai-orchestrator}"
DOCKER_CONFIG="${DOCKER_CONFIG:-/tmp/myapp-docker-config}"
QDRANT_RESTORE_COLLECTION="${QDRANT_RESTORE_COLLECTION:-myapp-products-restore-${TIMESTAMP,,}}"

if [[ -z "${BACKUP_DIR}" || ! -f "${BACKUP_DIR}/manifest.json" ]]; then
  echo "Usage: $0 /path/to/ai-backup-directory" >&2
  exit 2
fi
BACKUP_DIR="$(cd -- "${BACKUP_DIR}" && pwd)"
for file in "${ROOT_DIR}/.env" "${AI_ENV_FILE}" "${LANGFUSE_ENV_FILE}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing required env file: ${file}" >&2
    exit 1
  fi
done

compose_restore() {
  LANGFUSE_PORT="${LANGFUSE_PORT}" LANGFUSE_MINIO_PORT="${MINIO_PORT}" \
  DOCKER_CONFIG="${DOCKER_CONFIG}" docker compose -p "${PROJECT}" \
    --env-file "${ROOT_DIR}/.env" \
    --env-file "${AI_ENV_FILE}" \
    --env-file "${LANGFUSE_ENV_FILE}" \
    -f "${ROOT_DIR}/compose.yaml" \
    -f "${ROOT_DIR}/overrides/compose.langfuse.yaml" \
    "$@"
}

mkdir -p "${DOCKER_CONFIG}" "${REPORT_DIR}"
python3 - "${BACKUP_DIR}" "${LANGFUSE_ENV_FILE}" <<'PY'
import hashlib
import json
from pathlib import Path
import sys

backup_dir = Path(sys.argv[1])
manifest = json.loads((backup_dir / "manifest.json").read_text(encoding="utf-8"))
for name, metadata in manifest["files"].items():
    path = backup_dir / name
    if not path.is_file():
        raise SystemExit(f"Missing backup artifact: {name}")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != metadata["sha256"]:
        raise SystemExit(f"Checksum mismatch: {name}")
secret_digest = hashlib.sha256(Path(sys.argv[2]).read_bytes()).hexdigest()
if secret_digest != manifest["langfuse_secret_file_sha256"]:
    raise SystemExit("Langfuse secret file fingerprint does not match this backup")
PY

config_file="$(mktemp)"
LANGFUSE_PORT="${LANGFUSE_PORT}" LANGFUSE_MINIO_PORT="${MINIO_PORT}" compose_restore config --format json >"${config_file}"
volume_name() {
  python3 - "${config_file}" "$1" <<'PY'
import json
import sys
config = json.load(open(sys.argv[1], encoding="utf-8"))
print(config["volumes"][sys.argv[2]]["name"])
PY
}

postgres_volume="$(volume_name langfuse-postgres-data)"
clickhouse_volume="$(volume_name langfuse-clickhouse-data)"
minio_volume="$(volume_name langfuse-minio-data)"
redis_volume="$(volume_name langfuse-redis-data)"
network_name="$(python3 - "${config_file}" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["networks"]["default"]["name"])
PY
)"
rm -f "${config_file}"

cleanup() {
  docker run --rm --network frappe_docker_default \
    -v "${ROOT_DIR}/services/myapp-ai/scripts:/scripts:ro" \
    "${AI_TOOL_IMAGE}" python /scripts/qdrant_snapshot.py delete \
    --url http://ai-vector:6333 --collection "${QDRANT_RESTORE_COLLECTION}" >/dev/null 2>&1 || true
  compose_restore down -v --remove-orphans >/dev/null 2>&1 || true
  docker volume rm -f "${postgres_volume}" "${clickhouse_volume}" "${minio_volume}" "${redis_volume}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for volume in "${postgres_volume}" "${clickhouse_volume}" "${minio_volume}" "${redis_volume}"; do
  docker volume create "${volume}" >/dev/null
done

restore_volume() {
  local volume_name="$1"
  local archive_name="$2"
  docker run --rm --user 0:0 \
    -v "${volume_name}:/target" \
    -v "${BACKUP_DIR}:/backup:ro" \
    "${AI_TOOL_IMAGE}" \
    tar -C /target -xzf "/backup/${archive_name}"
}

restore_volume "${postgres_volume}" langfuse-postgres.tar.gz
restore_volume "${clickhouse_volume}" langfuse-clickhouse.tar.gz
restore_volume "${minio_volume}" langfuse-minio.tar.gz
restore_volume "${redis_volume}" langfuse-redis.tar.gz

compose_restore up -d \
  langfuse-postgres langfuse-clickhouse langfuse-redis langfuse-minio \
  langfuse-web langfuse-worker

healthy=0
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:${LANGFUSE_PORT}/api/public/health" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ "${healthy}" != "1" ]]; then
  echo "Restored Langfuse stack did not become healthy." >&2
  exit 1
fi

postgres_container="$(compose_restore ps -q langfuse-postgres)"
clickhouse_container="$(compose_restore ps -q langfuse-clickhouse)"
minio_container="$(compose_restore ps -q langfuse-minio)"
postgres_projects="$(docker exec "${postgres_container}" sh -lc 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "select count(*) from projects"')"
clickhouse_traces="$(docker exec "${clickhouse_container}" sh -lc 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM traces"')"
clickhouse_observations="$(docker exec "${clickhouse_container}" sh -lc 'clickhouse-client --user "$CLICKHOUSE_USER" --password "$CLICKHOUSE_PASSWORD" --query "SELECT count() FROM observations"')"
minio_objects="$(docker exec "${minio_container}" sh -lc 'mc alias set restored http://127.0.0.1:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null && mc ls --recursive restored/langfuse | wc -l')"

langfuse_api_total="$(docker run --rm -i --network "${network_name}" --env-file "${LANGFUSE_ENV_FILE}" \
  "${AI_TOOL_IMAGE}" python - <<'PY'
import os
import httpx
auth = httpx.BasicAuth(os.environ["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"], os.environ["LANGFUSE_INIT_PROJECT_SECRET_KEY"])
response = httpx.get("http://langfuse-web:3000/api/public/traces", auth=auth, params={"limit": 1}, timeout=20)
response.raise_for_status()
print(int((response.json().get("meta") or {}).get("totalItems") or 0))
PY
)"

qdrant_snapshot_file="$(python3 - "${BACKUP_DIR}/manifest.json" <<'PY'
import json
import sys
print(json.load(open(sys.argv[1], encoding="utf-8"))["qdrant"]["snapshot_file"])
PY
)"
docker run --rm --network frappe_docker_default --user "$(id -u):$(id -g)" \
  -v "${ROOT_DIR}/services/myapp-ai/scripts:/scripts:ro" \
  -v "${BACKUP_DIR}:/backup:ro" \
  "${AI_TOOL_IMAGE}" python /scripts/qdrant_snapshot.py restore \
  --url http://ai-vector:6333 \
  --collection "${QDRANT_RESTORE_COLLECTION}" \
  --snapshot "/backup/${qdrant_snapshot_file}" \
  >"${REPORT_DIR}/qdrant-restore-${TIMESTAMP}.json"

python3 - "${BACKUP_DIR}/manifest.json" "${REPORT_DIR}/qdrant-restore-${TIMESTAMP}.json" \
  "${REPORT_DIR}/restore-drill-${TIMESTAMP}.json" "${PROJECT}" \
  "${postgres_projects}" "${clickhouse_traces}" "${clickhouse_observations}" \
  "${minio_objects}" "${langfuse_api_total}" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
qdrant = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
actual = {
    "postgres_projects": int(sys.argv[5]),
    "clickhouse_traces": int(sys.argv[6]),
    "clickhouse_observations": int(sys.argv[7]),
    "minio_objects": int(sys.argv[8]),
}
expected = manifest["source_counts"]
checks = {key: actual[key] == int(expected[key]) for key in actual}
checks["langfuse_api_trace_count"] = int(sys.argv[9]) == int(expected["clickhouse_traces"])
checks["qdrant_points"] = qdrant["points_count"] == manifest["qdrant"]["points_count"]
checks["qdrant_vector_size"] = qdrant["vector_size"] == manifest["qdrant"]["vector_size"]
report = {
    "schema": "myapp-ai-restore-drill-v1",
    "project": sys.argv[4],
    "isolated_restore": True,
    "expected_counts": expected,
    "actual_counts": {**actual, "langfuse_api_traces": int(sys.argv[9])},
    "qdrant": qdrant,
    "checks": checks,
    "passed": all(checks.values()),
    "temporary_resources_removed_on_exit": True,
}
Path(sys.argv[3]).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
if not report["passed"]:
    raise SystemExit("Restore drill validation failed")
PY

echo "AI restore drill passed: ${REPORT_DIR}/restore-drill-${TIMESTAMP}.json"
