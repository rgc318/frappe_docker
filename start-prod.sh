#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WITH_OBSERVABILITY=no

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

"${ROOT_DIR}/sync-ai-gateway-env.sh"

COMPOSE_ARGS=(
  --env-file "${ROOT_DIR}/.env"
  --env-file "${ROOT_DIR}/.env.ai.local"
  -f "${ROOT_DIR}/compose.yaml"
  -f "${ROOT_DIR}/overrides/compose.redis.yaml"
  -f "${ROOT_DIR}/overrides/compose.mariadb.yaml"
  -f "${ROOT_DIR}/overrides/compose.traefik.yaml"
  -f "${ROOT_DIR}/overrides/compose.https.yaml"
)

if [[ "${WITH_OBSERVABILITY}" == yes ]]; then
  if [[ ! -f "${ROOT_DIR}/.env.langfuse.local" ]]; then
    echo "Missing .env.langfuse.local; run ./setup-ai-observability.sh first." >&2
    exit 1
  fi
  "${ROOT_DIR}/sync-langfuse-runtime-env.sh"
  COMPOSE_ARGS+=(
    --env-file "${ROOT_DIR}/.env.langfuse.local"
    -f "${ROOT_DIR}/overrides/compose.langfuse.yaml"
  )
fi

docker compose "${COMPOSE_ARGS[@]}" up -d --build
