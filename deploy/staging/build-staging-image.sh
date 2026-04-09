#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
APPS_JSON_FILE="${APPS_JSON_FILE:-${ROOT_DIR}/deploy/staging/apps.staging.json}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}"
  echo "Copy deploy/staging/staging.env.example to deploy/staging/staging.env first."
  exit 1
fi

read_env() {
  local key="$1"
  local line
  line="$(grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 || true)"
  if [[ -z "${line}" ]]; then
    return 1
  fi
  printf '%s\n' "${line#*=}"
}

CUSTOM_IMAGE="$(read_env CUSTOM_IMAGE)"
CUSTOM_TAG="$(read_env CUSTOM_TAG)"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-$(read_env FRAPPE_BRANCH || printf 'version-16')}"
FRAPPE_PATH="${FRAPPE_PATH:-$(read_env FRAPPE_PATH || printf 'https://github.com/frappe/frappe')}"
HTTP_PROXY_ARG="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}"
HTTPS_PROXY_ARG="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}"
NO_PROXY_ARG="${NO_PROXY:-${no_proxy:-}}"

: "${CUSTOM_IMAGE:?CUSTOM_IMAGE is required}"
: "${CUSTOM_TAG:?CUSTOM_TAG is required}"

if [[ ! -f "${APPS_JSON_FILE}" ]]; then
  echo "Missing apps json file: ${APPS_JSON_FILE}"
  echo "Copy deploy/staging/apps.staging.json.example to deploy/staging/apps.staging.json first."
  exit 1
fi

APPS_JSON_BASE64="$(base64 -w 0 "${APPS_JSON_FILE}")"

docker build \
  --build-arg FRAPPE_BRANCH="${FRAPPE_BRANCH}" \
  --build-arg FRAPPE_PATH="${FRAPPE_PATH}" \
  --build-arg APPS_JSON_BASE64="${APPS_JSON_BASE64}" \
  --build-arg HTTP_PROXY="${HTTP_PROXY_ARG}" \
  --build-arg HTTPS_PROXY="${HTTPS_PROXY_ARG}" \
  --build-arg NO_PROXY="${NO_PROXY_ARG}" \
  --tag "${CUSTOM_IMAGE}:${CUSTOM_TAG}" \
  --file "${ROOT_DIR}/images/custom/myapp-staging/Containerfile" \
  "${ROOT_DIR}"

echo "Built image: ${CUSTOM_IMAGE}:${CUSTOM_TAG}"
