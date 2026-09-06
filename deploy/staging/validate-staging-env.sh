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
import os
import re
import sys
from pathlib import Path
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

require_release_pair = os.environ.get(
    "STAGING_REQUIRE_PAIRED_RELEASE",
    values.get("STAGING_REQUIRE_PAIRED_RELEASE", "0"),
).lower() in {"1", "true", "yes"}
if require_release_pair and values["CUSTOM_TAG"] != values["MYAPP_AI_TAG"]:
    raise SystemExit("CUSTOM_TAG and MYAPP_AI_TAG must identify the same Backend/AI release pair")

release_tag_pattern = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
for key in ("CUSTOM_TAG", "MYAPP_AI_TAG", "MYAPP_AI_CANDIDATE_TAG"):
    value = values.get(key, "")
    if value and not release_tag_pattern.fullmatch(value):
        raise SystemExit(f"{key} must be a Docker tag-safe release identifier of at most 128 characters")

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

try:
    orchestrator_replicas = int(values.get("MYAPP_AI_ORCHESTRATOR_REPLICAS", "1"))
except ValueError as error:
    raise SystemExit("MYAPP_AI_ORCHESTRATOR_REPLICAS must be an integer") from error
if not 1 <= orchestrator_replicas <= 10:
    raise SystemExit("MYAPP_AI_ORCHESTRATOR_REPLICAS must be between 1 and 10")
orchestrator_url = urlparse(values.get("MYAPP_AI_ORCHESTRATOR_URL", "http://ai-router:4010"))
if orchestrator_replicas > 1 and orchestrator_url.hostname != "ai-router":
    raise SystemExit("Multiple AI replicas require MYAPP_AI_ORCHESTRATOR_URL=http://ai-router:4010")

try:
    candidate_replicas = int(values.get("MYAPP_AI_CANDIDATE_REPLICAS", "1"))
except ValueError as error:
    raise SystemExit("MYAPP_AI_CANDIDATE_REPLICAS must be an integer") from error
if not 1 <= candidate_replicas <= 10:
    raise SystemExit("MYAPP_AI_CANDIDATE_REPLICAS must be between 1 and 10")
candidate_tag = values.get("MYAPP_AI_CANDIDATE_TAG", "")
if candidate_tag and candidate_tag == values["MYAPP_AI_TAG"]:
    raise SystemExit("MYAPP_AI_CANDIDATE_TAG must differ from MYAPP_AI_TAG")
try:
    rollout_stages = [int(value) for value in values.get("AI_ROLLOUT_STAGES", "5,25,50,100").split(",")]
except ValueError as error:
    raise SystemExit("AI_ROLLOUT_STAGES must be comma-separated integers") from error
if not rollout_stages or any(not 1 <= value <= 100 for value in rollout_stages):
    raise SystemExit("AI_ROLLOUT_STAGES values must be between 1 and 100")
if rollout_stages != sorted(set(rollout_stages)):
    raise SystemExit("AI_ROLLOUT_STAGES must be strictly increasing without duplicates")
for key, minimum in (
    ("AI_ROLLOUT_DWELL_SECONDS", 0),
    ("AI_ROLLOUT_SAMPLE_COUNT", 100),
    ("AI_ROLLOUT_DRAIN_SECONDS", 60),
):
    try:
        default = {"AI_ROLLOUT_DWELL_SECONDS": "30", "AI_ROLLOUT_SAMPLE_COUNT": "500"}.get(
            key, "86400"
        )
        value = int(values.get(key, default))
    except ValueError as error:
        raise SystemExit(f"{key} must be an integer") from error
    if value < minimum:
        raise SystemExit(f"{key} must be at least {minimum}")

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
