#!/usr/bin/env bash
# Stop: while a story is in develop/fix/integrate/ui/verify, block finishing until
#  - the test suite, lint, and typecheck pass,
#  - in develop and fix: no test or out-of-scope file changed since the guard snapshot (scripts/guard.sh),
#  - in verify: the definition of done passes (scripts/dod-check.sh).
# Capped by max_stop_blocks to prevent endless loops. With no working Python it blocks and says why
# instead of silently allowing (see lib.sh); override with .storyforge/allow-no-python.
set -uo pipefail
HERE="$(dirname "$0")"
. "$HERE/lib.sh"
cat >/dev/null  # consume stdin
PHASE=$(sf_phase)

# Manager loop: unfinished ledger tasks mean the run is not over. Stopping to hand open issues
# back to the human is the failure this gate exists to stop. `echo blocked > .storyforge/phase`
# is the sanctioned exit when a task needs a product decision, a secret, or an irreversible action.
LEDGER="$SF_PROJECT/.storyforge/tasks.sqlite"
if [ -f "$LEDGER" ] && [ "$PHASE" != blocked ] && ! sf_state_tracked; then
  if ! LOUT=$(STORYFORGE_DB="$LEDGER" bash "$HERE/../scripts/bits-tasks.sh" status 2>&1); then
    mkdir -p "$SF_STATE"
    LN=$(( $(cat "$SF_STATE/ledger-blocks" 2>/dev/null || echo 0) + 1 ))
    echo $LN > "$SF_STATE/ledger-blocks"
    if [ "$LN" -le "$(sf_cfg max_stop_blocks 3)" ]; then
      LMSG="[storyforge] Task ledger has unfinished tasks. Follow playbooks/manager-loop.md: fix, measure or verify each one and record it, or mark the task blocked and run: echo blocked > .storyforge/phase. Do not hand open issues back as a question. $(printf '%s' "$LOUT" | head -n 12)"
      sf_find_python
      # shellcheck disable=SC2086
      [ -n "$SF_PY" ] && { $SF_PY -c 'import json,sys;print(json.dumps({"decision":"block","reason":sys.argv[1]}))' "$LMSG"; exit 0; }
    fi
  else
    rm -f "$SF_STATE/ledger-blocks"
  fi
fi

case "$PHASE" in develop|fix|integrate|ui|verify) ;; *) exit 0;; esac
[ -f "$SF_CONFIG" ] || exit 0
mkdir -p "$SF_STATE"
sf_find_python

N=$(( $(cat "$SF_STATE/stop-blocks" 2>/dev/null || echo 0) + 1 ))

if [ -z "$SF_PY" ]; then
  sf_allow_no_python && exit 0
  echo $N > "$SF_STATE/stop-blocks"
  [ "$N" -gt 3 ] && { echo "[storyforge] $SF_NO_PY_MSG" >&2; exit 0; }
  printf '%s\n' '{"decision":"block","reason":"'"$SF_NO_PY_MSG"'"}'
  exit 0
fi

REPORT=""; FAILED=0
run_gate() {
  local name="$1" required="$2" cmd output rc
  cmd=$(sf_cfg "$name" "")
  if [ -z "$cmd" ]; then
    if [ "$required" = true ]; then
      FAILED=1; REPORT="$REPORT
$name: BLOCKED (required command missing)"
    fi
    return
  fi
  output=$(cd "$SF_PROJECT" && bash -c "$cmd" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    FAILED=1; REPORT="$REPORT
$name: FAIL (exit $rc)
$(printf '%s\n' "$output" | tail -40)"
  fi
}
run_gate test true
if [ "$PHASE" != ui ]; then
  run_gate lint true
  run_gate typecheck true
fi
if [ "$PHASE" = integrate ] || [ "$PHASE" = verify ]; then
  [ -f "$SF_STATE/integration-ran" ] && run_gate integration_test true
fi
if [ "$PHASE" = ui ] || { [ "$PHASE" = verify ] && [ -f "$SF_STATE/ui-ran" ]; }; then
  run_gate e2e_test true
fi

if [ "$PHASE" = develop ] || [ "$PHASE" = fix ]; then
  GOUT=$(cd "$SF_PROJECT" && bash "$HERE/../scripts/guard.sh" check 2>&1); GRC=$?
  if [ $GRC -ne 0 ]; then FAILED=1; REPORT="$REPORT
$GOUT"; fi
fi

if [ "$PHASE" = verify ]; then
  STORY=$(cat "$SF_STATE/story" 2>/dev/null || true)
  if [ -n "$STORY" ]; then
    DOUT=$(cd "$SF_PROJECT" && bash "$HERE/../scripts/dod-check.sh" "$STORY" 2>&1); DRC=$?
    if [ $DRC -ne 0 ]; then FAILED=1; REPORT="$REPORT
$DOUT"; fi
  fi
fi

if [ $FAILED -eq 0 ]; then echo 0 > "$SF_STATE/stop-blocks"; rm -f "$SF_STATE/gate-blocked"; exit 0; fi

MAX=$(sf_cfg max_stop_blocks 3)
echo $N > "$SF_STATE/stop-blocks"
if [ "$N" -gt "$MAX" ]; then
  printf "gate-blocked: %s\n" "$REPORT" > "$SF_STATE/gate-blocked"
  echo "[storyforge] BLOCKED after $MAX attempts (session may stop but task cannot pass): $REPORT" >&2
  exit 0
fi
# shellcheck disable=SC2086
$SF_PY -c 'import json,sys;print(json.dumps({"decision":"block","reason":"[storyforge] Phase "+sys.argv[1]+", stop "+sys.argv[2]+"/"+sys.argv[3]+": "+sys.argv[4]}))' "$PHASE" "$N" "$MAX" "$REPORT"
