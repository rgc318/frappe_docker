from __future__ import annotations

import json
import os
import urllib.request
from datetime import UTC, datetime


def _parse_datetime(value: object) -> datetime | None:
	if not value:
		return None
	try:
		parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
	except ValueError:
		return None
	return parsed.replace(tzinfo=UTC) if parsed.tzinfo is None else parsed.astimezone(UTC)


def _is_effective(policy: dict, now: datetime) -> bool:
	if policy.get("environment") != "staging":
		return False
	try:
		if float(policy.get("rollout_percentage") or 0) <= 0:
			return False
	except (TypeError, ValueError):
		return False
	effective_from = _parse_datetime(policy.get("effective_from"))
	effective_to = _parse_datetime(policy.get("effective_to"))
	if policy.get("effective_from") and effective_from is None:
		return False
	if policy.get("effective_to") and effective_to is None:
		return False
	return not (
		(effective_from and now < effective_from)
		or (effective_to and now > effective_to)
	)


def _ready(models: dict, alias: str, capability: str) -> bool:
	metadata = models.get(alias) or {}
	return bool(
		metadata.get("status") in {"active", "validated"}
		and metadata.get(capability) is True
		and metadata.get("last_health_status") not in {"unavailable", "failed"}
	)


def main() -> None:
	token = os.environ["MYAPP_AI_SERVICE_TOKEN"]
	site = os.environ.get("MYAPP_AI_POLICY_SITE_HOST", "")
	request = urllib.request.Request(
		"http://backend:8000/api/method/myapp.api.gateway.get_ai_runtime_policy_snapshot_v1",
		headers={"Host": site, "X-MyApp-AI-Service-Token": token},
	)
	body = json.load(urllib.request.urlopen(request, timeout=10))
	payload = body.get("message", body)
	published = payload.get("policies") or []
	models = payload.get("models") or {}
	now = datetime.now(UTC)
	effective = [
		item for item in published
		if _is_effective(item.get("policy") or {}, now)
	]
	if not effective:
		raise RuntimeError(
			"No effective staging Runtime Policy with rollout_percentage > 0"
		)

	policy_aliases = {
		alias
		for item in effective
		for alias in [
			(item.get("policy") or {}).get("primary_model_alias"),
			*((item.get("policy") or {}).get("fallback_model_aliases") or []),
		]
		if alias
	}
	tool_ready = sorted(
		alias for alias in policy_aliases if _ready(models, alias, "supports_tools")
	)
	vision_ready = sorted(
		alias for alias in policy_aliases if _ready(models, alias, "supports_vision")
	)
	if not tool_ready:
		raise RuntimeError("Effective staging Runtime Policies have no tool-ready model")
	if not vision_ready:
		raise RuntimeError("Effective staging Runtime Policies have no vision-ready model")

	print(json.dumps({
		"effective_policy_count": len(effective),
		"published_policy_count": len(published),
		"tool_ready_models": tool_ready,
		"vision_ready_models": vision_ready,
	}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
	main()
