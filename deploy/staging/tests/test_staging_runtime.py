import json
import os
import subprocess
import unittest
from pathlib import Path


class StagingRuntimeTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).resolve().parents[3]

    def test_rendered_backend_uses_gunicorn_without_debugger(self):
        env = {
            **os.environ,
            "ERPNEXT_VERSION": "v16.18.3",
            "MYAPP_AI_LITELLM_API_KEY": "synthetic-key",
            "MYAPP_AI_SERVICE_TOKEN": "x" * 32,
        }
        result = subprocess.run(
            [
                "docker",
                "compose",
                "--env-file",
                "/dev/null",
                "-f",
                "deploy/staging/compose.staging.yaml",
                "-f",
                "overrides/compose.redis.yaml",
                "-f",
                "deploy/staging/compose.mariadb.staging.yaml",
                "-f",
                "overrides/compose.noproxy.yaml",
                "config",
                "--format",
                "json",
            ],
            cwd=self.root,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        backend = json.loads(result.stdout)["services"]["backend"]
        command = " ".join(backend["command"])
        self.assertIn("/env/bin/gunicorn", command)
        self.assertIn("frappe.app:application", command)
        self.assertNotIn("bench serve", command)
        self.assertEqual(backend["environment"]["ENABLE_PYCHARM_DEBUG"], "0")

    def test_deploy_enables_and_health_check_requires_scheduler(self):
        deploy = (self.root / "deploy/staging/deploy-staging.sh").read_text()
        check = (self.root / "deploy/staging/check-staging.sh").read_text()
        self.assertIn("bench --site ${SITE_NAME} enable-scheduler", deploy)
        self.assertIn("frappe.utils.scheduler.get_scheduler_status", check)
        self.assertIn('"status": "active"', check)

    def test_deploy_reuses_images_after_the_explicit_pull(self):
        deploy = (self.root / "deploy/staging/deploy-staging.sh").read_text()
        release_pull = "compose pull backend ai-orchestrator"
        self.assertIn(release_pull, deploy)
        self.assertNotIn("compose pull\n", deploy)
        pull_offset = deploy.index(release_pull)
        cached_offset = deploy.index("export PULL_POLICY=never")
        up_offset = deploy.index("compose up -d")
        self.assertLess(pull_offset, cached_offset)
        self.assertLess(cached_offset, up_offset)


if __name__ == "__main__":
    unittest.main()
