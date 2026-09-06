from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


def _load(path: str | Path) -> dict[str, Any]:
	payload = json.loads(Path(path).read_text(encoding="utf-8"))
	if not isinstance(payload, dict):
		raise ValueError(f"Expected a JSON object: {path}")
	return payload


def _candidate_buckets(map_path: str | Path) -> set[int]:
	buckets: set[int] = set()
	stable_default = False
	for raw_line in Path(map_path).read_text(encoding="utf-8").splitlines():
		line = raw_line.strip()
		if not line or line.startswith("#"):
			continue
		key, value = line.split()
		if key == "__default__":
			stable_default = value == "ai_stable"
		elif value == "ai_candidate":
			buckets.add(int(key))
		else:
			raise ValueError(f"Unsupported rollout map entry: {line}")
	if not stable_default:
		raise ValueError("Rollout map must contain __default__ ai_stable")
	return buckets


def _affinity_routes(map_path: str | Path) -> dict[str, str]:
	routes: dict[str, str] = {}
	for raw_line in Path(map_path).read_text(encoding="utf-8").splitlines():
		line = raw_line.strip()
		if not line or line.startswith("#"):
			continue
		key, value = line.split()
		if value not in {"ai_stable", "ai_candidate", "ai_affinity_missing"}:
			raise ValueError(f"Unsupported release affinity map entry: {line}")
		routes[key] = value
	if routes.get("__default__") != "ai_affinity_missing":
		raise ValueError("Release affinity map must contain __default__ ai_affinity_missing")
	return routes


def evaluate(
	state: dict[str, Any],
	sample: dict[str, Any],
	*,
	candidate_buckets: set[int],
	affinity_routes: dict[str, str],
) -> dict[str, Any]:
	violations: list[dict[str, str]] = []
	percent = int(state.get("candidate_percent") or 0)
	expected_buckets = set(range(percent))
	if state.get("status") not in {"active", "draining", "promoting"}:
		violations.append({
			"code": "AI_ROLLOUT_STATE_NOT_ACTIVE",
			"message": "AI rollout state is not active, draining, or promoting.",
		})
	if candidate_buckets != expected_buckets:
		violations.append({
			"code": "AI_ROLLOUT_MAP_STATE_DRIFT",
			"message": "Persisted HAProxy map does not match rollout-state.json.",
		})

	stable_release = str(state.get("stable_release_id") or "").strip()
	candidate_release = str(state.get("candidate_release_id") or "").strip()
	if not stable_release or not candidate_release or stable_release == candidate_release:
		violations.append({
			"code": "AI_ROLLOUT_RELEASE_ID_INVALID",
			"message": "Stable and candidate release IDs must be non-empty and different.",
		})
	expected_affinity = {"__default__": "ai_affinity_missing"}
	if stable_release and state.get("stable_affinity_enabled", True):
		expected_affinity[stable_release] = "ai_stable"
	if candidate_release:
		expected_affinity[candidate_release] = "ai_candidate"
	if affinity_routes != expected_affinity:
		violations.append({
			"code": "AI_ROLLOUT_AFFINITY_MAP_STATE_DRIFT",
			"message": "Persisted release affinity map does not match rollout-state.json.",
		})

	total = int(sample.get("samples") or 0)
	errors = sample.get("errors") or []
	if total < 100 or errors:
		violations.append({
			"code": "AI_ROLLOUT_SAMPLE_INCOMPLETE",
			"message": f"Router sampling produced {total} samples and {len(errors)} errors.",
		})
	counts = {stable_release: 0, candidate_release: 0}
	unknown_identities: list[str] = []
	for row in sample.get("identities") or []:
		identity = row.get("identity") or {}
		count = int(row.get("count") or 0)
		release_id = str(identity.get("release_id") or "")
		if identity.get("ready") is not True:
			violations.append({
				"code": "AI_ROLLOUT_ROUTER_NOT_READY",
				"message": f"Router sampled a non-ready runtime for release {release_id or 'unknown'}.",
			})
		if release_id not in counts:
			unknown_identities.append(release_id or "unknown")
		else:
			counts[release_id] += count
	if unknown_identities:
		violations.append({
			"code": "AI_ROLLOUT_UNKNOWN_RUNTIME",
			"message": "Router returned unapproved release IDs: " + ", ".join(sorted(set(unknown_identities))) + ".",
		})

	candidate_count = counts.get(candidate_release, 0)
	observed_ratio = candidate_count / total if total else 0.0
	expected_ratio = percent / 100
	tolerance = max(0.03, 4 * math.sqrt(expected_ratio * (1 - expected_ratio) / total)) if total else 1.0
	if total and abs(observed_ratio - expected_ratio) > tolerance:
		violations.append({
			"code": "AI_ROLLOUT_DISTRIBUTION_MISMATCH",
			"message": (
				f"Observed candidate ratio {observed_ratio:.2%}; expected {expected_ratio:.2%} "
				f"within ±{tolerance:.2%}."
			),
		})
	if percent > 0 and candidate_count == 0:
		violations.append({
			"code": "AI_ROLLOUT_CANDIDATE_NOT_RECEIVING_TRAFFIC",
			"message": "Candidate has a non-zero rollout percentage but received no sampled traffic.",
		})
	if percent < 100 and counts.get(stable_release, 0) == 0:
		violations.append({
			"code": "AI_ROLLOUT_STABLE_NOT_RECEIVING_TRAFFIC",
			"message": "Stable should receive traffic at this stage but received no sampled traffic.",
		})

	unique = list({(item["code"], item["message"]): item for item in violations}.values())
	return {
		"schema_version": "myapp-ai-router-rollout-report-v1",
		"status": "passed" if not unique else "failed",
		"candidate_percent": percent,
		"samples": total,
		"stable_release_id": stable_release,
		"candidate_release_id": candidate_release,
		"stable_samples": counts.get(stable_release, 0),
		"candidate_samples": candidate_count,
		"observed_candidate_ratio": round(observed_ratio, 6),
		"allowed_ratio_tolerance": round(tolerance, 6),
		"violations": unique,
	}


def main() -> int:
	parser = argparse.ArgumentParser(description="Verify persisted and observed AI rollout traffic.")
	parser.add_argument("--state", required=True)
	parser.add_argument("--map", required=True)
	parser.add_argument("--affinity-map", required=True)
	parser.add_argument("--sample", required=True)
	args = parser.parse_args()
	report = evaluate(
		_load(args.state),
		_load(args.sample),
		candidate_buckets=_candidate_buckets(args.map),
		affinity_routes=_affinity_routes(args.affinity_map),
	)
	print(json.dumps(report, ensure_ascii=False, sort_keys=True))
	return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
	raise SystemExit(main())
