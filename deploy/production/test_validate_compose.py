import copy
import json
import os
import subprocess
import unittest
from pathlib import Path

from validate_compose import ERP_SERVICES, validate


class ProductionComposeTests(unittest.TestCase):
    def setUp(self):
        self.config = {
            "services": {
                name: {"image": "registry.example/erp:release-20260913"}
                for name in ERP_SERVICES
            }
        }
        self.config["services"].update(
            {
                "proxy": {},
                "backend": {
                    "image": "registry.example/erp:release-20260913",
                    "command": ["gunicorn"],
                    "environment": {"ENABLE_PYCHARM_DEBUG": "0"},
                },
                "ai-orchestrator": {"image": "registry.example/ai:release-20260913"},
                "db": {
                    "environment": {
                        "MYSQL_ROOT_PASSWORD": "synthetic-test-password-only"
                    }
                },
            }
        )

    def test_valid_configuration(self):
        self.assertEqual(validate(self.config), [])

    def test_start_and_stop_scripts_use_the_hardened_composition(self):
        root = Path(__file__).resolve().parents[2]
        for filename in ("start-prod.sh", "stop.sh"):
            source = (root / filename).read_text()
            self.assertNotIn("compose.traefik.yaml", source)
            self.assertGreater(
                source.index("compose.production.yaml"),
                source.index("compose.langfuse.yaml"),
            )
        source = (root / "start-prod.sh").read_text()
        self.assertLess(source.index("validate_compose.py"), source.index("up -d"))
        self.assertIn("--no-build", source)
        self.assertNotIn("--reconcile", source)

    def test_rejects_development_settings(self):
        for field, value in (
            ("ports", [{"published": "8000"}]),
            ("command", ["bench serve"]),
            ("command", ["pip install -e apps/myapp"]),
            ("image", "registry.example/erp:latest"),
            (
                "volumes",
                [{"type": "bind", "target": "/home/frappe/frappe-bench/apps/myapp"}],
            ),
            ("environment", {"ENABLE_PYCHARM_DEBUG": "1"}),
            ("build", {"context": "."}),
        ):
            with self.subTest(field=field, value=value):
                config = copy.deepcopy(self.config)
                config["services"]["backend"][field] = value
                self.assertTrue(validate(config))

    def test_rejects_second_proxy_and_weak_database_password(self):
        self.config["services"]["traefik"] = {}
        self.config["services"]["db"]["environment"]["MYSQL_ROOT_PASSWORD"] = "123"
        self.assertEqual(len(validate(self.config)), 2)

    def test_rendered_real_compose_has_no_development_inheritance(self):
        root = Path(__file__).resolve().parents[2]
        env = {
            **os.environ,
            "ERPNEXT_VERSION": "v16",
            "MYAPP_PRODUCTION_ERP_IMAGE": "registry.example/erp:release-20260913",
            "MYAPP_PRODUCTION_AI_IMAGE": "registry.example/ai:release-20260913",
            "DB_PASSWORD": "synthetic-test-password-only",
            "SITES_RULE": "Host(`test.invalid`)",
            "LETSENCRYPT_EMAIL": "test@example.invalid",
        }
        for observability in (False, True):
            with self.subTest(observability=observability):
                args = [
                    "docker",
                    "compose",
                    "--env-file",
                    "/dev/null",
                    "-f",
                    "compose.yaml",
                    "-f",
                    "overrides/compose.redis.yaml",
                    "-f",
                    "overrides/compose.mariadb.yaml",
                    "-f",
                    "overrides/compose.https.yaml",
                ]
                if observability:
                    args.extend(["-f", "overrides/compose.langfuse.yaml"])
                args.extend(
                    [
                        "-f",
                        "overrides/compose.production.yaml",
                        "config",
                        "--no-env-resolution",
                        "--format",
                        "json",
                    ]
                )
                result = subprocess.run(
                    args, cwd=root, env=env, capture_output=True, text=True, timeout=30
                )
                self.assertEqual(
                    result.returncode,
                    0,
                    "Compose render failed; check Docker Compose >= 2.24.4 and required files",
                )
                config = json.loads(result.stdout)
                self.assertEqual(validate(config), [])
                self.assertEqual(
                    {p["target"] for p in config["services"]["proxy"]["ports"]},
                    {80, 443},
                )


if __name__ == "__main__":
    unittest.main()
