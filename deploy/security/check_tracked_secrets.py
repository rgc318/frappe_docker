"""Reject tracked Frappe runtime configs, including archive members, without exposing values."""

import pathlib
import subprocess
import sys
import tarfile
import zipfile

RUNTIME_CONFIGS = {"site_config.json", "common_site_config.json"}
MAX_ARCHIVE_MEMBERS = 100_000


def contains_runtime_config(path):
    if path.name in RUNTIME_CONFIGS:
        return True
    suffix = path.name.lower()
    try:
        if suffix.endswith((".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tar.xz")):
            with tarfile.open(path, "r:*") as archive:
                for index, member in enumerate(archive):
                    if index >= MAX_ARCHIVE_MEMBERS:
                        raise ValueError("archive exceeds scan limit")
                    if (
                        pathlib.PurePosixPath(member.name.replace("\\", "/")).name
                        in RUNTIME_CONFIGS
                    ):
                        return True
        elif suffix.endswith(".zip"):
            with zipfile.ZipFile(path) as archive:
                members = archive.infolist()
                if len(members) > MAX_ARCHIVE_MEMBERS:
                    raise ValueError("archive exceeds scan limit")
                return any(
                    pathlib.PurePosixPath(member.filename.replace("\\", "/")).name
                    in RUNTIME_CONFIGS
                    for member in members
                )
    except (tarfile.TarError, zipfile.BadZipFile, OSError) as exc:
        raise ValueError("archive cannot be inspected") from exc
    return False


def main():
    root = pathlib.Path(__file__).resolve().parents[2]
    paths = (
        subprocess.check_output(["git", "ls-files", "--cached", "-z"], cwd=root)
        .decode()
        .split("\0")
    )
    blocked = 0
    for relative in filter(None, paths):
        path = root / relative
        if not path.is_file():
            # Submodule gitlinks are directories, not files in this repository.
            continue
        try:
            unsafe = contains_runtime_config(path)
        except ValueError:
            unsafe = True
        if unsafe:
            blocked += 1
            print(
                f"Blocked tracked runtime config/archive: {relative!r}", file=sys.stderr
            )
    if blocked:
        print(
            "Keep runtime configs and backups outside Git; values were not inspected or printed.",
            file=sys.stderr,
        )
        return 1
    print("Tracked Frappe runtime-config/archive check passed (current snapshot only).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
