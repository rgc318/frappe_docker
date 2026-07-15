#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
AI_ENV_FILE="${AI_ENV_FILE:-${ROOT_DIR}/.env.ai.local}"
LANGFUSE_ENV_FILE="${LANGFUSE_ENV_FILE:-${ROOT_DIR}/.env.langfuse.local}"
DOCKER_CONFIG="${DOCKER_CONFIG:-/tmp/myapp-docker-config}"
REPORT_DIR="${REPORT_DIR:-${ROOT_DIR}/ai-recovery-reports}"
TIMESTAMP="${TIMESTAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"

for file in "${ROOT_DIR}/.env" "${AI_ENV_FILE}" "${LANGFUSE_ENV_FILE}"; do
  if [[ ! -f "${file}" ]]; then
    echo "Missing required env file: ${file}" >&2
    exit 1
  fi
done
LANGFUSE_ENV_FILE="${LANGFUSE_ENV_FILE}" "${ROOT_DIR}/sync-langfuse-runtime-env.sh" >/dev/null
if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required." >&2
  exit 1
fi

compose() {
  DOCKER_CONFIG="${DOCKER_CONFIG}" docker compose \
    --env-file "${ROOT_DIR}/.env" \
    --env-file "${AI_ENV_FILE}" \
    --env-file "${LANGFUSE_ENV_FILE}" \
    -f "${ROOT_DIR}/compose.yaml" \
    -f "${ROOT_DIR}/overrides/compose.langfuse.yaml" \
    "$@"
}

mkdir -p "${DOCKER_CONFIG}" "${REPORT_DIR}"
umask 077
backup_file="$(mktemp "${AI_ENV_FILE}.rotation.XXXXXX")"
cp "${AI_ENV_FILE}" "${backup_file}"
old_token="$(python3 - "${AI_ENV_FILE}" <<'PY'
from pathlib import Path
import sys
rows = [line.split("=", 1)[1].strip() for line in Path(sys.argv[1]).read_text().splitlines() if line.startswith("MYAPP_AI_SERVICE_TOKEN=")]
if len(rows) != 1 or not rows[0]:
    raise SystemExit("Expected exactly one non-empty MYAPP_AI_SERVICE_TOKEN")
print(rows[0])
PY
)"
new_token="$(openssl rand -hex 32)"
rotation_complete=0

rollback() {
  if [[ "${rotation_complete}" != "1" ]]; then
    mv "${backup_file}" "${AI_ENV_FILE}"
    chmod 600 "${AI_ENV_FILE}"
    AI_ENV_FILE="${AI_ENV_FILE}" "${ROOT_DIR}/sync-ai-gateway-env.sh" >/dev/null 2>&1 || true
    compose up -d --force-recreate \
      backend queue-short queue-long queue-ai-vector scheduler ai-orchestrator >/dev/null 2>&1 || true
  else
    rm -f "${backup_file}"
  fi
}
trap rollback EXIT

python3 - "${AI_ENV_FILE}" "${new_token}" <<'PY'
from pathlib import Path
import os
import sys

path = Path(sys.argv[1])
token = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines()
indexes = [index for index, line in enumerate(lines) if line.startswith("MYAPP_AI_SERVICE_TOKEN=")]
if len(indexes) != 1:
    raise SystemExit("Expected exactly one MYAPP_AI_SERVICE_TOKEN line")
lines[indexes[0]] = f"MYAPP_AI_SERVICE_TOKEN={token}"
temporary = path.with_suffix(path.suffix + ".tmp")
temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
os.chmod(temporary, 0o600)
os.replace(temporary, path)
PY

AI_ENV_FILE="${AI_ENV_FILE}" "${ROOT_DIR}/sync-ai-gateway-env.sh"

compose up -d --force-recreate \
  backend queue-short queue-long queue-ai-vector scheduler ai-orchestrator

healthy=0
for _ in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:4010/health >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ "${healthy}" != "1" ]]; then
  echo "AI Orchestrator did not become healthy after token rotation." >&2
  exit 1
fi

old_status="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer ${old_token}" \
  http://127.0.0.1:4010/internal/v1/vector/products/status)"
new_status="$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
  -H "Authorization: Bearer ${new_token}" \
  http://127.0.0.1:4010/internal/v1/vector/products/status)"
if [[ "${old_status}" != "401" || "${new_status}" != "200" ]]; then
  echo "Token rotation verification failed: old=${old_status}, new=${new_status}." >&2
  exit 1
fi

old_fingerprint="$(printf '%s' "${old_token}" | sha256sum | cut -c1-12)"
new_fingerprint="$(printf '%s' "${new_token}" | sha256sum | cut -c1-12)"
rotation_complete=1
python3 - "${REPORT_DIR}/service-token-rotation-${TIMESTAMP}.json" \
  "${old_fingerprint}" "${new_fingerprint}" "${old_status}" "${new_status}" <<'PY'
import json
from pathlib import Path
import sys

report = {
    "schema": "myapp-ai-service-token-rotation-v1",
    "old_token_fingerprint": sys.argv[2],
    "new_token_fingerprint": sys.argv[3],
    "old_token_status": int(sys.argv[4]),
    "new_token_status": int(sys.argv[5]),
    "services_recreated": [
        "backend", "queue-short", "queue-long", "queue-ai-vector", "scheduler", "ai-orchestrator"
    ],
    "passed": sys.argv[4] == "401" and sys.argv[5] == "200",
    "secrets_recorded": False,
}
Path(sys.argv[1]).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
echo "AI service token rotation passed."
echo "Old token fingerprint ${old_fingerprint} now returns 401; new fingerprint ${new_fingerprint} returns 200."
