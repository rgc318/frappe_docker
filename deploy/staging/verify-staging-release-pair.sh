#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
RELEASE_ID="${1:-}"
RELEASE_ROOT="${AI_STAGING_RELEASE_ROOT:-${ROOT_DIR}/artifacts/staging/ai-releases}"

if [[ -z "${RELEASE_ID}" ]]; then
  echo "Usage: $0 <release-id>" >&2
  exit 2
fi
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

get_env() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
}

backend_repository="$(get_env CUSTOM_IMAGE)"
ai_repository="$(get_env MYAPP_AI_IMAGE)"
manifest_path="${RELEASE_ROOT}/${RELEASE_ID}.json"
if [[ ! -f "${manifest_path}" ]]; then
  echo "No qualified release pair manifest exists for ${RELEASE_ID}: ${manifest_path}" >&2
  exit 1
fi

tmp_dir="$(mktemp -d "${RELEASE_ROOT}/.verify.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT
docker image inspect "${backend_repository}:${RELEASE_ID}" >"${tmp_dir}/backend.json"
docker image inspect "${ai_repository}:${RELEASE_ID}" >"${tmp_dir}/ai.json"
python3 "${ROOT_DIR}/deploy/staging/staging-release-pair.py" verify \
  --manifest "${manifest_path}" \
  --release-id "${RELEASE_ID}" \
  --backend-inspect "${tmp_dir}/backend.json" \
  --ai-inspect "${tmp_dir}/ai.json"
