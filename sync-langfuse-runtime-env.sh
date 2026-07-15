#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${LANGFUSE_ENV_FILE:-${ROOT_DIR}/.env.langfuse.local}"
RUNTIME_FILE="${LANGFUSE_RUNTIME_ENV_FILE:-${ROOT_DIR}/.env.langfuse.runtime.local}"
GATEWAY_FILE="${LANGFUSE_GATEWAY_ENV_FILE:-${ROOT_DIR}/.env.langfuse.gateway.local}"

if [[ $# -gt 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi

if [[ ! -f "${SOURCE_FILE}" ]]; then
  echo "Missing Langfuse environment file: ${SOURCE_FILE}" >&2
  echo "Run ./setup-ai-observability.sh once before starting the development stack." >&2
  exit 1
fi

python3 - "${SOURCE_FILE}" "${RUNTIME_FILE}" "${GATEWAY_FILE}" <<'PY'
from pathlib import Path
import os
import sys

source = Path(sys.argv[1])
runtime_output = Path(sys.argv[2])
gateway_output = Path(sys.argv[3])

defaults = {
    "LANGFUSE_PUBLIC_URL": "http://localhost:3000",
    "LANGFUSE_MINIO_PUBLIC_URL": "http://localhost:9090",
    "LANGFUSE_POSTGRES_USER": "langfuse",
    "LANGFUSE_POSTGRES_DB": "langfuse",
    "LANGFUSE_CLICKHOUSE_USER": "clickhouse",
    "LANGFUSE_MINIO_ROOT_USER": "langfuse",
    "LANGFUSE_INIT_ORG_ID": "myapp",
    "LANGFUSE_INIT_ORG_NAME": "MyApp",
    "LANGFUSE_INIT_PROJECT_ID": "myapp-ai",
    "LANGFUSE_INIT_PROJECT_NAME": "MyApp-AI-Copilot",
    "LANGFUSE_INIT_USER_EMAIL": "admin@myapp.local",
    "LANGFUSE_INIT_USER_NAME": "MyApp-AI-Admin",
    "LANGFUSE_TELEMETRY_ENABLED": "false",
    "MYAPP_AI_LANGFUSE_ENVIRONMENT": "development",
    "MYAPP_AI_LANGFUSE_RELEASE": "local",
    "MYAPP_AI_LANGFUSE_CAPTURE_CONTENT": "0",
    "MYAPP_AI_LANGFUSE_TIMEOUT_SECONDS": "5",
}
required = {
    "LANGFUSE_DATABASE_URL",
    "LANGFUSE_SALT",
    "LANGFUSE_ENCRYPTION_KEY",
    "LANGFUSE_NEXTAUTH_SECRET",
    "LANGFUSE_CLICKHOUSE_PASSWORD",
    "LANGFUSE_REDIS_AUTH",
    "LANGFUSE_MINIO_ROOT_PASSWORD",
    "LANGFUSE_POSTGRES_PASSWORD",
    "LANGFUSE_INIT_PROJECT_PUBLIC_KEY",
    "LANGFUSE_INIT_PROJECT_SECRET_KEY",
    "LANGFUSE_INIT_USER_PASSWORD",
}

values: dict[str, str] = {}
for raw_line in source.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    key = key.strip()
    if key in values:
        raise SystemExit(f"Duplicate {key} in {source}")
    values[key] = value.strip()

for key, value in defaults.items():
    values.setdefault(key, value)

missing = sorted(key for key in required if not values.get(key))
if missing:
    raise SystemExit(f"Missing required Langfuse variables in {source}: {', '.join(missing)}")

runtime = {
    "NEXTAUTH_URL": values["LANGFUSE_PUBLIC_URL"],
    "DATABASE_URL": values["LANGFUSE_DATABASE_URL"],
    "DIRECT_URL": values["LANGFUSE_DATABASE_URL"],
    "SALT": values["LANGFUSE_SALT"],
    "ENCRYPTION_KEY": values["LANGFUSE_ENCRYPTION_KEY"],
    "TELEMETRY_ENABLED": values["LANGFUSE_TELEMETRY_ENABLED"],
    "LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES": "false",
    "CLICKHOUSE_MIGRATION_URL": "clickhouse://langfuse-clickhouse:9000",
    "CLICKHOUSE_URL": "http://langfuse-clickhouse:8123",
    "CLICKHOUSE_DB": "default",
    "CLICKHOUSE_USER": values["LANGFUSE_CLICKHOUSE_USER"],
    "CLICKHOUSE_PASSWORD": values["LANGFUSE_CLICKHOUSE_PASSWORD"],
    "CLICKHOUSE_CLUSTER_ENABLED": "false",
    "REDIS_HOST": "langfuse-redis",
    "REDIS_PORT": "6379",
    "REDIS_AUTH": values["LANGFUSE_REDIS_AUTH"],
    "REDIS_PASSWORD": values["LANGFUSE_REDIS_AUTH"],
    "LANGFUSE_S3_EVENT_UPLOAD_BUCKET": "langfuse",
    "LANGFUSE_S3_EVENT_UPLOAD_REGION": "auto",
    "LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID": values["LANGFUSE_MINIO_ROOT_USER"],
    "LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY": values["LANGFUSE_MINIO_ROOT_PASSWORD"],
    "LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT": "http://langfuse-minio:9000",
    "LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE": "true",
    "LANGFUSE_S3_EVENT_UPLOAD_PREFIX": "events/",
    "LANGFUSE_S3_MEDIA_UPLOAD_BUCKET": "langfuse",
    "LANGFUSE_S3_MEDIA_UPLOAD_REGION": "auto",
    "LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID": values["LANGFUSE_MINIO_ROOT_USER"],
    "LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY": values["LANGFUSE_MINIO_ROOT_PASSWORD"],
    "LANGFUSE_S3_MEDIA_UPLOAD_ENDPOINT": values["LANGFUSE_MINIO_PUBLIC_URL"],
    "LANGFUSE_S3_MEDIA_UPLOAD_FORCE_PATH_STYLE": "true",
    "LANGFUSE_S3_MEDIA_UPLOAD_PREFIX": "media/",
    "LANGFUSE_ENABLE_BLOB_STORAGE_FILE_LOG": "true",
    "LANGFUSE_S3_EVENT_KEY_MAX_SEGMENT_BYTES": "255",
    "AUTH_DISABLE_SIGNUP": "true",
    "NEXTAUTH_SECRET": values["LANGFUSE_NEXTAUTH_SECRET"],
    "LANGFUSE_INIT_ORG_ID": values["LANGFUSE_INIT_ORG_ID"],
    "LANGFUSE_INIT_ORG_NAME": values["LANGFUSE_INIT_ORG_NAME"],
    "LANGFUSE_INIT_PROJECT_ID": values["LANGFUSE_INIT_PROJECT_ID"],
    "LANGFUSE_INIT_PROJECT_NAME": values["LANGFUSE_INIT_PROJECT_NAME"],
    "LANGFUSE_INIT_PROJECT_PUBLIC_KEY": values["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"],
    "LANGFUSE_INIT_PROJECT_SECRET_KEY": values["LANGFUSE_INIT_PROJECT_SECRET_KEY"],
    "LANGFUSE_INIT_USER_EMAIL": values["LANGFUSE_INIT_USER_EMAIL"],
    "LANGFUSE_INIT_USER_NAME": values["LANGFUSE_INIT_USER_NAME"],
    "LANGFUSE_INIT_USER_PASSWORD": values["LANGFUSE_INIT_USER_PASSWORD"],
    "MINIO_ROOT_USER": values["LANGFUSE_MINIO_ROOT_USER"],
    "MINIO_ROOT_PASSWORD": values["LANGFUSE_MINIO_ROOT_PASSWORD"],
    "POSTGRES_USER": values["LANGFUSE_POSTGRES_USER"],
    "POSTGRES_PASSWORD": values["LANGFUSE_POSTGRES_PASSWORD"],
    "POSTGRES_DB": values["LANGFUSE_POSTGRES_DB"],
    "TZ": "UTC",
    "PGTZ": "UTC",
}
gateway = {
    "MYAPP_AI_LANGFUSE_HOST": "http://langfuse-web:3000",
    "MYAPP_AI_LANGFUSE_PUBLIC_KEY": values["LANGFUSE_INIT_PROJECT_PUBLIC_KEY"],
    "MYAPP_AI_LANGFUSE_SECRET_KEY": values["LANGFUSE_INIT_PROJECT_SECRET_KEY"],
    "MYAPP_AI_LANGFUSE_ENVIRONMENT": values["MYAPP_AI_LANGFUSE_ENVIRONMENT"],
    "MYAPP_AI_LANGFUSE_RELEASE": values["MYAPP_AI_LANGFUSE_RELEASE"],
    "MYAPP_AI_LANGFUSE_CAPTURE_CONTENT": values["MYAPP_AI_LANGFUSE_CAPTURE_CONTENT"],
    "MYAPP_AI_LANGFUSE_TIMEOUT_SECONDS": values["MYAPP_AI_LANGFUSE_TIMEOUT_SECONDS"],
}

def write_env(path: Path, rows: dict[str, str]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(
        "# Generated by sync-langfuse-runtime-env.sh; do not edit or commit.\n"
        + "\n".join(f"{key}={value}" for key, value in rows.items())
        + "\n",
        encoding="utf-8",
    )
    os.chmod(temporary, 0o600)
    os.replace(temporary, path)

write_env(runtime_output, runtime)
write_env(gateway_output, gateway)
PY

chmod 600 "${RUNTIME_FILE}" "${GATEWAY_FILE}"
echo "Synchronized Langfuse runtime and restricted Orchestrator environments."
