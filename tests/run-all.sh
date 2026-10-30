#!/usr/bin/env bash
# Run with: bash tests/run-all.sh
set -euo pipefail
cd "$(dirname "$0")/.."
for f in plugins/storyforge/hooks/*.sh plugins/storyforge/scripts/*.sh; do
  bash -n "$f"
done
PY=""
for c in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $c -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || { echo "no working Python 3 found" >&2; exit 1; }
# shellcheck disable=SC2086
$PY -m unittest discover -s tests -p 'test_*.py' -v
