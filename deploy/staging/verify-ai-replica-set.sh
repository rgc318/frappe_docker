#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if (($# < 4)); then
  echo "Usage: $0 <backend-container> <router-readiness-url> <expected-replicas> <replica-id>..." >&2
  exit 2
fi
BACKEND_CONTAINER="$1"
ROUTER_READINESS_URL="$2"
EXPECTED_REPLICAS="$3"
shift 3
REPLICA_IDS=("$@")

if ! [[ "${EXPECTED_REPLICAS}" =~ ^[1-9]$|^10$ ]]; then
  echo "Expected replica count must be between 1 and 10." >&2
  exit 2
fi

tmp_dir="$(mktemp -d /tmp/myapp-ai-replicas.XXXXXX)"
trap 'rm -rf "${tmp_dir}"' EXIT

for replica_id in "${REPLICA_IDS[@]}"; do
  health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "${replica_id}")"
  image_id="$(docker inspect --format '{{.Image}}' "${replica_id}")"
  docker exec "${replica_id}" python -c \
    'import json, urllib.error, urllib.request
try:
    response = urllib.request.urlopen("http://127.0.0.1:4010/readyz", timeout=10)
    payload = json.load(response)
    payload["probe_http_status"] = response.status
except urllib.error.HTTPError as error:
    try:
        payload = json.load(error)
    except Exception:
        payload = {}
    payload.update({"ready": False, "probe_http_status": error.code, "probe_error": f"HTTP {error.code}"})
except Exception as error:
    payload = {"ready": False, "probe_error": f"{type(error).__name__}: {error}"}
print(json.dumps(payload))' \
    >"${tmp_dir}/${replica_id}.ready.json"
  python3 - "${replica_id}" "${image_id}" "${health_status}" \
    "${tmp_dir}/${replica_id}.ready.json" >"${tmp_dir}/${replica_id}.snapshot.json" <<'PY'
import json
import sys

print(json.dumps({
    "container_id": sys.argv[1],
    "image_id": sys.argv[2],
    "health_status": sys.argv[3],
    "readiness": json.load(open(sys.argv[4], encoding="utf-8")),
}))
PY
done

docker exec -i "${BACKEND_CONTAINER}" /home/frappe/frappe-bench/env/bin/python - \
  "${ROUTER_READINESS_URL}" >"${tmp_dir}/router.json" <<'PY'
import json
import sys
import urllib.error
import urllib.request

try:
    response = urllib.request.urlopen(sys.argv[1], timeout=10)
    payload = json.load(response)
    payload["probe_http_status"] = response.status
except urllib.error.HTTPError as error:
    try:
        payload = json.load(error)
    except Exception:
        payload = {}
    payload.update({"ready": False, "probe_http_status": error.code, "probe_error": f"HTTP {error.code}"})
except Exception as error:
    payload = {"ready": False, "probe_error": f"{type(error).__name__}: {error}"}
print(json.dumps(payload))
PY

python3 - "${tmp_dir}" >"${tmp_dir}/set.json" <<'PY'
import glob
import json
import sys

root = sys.argv[1]
replicas = [json.load(open(path, encoding="utf-8")) for path in sorted(glob.glob(f"{root}/*.snapshot.json"))]
router = json.load(open(f"{root}/router.json", encoding="utf-8"))
print(json.dumps({"replicas": replicas, "router": router}))
PY

python3 "${ROOT_DIR}/deploy/staging/verify-ai-replica-set.py" \
  --snapshot "${tmp_dir}/set.json" \
  --expected-replicas "${EXPECTED_REPLICAS}"
