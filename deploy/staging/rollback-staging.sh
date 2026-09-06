#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"
SITE_NAME="${SITE_NAME:-}"
ROLLBACK_TAG="${ROLLBACK_TAG:-}"
SKIP_HEALTH_CHECK="${SKIP_HEALTH_CHECK:-0}"
ALLOW_UNQUALIFIED_ROLLBACK="${ALLOW_UNQUALIFIED_ROLLBACK:-0}"

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

rollout_state_path="${AI_ROUTER_ROLLOUT_STATE_PATH:-${ROOT_DIR}/artifacts/staging/ai-router/rollout-state.json}"
if [[ -f "${rollout_state_path}" ]]; then
  readarray -t rollout_values < <(
    python3 - "${rollout_state_path}" <<'PY'
import json
import sys

state = json.load(open(sys.argv[1], encoding="utf-8"))
print(state.get("status") or "")
print(state.get("stable_release_id") or "")
PY
  )
  if [[ "${rollout_values[0]}" =~ ^(active|draining|promoting)$ ]]; then
    if [[ "${ROLLBACK_TAG}" != "${rollout_values[1]}" ]]; then
      echo "Rollback is blocked while AI rollout is ${rollout_values[0]}." >&2
      echo "Abort to the recorded stable release ${rollout_values[1]} first." >&2
      exit 1
    fi
    echo "Aborting managed AI rollout before paired rollback."
    "${ROOT_DIR}/deploy/staging/abort-ai-progressive-rollout.sh"
  fi
fi

custom_image="$(grep -E '^CUSTOM_IMAGE=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true)"
ai_image="$(grep -E '^MYAPP_AI_IMAGE=' "${ENV_FILE}" | tail -n 1 | cut -d= -f2- || true)"
if [[ -z "${custom_image}" || -z "${ai_image}" ]]; then
  echo "CUSTOM_IMAGE and MYAPP_AI_IMAGE are required for paired rollback." >&2
  exit 1
fi

echo "Pulling the exact Backend and AI rollback candidates..."
docker pull "${custom_image}:${ROLLBACK_TAG}"
docker pull "${ai_image}:${ROLLBACK_TAG}"
if ! "${ROOT_DIR}/deploy/staging/verify-staging-release-pair.sh" "${ROLLBACK_TAG}"; then
  if [[ "${ALLOW_UNQUALIFIED_ROLLBACK}" != "1" ]]; then
    echo "Rollback blocked: the target is not the exact previously qualified Backend/AI release pair." >&2
    echo "Use ALLOW_UNQUALIFIED_ROLLBACK=1 only for a documented emergency recovery." >&2
    exit 1
  fi
  echo "WARNING: proceeding with an unqualified emergency rollback override." >&2
fi

echo "Switching staging application and AI image tags to: ${ROLLBACK_TAG}"
if grep -q '^CUSTOM_TAG=' "${ENV_FILE}"; then
  sed -i "s/^CUSTOM_TAG=.*/CUSTOM_TAG=${ROLLBACK_TAG}/" "${ENV_FILE}"
else
  printf '\nCUSTOM_TAG=%s\n' "${ROLLBACK_TAG}" >>"${ENV_FILE}"
fi

if grep -q '^MYAPP_AI_TAG=' "${ENV_FILE}"; then
  sed -i "s/^MYAPP_AI_TAG=.*/MYAPP_AI_TAG=${ROLLBACK_TAG}/" "${ENV_FILE}"
else
  printf '\nMYAPP_AI_TAG=%s\n' "${ROLLBACK_TAG}" >>"${ENV_FILE}"
fi

echo "Restarting staging stack with rollback tag..."
SITE_NAME="${SITE_NAME}" ./deploy/staging/deploy-staging.sh

if [[ "${SKIP_HEALTH_CHECK}" != "1" ]]; then
  echo "Running staging health check..."
  ./deploy/staging/check-staging.sh
fi

echo "Rollback completed."
