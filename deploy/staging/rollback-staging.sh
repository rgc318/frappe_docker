#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
SITE_NAME="${SITE_NAME:-}"
ROLLBACK_TAG="${ROLLBACK_TAG:-}"
SKIP_HEALTH_CHECK="${SKIP_HEALTH_CHECK:-0}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Run ./deploy/staging/init-staging-server.sh first."
  exit 1
fi

if [[ -z "${ROLLBACK_TAG}" ]]; then
  echo "ROLLBACK_TAG is required."
  echo "Example: ROLLBACK_TAG=staging-20260409-abc123 ./deploy/staging/rollback-staging.sh"
  exit 1
fi

current_tag="$(
  grep -E '^CUSTOM_TAG=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
)"

if [[ -n "${current_tag}" ]]; then
  echo "Current staging tag: ${current_tag}"
fi

echo "Switching staging tag to: ${ROLLBACK_TAG}"
if grep -q '^CUSTOM_TAG=' "${ENV_FILE}"; then
  sed -i "s/^CUSTOM_TAG=.*/CUSTOM_TAG=${ROLLBACK_TAG}/" "${ENV_FILE}"
else
  printf '\nCUSTOM_TAG=%s\n' "${ROLLBACK_TAG}" >>"${ENV_FILE}"
fi

echo "Restarting staging stack with rollback tag..."
SITE_NAME="${SITE_NAME}" ./deploy/staging/deploy-staging.sh

if [[ "${SKIP_HEALTH_CHECK}" != "1" ]]; then
  echo "Running staging health check..."
  ./deploy/staging/check-staging.sh
fi

echo "Rollback completed."
