#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_FILE="${ROOT_DIR}/.env.langfuse.local"

if [[ $# -gt 0 ]]; then
  echo "Usage: $0" >&2
  exit 2
fi

if [[ -e "${OUTPUT_FILE}" ]]; then
  echo "${OUTPUT_FILE} already exists; refusing to overwrite persistent-stack secrets." >&2
  echo "Use a documented key-rotation or full data-reset procedure before replacing it." >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to generate local Langfuse secrets." >&2
  exit 1
fi

random_hex() {
  openssl rand -hex "$1"
}

postgres_password="$(random_hex 24)"
clickhouse_password="$(random_hex 24)"
redis_password="$(random_hex 24)"
minio_password="$(random_hex 24)"
salt="$(random_hex 32)"
encryption_key="$(random_hex 32)"
nextauth_secret="$(random_hex 32)"
project_public_key="pk-lf-$(random_hex 16)"
project_secret_key="sk-lf-$(random_hex 32)"
admin_password="$(random_hex 16)"

umask 077
temporary_file="$(mktemp "${OUTPUT_FILE}.tmp.XXXXXX")"
trap 'rm -f "${temporary_file}"' EXIT

{
  printf '%s\n' 'LANGFUSE_VERSION=3.212.0'
  printf '%s\n' 'LANGFUSE_CLICKHOUSE_IMAGE=docker.io/clickhouse/clickhouse-server:26.6.1.1193'
  printf '%s\n' 'LANGFUSE_MINIO_IMAGE=cgr.dev/chainguard/minio@sha256:8230f06574280781ea6ad45e27962db60175b18e4a43dd54c19012feb5438174'
  printf '%s\n' 'LANGFUSE_REDIS_VERSION=7.4.9'
  printf '%s\n' 'LANGFUSE_POSTGRES_VERSION=17.10'
  printf '%s\n' 'LANGFUSE_PORT=3000'
  printf '%s\n' 'LANGFUSE_MINIO_PORT=9090'
  printf '%s\n' 'LANGFUSE_PUBLIC_URL=http://localhost:3000'
  printf '%s\n' 'LANGFUSE_MINIO_PUBLIC_URL=http://localhost:9090'
  printf '%s\n' 'LANGFUSE_POSTGRES_USER=langfuse'
  printf 'LANGFUSE_POSTGRES_PASSWORD=%s\n' "${postgres_password}"
  printf '%s\n' 'LANGFUSE_POSTGRES_DB=langfuse'
  printf 'LANGFUSE_DATABASE_URL=postgresql://langfuse:%s@langfuse-postgres:5432/langfuse\n' "${postgres_password}"
  printf 'LANGFUSE_SALT=%s\n' "${salt}"
  printf 'LANGFUSE_ENCRYPTION_KEY=%s\n' "${encryption_key}"
  printf 'LANGFUSE_NEXTAUTH_SECRET=%s\n' "${nextauth_secret}"
  printf '%s\n' 'LANGFUSE_CLICKHOUSE_USER=clickhouse'
  printf 'LANGFUSE_CLICKHOUSE_PASSWORD=%s\n' "${clickhouse_password}"
  printf 'LANGFUSE_REDIS_AUTH=%s\n' "${redis_password}"
  printf '%s\n' 'LANGFUSE_MINIO_ROOT_USER=langfuse'
  printf 'LANGFUSE_MINIO_ROOT_PASSWORD=%s\n' "${minio_password}"
  printf '%s\n' 'LANGFUSE_INIT_ORG_ID=myapp'
  printf '%s\n' 'LANGFUSE_INIT_ORG_NAME=MyApp'
  printf '%s\n' 'LANGFUSE_INIT_PROJECT_ID=myapp-ai'
  printf '%s\n' 'LANGFUSE_INIT_PROJECT_NAME=MyApp-AI-Copilot'
  printf 'LANGFUSE_INIT_PROJECT_PUBLIC_KEY=%s\n' "${project_public_key}"
  printf 'LANGFUSE_INIT_PROJECT_SECRET_KEY=%s\n' "${project_secret_key}"
  printf '%s\n' 'LANGFUSE_INIT_USER_EMAIL=admin@myapp.local'
  printf '%s\n' 'LANGFUSE_INIT_USER_NAME=MyApp-AI-Admin'
  printf 'LANGFUSE_INIT_USER_PASSWORD=%s\n' "${admin_password}"
  printf '%s\n' 'LANGFUSE_TELEMETRY_ENABLED=false'
  printf '%s\n' 'MYAPP_AI_LANGFUSE_ENVIRONMENT=development'
  printf '%s\n' 'MYAPP_AI_LANGFUSE_RELEASE=local'
  printf '%s\n' 'MYAPP_AI_LANGFUSE_CAPTURE_CONTENT=0'
  printf '%s\n' 'MYAPP_AI_LANGFUSE_TIMEOUT_SECONDS=5'
} >"${temporary_file}"

mv "${temporary_file}" "${OUTPUT_FILE}"
trap - EXIT
chmod 600 "${OUTPUT_FILE}"

echo "Generated ${OUTPUT_FILE} with mode 600; secret values were not printed."
echo "The local admin login and project API keys are stored in that ignored file."
echo "Start the stack with:"
echo "docker compose --env-file .env --env-file .env.ai.local --env-file .env.langfuse.local -f compose.yaml -f overrides/compose.langfuse.yaml up -d --build ai-orchestrator langfuse-web langfuse-worker"
