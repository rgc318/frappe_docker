#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Copy deploy/staging/staging.env.example to deploy/staging/staging.env first."
  exit 1
fi

docker compose \
  --env-file "${ENV_FILE}" \
  -f "${ROOT_DIR}/compose.yaml" \
  -f "${ROOT_DIR}/overrides/compose.redis.yaml" \
  -f "${ROOT_DIR}/overrides/compose.mariadb.yaml" \
  -f "${ROOT_DIR}/overrides/compose.https.yaml" \
  up -d
