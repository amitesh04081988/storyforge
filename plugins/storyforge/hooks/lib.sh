#!/usr/bin/env bash
# Shared helpers for StoryForge hooks. Sourced, not executed.
SF_PROJECT="${CLAUDE_PROJECT_DIR:-$PWD}"
SF_STATE="$SF_PROJECT/.storyforge"
SF_CONFIG="$SF_PROJECT/storyforge.config.json"

sf_phase() { cat "$SF_STATE/phase" 2>/dev/null || echo ""; }

# sf_cfg <key> [default]  -> prints scalar config value (lists joined by newline)
sf_cfg() {
  [ -f "$SF_CONFIG" ] || { printf '%s' "${2:-}"; return; }
  python3 - "$SF_CONFIG" "$1" "${2:-}" <<'PY' 2>/dev/null || printf '%s' "${2:-}"
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
  printf '%s' "$1" | python3 -c '
import json,sys
try: o=json.load(sys.stdin)
except Exception: sys.exit(0)
for k in sys.argv[1].split("."):
    o=o.get(k) if isinstance(o,dict) else None
print(o if isinstance(o,(str,int,float)) and not isinstance(o,bool) else ("true" if o is True else ""),end="")' "$2" 2>/dev/null
}
