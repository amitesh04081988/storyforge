#!/usr/bin/env bash
# Run with: bash tests/run-all.sh
set -euo pipefail
cd "$(dirname "$0")/.."
for f in plugins/storyforge/hooks/*.sh plugins/storyforge/scripts/*.sh; do
  bash -n "$f"
done
python3 -m unittest discover -s tests -p 'test_*.py' -v
