#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/deploy/staging/staging.env}"

if [[ $# -gt 0 ]]; then
  echo "Usage: ENV_FILE=<path> $0" >&2
  exit 2
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing staging environment file: ${ENV_FILE}" >&2
  exit 1
fi

"${ROOT_DIR}/validate-secret-env-files.sh" "${ENV_FILE}"

python3 - "${ENV_FILE}" <<'PY'
from pathlib import Path
import sys
from urllib.parse import urlparse

path = Path(sys.argv[1])
values: dict[str, str] = {}
for raw_line in path.read_text(encoding="utf-8").splitlines():
    line = raw_line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip()

required = (
    "CUSTOM_IMAGE",
    "CUSTOM_TAG",
    "MYAPP_AI_IMAGE",
    "MYAPP_AI_TAG",
    "MYAPP_AI_LITELLM_BASE_URL",
    "MYAPP_AI_LITELLM_API_KEY",
    "MYAPP_AI_SERVICE_TOKEN",
    "MYAPP_AI_FRAPPE_SITE_HOST",
)
missing = [key for key in required if not values.get(key)]
if missing:
    raise SystemExit(f"Missing required staging variables: {', '.join(missing)}")

placeholder_markers = ("<github-owner>", "replace-with", "changeit", "example.internal")
placeholders = [
    key
    for key in required
    if any(marker in values.get(key, "").lower() for marker in placeholder_markers)
]
if placeholders:
    raise SystemExit(f"Replace placeholder staging values before deployment: {', '.join(placeholders)}")

for key in ("MYAPP_AI_LITELLM_BASE_URL",):
    parsed = urlparse(values[key])
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise SystemExit(f"{key} must be an absolute HTTP(S) URL")

if len(values["MYAPP_AI_SERVICE_TOKEN"]) < 32:
    raise SystemExit("MYAPP_AI_SERVICE_TOKEN must contain at least 32 characters")

vector_enabled = values.get("MYAPP_AI_VECTOR_SEARCH_ENABLED", "0").lower() in {"1", "true", "yes"}
if vector_enabled:
    vector_required = ("MYAPP_AI_EMBEDDING_MODEL", "MYAPP_AI_QDRANT_ALIAS")
    vector_missing = [key for key in vector_required if not values.get(key)]
    if vector_missing:
        raise SystemExit(
            "Vector search is enabled but required variables are missing: " + ", ".join(vector_missing)
        )

langfuse_keys = (
    "MYAPP_AI_LANGFUSE_HOST",
    "MYAPP_AI_LANGFUSE_PUBLIC_KEY",
    "MYAPP_AI_LANGFUSE_SECRET_KEY",
)
configured_langfuse = [key for key in langfuse_keys if values.get(key)]
if configured_langfuse and len(configured_langfuse) != len(langfuse_keys):
    raise SystemExit("Configure all Langfuse host/public/secret values, or leave all three empty")

print("Staging environment validation passed; secret values were not printed.")
PY
