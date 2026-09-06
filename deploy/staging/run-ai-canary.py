from __future__ import annotations

import json
import os
import socket
import sys
import time
import urllib.error
import urllib.request
from datetime import UTC, datetime
from typing import Any

from myapp.ai_runtime_contract import (
	ai_runtime_request_contract,
	evaluate_ai_runtime_compatibility,
	validate_ai_runtime_response,
)


SCENARIOS = {
	"intent_parse": (
		"/internal/v1/intent/parse",
		"intent_parse",
		"请判断这个只读请求的意图：查询本月销售情况。",
	),
	"chat": (
		"/internal/v1/chat",
		"chat",
		"这是部署后的只读连通性测试。请简短回复系统已就绪，不要调用或建议任何写操作。",
	),
	"sales_order_draft": (
		"/internal/v1/drafts/sales-order",
		"sales_order_draft",
		"只生成销售订单候选：测试客户购买测试商品 1 件。不要执行或确认任何业务单据。",
	),
	"purchase_order_draft": (
		"/internal/v1/drafts/purchase-order",
		"purchase_order_draft",
		"只生成采购订单候选：向测试供应商采购测试商品 1 件。不要执行或确认任何业务单据。",
	),
	"inventory_adjustment_draft": (
		"/internal/v1/drafts/inventory-adjustment",
		"inventory_adjustment_draft",
		"只生成库存调整候选：测试商品增加 1 件。不要执行或确认任何业务单据。",
	),
	"product_setup_draft": (
		"/internal/v1/drafts/product-setup",
		"product_setup_draft",
		"只生成商品资料候选：测试商品，单位为件。不要创建或更新真实商品。",
	),
}

DEFAULT_SCENARIOS = (
	"readiness",
	"intent_parse",
	"chat",
	"product_setup_draft",
)

TRANSIENT_HTTP_STATUSES = {408, 425, 429, 500, 502, 503, 504}
TRANSIENT_CODES = {
	"AI_MODEL_BUSY",
	"AI_MODEL_CIRCUIT_OPEN",
	"AI_MODEL_HEALTH_HALF_OPEN_BUSY",
	"AI_PROVIDER_EMPTY_RESPONSE",
	"AI_PROVIDER_TIMEOUT",
	"MODEL_PROVIDER_TIMEOUT",
}


def _utc_now() -> str:
	return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def _env_int(name: str, default: int, *, minimum: int, maximum: int) -> int:
	raw = os.environ.get(name, "").strip()
	try:
		value = int(raw) if raw else default
	except ValueError as error:
		raise ValueError(f"{name} must be an integer") from error
	if not minimum <= value <= maximum:
		raise ValueError(f"{name} must be between {minimum} and {maximum}")
	return value


def _selected_scenarios() -> list[str]:
	raw = os.environ.get("AI_CANARY_SCENARIOS", "").strip()
	values = [item.strip() for item in raw.split(",") if item.strip()] if raw else list(DEFAULT_SCENARIOS)
	unknown = [item for item in values if item != "readiness" and item not in SCENARIOS]
	if unknown:
		raise ValueError(f"Unsupported AI canary scenarios: {', '.join(unknown)}")
	if not values:
		raise ValueError("AI_CANARY_SCENARIOS must select at least one scenario")
	return list(dict.fromkeys(values))


def _extract_error(payload: object) -> tuple[str | None, str | None, str | None]:
	if not isinstance(payload, dict):
		return None, None, None
	detail = payload.get("detail", payload)
	if isinstance(detail, str):
		return None, detail, None
	if not isinstance(detail, dict):
		return None, None, None
	return (
		str(detail.get("code") or "").strip() or None,
		str(detail.get("message") or "").strip() or None,
		str(detail.get("provider_error_code") or "").strip() or None,
	)


def _classification(*, http_status: int | None, code: str | None, provider_code: str | None) -> str:
	if provider_code:
		provider_status = provider_code.removeprefix("PROVIDER_HTTP_")
		if provider_status.isdigit():
			return "partial" if int(provider_status) in TRANSIENT_HTTP_STATUSES else "failed"
	if code in TRANSIENT_CODES:
		return "partial"
	if http_status in TRANSIENT_HTTP_STATUSES:
		return "partial"
	return "failed"


def _request_json(
	url: str,
	*,
	token: str = "",
	payload: dict[str, Any] | None = None,
	timeout: int,
) -> tuple[int, dict[str, Any]]:
	body = None
	headers = {"Accept": "application/json"}
	if token:
		headers["Authorization"] = f"Bearer {token}"
	if payload is not None:
		body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
		headers["Content-Type"] = "application/json"
	request = urllib.request.Request(
		url,
		data=body,
		headers=headers,
		method="POST" if body is not None else "GET",
	)
	try:
		with urllib.request.urlopen(request, timeout=timeout) as response:
			return response.status, json.loads(response.read().decode("utf-8") or "{}")
	except urllib.error.HTTPError as error:
		try:
			payload = json.loads(error.read().decode("utf-8") or "{}")
		except json.JSONDecodeError:
			payload = {}
		return error.code, payload


def _run_readiness(*, base_url: str, timeout: int, expected_release: str) -> dict[str, Any]:
	started = time.perf_counter()
	try:
		http_status, payload = _request_json(f"{base_url}/readyz", timeout=timeout)
		compatibility = evaluate_ai_runtime_compatibility(payload)
		if http_status != 200 or not compatibility["ready"]:
			code = compatibility.get("code") or f"HTTP_{http_status}"
			return {
				"status": "failed",
				"http_status": http_status,
				"error_code": code,
				"message": "AI runtime readiness or contract compatibility failed.",
				"duration_ms": round((time.perf_counter() - started) * 1000, 2),
				"runtime": compatibility.get("runtime"),
			}
		actual_release = str(payload.get("release_id") or "").strip()
		if expected_release and actual_release != expected_release:
			return {
				"status": "failed",
				"http_status": http_status,
				"error_code": "AI_RELEASE_ID_MISMATCH",
				"message": f"Expected release {expected_release}, got {actual_release or 'unversioned'}.",
				"duration_ms": round((time.perf_counter() - started) * 1000, 2),
				"runtime": compatibility.get("runtime"),
			}
		return {
			"status": "passed",
			"http_status": http_status,
			"duration_ms": round((time.perf_counter() - started) * 1000, 2),
			"runtime": compatibility.get("runtime"),
			"protocol_version": payload.get("protocol_version"),
			"schema_family_count": len(payload.get("schema_versions") or {}),
		}
	except (urllib.error.URLError, TimeoutError, socket.timeout, json.JSONDecodeError) as error:
		return {
			"status": "partial",
			"error_code": type(error).__name__,
			"message": str(error),
			"duration_ms": round((time.perf_counter() - started) * 1000, 2),
		}


def _run_scenario(
	name: str,
	*,
	base_url: str,
	token: str,
	timeout: int,
	company: str | None,
	model_alias: str | None,
	expected_release: str,
) -> dict[str, Any]:
	endpoint, schema_family, prompt = SCENARIOS[name]
	payload: dict[str, Any] = {
		"messages": [{"role": "user", "content": prompt}],
		"scenario": "general" if name == "chat" else name,
		"user": "ai-canary@example.invalid",
		"company": company,
		"locale": "zh-CN",
		"policy_context": {"roles": [], "environment": "staging"},
		**ai_runtime_request_contract(schema_family),
	}
	if model_alias:
		payload["model_alias"] = model_alias
	started = time.perf_counter()
	try:
		http_status, response = _request_json(
			f"{base_url}{endpoint}", token=token, payload=payload, timeout=timeout,
		)
		if http_status >= 400:
			code, message, provider_code = _extract_error(response)
			return {
				"status": _classification(
					http_status=http_status, code=code, provider_code=provider_code,
				),
				"http_status": http_status,
				"error_code": code or f"HTTP_{http_status}",
				"provider_error_code": provider_code,
				"message": message or "AI canary request failed.",
				"duration_ms": round((time.perf_counter() - started) * 1000, 2),
			}
		metadata = validate_ai_runtime_response(response, schema_family=schema_family)
		if expected_release and metadata["release_id"] != expected_release:
			raise ValueError(
				f"AI_RELEASE_ID_MISMATCH: expected {expected_release}, got {metadata['release_id']}"
			)
		if name == "chat" and not str((response.get("message") or {}).get("content") or "").strip():
			raise ValueError("AI chat canary returned empty content")
		return {
			"status": "passed",
			"http_status": http_status,
			"duration_ms": round((time.perf_counter() - started) * 1000, 2),
			"model_alias": response.get("model_alias") or model_alias,
			"fallback_reason": response.get("fallback_reason"),
			**metadata,
		}
	except (urllib.error.URLError, TimeoutError, socket.timeout) as error:
		return {
			"status": "partial",
			"error_code": type(error).__name__,
			"message": str(error),
			"duration_ms": round((time.perf_counter() - started) * 1000, 2),
		}
	except (json.JSONDecodeError, ValueError) as error:
		message = str(error)
		error_code = getattr(error, "code", None)
		if not error_code and message.startswith("AI_") and ":" in message:
			error_code = message.split(":", 1)[0]
		return {
			"status": "failed",
			"error_code": error_code or type(error).__name__,
			"message": message,
			"duration_ms": round((time.perf_counter() - started) * 1000, 2),
		}


def main() -> int:
	started_at = _utc_now()
	started = time.perf_counter()
	base_url = os.environ.get("AI_CANARY_BASE_URL", "http://ai-orchestrator:4010").rstrip("/")
	token = os.environ.get("MYAPP_AI_SERVICE_TOKEN", "")
	expected_release = os.environ.get("AI_CANARY_EXPECTED_RELEASE_ID", "").strip()
	company = os.environ.get("AI_CANARY_COMPANY", "").strip() or None
	model_alias = os.environ.get("AI_CANARY_MODEL_ALIAS", "").strip() or None
	timeout = _env_int("AI_CANARY_TIMEOUT_SECONDS", 60, minimum=5, maximum=300)
	retries = _env_int("AI_CANARY_TRANSIENT_RETRIES", 1, minimum=0, maximum=1)
	scenarios = _selected_scenarios()
	results: list[dict[str, Any]] = []

	for name in scenarios:
		attempts = []
		for attempt in range(retries + 1):
			if name == "readiness":
				result = _run_readiness(
					base_url=base_url, timeout=timeout, expected_release=expected_release,
				)
			else:
				result = _run_scenario(
					name,
					base_url=base_url,
					token=token,
					timeout=timeout,
					company=company,
					model_alias=model_alias,
					expected_release=expected_release,
				)
			attempts.append(result)
			if result["status"] != "partial" or attempt >= retries:
				break
		final = dict(attempts[-1])
		final["scenario"] = name
		final["attempt_count"] = len(attempts)
		final["attempts"] = attempts
		results.append(final)

	statuses = {item["status"] for item in results}
	status = "failed" if "failed" in statuses else "partial" if "partial" in statuses else "passed"
	report = {
		"schema_version": "myapp-ai-staging-canary-report-v1",
		"status": status,
		"started_at": started_at,
		"completed_at": _utc_now(),
		"duration_ms": round((time.perf_counter() - started) * 1000, 2),
		"release_id": expected_release or None,
		"backend_revision": os.environ.get("AI_CANARY_BACKEND_REVISION", "").strip() or None,
		"requested_model_alias": model_alias,
		"company": company,
		"transient_retry_limit": retries,
		"scenarios": results,
		"summary": {
			"passed": sum(item["status"] == "passed" for item in results),
			"partial": sum(item["status"] == "partial" for item in results),
			"failed": sum(item["status"] == "failed" for item in results),
			"total": len(results),
		},
	}
	print(json.dumps(report, ensure_ascii=False, sort_keys=True))
	return 0 if status == "passed" else 10 if status == "partial" else 20


if __name__ == "__main__":
	try:
		raise SystemExit(main())
	except Exception as error:
		print(json.dumps({
			"schema_version": "myapp-ai-staging-canary-report-v1",
			"status": "failed",
			"completed_at": _utc_now(),
			"error_code": type(error).__name__,
			"message": str(error),
		}, ensure_ascii=False, sort_keys=True))
		raise SystemExit(20) from error
