#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <expected-gateway-env-file> <container-id-or-name> [...]" >&2
  exit 2
fi

EXPECTED_ENV_FILE="$1"
shift

python3 - "${EXPECTED_ENV_FILE}" "$@" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys


expected_path = Path(sys.argv[1])
containers = sys.argv[2:]
if not expected_path.is_file():
    raise SystemExit(f"Missing expected AI gateway environment file: {expected_path}")


gateway_keys = {
    "MYAPP_AI_ORCHESTRATOR_URL",
    "MYAPP_AI_SERVICE_TOKEN",
    "MYAPP_AI_AGENT_RUNTIME_ENABLED",
    "MYAPP_AI_VECTOR_SEARCH_ENABLED",
    "MYAPP_AI_EMBEDDING_MODEL",
    "MYAPP_AI_QDRANT_COLLECTION",
    "MYAPP_AI_QDRANT_ALIAS",
    "MYAPP_AI_VECTOR_EXCLUDED_ITEM_PREFIXES",
    "MYAPP_AI_ENVIRONMENT",
    "MYAPP_AI_RETENTION_DAYS",
    "MYAPP_AI_RUN_STALE_TIMEOUT_SECONDS",
}

expected_defaults = {
    "MYAPP_AI_AGENT_RUNTIME_ENABLED": "1",
    "MYAPP_AI_RUN_STALE_TIMEOUT_SECONDS": "900",
}


def parse_env_lines(lines: list[str], *, source: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in lines:
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key not in gateway_keys:
            continue
        if key in values:
            raise SystemExit(f"Duplicate {key} in {source}")
        values[key] = value
    return values


configured_expected = parse_env_lines(
    expected_path.read_text(encoding="utf-8").splitlines(),
    source=str(expected_path),
)
if not configured_expected:
    raise SystemExit(f"No MYAPP_AI_* values found in {expected_path}")
expected = {**expected_defaults, **configured_expected}

failed = False
baseline_actual: dict[str, str] | None = None
baseline_name = ""
for container in containers:
    completed = subprocess.run(
        ["docker", "inspect", container],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        print(f"AI runtime configuration check failed: cannot inspect {container}", file=sys.stderr)
        failed = True
        continue
    payload = json.loads(completed.stdout)
    if len(payload) != 1:
        print(f"AI runtime configuration check failed: invalid inspect result for {container}", file=sys.stderr)
        failed = True
        continue
    container_name = str(payload[0].get("Name") or container).lstrip("/")
    actual = parse_env_lines(
        list((payload[0].get("Config") or {}).get("Env") or []),
        source=container_name,
    )
    mismatched = sorted(
        key for key, expected_value in expected.items()
        if actual.get(key) != expected_value
    )
    if mismatched:
        print(
            f"AI runtime configuration mismatch in {container_name}: {', '.join(mismatched)}",
            file=sys.stderr,
        )
        failed = True
    if baseline_actual is None:
        baseline_actual = actual
        baseline_name = container_name
        continue
    inconsistent = sorted(
        key for key in gateway_keys
        if actual.get(key) != baseline_actual.get(key)
    )
    if inconsistent:
        print(
            "AI runtime configuration differs between "
            f"{baseline_name} and {container_name}: {', '.join(inconsistent)}",
            file=sys.stderr,
        )
        failed = True

if failed:
    raise SystemExit(1)

print(f"AI gateway runtime configuration is consistent across {len(containers)} containers.")
PY
