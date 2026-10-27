#!/usr/bin/env bash
# Stop: while a story is in develop/fix/integrate/verify, block finishing
# until the test suite, lint, and typecheck pass. Capped by max_stop_blocks to prevent endless loops.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
cat >/dev/null  # consume stdin
PHASE=$(sf_phase)
case "$PHASE" in develop|fix|integrate|ui|verify) ;; *) exit 0;; esac
[ -f "$SF_CONFIG" ] || exit 0
TEST=$(sf_cfg test "")
[ -z "$TEST" ] && exit 0
CMD="$TEST"
if [ "$PHASE" != ui ]; then
  for K in lint typecheck; do
    C=$(sf_cfg "$K" ""); [ -n "$C" ] && CMD="$CMD && $C"
  done
fi
if [ "$PHASE" = integrate ] || [ "$PHASE" = verify ]; then
  IT=$(sf_cfg integration_test ""); [ -n "$IT" ] && CMD="$CMD && $IT"
fi
if [ "$PHASE" = ui ] || { [ "$PHASE" = verify ] && [ "$(sf_cfg ui.enabled false)" = true ] && [ -f "$SF_STATE/ui-ran" ]; }; then
  E2E=$(sf_cfg e2e_test ""); [ -n "$E2E" ] && CMD="$CMD && $E2E"
fi
OUT=$(cd "$SF_PROJECT" && bash -c "$CMD" 2>&1); RC=$?
if [ $RC -eq 0 ]; then echo 0 > "$SF_STATE/stop-blocks"; exit 0; fi
MAX=$(sf_cfg max_stop_blocks 3)
N=$(( $(cat "$SF_STATE/stop-blocks" 2>/dev/null || echo 0) + 1 ))
echo $N > "$SF_STATE/stop-blocks"
if [ "$N" -gt "$MAX" ]; then
  echo "[storyforge] Tests, lint, or typecheck still failing after $MAX blocked stops; letting the session end. Record the failures under ## Blocked in status.md." >&2
  exit 0
fi
TAIL=$(printf '%s\n' "$OUT" | grep -v '^\s*$' | tail -40)
python3 -c 'import json,sys;print(json.dumps({"decision":"block","reason":"[storyforge] Phase "+sys.argv[1]+": tests, lint, or typecheck are failing (exit "+sys.argv[2]+"), stop "+sys.argv[3]+"/"+sys.argv[4]+". Fix by root cause; do not weaken tests. Last output:\n"+sys.argv[5]}))' "$PHASE" "$RC" "$N" "$MAX" "$TAIL"
