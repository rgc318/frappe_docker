#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REMOVE_VOLUMES=false
REMOVE_ORPHANS=false
MODE=dev
WITH_OBSERVABILITY=auto

while [[ $# -gt 0 ]]; do
  case "$1" in
  -v)
    REMOVE_VOLUMES=true
    ;;
  -r)
    REMOVE_ORPHANS=true
    ;;
  --prod)
    MODE=prod
    ;;
  --devcontainer)
    MODE=devcontainer
    REMOVE_ORPHANS=true
    ;;
  --with-observability)
    WITH_OBSERVABILITY=yes
    ;;
  --without-observability)
    WITH_OBSERVABILITY=no
    ;;
  *)
    echo "Usage: $0 [-v] [-r] [--prod|--devcontainer] [--with-observability|--without-observability]" >&2
    exit 2
    ;;
  esac
  shift
done

if [[ -f "${ROOT_DIR}/.env.ai.local" ]]; then
  "${ROOT_DIR}/sync-ai-gateway-env.sh" >/dev/null
elif [[ ! -f "${ROOT_DIR}/.env.ai.gateway.local" ]]; then
  echo "Neither .env.ai.local nor .env.ai.gateway.local exists; cannot resolve the Compose configuration." >&2
  exit 1
fi

COMPOSE_ARGS=(
  --env-file "${ROOT_DIR}/.env"
  -f "${ROOT_DIR}/compose.yaml"
  -f "${ROOT_DIR}/overrides/compose.redis.yaml"
  -f "${ROOT_DIR}/overrides/compose.mariadb.yaml"
)

if [[ -f "${ROOT_DIR}/.env.ai.local" ]]; then
  COMPOSE_ARGS+=(--env-file "${ROOT_DIR}/.env.ai.local")
fi

case "${MODE}" in
prod)
  COMPOSE_ARGS+=(
    -f "${ROOT_DIR}/overrides/compose.traefik.yaml"
    -f "${ROOT_DIR}/overrides/compose.https.yaml"
  )
  ;;
devcontainer)
  COMPOSE_ARGS+=(
    -f "${ROOT_DIR}/overrides/compose.noproxy.yaml"
    -f "${ROOT_DIR}/.devcontainer/docker-compose.yml"
  )
  ;;
*)
  COMPOSE_ARGS+=(-f "${ROOT_DIR}/overrides/compose.noproxy.yaml")
  ;;
esac

if [[ "${WITH_OBSERVABILITY}" == yes || ("${WITH_OBSERVABILITY}" == auto && -f "${ROOT_DIR}/.env.langfuse.local") ]]; then
  if [[ ! -f "${ROOT_DIR}/.env.langfuse.local" ]]; then
    echo "Missing .env.langfuse.local; cannot resolve the observability stack." >&2
    exit 1
  fi
  "${ROOT_DIR}/sync-langfuse-runtime-env.sh" >/dev/null
  COMPOSE_ARGS+=(
    --env-file "${ROOT_DIR}/.env.langfuse.local"
    -f "${ROOT_DIR}/overrides/compose.langfuse.yaml"
  )
fi

CMD=(docker compose "${COMPOSE_ARGS[@]}" down)
if [[ "${REMOVE_VOLUMES}" == true ]]; then
  CMD+=(-v)
fi
if [[ "${REMOVE_ORPHANS}" == true ]]; then
  CMD+=(--remove-orphans)
fi

printf 'Stopping %s stack' "${MODE}"
if [[ "${WITH_OBSERVABILITY}" == yes || ("${WITH_OBSERVABILITY}" == auto && -f "${ROOT_DIR}/.env.langfuse.local") ]]; then
  printf ' with AI observability'
fi
printf '.\n'
"${CMD[@]}"
