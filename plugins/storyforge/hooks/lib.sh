#!/usr/bin/env bash
# Shared helpers for StoryForge hooks. Sourced, not executed.
SF_PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
SF_STATE="$SF_PROJECT/.storyforge"
SF_CONFIG="$SF_PROJECT/storyforge.config.json"

# Find a Python 3 that actually runs and set SF_PY to its command ("" when none does).
# Existing is not enough: on Windows `python3` is often the Microsoft Store shortcut, which is on
# the PATH but only prints "Python was not found". So each candidate is executed once.
sf_find_python() {
  [ -n "${SF_PY_CHECKED:-}" ] && return 0
  SF_PY_CHECKED=1; SF_PY=""
  local c
  for c in python3 python "py -3"; do
    # shellcheck disable=SC2086
    if $c -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then SF_PY="$c"; return 0; fi
  done
  return 1
}
sf_find_python

# Hooks that need Python must not silently turn themselves off when it is missing.
# They block and say why, unless the user has run: touch .storyforge/allow-no-python
# The text is JSON-safe on purpose (no quotes or backslashes), because it is printed without Python.
SF_NO_PY_MSG='[storyforge] No working Python 3 was found (tried python3, python, py -3), so the test lock, scope lock and stop gate cannot run. They are blocking instead of silently skipping. Install Python 3 or fix the PATH. To continue without them, run: touch .storyforge/allow-no-python'
sf_allow_no_python() { [ -f "$SF_STATE/allow-no-python" ]; }

sf_phase() { cat "$SF_STATE/phase" 2>/dev/null || echo ""; }

# sf_cfg <key> [default]  -> prints scalar config value (lists joined by newline)
sf_cfg() {
  [ -f "$SF_CONFIG" ] && [ -n "$SF_PY" ] || { printf '%s' "${2:-}"; return; }
  # shellcheck disable=SC2086
  $SF_PY - "$SF_CONFIG" "$1" "${2:-}" <<'PY' 2>/dev/null || printf '%s' "${2:-}"
import json,sys
try:
    v=json.load(open(sys.argv[1]))
    for k in sys.argv[2].split('.'): v=v.get(k) if isinstance(v,dict) else None
except Exception: v=None
if v is None or v=="": print(sys.argv[3],end="")
elif isinstance(v,list): print("\n".join(map(str,v)),end="")
elif isinstance(v,bool): print("true" if v else "false",end="")
else: print(v,end="")
PY
}

# sf_json_field <json> <dotted.path>  -> prints string value or empty
sf_json_field() {
  [ -n "$SF_PY" ] || return 0
  # shellcheck disable=SC2086
  printf '%s' "$1" | $SF_PY -c '
import json,sys
try: o=json.load(sys.stdin)
except Exception: sys.exit(0)
for k in sys.argv[1].split("."):
    o=o.get(k) if isinstance(o,dict) else None
print(o if isinstance(o,(str,int,float)) and not isinstance(o,bool) else ("true" if o is True else ""),end="")' "$2" 2>/dev/null
}
