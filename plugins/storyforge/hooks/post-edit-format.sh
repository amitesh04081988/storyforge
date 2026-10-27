#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): run the configured formatter on the edited file.
# Silent and non-blocking; formatting noise never reaches the model.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
INPUT=$(cat)
[ -f "$SF_CONFIG" ] || exit 0
# Default config has no formatter: leave without starting Python (this hook runs on every edit).
grep -qE '"format"[[:space:]]*:[[:space:]]*"[^"]' "$SF_CONFIG" || exit 0
sf_find_python
FMT=$(sf_cfg format "")
[ -z "$FMT" ] && exit 0
FILE=$(sf_json_field "$INPUT" tool_input.file_path)
[ -n "$FILE" ] && [ -f "$FILE" ] && (cd "$SF_PROJECT" && bash -c "$FMT \"\$1\"" _ "$FILE" >/dev/null 2>&1)
exit 0
