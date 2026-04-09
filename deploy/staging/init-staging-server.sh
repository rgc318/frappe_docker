#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_TEMPLATE="${ROOT_DIR}/deploy/staging/staging.env.example"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
SITES_DIR="${SITES_DIR:-${ROOT_DIR}/sites}"
LOGS_DIR="${LOGS_DIR:-${ROOT_DIR}/logs}"

mkdir -p "${ROOT_DIR}/deploy/staging"
mkdir -p "${SITES_DIR}"
mkdir -p "${LOGS_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${ENV_TEMPLATE}" "${ENV_FILE}"
  echo "Created ${ENV_FILE} from example template."
else
  echo "Keeping existing env file: ${ENV_FILE}"
fi

chmod 755 "${ROOT_DIR}/deploy/staging/"*.sh 2>/dev/null || true

echo "Staging server directories are ready."
echo "Next steps:"
echo "1. Edit ${ENV_FILE}"
echo "2. Set CUSTOM_IMAGE / CUSTOM_TAG to the published staging image"
echo "3. Run ./deploy/staging/start-staging.sh"
