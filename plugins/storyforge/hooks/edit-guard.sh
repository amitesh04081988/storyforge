#!/usr/bin/env bash
# PreToolUse(Edit|Write|MultiEdit|NotebookEdit) during develop/fix:
#  1. Test lock: deny edits to test files (code can't pass by changing its tests).
#  2. Scope lock (idea from gstack /freeze): deny edits outside the plan's scope globs
#     in docs/stories/<id>/scope.txt, when scope_lock is true.
# This hook only sees the Edit and Write tools. Changes made another way (a shell redirect, sed -i,
# a formatter, a script) are caught afterwards by scripts/guard.sh check.
# It needs Python. With none working it denies instead of silently allowing (see lib.sh).
# Overrides: .storyforge/allow-test-edit, .storyforge/allow-scope-edit, .storyforge/allow-no-python
set -uo pipefail
. "$(dirname "$0")/lib.sh"
INPUT=$(cat)
PHASE=$(sf_phase)
case "$PHASE" in develop|fix) ;; *) echo '{}'; exit 0;; esac
sf_find_python
if [ -z "$SF_PY" ]; then
  if sf_allow_no_python; then echo '{}'; exit 0; fi
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"'"$SF_NO_PY_MSG"'"}}'
  exit 0
fi
FILE=$(sf_json_field "$INPUT" tool_input.file_path)
[ -z "$FILE" ] && FILE=$(sf_json_field "$INPUT" tool_input.notebook_path)
[ -z "$FILE" ] && { echo '{}'; exit 0; }
STORY=$(cat "$SF_STATE/story" 2>/dev/null || true)
SCOPE_FILE="$SF_PROJECT/docs/stories/$STORY/scope.txt"
TEST_GLOBS=$(sf_cfg test_globs $'**/*.test.*\n**/*.spec.*\ntests/**\ntest/**')
SCOPE_LOCK=$(sf_cfg scope_lock true)
ALLOW_TEST=$([ -f "$SF_STATE/allow-test-edit" ] && echo 1 || echo "")
ALLOW_SCOPE=$([ -f "$SF_STATE/allow-scope-edit" ] && echo 1 || echo "")
# shellcheck disable=SC2086
$SF_PY - "$SF_PROJECT" "$FILE" "$TEST_GLOBS" "$PHASE" "$SCOPE_FILE" "$SCOPE_LOCK" "$ALLOW_TEST" "$ALLOW_SCOPE" "$STORY" <<'PY'
import os,sys,fnmatch,json
from pathlib import Path
root,f,tglobs,phase,scope_file,scope_lock,allow_test,allow_scope,story=sys.argv[1:10]
def deny(msg):
    print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":msg}})); sys.exit(0)
base=Path(root).resolve()
target=Path(f).resolve(strict=False)
try:
    rel=target.relative_to(base).as_posix()
except ValueError:
    deny("[storyforge] Refused write outside the project workspace")
protected=(rel.startswith(".claude/") or rel.startswith(".github/workflows/") or
           rel=="storyforge.config.json" or rel.startswith("plugins/storyforge/hooks/") or
           rel.startswith("plugins/storyforge/scripts/"))
if protected and not allow_scope:
    deny("[storyforge] Protected policy file requires explicit allow-scope-edit approval")
def m(p,g):
    g=g.strip()
    if not g or g.startswith("#"): return False
    if g.endswith("/"): g+="**"
    return fnmatch.fnmatch(p,g) or (g.startswith("**/") and fnmatch.fnmatch(p,g[3:]))
def deny(msg):
    print(json.dumps({"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":msg}})); sys.exit(0)
if True:
    if not allow_test and any(m(rel,g) for g in tglobs.splitlines()):
        deny(f"[storyforge] Test files are locked during the {phase} phase. Fix the production code instead. If the test itself is wrong, record TEST-DISPUTE in findings.md for the orchestrator.")
    always=[f"docs/stories/{story}/**","docs/memory/**"]
    if scope_lock=="true" and not allow_scope and os.path.isfile(scope_file):
        globs=open(scope_file).read().splitlines()+always
        if not any(m(rel,g) for g in globs):
            deny(f"[storyforge] {rel} is outside this story's planned scope (docs/stories/{story}/scope.txt). If it truly needs changing, add it under plan.md § Deviations with the reason and return; the orchestrator will widen the scope.")
print("{}")
PY
