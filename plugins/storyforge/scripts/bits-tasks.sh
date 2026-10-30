#!/usr/bin/env bash
# Entry point for the Bits-Mode ledger and its Python helpers.
#   bits-tasks.sh <command> ...            the transactional ledger (see bits-state.py --help)
#   bits-tasks.sh verify <id> --verifier X run the project's gates and store their real exit codes (verify-run.py)
#   bits-tasks.sh policy "<request>" --path P   minimum risk mode for a request (bits-policy.py)
# It finds a Python 3 that actually runs (python3, python, py -3). On Windows `python3` is often the Microsoft Store
# stub, which exists but only prints "Python was not found", so each candidate is executed before it is chosen.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PY=""
for c in python3 python "py -3"; do
  # shellcheck disable=SC2086
  if $c -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' >/dev/null 2>&1; then PY="$c"; break; fi
done
[ -n "$PY" ] || { echo "StoryForge BLOCKED: no working Python 3 (tried python3, python, py -3)" >&2; exit 1; }
case "${1:-}" in
  verify) shift; exec $PY "$DIR/verify-run.py" "$@" ;;
  policy) shift; exec $PY "$DIR/bits-policy.py" "$@" ;;
  *) exec $PY "$DIR/bits-state.py" "$@" ;;
esac
