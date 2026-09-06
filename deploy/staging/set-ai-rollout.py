from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import tempfile
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any


RUNTIME_MAP_PATH = "/var/lib/haproxy/ai-router/rollout.map"
RUNTIME_AFFINITY_MAP_PATH = "/var/lib/haproxy/ai-router/release-affinity.map"
RELEASE_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")


def validate_release_id(value: str | None, *, field: str) -> str | None:
	if value is None:
		return None
	resolved = str(value).strip()
	if not resolved:
		return None
	if not RELEASE_ID_PATTERN.fullmatch(resolved):
		raise ValueError(
			f"{field} must use Docker tag-safe release characters and be at most 128 characters"
		)
	return resolved


def desired_entries(candidate_percent: int) -> dict[str, str]:
	entries = {"__default__": "ai_stable"}
	entries.update({str(bucket): "ai_candidate" for bucket in range(candidate_percent)})
	return entries


def render_map(entries: dict[str, str]) -> str:
	lines = [
		"# Managed by deploy/staging/set-ai-rollout.py; absent buckets route to ai_stable.",
		"__default__ ai_stable",
	]
	lines.extend(f"{bucket} ai_candidate" for bucket in range(100) if str(bucket) in entries)
	return "\n".join(lines) + "\n"


def affinity_entries(
	stable_release_id: str | None,
	candidate_release_id: str | None,
	*,
	stable_affinity_enabled: bool = True,
) -> dict[str, str]:
	entries = {"__default__": "ai_affinity_missing"}
	if stable_release_id and stable_affinity_enabled:
		entries[stable_release_id] = "ai_stable"
	if candidate_release_id:
		entries[candidate_release_id] = "ai_candidate"
	return entries


def render_affinity_map(entries: dict[str, str]) -> str:
	lines = [
		"# Managed by deploy/staging/set-ai-rollout.py; unknown releases fail closed.",
		"__default__ ai_affinity_missing",
	]
	lines.extend(
		f"{release_id} {backend}"
		for release_id, backend in entries.items()
		if release_id != "__default__"
	)
	return "\n".join(lines) + "\n"


def parse_show_map(payload: str) -> dict[str, str]:
	entries: dict[str, str] = {}
	for line in payload.splitlines():
		parts = line.split(maxsplit=2)
		if len(parts) == 3 and parts[0].startswith("0x"):
			entries[parts[1]] = parts[2]
	return entries


def verify_entries(actual: dict[str, str], expected: dict[str, str]) -> None:
	if actual != expected:
		raise RuntimeError(
			"HAProxy rollout map verification failed: "
			f"expected {len(expected)} entries, got {len(actual)}"
		)


def _atomic_write(path: Path, content: str, *, mode: int = 0o644) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as handle:
		handle.write(content)
		temporary_path = Path(handle.name)
	os.chmod(temporary_path, mode)
	os.replace(temporary_path, path)


def _socket_command(container: str, command: str) -> str:
	result = subprocess.run(
		["docker", "exec", "-i", container, "socat", "stdio", "/tmp/haproxy-admin.sock"],
		input=command.rstrip("\n") + "\n",
		capture_output=True,
		text=True,
		check=False,
	)
	if result.returncode != 0:
		raise RuntimeError(result.stderr.strip() or "HAProxy runtime socket command failed")
	return result.stdout


def _map_identifier(container: str, runtime_map_path: str) -> str:
	payload = _socket_command(container, "show map")
	for line in payload.splitlines():
		match = re.match(r"^(\d+) \(([^)]+)\)", line.strip())
		if match and match.group(2) == runtime_map_path:
			return f"#{match.group(1)}"
	raise RuntimeError(f"HAProxy runtime map is not loaded: {runtime_map_path}")


def _apply_runtime_map(container: str, runtime_map_path: str, entries: dict[str, str]) -> None:
	map_id = _map_identifier(container, runtime_map_path)
	prepare_output = _socket_command(container, f"prepare map {map_id}")
	match = re.search(r"New version created:\s*(\d+)", prepare_output)
	if not match:
		raise RuntimeError(f"HAProxy did not create a map transaction: {prepare_output.strip()}")
	version = match.group(1)
	transaction = f"@{version}"
	try:
		commands = [f"clear map {transaction} {map_id}"]
		commands.extend(
			f"add map {transaction} {map_id} {key} {value}"
			for key, value in entries.items()
		)
		commands.append(f"commit map {transaction} {map_id}")
		# HAProxy closes a non-interactive CLI connection after one newline-delimited
		# command. Semicolon separation keeps the whole transaction in one session.
		_socket_command(container, "; ".join(commands))
	except Exception:
		try:
			_socket_command(container, f"abort map {transaction} {map_id}")
		except Exception:
			pass
		raise
	verify_entries(parse_show_map(_socket_command(container, f"show map {map_id}")), entries)


def _state_payload(
	*,
	status: str,
	candidate_percent: int,
	stable_release_id: str | None,
	candidate_release_id: str | None,
	candidate_replicas: int,
	stable_pool_release_id: str | None = None,
	stable_affinity_enabled: bool = True,
	drain_started_at: str | None = None,
	drain_deadline: str | None = None,
	drain_action: str | None = None,
	retired_release_id: str | None = None,
	error: str | None = None,
) -> dict[str, Any]:
	return {
		"schema_version": "myapp-ai-rollout-state-v2",
		"status": status,
		"candidate_percent": candidate_percent,
		"stable_percent": 100 - candidate_percent,
		"stable_release_id": stable_release_id,
		"candidate_release_id": candidate_release_id,
		"stable_pool_release_id": stable_pool_release_id or stable_release_id,
		"candidate_replicas": candidate_replicas,
		"stable_affinity_enabled": stable_affinity_enabled,
		"drain_started_at": drain_started_at,
		"drain_deadline": drain_deadline,
		"drain_action": drain_action,
		"retired_release_id": retired_release_id,
		"updated_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
		"error": error,
	}


def apply_rollout(
	*,
	container: str,
	map_path: Path,
	affinity_map_path: Path,
	state_path: Path,
	candidate_percent: int,
	stable_release_id: str | None,
	candidate_release_id: str | None,
	candidate_replicas: int = 1,
	runtime_map_path: str = RUNTIME_MAP_PATH,
	runtime_affinity_map_path: str = RUNTIME_AFFINITY_MAP_PATH,
	final_status: str = "active",
	stable_pool_release_id: str | None = None,
	stable_affinity_enabled: bool = True,
	drain_started_at: str | None = None,
	drain_deadline: str | None = None,
	drain_action: str | None = None,
	retired_release_id: str | None = None,
) -> dict[str, Any]:
	stable_release_id = validate_release_id(stable_release_id, field="stable_release_id")
	candidate_release_id = validate_release_id(candidate_release_id, field="candidate_release_id")
	stable_pool_release_id = validate_release_id(
		stable_pool_release_id, field="stable_pool_release_id",
	)
	retired_release_id = validate_release_id(retired_release_id, field="retired_release_id")
	new_entries = desired_entries(candidate_percent)
	new_affinity_entries = affinity_entries(
		stable_release_id,
		candidate_release_id,
		stable_affinity_enabled=stable_affinity_enabled,
	)
	old_content = map_path.read_text(encoding="utf-8")
	old_entries = parse_file_entries(old_content)
	old_affinity_content = affinity_map_path.read_text(encoding="utf-8")
	old_affinity_entries = parse_affinity_file_entries(old_affinity_content)
	old_state = None
	if state_path.exists():
		try:
			candidate_state = json.loads(state_path.read_text(encoding="utf-8"))
			if isinstance(candidate_state, dict):
				old_state = candidate_state
		except (OSError, json.JSONDecodeError):
			pass
	pending = _state_payload(
		status="applying",
		candidate_percent=candidate_percent,
		stable_release_id=stable_release_id,
		candidate_release_id=candidate_release_id,
		candidate_replicas=candidate_replicas,
		stable_pool_release_id=stable_pool_release_id,
		stable_affinity_enabled=stable_affinity_enabled,
		drain_started_at=drain_started_at,
		drain_deadline=drain_deadline,
		drain_action=drain_action,
		retired_release_id=retired_release_id,
	)
	_atomic_write(state_path, json.dumps(pending, ensure_ascii=False, sort_keys=True) + "\n", mode=0o640)
	_atomic_write(map_path, render_map(new_entries))
	_atomic_write(affinity_map_path, render_affinity_map(new_affinity_entries))
	try:
		_apply_runtime_map(container, runtime_affinity_map_path, new_affinity_entries)
		_apply_runtime_map(container, runtime_map_path, new_entries)
	except Exception as error:
		_atomic_write(map_path, old_content)
		_atomic_write(affinity_map_path, old_affinity_content)
		try:
			_apply_runtime_map(container, runtime_affinity_map_path, old_affinity_entries)
			_apply_runtime_map(container, runtime_map_path, old_entries)
		except Exception as rollback_error:
			error = RuntimeError(f"{error}; runtime rollback also failed: {rollback_error}")
		if old_state is not None:
			failed = {
				**old_state,
				"last_apply_error": str(error),
				"last_apply_failed_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
			}
		else:
			failed = _state_payload(
				status="failed",
				candidate_percent=candidate_percent,
				stable_release_id=stable_release_id,
				candidate_release_id=candidate_release_id,
				candidate_replicas=candidate_replicas,
				stable_pool_release_id=stable_pool_release_id,
				stable_affinity_enabled=stable_affinity_enabled,
				drain_started_at=drain_started_at,
				drain_deadline=drain_deadline,
				drain_action=drain_action,
				retired_release_id=retired_release_id,
				error=str(error),
			)
		_atomic_write(state_path, json.dumps(failed, ensure_ascii=False, sort_keys=True) + "\n", mode=0o640)
		raise
	active = _state_payload(
		status=final_status,
		candidate_percent=candidate_percent,
		stable_release_id=stable_release_id,
		candidate_release_id=candidate_release_id,
		candidate_replicas=candidate_replicas,
		stable_pool_release_id=stable_pool_release_id,
		stable_affinity_enabled=stable_affinity_enabled,
		drain_started_at=drain_started_at,
		drain_deadline=drain_deadline,
		drain_action=drain_action,
		retired_release_id=retired_release_id,
	)
	_atomic_write(state_path, json.dumps(active, ensure_ascii=False, sort_keys=True) + "\n", mode=0o640)
	return active


def parse_file_entries(content: str) -> dict[str, str]:
	entries: dict[str, str] = {}
	for raw_line in content.splitlines():
		line = raw_line.strip()
		if not line or line.startswith("#"):
			continue
		parts = line.split()
		if len(parts) != 2:
			raise ValueError(f"Invalid rollout map line: {raw_line}")
		entries[parts[0]] = parts[1]
	if entries.get("__default__") != "ai_stable":
		raise ValueError("Rollout map must retain __default__ ai_stable")
	return entries


def parse_affinity_file_entries(content: str) -> dict[str, str]:
	entries: dict[str, str] = {}
	for raw_line in content.splitlines():
		line = raw_line.strip()
		if not line or line.startswith("#"):
			continue
		parts = line.split()
		if len(parts) != 2:
			raise ValueError(f"Invalid release affinity map line: {raw_line}")
		entries[parts[0]] = parts[1]
	if entries.get("__default__") != "ai_affinity_missing":
		raise ValueError("Release affinity map must retain __default__ ai_affinity_missing")
	return entries


def main() -> int:
	parser = argparse.ArgumentParser(description="Persist and atomically apply an AI candidate traffic percentage.")
	parser.add_argument("--router-container", required=True)
	parser.add_argument("--map-path", required=True)
	parser.add_argument("--affinity-map-path", required=True)
	parser.add_argument("--state-path", required=True)
	parser.add_argument("--candidate-percent", required=True, type=int)
	parser.add_argument("--stable-release-id")
	parser.add_argument("--candidate-release-id")
	parser.add_argument("--candidate-replicas", type=int, default=1)
	parser.add_argument(
		"--final-status", choices=("active", "draining", "promoting", "completed"),
		default="active",
	)
	parser.add_argument("--stable-pool-release-id")
	parser.add_argument("--disable-stable-affinity", action="store_true")
	parser.add_argument("--drain-seconds", type=int)
	parser.add_argument("--drain-started-at")
	parser.add_argument("--drain-deadline")
	parser.add_argument("--drain-action", choices=("promote_candidate", "retire_candidate"))
	parser.add_argument("--retired-release-id")
	args = parser.parse_args()
	if not 0 <= args.candidate_percent <= 100:
		parser.error("--candidate-percent must be between 0 and 100")
	if args.final_status == "completed" and args.candidate_percent != 0:
		parser.error("--final-status completed requires --candidate-percent 0")
	if args.final_status == "draining" and args.candidate_percent not in {0, 100}:
		parser.error("--final-status draining requires --candidate-percent 0 or 100")
	if args.final_status == "promoting" and args.candidate_percent != 100:
		parser.error("--final-status promoting requires --candidate-percent 100")
	if args.final_status == "promoting" and not args.disable_stable_affinity:
		parser.error("--final-status promoting requires --disable-stable-affinity")
	if args.final_status == "draining" and args.drain_action is None:
		parser.error("--final-status draining requires --drain-action")
	if args.final_status == "draining" and args.candidate_percent == 100 and args.drain_action != "promote_candidate":
		parser.error("100% candidate draining requires --drain-action promote_candidate")
	if args.final_status == "draining" and args.candidate_percent == 0 and args.drain_action != "retire_candidate":
		parser.error("0% candidate draining requires --drain-action retire_candidate")
	if args.final_status == "promoting" and args.drain_action != "promote_candidate":
		parser.error("--final-status promoting requires --drain-action promote_candidate")
	if args.final_status == "completed" and args.candidate_release_id:
		parser.error("--final-status completed must not retain --candidate-release-id")
	if not 1 <= args.candidate_replicas <= 10:
		parser.error("--candidate-replicas must be between 1 and 10")
	drain_started_at = args.drain_started_at
	drain_deadline = args.drain_deadline
	if args.final_status == "draining" and not drain_deadline:
		if args.drain_seconds is None or args.drain_seconds < 1:
			parser.error("--final-status draining requires a positive --drain-seconds")
		now = datetime.now(UTC)
		drain_started_at = now.isoformat().replace("+00:00", "Z")
		drain_deadline = (now + timedelta(seconds=args.drain_seconds)).isoformat().replace("+00:00", "Z")
	if args.final_status == "promoting" and (not drain_started_at or not drain_deadline):
		parser.error("--final-status promoting requires --drain-started-at and --drain-deadline")
	state = apply_rollout(
		container=args.router_container,
		map_path=Path(args.map_path),
		affinity_map_path=Path(args.affinity_map_path),
		state_path=Path(args.state_path),
		candidate_percent=args.candidate_percent,
		stable_release_id=args.stable_release_id,
		candidate_release_id=args.candidate_release_id,
		candidate_replicas=args.candidate_replicas,
		final_status=args.final_status,
		stable_pool_release_id=args.stable_pool_release_id,
		stable_affinity_enabled=not args.disable_stable_affinity,
		drain_started_at=drain_started_at,
		drain_deadline=drain_deadline,
		drain_action=args.drain_action,
		retired_release_id=args.retired_release_id,
	)
	print(json.dumps(state, ensure_ascii=False, sort_keys=True))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
