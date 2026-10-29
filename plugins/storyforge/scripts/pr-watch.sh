#!/usr/bin/env bash
# One-line state of a pull request, read from GitHub with the gh CLI.
#   pr-watch.sh <number|branch> [--repo owner/name]
# Prints: PR <n> head=<sha> state=<s> ci=<pass|pending|fail> mergeable=<m> review=<r> -> <READY|WAIT|ACT|CLOSED>
# Exit 0 READY (open, CI green, no conflicts, no requested changes, no review still required), 1 WAIT (CI pending or review required),
#      2 ACT (CI failing, conflicts, or changes requested), 3 CLOSED or merged, 4 gh failed.
# The head sha it prints is what `bits-tasks.sh mergeable` compares a verdict against.
set -uo pipefail
PR="${1:-}"; [ -n "$PR" ] || { echo "usage: $0 <number|branch> [--repo owner/name]"; exit 1; }
shift
REPO=()
[ "${1:-}" = "--repo" ] && REPO=(--repo "${2:?--repo needs a value}")
command -v gh >/dev/null || { echo "gh CLI not found"; exit 4; }

JQ='[.statusCheckRollup[]? | (.conclusion // .state // "")] as $c
 | [ .state, (.mergeable | if . == null or . == "" then "UNKNOWN" else . end), (.reviewDecision | if . == null or . == "" then "NONE" else . end), .headRefOid,
     ([$c[] | select(. == "FAILURE" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ERROR" or . == "ACTION_REQUIRED")] | length | tostring),
     ([$c[] | select(. == "" or . == "PENDING" or . == "QUEUED" or . == "IN_PROGRESS" or . == "EXPECTED")] | length | tostring) ] | join("|")'
OUT=$(gh pr view "$PR" "${REPO[@]}" --json state,mergeable,reviewDecision,headRefOid,statusCheckRollup --jq "$JQ" 2>&1) || { echo "gh failed: $OUT"; exit 4; }
IFS='|' read -r state mergeable review sha failing pending <<< "$OUT"

ci=pass; [ "$pending" != 0 ] && ci=pending; [ "$failing" != 0 ] && ci=fail
verdict=READY; code=0
if [ "$state" != OPEN ]; then verdict=CLOSED; code=3
elif [ "$ci" = fail ] || [ "$mergeable" = CONFLICTING ] || [ "$review" = CHANGES_REQUESTED ]; then verdict=ACT; code=2
elif [ "$ci" = pending ] || [ "$mergeable" = UNKNOWN ] || [ "$review" = REVIEW_REQUIRED ]; then verdict=WAIT; code=1
fi
echo "PR $PR head=$sha state=$state ci=$ci mergeable=$mergeable review=$review -> $verdict"
exit $code
