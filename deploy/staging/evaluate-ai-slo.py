from __future__ import annotations

import argparse
import json
import math
from datetime import UTC, datetime
from pathlib import Path
from typing import Any


CONTRACT_ERROR_CODES = {
	"AI_RUNTIME_CONTRACT_MISMATCH",
	"AI_SCHEMA_VERSION_MISMATCH",
	"AI_PROMPT_VERSION_MISMATCH",
	"AI_RELEASE_ID_MISMATCH",
}


def _load(path: str) -> dict[str, Any]:
	payload = json.loads(Path(path).read_text(encoding="utf-8"))
	if not isinstance(payload, dict):
		raise ValueError(f"Report must be a JSON object: {path}")
	return payload


def _percentile(values: list[float], percentile: float) -> float | None:
	if not values:
		return None
	ordered = sorted(values)
	position = (len(ordered) - 1) * percentile
	lower = math.floor(position)
	upper = math.ceil(position)
	if lower == upper:
		return round(ordered[lower], 2)
	weight = position - lower
	return round(ordered[lower] * (1 - weight) + ordered[upper] * weight, 2)


def evaluate(
	canary_reports: list[dict[str, Any]],
	load_reports: list[dict[str, Any]],
	*,
	min_success_rate: float,
	min_samples: int,
	max_p95_ms: float,
) -> dict[str, Any]:
	total = 0
	successes = 0
	latencies: list[float] = []
	contract_mismatches = 0
	fallbacks = 0
	partial_canaries = 0
	failed_canaries = 0
	error_codes: dict[str, int] = {}

	for report in canary_reports:
		if report.get("schema_version") != "myapp-ai-staging-canary-report-v1":
			raise ValueError("Unsupported AI canary report schema")
		partial_canaries += report.get("status") == "partial"
		failed_canaries += report.get("status") == "failed"
		for scenario in report.get("scenarios") or []:
			if not isinstance(scenario, dict) or scenario.get("scenario") == "readiness":
				continue
			total += 1
			successes += scenario.get("status") == "passed"
			if isinstance(scenario.get("duration_ms"), (int, float)):
				latencies.append(float(scenario["duration_ms"]))
			if scenario.get("fallback_reason"):
				fallbacks += 1
			code = str(scenario.get("error_code") or "").strip()
			if code:
				error_codes[code] = error_codes.get(code, 0) + 1
				contract_mismatches += code in CONTRACT_ERROR_CODES

	for report in load_reports:
		if report.get("schema") != "myapp-ai-load-report-v1":
			raise ValueError("Unsupported AI load report schema")
		for rows in (report.get("scenarios") or {}).values():
			rows = rows if isinstance(rows, list) else [rows]
			for row in rows:
				if not isinstance(row, dict):
					continue
				requests = int(row.get("requests") or 0)
				total += requests
				successes += int(row.get("successes") or 0)
				latency = row.get("successful_latency_ms") or {}
				if isinstance(latency.get("p95"), (int, float)):
					latencies.append(float(latency["p95"]))
				for code, count in (row.get("error_codes") or {}).items():
					count = int(count or 0)
					error_codes[str(code)] = error_codes.get(str(code), 0) + count
					if str(code) in CONTRACT_ERROR_CODES:
						contract_mismatches += count

	success_rate = successes / total if total else 0.0
	p95_ms = _percentile(latencies, 0.95)
	violations: list[dict[str, Any]] = []
	warnings: list[dict[str, Any]] = []
	if failed_canaries:
		violations.append({
			"code": "AI_SLO_CANARY_FAILED",
			"message": f"{failed_canaries} canary report(s) contain deterministic failures.",
		})
	if contract_mismatches:
		violations.append({
			"code": "AI_SLO_CONTRACT_MISMATCH",
			"message": f"Observed {contract_mismatches} runtime contract mismatch(es).",
		})
	if partial_canaries:
		warnings.append({
			"code": "AI_SLO_TRANSIENT_PARTIAL",
			"message": f"{partial_canaries} canary report(s) remain partial after bounded retry.",
		})
	if total < min_samples:
		warnings.append({
			"code": "AI_SLO_INSUFFICIENT_SAMPLE",
			"message": f"Observed {total} samples; at least {min_samples} are required for an SLO decision.",
		})
	else:
		if success_rate < min_success_rate:
			violations.append({
				"code": "AI_SLO_SUCCESS_RATE_BREACH",
				"message": f"Success rate {success_rate:.4%} is below {min_success_rate:.4%}.",
			})
		if p95_ms is not None and p95_ms > max_p95_ms:
			violations.append({
				"code": "AI_SLO_LATENCY_BREACH",
				"message": f"Observed p95 {p95_ms:.2f} ms exceeds {max_p95_ms:.2f} ms.",
			})

	status = "failed" if violations else "warning" if warnings else "passed"
	alerts = [
		{"severity": "critical", **item} for item in violations
	] + [
		{"severity": "warning", **item} for item in warnings
	]
	return {
		"schema_version": "myapp-ai-slo-report-v1",
		"status": status,
		"generated_at": datetime.now(UTC).isoformat().replace("+00:00", "Z"),
		"objectives": {
			"min_success_rate": min_success_rate,
			"min_samples": min_samples,
			"max_p95_ms": max_p95_ms,
			"max_contract_mismatches": 0,
		},
		"observations": {
			"samples": total,
			"successes": successes,
			"success_rate": round(success_rate, 6),
			"p95_ms": p95_ms,
			"contract_mismatches": contract_mismatches,
			"fallbacks": fallbacks,
			"partial_canaries": partial_canaries,
			"failed_canaries": failed_canaries,
			"error_codes": error_codes,
		},
		"violations": violations,
		"warnings": warnings,
		"alerts": alerts,
	}


def main() -> int:
	parser = argparse.ArgumentParser(description="Evaluate AI canary/load reports against release SLOs.")
	parser.add_argument("--canary", action="append", default=[])
	parser.add_argument("--load-report", action="append", default=[])
	parser.add_argument("--min-success-rate", type=float, default=0.995)
	parser.add_argument("--min-samples", type=int, default=20)
	parser.add_argument("--max-p95-ms", type=float, default=30000)
	args = parser.parse_args()
	if not args.canary and not args.load_report:
		parser.error("At least one --canary or --load-report is required")
	if not 0 < args.min_success_rate <= 1:
		parser.error("--min-success-rate must be greater than 0 and at most 1")
	if args.min_samples < 1 or args.max_p95_ms <= 0:
		parser.error("SLO sample and latency thresholds must be positive")
	report = evaluate(
		[_load(path) for path in args.canary],
		[_load(path) for path in args.load_report],
		min_success_rate=args.min_success_rate,
		min_samples=args.min_samples,
		max_p95_ms=args.max_p95_ms,
	)
	print(json.dumps(report, ensure_ascii=False, sort_keys=True))
	return 0 if report["status"] == "passed" else 10 if report["status"] == "warning" else 20


if __name__ == "__main__":
	raise SystemExit(main())
