"""Validate rendered Compose without logging environment values or credentials."""

import json
import re
import sys

ERP_SERVICES = ("configurator", "backend", "frontend", "websocket", "queue-short", "queue-long", "queue-ai-vector", "scheduler")


def validate(config):
    services = config.get("services", {})
    errors = []
    if "traefik" in services or "proxy" not in services:
        errors.append("production requires the single HTTPS proxy, not the dashboard proxy")
    for name in (*ERP_SERVICES, "ai-orchestrator"):
        service = services.get(name, {})
        image = service.get("image", "")
        tag = image.rsplit("/", 1)[-1].partition(":")[2]
        digest = re.search(r"@sha256:[0-9a-f]{64}$", image)
        if not digest and (not tag or tag.lower() in {"latest", "develop", "main", "master", "stable"}):
            errors.append(f"{name}: explicit versioned image required")
        if service.get("build"):
            errors.append(f"{name}: runtime build forbidden")
        command = " ".join(service.get("command", []) or [])
        if "pip install" in command or "bench serve" in command:
            errors.append(f"{name}: development startup forbidden")
        if any(v.get("type") == "bind" and "/apps" in v.get("target", "") for v in service.get("volumes", [])):
            errors.append(f"{name}: application source bind mount forbidden")
    if len({services.get(name, {}).get("image") for name in ERP_SERVICES}) != 1:
        errors.append("ERP services must use the same approved image")
    for name in ("backend", "db", "ai-orchestrator", "ai-vector", "redis-cache", "redis-queue"):
        if services.get(name, {}).get("ports"):
            errors.append(f"{name}: direct host ports forbidden")
    backend = services.get("backend", {})
    if backend.get("environment", {}).get("ENABLE_PYCHARM_DEBUG") != "0":
        errors.append("backend: debugger must be disabled")
    if "gunicorn" not in " ".join(backend.get("command", [])):
        errors.append("backend: Gunicorn required")
    password = services.get("db", {}).get("environment", {}).get("MYSQL_ROOT_PASSWORD", "")
    if len(password) < 16 or password.lower() in {"change-me-in-production", "replace-with-secure-password"}:
        errors.append("db: non-placeholder password of at least 16 characters required")
    return errors


if __name__ == "__main__":
    errors = validate(json.load(sys.stdin))
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        sys.exit(1)
    print("Production Compose static safety checks passed (not a release approval).")
