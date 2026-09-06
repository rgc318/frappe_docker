from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


IDENTITY_FIELDS = (
	"release_id",
	"runtime_revision",
	"protocol_version",
	"prompt_manifest_sha256",
	"schema_manifest_sha256",
	"tool_manifest_sha256",
)


def _load(path: str | Path) -> Any:
	return json.loads(Path(path).read_text(encoding="utf-8"))


def evaluate(snapshot: dict[str, Any], *, expected_replicas: int) -> dict[str, Any]:
	replicas = snapshot.get("replicas") or []
	router = snapshot.get("router") or {}
	violations: list[dict[str, str]] = []
	if len(replicas) != expected_replicas:
		violations.append({
			"code": "AI_REPLICA_COUNT_MISMATCH",
			"message": f"Expected {expected_replicas} replicas, got {len(replicas)}.",
		})

	image_ids = {str(item.get("image_id") or "") for item in replicas}
	if len(image_ids) > 1:
		violations.append({
			"code": "AI_REPLICA_IMAGE_DRIFT",
			"message": "Orchestrator replicas do not use the same immutable image ID.",
		})

	ready_replicas = []
	for replica in replicas:
		container_id = str(replica.get("container_id") or "unknown")[:12]
		readiness = replica.get("readiness") or {}
		if replica.get("health_status") != "healthy" or readiness.get("ready") is not True:
			detail = str(readiness.get("probe_error") or "").strip()
			violations.append({
				"code": "AI_REPLICA_NOT_READY",
				"message": (
					f"Replica {container_id} is not healthy and ready"
					+ (f": {detail}." if detail else ".")
				),
			})
			continue
		missing_fields = [field for field in IDENTITY_FIELDS if not readiness.get(field)]
		if missing_fields:
			violations.append({
				"code": "AI_REPLICA_RUNTIME_IDENTITY_MISSING",
				"message": (
					f"Replica {container_id} is missing runtime identity fields: "
					+ ", ".join(missing_fields)
					+ "."
				),
			})
			continue
		ready_replicas.append(replica)

	if ready_replicas:
		baseline = ready_replicas[0]
		baseline_readiness = baseline["readiness"]
		for replica in ready_replicas[1:]:
			for field in IDENTITY_FIELDS:
				if replica["readiness"].get(field) != baseline_readiness.get(field):
					violations.append({
						"code": "AI_REPLICA_RUNTIME_DRIFT",
						"message": f"Orchestrator replica field {field} is inconsistent.",
					})

		if router.get("ready") is not True:
			detail = str(router.get("probe_error") or "").strip()
			violations.append({
				"code": "AI_ROUTER_NOT_READY",
				"message": (
					"AI router did not return a ready runtime"
					+ (f": {detail}." if detail else ".")
				),
			})
		else:
			missing_fields = [field for field in IDENTITY_FIELDS if not router.get(field)]
			if missing_fields:
				violations.append({
					"code": "AI_ROUTER_RUNTIME_IDENTITY_MISSING",
					"message": (
						"AI router is missing runtime identity fields: "
						+ ", ".join(missing_fields)
						+ "."
					),
				})
			for field in IDENTITY_FIELDS:
				if router.get(field) != baseline_readiness.get(field):
					violations.append({
						"code": "AI_ROUTER_RUNTIME_DRIFT",
						"message": f"AI router field {field} does not match the replica set.",
					})
	else:
		violations.append({
			"code": "AI_REPLICA_SET_UNAVAILABLE",
			"message": "No ready Orchestrator replica is available.",
		})

	unique_violations = list({(item["code"], item["message"]): item for item in violations}.values())
	identity = {
		field: ready_replicas[0]["readiness"].get(field) if ready_replicas else None
		for field in IDENTITY_FIELDS
	}
	return {
		"schema_version": "myapp-ai-replica-set-report-v1",
		"status": "passed" if not unique_violations else "failed",
		"expected_replicas": expected_replicas,
		"actual_replicas": len(replicas),
		"ready_replicas": len(ready_replicas),
		"image_ids": sorted(image_ids),
		"identity": identity,
		"violations": unique_violations,
	}


def main() -> int:
	parser = argparse.ArgumentParser(description="Verify a readiness-routed AI replica set.")
	parser.add_argument("--snapshot", required=True)
	parser.add_argument("--expected-replicas", required=True, type=int)
	args = parser.parse_args()
	if not 1 <= args.expected_replicas <= 10:
		parser.error("--expected-replicas must be between 1 and 10")
	report = evaluate(_load(args.snapshot), expected_replicas=args.expected_replicas)
	print(json.dumps(report, ensure_ascii=False, sort_keys=True))
	return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
	raise SystemExit(main())
