#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <backend-container-id-or-name> [orchestrator-readiness-url]" >&2
  exit 2
fi

BACKEND_CONTAINER="$1"
READINESS_URL="${2:-http://ai-orchestrator:4010/readyz}"

docker exec -i "${BACKEND_CONTAINER}" bash -lc \
  'cd /home/frappe/frappe-bench && env/bin/python - "$1"' bash "${READINESS_URL}" <<'PY'
from __future__ import annotations

import json
import sys
import time
import urllib.error
import urllib.request

from myapp.ai_runtime_contract import evaluate_ai_runtime_compatibility


readiness_url = sys.argv[1]
runtime_status = None
last_error = None
for _attempt in range(20):
    try:
        request = urllib.request.Request(
            readiness_url,
            headers={"Accept": "application/json"},
            method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=5) as response:
                runtime_status = json.loads(response.read().decode("utf-8") or "{}")
        except urllib.error.HTTPError as error:
            if error.code == 404:
                raise SystemExit(
                    "AI runtime compatibility check failed: the running orchestrator "
                    "does not expose /readyz; rebuild it with the current release."
                ) from error
            if error.code != 503:
                raise SystemExit(
                    "AI runtime compatibility check failed: readiness endpoint returned "
                    f"HTTP {error.code}."
                ) from error
            runtime_status = json.loads(error.read().decode("utf-8") or "{}")
        break
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        last_error = type(error).__name__
        time.sleep(1.5)

if not isinstance(runtime_status, dict):
    raise SystemExit(
        "AI runtime compatibility check failed: readiness endpoint did not return JSON"
        + (f" ({last_error})" if last_error else "")
    )

result = evaluate_ai_runtime_compatibility(runtime_status)
if not result["ready"]:
    print(
        "AI runtime compatibility check failed: "
        f"status={result['status']} code={result['code']}",
        file=sys.stderr,
    )
    protocol = result["protocol"]
    if protocol["status"] != "ready":
        print(
            "  protocol: "
            f"expected={protocol.get('expected_version') or '-'} "
            f"actual={protocol.get('actual_version') or '-'}",
            file=sys.stderr,
        )
    for family, row in result.get("schema_families", {}).items():
        if row["status"] != "ready":
            print(
                f"  schema {family}: expected={','.join(row.get('expected_versions') or []) or '-'} "
                f"actual={','.join(row.get('actual_versions') or []) or '-'}",
                file=sys.stderr,
            )
    raise SystemExit(1)

print(
    "AI runtime compatibility is ready: "
    f"protocol={result['protocol']['actual_version']} "
    f"release={result['runtime'].get('release_id') or 'unversioned'} "
    f"runtime={result['runtime']['revision'] or 'unversioned'} "
    f"schemas={len(result.get('schema_families', {}))} "
    f"scenarios={len(result['scenarios'])}."
)
PY
