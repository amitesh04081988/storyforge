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
case "$PHASE" in develop|fix|integrate|ui|verify) ;; *) exit 0;; esac
[ -f "$SF_CONFIG" ] || exit 0
mkdir -p "$SF_STATE"

N=$(( $(cat "$SF_STATE/stop-blocks" 2>/dev/null || echo 0) + 1 ))

if [ -z "$SF_PY" ]; then
  sf_allow_no_python && exit 0
  echo $N > "$SF_STATE/stop-blocks"
  [ "$N" -gt 3 ] && { echo "[storyforge] $SF_NO_PY_MSG" >&2; exit 0; }
  printf '%s\n' '{"decision":"block","reason":"'"$SF_NO_PY_MSG"'"}'
  exit 0
fi

TEST=$(sf_cfg test "")
REPORT=""; FAILED=0

if [ -n "$TEST" ]; then
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
  if [ $RC -ne 0 ]; then
    FAILED=1
    REPORT="tests, lint, or typecheck are failing (exit $RC). Fix by root cause; do not weaken tests. Last output:
$(printf '%s\n' "$OUT" | grep -v '^\s*$' | tail -40)"
  fi
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

if [ $FAILED -eq 0 ]; then echo 0 > "$SF_STATE/stop-blocks"; exit 0; fi

MAX=$(sf_cfg max_stop_blocks 3)
echo $N > "$SF_STATE/stop-blocks"
if [ "$N" -gt "$MAX" ]; then
  echo "[storyforge] Checks still failing after $MAX blocked stops; letting the session end. Record what is open under ## Blocked in status.md." >&2
  exit 0
fi
# shellcheck disable=SC2086
$SF_PY -c 'import json,sys;print(json.dumps({"decision":"block","reason":"[storyforge] Phase "+sys.argv[1]+", stop "+sys.argv[2]+"/"+sys.argv[3]+": "+sys.argv[4]}))' "$PHASE" "$N" "$MAX" "$REPORT"
