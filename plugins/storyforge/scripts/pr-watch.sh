#!/usr/bin/env bash
# One-line state of a pull request, read from GitHub with the gh CLI.
#   pr-watch.sh <number|branch> [--repo owner/name]
# Prints: PR <n> head=<sha> state=<s> ci=<pass|pending|fail|not-configured> policy=<ok|missing-policy|missing-required> mergeable=<m> review=<r> -> <READY|WAIT|ACT|CLOSED>
# Exit 0 READY, 1 WAIT, 2 ACT (CI failing, conflicts, or changes requested), 3 CLOSED or merged, 4 gh failed.
#
# READY needs ALL of: an open PR, at least one check, every check passing (SKIPPED and NEUTRAL count as passing),
# every name in STORYFORGE_REQUIRED_CHECKS present, no conflicts, no review outstanding.
# STORYFORGE_REQUIRED_CHECKS lists check names separated by ";" or newlines (names may contain commas).
# Without it the script never says READY: it cannot know which checks must exist.
# The head sha it prints is what `bits-tasks.sh mergeable` compares a verdict against.
set -uo pipefail
PR="${1:-}"; [ -n "$PR" ] || { echo "usage: $0 <number|branch> [--repo owner/name]"; exit 1; }
shift
REPO=()
[ "${1:-}" = "--repo" ] && REPO=(--repo "${2:?--repo needs a value}")
command -v gh >/dev/null || { echo "gh CLI not found"; exit 4; }

# Fields, "|"-separated: state, mergeable, review, head sha, failing, pending, check count, check names (0x1f-separated, last).
# Failing = a conclusion that is a real failure. Passing = SUCCESS, NEUTRAL, SKIPPED. Anything else (empty, PENDING, QUEUED,
# IN_PROGRESS, WAITING, STALE, unknown) is still pending, so the answer is WAIT, never a false READY.
JQ='(.statusCheckRollup // []) as $r
 | [$r[] | (.conclusion // .state // "")] as $c
 | [ .state, (.mergeable | if . == null or . == "" then "UNKNOWN" else . end), (.reviewDecision | if . == null or . == "" then "NONE" else . end), .headRefOid,
     ([$c[] | select(. == "FAILURE" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ERROR" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE")] | length | tostring),
     ([$c[] | select(. != "SUCCESS" and . != "NEUTRAL" and . != "SKIPPED" and . != "FAILURE" and . != "TIMED_OUT" and . != "CANCELLED" and . != "ERROR" and . != "ACTION_REQUIRED" and . != "STARTUP_FAILURE")] | length | tostring),
     ($r | length | tostring), ([$r[] | (.name // .context // "")] | join("\u001f")) ] | join("|")'
OUT=$(gh pr view "$PR" "${REPO[@]}" --json state,mergeable,reviewDecision,headRefOid,statusCheckRollup --jq "$JQ" 2>&1) || { echo "gh failed: $OUT"; exit 4; }
IFS='|' read -r state mergeable review sha failing pending count names <<< "$OUT"

ci=pass; [ "${pending:-0}" != 0 ] && ci=pending; [ "${failing:-0}" != 0 ] && ci=fail
[ "${count:-0}" = 0 ] && ci=not-configured

policy=ok
if [ -z "${STORYFORGE_REQUIRED_CHECKS:-}" ]; then
  policy=missing-policy
else
  sep=$'\x1f'
  while IFS= read -r needed; do
    [ -n "$needed" ] || continue
    case "$sep$names$sep" in *"$sep$needed$sep"*) ;; *) policy=missing-required;; esac
  done < <(printf '%s\n' "$STORYFORGE_REQUIRED_CHECKS" | tr ';' '\n')
fi

verdict=READY; code=0
if [ "$state" != OPEN ]; then verdict=CLOSED; code=3
elif [ "$ci" = fail ] || [ "$mergeable" = CONFLICTING ] || [ "$review" = CHANGES_REQUESTED ]; then verdict=ACT; code=2
elif [ "$ci" != pass ] || [ "$policy" != ok ] || [ "$mergeable" = UNKNOWN ] || [ "$review" = REVIEW_REQUIRED ]; then verdict=WAIT; code=1
fi
echo "PR $PR head=$sha state=$state ci=$ci policy=$policy mergeable=$mergeable review=$review -> $verdict"
exit $code
