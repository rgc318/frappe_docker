#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WITH_OBSERVABILITY=yes

if [[ ! -f "${ROOT_DIR}/services/myapp-ai/Dockerfile" ]]; then
  echo "Missing services/myapp-ai submodule; run: git submodule update --init --recursive" >&2
  exit 1
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
  --with-observability)
    WITH_OBSERVABILITY=yes
    ;;
  --without-observability)
    WITH_OBSERVABILITY=no
    ;;
  *)
    echo "Usage: $0 [--with-observability|--without-observability]" >&2
    exit 2
    ;;
  esac
  shift
done

SOURCE_SECRET_ENV_FILES=(
  "${ROOT_DIR}/.env"
  "${ROOT_DIR}/.env.ai.local"
)
if [[ "${WITH_OBSERVABILITY}" == yes ]]; then
  if [[ ! -f "${ROOT_DIR}/.env.langfuse.local" ]]; then
    echo "Missing .env.langfuse.local; run ./setup-ai-observability.sh first." >&2
    exit 1
  fi
  SOURCE_SECRET_ENV_FILES+=("${ROOT_DIR}/.env.langfuse.local")
fi
"${ROOT_DIR}/validate-secret-env-files.sh" "${SOURCE_SECRET_ENV_FILES[@]}"

"${ROOT_DIR}/sync-ai-gateway-env.sh"

COMPOSE_ARGS=(
  --env-file "${ROOT_DIR}/.env"
  --env-file "${ROOT_DIR}/.env.ai.local"
  -f "${ROOT_DIR}/compose.yaml"
  -f "${ROOT_DIR}/overrides/compose.redis.yaml"
  -f "${ROOT_DIR}/overrides/compose.mariadb.yaml"
  -f "${ROOT_DIR}/overrides/compose.noproxy.yaml"
)

if [[ "${WITH_OBSERVABILITY}" == yes ]]; then
  "${ROOT_DIR}/sync-langfuse-runtime-env.sh" --reconcile
  COMPOSE_ARGS+=(
    --env-file "${ROOT_DIR}/.env.langfuse.local"
    -f "${ROOT_DIR}/overrides/compose.langfuse.yaml"
  )
fi

SECRET_ENV_FILES=(
  "${ROOT_DIR}/.env"
  "${ROOT_DIR}/.env.ai.local"
  "${ROOT_DIR}/.env.ai.gateway.local"
)
if [[ "${WITH_OBSERVABILITY}" == yes ]]; then
  SECRET_ENV_FILES+=(
    "${ROOT_DIR}/.env.langfuse.local"
    "${ROOT_DIR}/.env.langfuse.runtime.local"
    "${ROOT_DIR}/.env.langfuse.gateway.local"
    "${ROOT_DIR}/.env.langfuse.web.local"
    "${ROOT_DIR}/.env.langfuse.postgres.local"
    "${ROOT_DIR}/.env.langfuse.clickhouse.local"
    "${ROOT_DIR}/.env.langfuse.redis.local"
    "${ROOT_DIR}/.env.langfuse.minio.local"
  )
fi
"${ROOT_DIR}/validate-secret-env-files.sh" "${SECRET_ENV_FILES[@]}"

docker compose "${COMPOSE_ARGS[@]}" up -d --build --wait --wait-timeout 300

AI_GATEWAY_CONTAINER_IDS=()
for service in backend queue-short queue-long queue-ai-vector scheduler; do
  container_id="$(docker compose "${COMPOSE_ARGS[@]}" ps -q "${service}")"
  if [[ -z "${container_id}" ]]; then
    echo "AI gateway runtime configuration check failed: ${service} is not running." >&2
    exit 1
  fi
  AI_GATEWAY_CONTAINER_IDS+=("${container_id}")
done
"${ROOT_DIR}/verify-ai-gateway-runtime-env.sh" \
  "${ROOT_DIR}/.env.ai.gateway.local" "${AI_GATEWAY_CONTAINER_IDS[@]}"
