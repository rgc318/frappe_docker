#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
BACKEND_CONTAINER="${RELEASE_PAIR_BACKEND_CONTAINER:-}"
AI_CONTAINER="${RELEASE_PAIR_AI_CONTAINER:-}"
CANARY_REPORT="${AI_CANARY_REPORT_PATH:-}"
RELEASE_ROOT="${AI_STAGING_RELEASE_ROOT:-${ROOT_DIR}/artifacts/staging/ai-releases}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi
if [[ -z "${BACKEND_CONTAINER}" || -z "${AI_CONTAINER}" || -z "${CANARY_REPORT}" ]]; then
  echo "RELEASE_PAIR_BACKEND_CONTAINER, RELEASE_PAIR_AI_CONTAINER and AI_CANARY_REPORT_PATH are required." >&2
  exit 1
fi
if [[ ! -f "${CANARY_REPORT}" ]]; then
  echo "Missing passed canary report: ${CANARY_REPORT}" >&2
  exit 1
fi

get_env() {
  local key="$1"
  grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true
}

backend_repository="$(get_env CUSTOM_IMAGE)"
backend_tag="$(get_env CUSTOM_TAG)"
ai_repository="$(get_env MYAPP_AI_IMAGE)"
ai_tag="$(get_env MYAPP_AI_TAG)"
if [[ -z "${backend_repository}" || -z "${backend_tag}" || -z "${ai_repository}" || -z "${ai_tag}" ]]; then
  echo "Staging image repositories and tags must be configured." >&2
  exit 1
fi

mkdir -p "${RELEASE_ROOT}"
tmp_dir="$(mktemp -d "${RELEASE_ROOT}/.capture.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

backend_image_id="$(docker inspect --format '{{.Image}}' "${BACKEND_CONTAINER}")"
ai_image_id="$(docker inspect --format '{{.Image}}' "${AI_CONTAINER}")"
docker image inspect "${backend_image_id}" >"${tmp_dir}/backend.json"
docker image inspect "${ai_image_id}" >"${tmp_dir}/ai.json"
docker exec "${BACKEND_CONTAINER}" /home/frappe/frappe-bench/env/bin/python -c \
  'import json, os, urllib.request; base=os.environ["MYAPP_AI_ORCHESTRATOR_URL"].rstrip("/"); print(json.dumps(json.load(urllib.request.urlopen(f"{base}/readyz", timeout=10))))' \
  >"${tmp_dir}/readiness.json"

manifest_path="${RELEASE_ROOT}/${backend_tag}.json"
if [[ -f "${manifest_path}" ]]; then
  python3 "${ROOT_DIR}/deploy/staging/staging-release-pair.py" verify \
    --manifest "${manifest_path}" \
    --release-id "${backend_tag}" \
    --backend-inspect "${tmp_dir}/backend.json" \
    --ai-inspect "${tmp_dir}/ai.json" >/dev/null
  echo "Qualified staging release pair already exists and still matches: ${manifest_path}"
  exit 0
fi

python3 "${ROOT_DIR}/deploy/staging/staging-release-pair.py" capture \
  --backend-inspect "${tmp_dir}/backend.json" \
  --ai-inspect "${tmp_dir}/ai.json" \
  --readiness "${tmp_dir}/readiness.json" \
  --canary-report "${CANARY_REPORT}" \
  --backend-repository "${backend_repository}" \
  --backend-tag "${backend_tag}" \
  --ai-repository "${ai_repository}" \
  --ai-tag "${ai_tag}" \
  --parent-revision "$(git -C "${ROOT_DIR}" rev-parse --verify HEAD)" \
  >"${tmp_dir}/manifest.json"
install -m 0640 "${tmp_dir}/manifest.json" "${manifest_path}"
echo "Qualified staging release pair: ${manifest_path}"
