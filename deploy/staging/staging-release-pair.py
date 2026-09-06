from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


SHA_PATTERN = re.compile(r"^[0-9a-f]{40,64}$")


def _load(path: str) -> Any:
	return json.loads(Path(path).read_text(encoding="utf-8"))


def _image(path: str, *, role: str) -> dict[str, Any]:
	payload = _load(path)
	if not isinstance(payload, list) or len(payload) != 1 or not isinstance(payload[0], dict):
		raise ValueError(f"{role} image inspect must contain exactly one image")
	item = payload[0]
	labels = (item.get("Config") or {}).get("Labels") or {}
	return {
		"image_id": str(item.get("Id") or "").strip(),
		"repo_tags": sorted(str(value) for value in item.get("RepoTags") or []),
		"repo_digests": sorted(str(value) for value in item.get("RepoDigests") or []),
		"labels": {str(key): str(value) for key, value in labels.items()},
	}


def _require_revision(value: object, *, name: str) -> str:
	revision = str(value or "").strip().lower()
	if not SHA_PATTERN.fullmatch(revision):
		raise ValueError(f"{name} must be an immutable 40-64 character hex revision")
	return revision


def _require_label(labels: dict[str, str], name: str, expected: str) -> None:
	actual = labels.get(name, "").strip()
	if actual != expected:
		raise ValueError(f"Image label {name} mismatch: expected {expected}, got {actual or '-'}")


def _identity(image: dict[str, Any], *, repository: str, tag: str) -> dict[str, Any]:
	if not image["image_id"]:
		raise ValueError(f"Image {repository}:{tag} has no immutable image ID")
	if f"{repository}:{tag}" not in image["repo_tags"]:
		raise ValueError(f"Image inspect does not contain expected tag {repository}:{tag}")
	return {
		"repository": repository,
		"tag": tag,
		"image_id": image["image_id"],
		"repo_digests": image["repo_digests"],
	}


def capture(args: argparse.Namespace) -> dict[str, Any]:
	if args.backend_tag != args.ai_tag:
		raise ValueError("Backend and AI tags must be identical for a release pair")
	release_id = args.backend_tag
	backend = _image(args.backend_inspect, role="Backend")
	ai = _image(args.ai_inspect, role="AI")
	readiness = _load(args.readiness)
	report_bytes = Path(args.canary_report).read_bytes()
	canary = json.loads(report_bytes)

	if canary.get("status") != "passed":
		raise ValueError("Only a passed AI canary report can qualify a rollback release pair")
	if str(canary.get("release_id") or "").strip() != release_id:
		raise ValueError("AI canary report release_id does not match the release pair tag")
	if readiness.get("ready") is not True:
		raise ValueError("AI readiness must be true before recording a release pair")
	if str(readiness.get("release_id") or "").strip() != release_id:
		raise ValueError("Running AI release_id does not match the release pair tag")

	backend_revision = _require_revision(
		backend["labels"].get("org.rgc.myapp_revision"), name="Backend revision",
	)
	ai_revision = _require_revision(readiness.get("runtime_revision"), name="AI runtime revision")
	if str(canary.get("backend_revision") or "").strip().lower() != backend_revision:
		raise ValueError("AI canary Backend revision does not match the running Backend image")
	for scenario in canary.get("scenarios") or []:
		if not isinstance(scenario, dict) or scenario.get("status") != "passed":
			continue
		scenario_revision = scenario.get("runtime_revision")
		if scenario.get("scenario") == "readiness":
			scenario_revision = (scenario.get("runtime") or {}).get("revision")
		if scenario_revision and str(scenario_revision).strip().lower() != ai_revision:
			raise ValueError("AI canary mixed more than one Orchestrator runtime revision")
	_require_label(backend["labels"], "org.rgc.release_id", release_id)
	_require_label(backend["labels"], "org.rgc.myapp_revision", backend_revision)
	_require_label(ai["labels"], "org.rgc.release_id", release_id)
	_require_label(ai["labels"], "org.opencontainers.image.revision", ai_revision)

	return {
		"schema_version": "myapp-staging-release-pair-v1",
		"qualification_status": "passed",
		"release_id": release_id,
		"recorded_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
		"parent_revision": args.parent_revision or None,
		"backend": {
			**_identity(backend, repository=args.backend_repository, tag=args.backend_tag),
			"revision": backend_revision,
		},
		"ai_orchestrator": {
			**_identity(ai, repository=args.ai_repository, tag=args.ai_tag),
			"revision": ai_revision,
			"protocol_version": readiness.get("protocol_version"),
		},
		"canary": {
			"schema_version": canary.get("schema_version"),
			"status": canary.get("status"),
			"completed_at": canary.get("completed_at"),
			"report_sha256": hashlib.sha256(report_bytes).hexdigest(),
		},
	}


def _verify_identity(*, expected: dict[str, Any], actual: dict[str, Any], role: str) -> None:
	if actual["image_id"] != expected.get("image_id"):
		raise ValueError(
			f"{role} image ID drift: expected {expected.get('image_id')}, got {actual['image_id']}"
		)
	expected_digests = set(expected.get("repo_digests") or [])
	actual_digests = set(actual.get("repo_digests") or [])
	if expected_digests and not expected_digests.intersection(actual_digests):
		raise ValueError(f"{role} image digest does not match the qualified release pair")
	expected_ref = f"{expected.get('repository')}:{expected.get('tag')}"
	if expected_ref not in actual["repo_tags"]:
		raise ValueError(f"{role} image does not contain qualified tag {expected_ref}")


def verify(args: argparse.Namespace) -> dict[str, Any]:
	manifest = _load(args.manifest)
	if manifest.get("schema_version") != "myapp-staging-release-pair-v1":
		raise ValueError("Unsupported staging release pair manifest")
	if manifest.get("qualification_status") != "passed":
		raise ValueError("Rollback target is not qualified by a passed canary")
	if manifest.get("release_id") != args.release_id:
		raise ValueError("Rollback tag does not match release pair manifest")

	backend = _image(args.backend_inspect, role="Backend")
	ai = _image(args.ai_inspect, role="AI")
	_verify_identity(expected=manifest["backend"], actual=backend, role="Backend")
	_verify_identity(expected=manifest["ai_orchestrator"], actual=ai, role="AI")
	_require_label(backend["labels"], "org.rgc.release_id", args.release_id)
	_require_label(backend["labels"], "org.rgc.myapp_revision", manifest["backend"]["revision"])
	_require_label(ai["labels"], "org.rgc.release_id", args.release_id)
	_require_label(
		ai["labels"], "org.opencontainers.image.revision", manifest["ai_orchestrator"]["revision"],
	)
	return {
		"schema_version": "myapp-staging-release-pair-verification-v1",
		"status": "passed",
		"release_id": args.release_id,
		"backend_revision": manifest["backend"]["revision"],
		"ai_revision": manifest["ai_orchestrator"]["revision"],
	}


def main() -> int:
	parser = argparse.ArgumentParser(description="Capture or verify an immutable staging release pair.")
	subparsers = parser.add_subparsers(dest="command", required=True)

	capture_parser = subparsers.add_parser("capture")
	capture_parser.add_argument("--backend-inspect", required=True)
	capture_parser.add_argument("--ai-inspect", required=True)
	capture_parser.add_argument("--readiness", required=True)
	capture_parser.add_argument("--canary-report", required=True)
	capture_parser.add_argument("--backend-repository", required=True)
	capture_parser.add_argument("--backend-tag", required=True)
	capture_parser.add_argument("--ai-repository", required=True)
	capture_parser.add_argument("--ai-tag", required=True)
	capture_parser.add_argument("--parent-revision", default="")

	verify_parser = subparsers.add_parser("verify")
	verify_parser.add_argument("--manifest", required=True)
	verify_parser.add_argument("--release-id", required=True)
	verify_parser.add_argument("--backend-inspect", required=True)
	verify_parser.add_argument("--ai-inspect", required=True)

	args = parser.parse_args()
	result = capture(args) if args.command == "capture" else verify(args)
	print(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2))
	return 0


if __name__ == "__main__":
	try:
		raise SystemExit(main())
	except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
		raise SystemExit(f"Staging release pair validation failed: {error}") from error
