#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit): run the configured formatter on the edited file.
# Silent and non-blocking; formatting noise never reaches the model.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
INPUT=$(cat)
FMT=$(sf_cfg format "")
[ -z "$FMT" ] && exit 0
FILE=$(sf_json_field "$INPUT" tool_input.file_path)
[ -n "$FILE" ] && [ -f "$FILE" ] && (cd "$SF_PROJECT" && bash -c "$FMT \"\$1\"" _ "$FILE" >/dev/null 2>&1)
exit 0
