#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_CONTAINER="${1:-}"
ROUTER_READINESS_URL="${2:-http://ai-router:4010/readyz}"
MAP_PATH="${3:-${ROOT_DIR}/artifacts/staging/ai-router/rollout.map}"
STATE_PATH="${4:-${ROOT_DIR}/artifacts/staging/ai-router/rollout-state.json}"
AFFINITY_MAP_PATH="${5:-${ROOT_DIR}/artifacts/staging/ai-router/release-affinity.map}"
SAMPLE_COUNT="${6:-500}"

if [[ -z "${BACKEND_CONTAINER}" || ! -f "${MAP_PATH}" || ! -f "${STATE_PATH}" || ! -f "${AFFINITY_MAP_PATH}" ]]; then
	echo "Usage: $0 <backend-container> <router-readiness-url> <map-path> <state-path> <affinity-map-path> [samples]" >&2
  exit 2
fi
if ! [[ "${SAMPLE_COUNT}" =~ ^[0-9]+$ ]] || ((SAMPLE_COUNT < 100)); then
  echo "AI rollout verification requires at least 100 samples." >&2
  exit 2
fi

tmp_sample="$(mktemp /tmp/myapp-ai-rollout-sample.XXXXXX)"
trap 'rm -f "${tmp_sample}"' EXIT

docker exec -i "${BACKEND_CONTAINER}" /home/frappe/frappe-bench/env/bin/python - \
  "${ROUTER_READINESS_URL}" "${SAMPLE_COUNT}" >"${tmp_sample}" <<'PY'
import collections
import json
import sys
import urllib.request

url = sys.argv[1]
sample_count = int(sys.argv[2])
identities = collections.Counter()
errors = []
for _index in range(sample_count):
    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            payload = json.load(response)
        identity = {
            key: payload.get(key)
            for key in (
                "ready",
                "release_id",
                "runtime_revision",
                "protocol_version",
                "prompt_manifest_sha256",
                "schema_manifest_sha256",
                "tool_manifest_sha256",
            )
        }
        identities[json.dumps(identity, sort_keys=True)] += 1
    except Exception as error:
        errors.append(f"{type(error).__name__}: {error}")

print(json.dumps({
    "samples": sample_count,
    "identities": [
        {"identity": json.loads(identity), "count": count}
        for identity, count in identities.items()
    ],
    "errors": errors[:20],
}))
PY

python3 "${ROOT_DIR}/deploy/staging/verify-ai-router-rollout.py" \
  --state "${STATE_PATH}" \
  --map "${MAP_PATH}" \
  --affinity-map "${AFFINITY_MAP_PATH}" \
  --sample "${tmp_sample}"
