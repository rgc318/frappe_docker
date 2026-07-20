#!/usr/bin/env bash

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 <secret-env-file> [<secret-env-file> ...]" >&2
  exit 2
fi

python3 - "$@" <<'PY'
from pathlib import Path
import stat
import sys

errors: list[str] = []
for raw_path in sys.argv[1:]:
    path = Path(raw_path).resolve()
    try:
        file_stat = path.stat()
    except FileNotFoundError:
        errors.append(f"Missing secret environment file: {path}")
        continue

    if not stat.S_ISREG(file_stat.st_mode):
        errors.append(f"Secret environment path is not a regular file: {path}")
        continue

    mode = stat.S_IMODE(file_stat.st_mode)
    if mode & 0o077:
        errors.append(
            f"Secret environment file has group/other access: {path} "
            f"(mode {mode:04o}; expected 0600 or stricter)"
        )

if errors:
    raise SystemExit("\n".join(errors))

print(f"Secret environment file permissions passed: {len(sys.argv) - 1} file(s).")
PY
