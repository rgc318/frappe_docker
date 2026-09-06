#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_ROOT="${AI_ROUTER_STATE_ROOT:-${ROOT_DIR}/artifacts/staging/ai-router}"
MAP_PATH="${AI_ROUTER_MAP_PATH:-${STATE_ROOT}/rollout.map}"
AFFINITY_MAP_PATH="${AI_ROUTER_AFFINITY_MAP_PATH:-${STATE_ROOT}/release-affinity.map}"
DEFAULT_MAP="${ROOT_DIR}/deploy/staging/ai-rollout.map.default"
DEFAULT_AFFINITY_MAP="${ROOT_DIR}/deploy/staging/ai-release-affinity.map.default"

mkdir -p "${STATE_ROOT}"
if [[ ! -f "${MAP_PATH}" ]]; then
  install -m 0644 "${DEFAULT_MAP}" "${MAP_PATH}"
else
  chmod 0644 "${MAP_PATH}"
fi
if [[ ! -f "${AFFINITY_MAP_PATH}" ]]; then
  install -m 0644 "${DEFAULT_AFFINITY_MAP}" "${AFFINITY_MAP_PATH}"
else
  chmod 0644 "${AFFINITY_MAP_PATH}"
fi

echo "AI router state ready: ${MAP_PATH}, ${AFFINITY_MAP_PATH}"
