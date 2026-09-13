import io
import pathlib
import tarfile
import tempfile
import unittest
import zipfile

from check_tracked_secrets import contains_runtime_config


class TrackedSecretTests(unittest.TestCase):
    def test_direct_config_is_rejected_without_reading_contents(self):
        self.assertTrue(
            contains_runtime_config(pathlib.Path("private/site_config.json"))
        )
        self.assertTrue(
            contains_runtime_config(pathlib.Path("private/common_site_config.json"))
        )
        self.assertFalse(
            contains_runtime_config(pathlib.Path("site_config.json.example"))
        )

    def test_tar_member_is_detected_without_extracting(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "backup.tar.gz"
            with tarfile.open(path, "w:gz") as archive:
                data = b'{"db_password":"synthetic-only"}'
                member = tarfile.TarInfo("data/localhost/site_config.json")
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
            self.assertTrue(contains_runtime_config(path))
            self.assertEqual(list(pathlib.Path(directory).iterdir()), [path])

    def test_zip_member_is_detected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "backup.zip"
            with zipfile.ZipFile(path, "w") as archive:
                archive.writestr("data/common_site_config.json", "{}")
            self.assertTrue(contains_runtime_config(path))

    def test_normal_archive_is_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "assets.tar.gz"
            with tarfile.open(path, "w:gz") as archive:
                archive.addfile(tarfile.TarInfo("assets/logo.svg"), io.BytesIO())
            self.assertFalse(contains_runtime_config(path))

    def test_corrupt_archive_fails_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "invalid.tar.gz"
            path.touch()
            with self.assertRaises(ValueError):
                contains_runtime_config(path)
