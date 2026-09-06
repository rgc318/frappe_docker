from __future__ import annotations

import argparse
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[3]


def _load_module(name: str, relative_path: str):
	spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
	if spec is None or spec.loader is None:
		raise RuntimeError(f"Cannot load {relative_path}")
	module = importlib.util.module_from_spec(spec)
	sys.modules[name] = module
	spec.loader.exec_module(module)
	return module


canary = _load_module("staging_ai_canary", "deploy/staging/run-ai-canary.py")
release_pair = _load_module("staging_release_pair", "deploy/staging/staging-release-pair.py")
replica_set = _load_module("staging_replica_set", "deploy/staging/verify-ai-replica-set.py")
slo = _load_module("staging_ai_slo", "deploy/staging/evaluate-ai-slo.py")
rollout = _load_module("staging_ai_rollout", "deploy/staging/set-ai-rollout.py")
rollout_verifier = _load_module(
	"staging_ai_rollout_verifier", "deploy/staging/verify-ai-router-rollout.py",
)


class AiCanaryTest(unittest.TestCase):
	def test_provider_403_is_deterministic_even_when_wrapped_by_502(self):
		self.assertEqual(
			canary._classification(
				http_status=502,
				code="MODEL_PROVIDER_REJECTED",
				provider_code="PROVIDER_HTTP_403",
			),
			"failed",
		)

	def test_provider_503_and_rate_limit_are_partial(self):
		for provider_code in ("PROVIDER_HTTP_429", "PROVIDER_HTTP_503"):
			with self.subTest(provider_code=provider_code):
				self.assertEqual(
					canary._classification(
						http_status=502,
						code="MODEL_PROVIDER_REJECTED",
						provider_code=provider_code,
					),
					"partial",
				)

	@patch.object(canary, "_request_json")
	def test_chat_requires_contract_metadata_and_non_empty_content(self, request_json):
		request_json.return_value = (200, {
			"message": {"role": "assistant", "content": "已就绪"},
			"model_alias": "gpt-5.6-luna",
			"protocol_version": "ai-runtime-contract-v1",
			"schema_version": "chat-v1",
			"prompt_version": "erp-readonly-v11",
			"runtime_revision": "a" * 40,
			"release_id": "staging-1",
		})
		result = canary._run_scenario(
			"chat",
			base_url="http://ai",
			token="token",
			timeout=10,
			company=None,
			model_alias=None,
			expected_release="staging-1",
		)
		self.assertEqual(result["status"], "passed")
		self.assertEqual(result["release_id"], "staging-1")


class ReleasePairTest(unittest.TestCase):
	def setUp(self):
		self.temp_dir = tempfile.TemporaryDirectory()
		self.root = Path(self.temp_dir.name)
		self.backend_revision = "a" * 40
		self.ai_revision = "b" * 40
		self.release_id = "staging-immutable-1"
		self.backend_path = self._write("backend.json", [{
			"Id": "sha256:backend",
			"RepoTags": [f"example/backend:{self.release_id}"],
			"RepoDigests": ["example/backend@sha256:111"],
			"Config": {"Labels": {
				"org.rgc.myapp_revision": self.backend_revision,
				"org.rgc.release_id": self.release_id,
			}},
		}])
		self.ai_path = self._write("ai.json", [{
			"Id": "sha256:ai",
			"RepoTags": [f"example/ai:{self.release_id}"],
			"RepoDigests": ["example/ai@sha256:222"],
			"Config": {"Labels": {
				"org.opencontainers.image.revision": self.ai_revision,
				"org.rgc.release_id": self.release_id,
			}},
		}])
		self.readiness_path = self._write("ready.json", {
			"ready": True,
			"release_id": self.release_id,
			"runtime_revision": self.ai_revision,
			"protocol_version": "ai-runtime-contract-v1",
		})
		self.canary_path = self._write("canary.json", {
			"schema_version": "myapp-ai-staging-canary-report-v1",
			"status": "passed",
			"release_id": self.release_id,
			"backend_revision": self.backend_revision,
			"completed_at": "2026-09-05T00:00:00Z",
		})

	def tearDown(self):
		self.temp_dir.cleanup()

	def _write(self, name: str, payload) -> str:
		path = self.root / name
		path.write_text(json.dumps(payload), encoding="utf-8")
		return str(path)

	def _capture_args(self):
		return argparse.Namespace(
			backend_inspect=self.backend_path,
			ai_inspect=self.ai_path,
			readiness=self.readiness_path,
			canary_report=self.canary_path,
			backend_repository="example/backend",
			backend_tag=self.release_id,
			ai_repository="example/ai",
			ai_tag=self.release_id,
			parent_revision="c" * 40,
		)

	def test_capture_and_verify_exact_pair(self):
		manifest = release_pair.capture(self._capture_args())
		manifest_path = self._write("manifest.json", manifest)
		result = release_pair.verify(argparse.Namespace(
			manifest=manifest_path,
			release_id=self.release_id,
			backend_inspect=self.backend_path,
			ai_inspect=self.ai_path,
		))
		self.assertEqual(result["status"], "passed")
		self.assertEqual(result["backend_revision"], self.backend_revision)

	def test_capture_rejects_partial_canary(self):
		self._write("canary.json", {
			"status": "partial",
			"release_id": self.release_id,
			"backend_revision": self.backend_revision,
		})
		with self.assertRaisesRegex(ValueError, "passed AI canary"):
			release_pair.capture(self._capture_args())

	def test_verify_rejects_mutated_tag_image(self):
		manifest = release_pair.capture(self._capture_args())
		manifest_path = self._write("manifest.json", manifest)
		mutated = json.loads(Path(self.backend_path).read_text(encoding="utf-8"))
		mutated[0]["Id"] = "sha256:mutated"
		mutated_path = self._write("mutated.json", mutated)
		with self.assertRaisesRegex(ValueError, "image ID drift"):
			release_pair.verify(argparse.Namespace(
				manifest=manifest_path,
				release_id=self.release_id,
				backend_inspect=mutated_path,
				ai_inspect=self.ai_path,
			))


class ReplicaSetTest(unittest.TestCase):
	def _readiness(self):
		return {
			"ready": True,
			"release_id": "release-1",
			"runtime_revision": "a" * 40,
			"protocol_version": "ai-runtime-contract-v1",
			"prompt_manifest_sha256": "prompt",
			"schema_manifest_sha256": "schema",
			"tool_manifest_sha256": "tool",
		}

	def test_two_identical_ready_replicas_pass(self):
		readiness = self._readiness()
		report = replica_set.evaluate({
			"replicas": [
				{"container_id": "one", "image_id": "sha256:1", "health_status": "healthy", "readiness": readiness},
				{"container_id": "two", "image_id": "sha256:1", "health_status": "healthy", "readiness": dict(readiness)},
			],
			"router": dict(readiness),
		}, expected_replicas=2)
		self.assertEqual(report["status"], "passed")
		self.assertEqual(report["ready_replicas"], 2)

	def test_replica_revision_drift_fails(self):
		first = self._readiness()
		second = {**first, "runtime_revision": "b" * 40}
		report = replica_set.evaluate({
			"replicas": [
				{"container_id": "one", "image_id": "sha256:1", "health_status": "healthy", "readiness": first},
				{"container_id": "two", "image_id": "sha256:2", "health_status": "healthy", "readiness": second},
			],
			"router": dict(first),
		}, expected_replicas=2)
		self.assertEqual(report["status"], "failed")
		self.assertIn("AI_REPLICA_RUNTIME_DRIFT", {item["code"] for item in report["violations"]})

	def test_unready_replica_image_drift_still_fails(self):
		readiness = self._readiness()
		report = replica_set.evaluate({
			"replicas": [
				{"container_id": "one", "image_id": "sha256:1", "health_status": "healthy", "readiness": readiness},
				{
					"container_id": "two",
					"image_id": "sha256:2",
					"health_status": "unhealthy",
					"readiness": {"ready": False, "probe_error": "HTTP 503"},
				},
			],
			"router": dict(readiness),
		}, expected_replicas=2)
		codes = {item["code"] for item in report["violations"]}
		self.assertIn("AI_REPLICA_IMAGE_DRIFT", codes)
		self.assertIn("AI_REPLICA_NOT_READY", codes)

	def test_missing_runtime_identity_fails_closed(self):
		readiness = self._readiness()
		del readiness["tool_manifest_sha256"]
		report = replica_set.evaluate({
			"replicas": [
				{"container_id": "one", "image_id": "sha256:1", "health_status": "healthy", "readiness": readiness},
			],
			"router": dict(readiness),
		}, expected_replicas=1)
		self.assertEqual(report["status"], "failed")
		self.assertIn(
			"AI_REPLICA_RUNTIME_IDENTITY_MISSING",
			{item["code"] for item in report["violations"]},
		)


class SloGateTest(unittest.TestCase):
	def _canary(self, *, status: str = "passed", error_code: str | None = None):
		scenario = {
			"scenario": "chat",
			"status": status,
			"duration_ms": 1000,
		}
		if error_code:
			scenario["error_code"] = error_code
		return {
			"schema_version": "myapp-ai-staging-canary-report-v1",
			"status": status,
			"scenarios": [scenario],
		}

	def test_small_passed_canary_is_warning_not_false_slo_pass(self):
		report = slo.evaluate(
			[self._canary()], [], min_success_rate=0.995, min_samples=20, max_p95_ms=30000,
		)
		self.assertEqual(report["status"], "warning")
		self.assertEqual(report["warnings"][0]["code"], "AI_SLO_INSUFFICIENT_SAMPLE")

	def test_load_report_can_satisfy_slo(self):
		load_report = {
			"schema": "myapp-ai-load-report-v1",
			"scenarios": {"chat": [{
				"requests": 20,
				"successes": 20,
				"successful_latency_ms": {"p95": 1500},
				"error_codes": {},
			}]},
		}
		report = slo.evaluate(
			[], [load_report], min_success_rate=0.995, min_samples=20, max_p95_ms=30000,
		)
		self.assertEqual(report["status"], "passed")

	def test_contract_mismatch_is_always_critical(self):
		report = slo.evaluate(
			[self._canary(status="failed", error_code="AI_RUNTIME_CONTRACT_MISMATCH")],
			[], min_success_rate=0.995, min_samples=20, max_p95_ms=30000,
		)
		self.assertEqual(report["status"], "failed")
		self.assertIn("AI_SLO_CONTRACT_MISMATCH", {item["code"] for item in report["violations"]})

	def _run_gate(self, canary_report: dict, *, require_pass: bool = False):
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			env_file = root / "staging.env"
			env_file.write_text("", encoding="utf-8")
			canary_path = root / "canary.json"
			canary_path.write_text(json.dumps({
				"release_id": "test-release",
				**canary_report,
			}), encoding="utf-8")
			report_root = root / "reports"
			env = {
				**os.environ,
				"ENV_FILE": str(env_file),
				"AI_SLO_CANARY_REPORT_PATH": str(canary_path),
				"AI_SLO_REPORT_ROOT": str(report_root),
				"AI_SLO_MIN_SUCCESS_RATE": "0.995",
				"AI_SLO_MIN_SAMPLES": "20",
				"AI_SLO_MAX_P95_MS": "30000",
				"AI_SLO_REQUIRE_PASS": "1" if require_pass else "0",
				"AI_SLO_ALERT_WEBHOOK_URL": "",
				"AI_SLO_ALERT_DELIVERY_REQUIRED": "0",
			}
			result = subprocess.run(
				[ROOT / "deploy/staging/run-ai-slo-gate.sh"],
				cwd=ROOT,
				env=env,
				capture_output=True,
				text=True,
				check=False,
			)
			alert_state = json.loads((report_root / "current-alert-state.json").read_text(encoding="utf-8"))
			return result, alert_state

	def test_gate_allows_warning_by_default_and_persists_alert_state(self):
		result, alert_state = self._run_gate(self._canary())
		self.assertEqual(result.returncode, 0, result.stderr)
		self.assertEqual(alert_state["status"], "warning")
		self.assertIn("AI_SLO_INSUFFICIENT_SAMPLE", {
			item["code"] for item in alert_state["alerts"]
		})

	def test_gate_can_require_full_slo_pass(self):
		result, alert_state = self._run_gate(self._canary(), require_pass=True)
		self.assertEqual(result.returncode, 1)
		self.assertEqual(alert_state["status"], "warning")

	def test_gate_blocks_contract_failure(self):
		result, alert_state = self._run_gate(
			self._canary(status="failed", error_code="AI_RUNTIME_CONTRACT_MISMATCH"),
		)
		self.assertEqual(result.returncode, 1)
		self.assertEqual(alert_state["status"], "failed")


class RolloutMapTest(unittest.TestCase):
	def test_candidate_percentage_renders_exact_buckets(self):
		entries = rollout.desired_entries(25)
		self.assertEqual(entries["0"], "ai_candidate")
		self.assertEqual(entries["24"], "ai_candidate")
		self.assertNotIn("25", entries)
		self.assertEqual(entries["__default__"], "ai_stable")
		self.assertEqual(rollout.parse_file_entries(rollout.render_map(entries)), entries)

	def test_runtime_map_parser_ignores_reference_ids(self):
		payload = "0xabc __default__ ai_stable\n0xdef 0 ai_candidate\n"
		self.assertEqual(
			rollout.parse_show_map(payload),
			{"__default__": "ai_stable", "0": "ai_candidate"},
		)

	@patch.object(rollout, "_socket_command")
	def test_runtime_map_update_batches_transaction_commands(self, socket_command):
		entries = {"__default__": "ai_stable", "0": "ai_candidate", "1": "ai_candidate"}
		socket_command.side_effect = [
			"1 (/var/lib/haproxy/ai-router/rollout.map)\n",
			"New version created: 7\n",
			"",
			"0x1 __default__ ai_stable\n0x2 0 ai_candidate\n0x3 1 ai_candidate\n",
		]

		rollout._apply_runtime_map(
			"router", "/var/lib/haproxy/ai-router/rollout.map", entries,
		)

		self.assertEqual(socket_command.call_count, 4)
		transaction = socket_command.call_args_list[2].args[1]
		self.assertIn("clear map @7 #1", transaction)
		self.assertIn("add map @7 #1 0 ai_candidate", transaction)
		self.assertTrue(transaction.endswith("commit map @7 #1"))

	def test_release_affinity_maps_exact_releases(self):
		entries = rollout.affinity_entries("stable-release", "candidate-release")
		self.assertEqual(entries["stable-release"], "ai_stable")
		self.assertEqual(entries["candidate-release"], "ai_candidate")
		self.assertEqual(
			rollout.parse_affinity_file_entries(rollout.render_affinity_map(entries)),
			entries,
		)

	def test_release_id_rejects_runtime_cli_delimiters(self):
		with self.assertRaisesRegex(ValueError, "Docker tag-safe"):
			rollout.apply_rollout(
				container="router",
				map_path=Path("unused"),
				affinity_map_path=Path("unused"),
				state_path=Path("unused"),
				candidate_percent=5,
				stable_release_id="stable;show map",
				candidate_release_id="candidate",
			)

	def test_rollout_map_requires_stable_default(self):
		with self.assertRaisesRegex(ValueError, "__default__ ai_stable"):
			rollout.parse_file_entries("0 ai_candidate\n")

	@patch.object(rollout, "_apply_runtime_map")
	def test_failed_runtime_update_restores_persisted_map(self, apply_runtime_map):
		apply_runtime_map.side_effect = [RuntimeError("socket failed"), None, None]
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			map_path = root / "rollout.map"
			affinity_map_path = root / "release-affinity.map"
			state_path = root / "rollout-state.json"
			original = rollout.render_map(rollout.desired_entries(5))
			original_affinity = rollout.render_affinity_map(
				rollout.affinity_entries("stable", "candidate"),
			)
			map_path.write_text(original, encoding="utf-8")
			affinity_map_path.write_text(original_affinity, encoding="utf-8")
			with self.assertRaisesRegex(RuntimeError, "socket failed"):
				rollout.apply_rollout(
					container="router",
					map_path=map_path,
					affinity_map_path=affinity_map_path,
					state_path=state_path,
					candidate_percent=25,
					stable_release_id="stable",
					candidate_release_id="candidate",
				)
			self.assertEqual(map_path.read_text(encoding="utf-8"), original)
			self.assertEqual(affinity_map_path.read_text(encoding="utf-8"), original_affinity)
			self.assertEqual(json.loads(state_path.read_text(encoding="utf-8"))["status"], "failed")

	def test_promoting_state_removes_old_release_affinity(self):
		entries = rollout.affinity_entries(
			"old-release", "new-release", stable_affinity_enabled=False,
		)
		self.assertNotIn("old-release", entries)
		self.assertEqual(entries["new-release"], "ai_candidate")

	@patch.object(rollout, "_apply_runtime_map")
	def test_failed_update_preserves_previous_active_state(self, apply_runtime_map):
		apply_runtime_map.side_effect = [RuntimeError("socket failed"), None, None]
		with tempfile.TemporaryDirectory() as temp_dir:
			root = Path(temp_dir)
			map_path = root / "rollout.map"
			affinity_map_path = root / "release-affinity.map"
			state_path = root / "rollout-state.json"
			map_path.write_text(rollout.render_map(rollout.desired_entries(5)), encoding="utf-8")
			affinity_map_path.write_text(rollout.render_affinity_map(
				rollout.affinity_entries("stable", "candidate"),
			), encoding="utf-8")
			state_path.write_text(json.dumps({
				"status": "active", "candidate_percent": 5,
				"stable_release_id": "stable", "candidate_release_id": "candidate",
			}), encoding="utf-8")
			with self.assertRaisesRegex(RuntimeError, "socket failed"):
				rollout.apply_rollout(
					container="router", map_path=map_path, affinity_map_path=affinity_map_path,
					state_path=state_path, candidate_percent=25,
					stable_release_id="stable", candidate_release_id="candidate",
				)
			state = json.loads(state_path.read_text(encoding="utf-8"))
			self.assertEqual(state["status"], "active")
			self.assertEqual(state["candidate_percent"], 5)
			self.assertIn("socket failed", state["last_apply_error"])


class RolloutVerifierTest(unittest.TestCase):
	def _state(self, percent: int):
		return {
			"status": "active",
			"candidate_percent": percent,
			"stable_release_id": "stable",
			"candidate_release_id": "candidate",
		}

	def _sample(self, *, stable: int, candidate: int):
		return {
			"samples": stable + candidate,
			"errors": [],
			"identities": [
				{"identity": {"ready": True, "release_id": "stable"}, "count": stable},
				{"identity": {"ready": True, "release_id": "candidate"}, "count": candidate},
			],
		}

	def _affinity(self, *, stable_enabled: bool = True):
		entries = {"__default__": "ai_affinity_missing", "candidate": "ai_candidate"}
		if stable_enabled:
			entries["stable"] = "ai_stable"
		return entries

	def test_expected_distribution_passes(self):
		report = rollout_verifier.evaluate(
			self._state(25), self._sample(stable=375, candidate=125),
			candidate_buckets=set(range(25)),
			affinity_routes=self._affinity(),
		)
		self.assertEqual(report["status"], "passed")

	def test_candidate_auto_fallback_is_safe_but_blocks_progression(self):
		report = rollout_verifier.evaluate(
			self._state(25), self._sample(stable=500, candidate=0),
			candidate_buckets=set(range(25)),
			affinity_routes=self._affinity(),
		)
		self.assertEqual(report["status"], "failed")
		self.assertIn(
			"AI_ROLLOUT_CANDIDATE_NOT_RECEIVING_TRAFFIC",
			{item["code"] for item in report["violations"]},
		)

	def test_map_state_drift_fails(self):
		report = rollout_verifier.evaluate(
			self._state(25), self._sample(stable=375, candidate=125),
			candidate_buckets=set(range(5)),
			affinity_routes=self._affinity(),
		)
		self.assertEqual(report["status"], "failed")
		self.assertIn("AI_ROLLOUT_MAP_STATE_DRIFT", {item["code"] for item in report["violations"]})

	def test_affinity_map_state_drift_fails(self):
		report = rollout_verifier.evaluate(
			self._state(25), self._sample(stable=375, candidate=125),
			candidate_buckets=set(range(25)),
			affinity_routes={"__default__": "ai_affinity_missing"},
		)
		self.assertEqual(report["status"], "failed")
		self.assertIn(
			"AI_ROLLOUT_AFFINITY_MAP_STATE_DRIFT",
			{item["code"] for item in report["violations"]},
		)

	def test_promoting_state_allows_candidate_only_affinity(self):
		state = {**self._state(100), "status": "promoting", "stable_affinity_enabled": False}
		report = rollout_verifier.evaluate(
			state, self._sample(stable=0, candidate=500),
			candidate_buckets=set(range(100)),
			affinity_routes=self._affinity(stable_enabled=False),
		)
		self.assertEqual(report["status"], "passed")

	def test_rollback_draining_keeps_candidate_affinity_without_fresh_traffic(self):
		state = {
			**self._state(0), "status": "draining", "drain_action": "retire_candidate",
		}
		report = rollout_verifier.evaluate(
			state, self._sample(stable=500, candidate=0),
			candidate_buckets=set(),
			affinity_routes=self._affinity(),
		)
		self.assertEqual(report["status"], "passed")


if __name__ == "__main__":
	unittest.main()
