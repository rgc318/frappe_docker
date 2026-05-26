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

if [[ ! -f "${APPS_JSON_FILE}" ]]; then
  echo "Missing apps json file: ${APPS_JSON_FILE}"
  echo "Copy deploy/staging/apps.staging.json.example to deploy/staging/apps.staging.json first."
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

read_app_ref() {
  local url_part="$1"
  python3 - "${APPS_JSON_FILE}" "${url_part}" <<'PY'
import json
import sys

path, needle = sys.argv[1:]
with open(path, encoding="utf-8") as f:
    apps = json.load(f)

for app in apps:
    if needle in app.get("url", ""):
        ref = app.get("branch", "")
        if ref:
            print(ref)
            raise SystemExit(0)

raise SystemExit(1)
PY
}

CUSTOM_IMAGE="$(read_env CUSTOM_IMAGE)"
CUSTOM_TAG="$(read_env CUSTOM_TAG)"
FRAPPE_BRANCH="${FRAPPE_BRANCH:-$(read_env FRAPPE_BRANCH || printf 'v16.14.0')}"
FRAPPE_PATH="${FRAPPE_PATH:-$(read_env FRAPPE_PATH || printf 'https://github.com/frappe/frappe')}"
ERPNEXT_REF="${ERPNEXT_REF:-$(read_app_ref 'frappe/erpnext' || read_env ERPNEXT_BRANCH || printf 'v16.14.0')}"
MYAPP_REF="${MYAPP_REF:-$(read_app_ref 'rgc318/myapp' || read_env MYAPP_BRANCH || printf 'main')}"
CACHE_BUST="${CACHE_BUST:-local-$(date +%s)}"
HTTP_PROXY_ARG="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}"
HTTPS_PROXY_ARG="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy:-}}}}"
NO_PROXY_ARG="${NO_PROXY:-${no_proxy:-}}"

: "${CUSTOM_IMAGE:?CUSTOM_IMAGE is required}"
: "${CUSTOM_TAG:?CUSTOM_TAG is required}"

APPS_JSON_BASE64="$(base64 -w 0 "${APPS_JSON_FILE}")"

docker build \
  --build-arg FRAPPE_BRANCH="${FRAPPE_BRANCH}" \
  --build-arg FRAPPE_PATH="${FRAPPE_PATH}" \
  --build-arg ERPNEXT_REF="${ERPNEXT_REF}" \
  --build-arg MYAPP_REF="${MYAPP_REF}" \
  --build-arg APPS_JSON_BASE64="${APPS_JSON_BASE64}" \
  --build-arg CACHE_BUST="${CACHE_BUST}" \
  --build-arg HTTP_PROXY="${HTTP_PROXY_ARG}" \
  --build-arg HTTPS_PROXY="${HTTPS_PROXY_ARG}" \
  --build-arg NO_PROXY="${NO_PROXY_ARG}" \
  --tag "${CUSTOM_IMAGE}:${CUSTOM_TAG}" \
  --file "${ROOT_DIR}/images/custom/myapp-staging/Containerfile" \
  "${ROOT_DIR}"

echo "Built image: ${CUSTOM_IMAGE}:${CUSTOM_TAG}"
