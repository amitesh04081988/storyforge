#!/usr/bin/env bash
# Check a story's definition of done with code, not with the model's own word.
#   dod-check.sh <story-id>
# Reads docs/stories/<id>/{status,plan,findings,impact}.md. Exit 0 = done; exit 1 = not done, with reasons.
# Rules:
#  1. status.md has a "## Definition of done" table with at least one row.
#  2. Every row has evidence (not empty, "-", n/a, tbd, assumed, "covered elsewhere") and Result "pass".
#  3. Every numbered item under plan.md "Acceptance criteria" and "Impact-driven changes" has a row with that number.
#  4. Every area marked check or change in impact.md is named in some row.
#  5. No CRITICAL or HIGH finding in findings.md is still open (a finding is closed by "FIXED:" on its line or the lines under it).
#     Every agent writes findings as "- [CRITICAL|HIGH|INFO] ..."; the tags and FIXED: are matched ignoring case.
set -uo pipefail
ID="${1:-}"; [ -n "$ID" ] || { echo "usage: $0 <story-id>"; exit 1; }
D="docs/stories/$ID"; ST="$D/status.md"; PL="$D/plan.md"; FI="$D/findings.md"; IM="$D/impact.md"
[ -f "$ST" ] || { echo "DOD FAIL: $ST not found"; exit 1; }
TMP="${TMPDIR:-/tmp}/dod.$$"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
FAIL=0; bad() { echo "DOD FAIL: $*"; FAIL=1; }

# 1-2. The matrix: id, criterion, evidence, result per row.
tr -d '\r' < "$ST" | awk -F'|' '
  /^##[ \t]+Definition of done/ { on = 1; next }
  on && /^##[ \t]/ { exit }
  on && /^\|/ && NF >= 5 {
    for (i = 2; i <= 5; i++) { gsub(/^[ \t]+|[ \t]+$/, "", $i) }
    if ($2 == "#" || $2 ~ /^-+$/ || $2 ~ /^:?-+:?$/) next
    print $2 "\t" $3 "\t" $4 "\t" $5
  }' > "$TMP/rows.tsv"
[ -s "$TMP/rows.tsv" ] || bad "status.md has no rows under '## Definition of done'"
while IFS=$'\t' read -r id crit ev res; do
  low=$(printf '%s' "$ev" | tr '[:upper:]' '[:lower:]')
  case "$low" in ""|"-"|"n/a"|"na"|"none"|"tbd"|"todo"|assumed*|"covered elsewhere"*) bad "row $id ($crit): no evidence";; esac
  case "$(printf '%s' "$res" | tr '[:upper:]' '[:lower:]')" in pass*) ;; *) bad "row $id ($crit): result is '$res', not pass";; esac
done < "$TMP/rows.tsv"

# 3. Every criterion in the plan has a row. A criterion is a list item that starts with a number or a short
#    label: "1.", "2)", "AC1:", "AC-2.", "R3)", also after a bullet, a checkbox, or bold. Ids are compared
#    ignoring case, dashes, and asterisks, so "AC-1" in the plan matches "ac1" in the matrix.
if [ -f "$PL" ]; then
  tr -d '\r' < "$PL" | awk '
    function startsec(l) { return l ~ /([Aa]cceptance [Cc]riteria|[Ii]mpact-driven)/ && (l ~ /^#/ || l ~ /^[0-9]+\.[ \t]+\*\*/ || l ~ /^\*\*/) }
    function itemid(l,   t, id) {
      t = l
      sub(/^[ \t]*([-*+][ \t]+)?(\[[ xX]\][ \t]+)?\**/, "", t)
      if (match(t, /^[0-9]+\**[.)][ \t]/)) { id = t; sub(/\**[.)].*$/, "", id); return id }
      if (match(t, /^[A-Za-z][A-Za-z]?[A-Za-z]?-?[0-9]+\**[.):]/)) { id = t; sub(/\**[.):].*$/, "", id); gsub(/-/, "", id); return toupper(id) }
      return ""
    }
    startsec($0) { on = 1; next }
    on && (/^#/ || /^[0-9]+\.[ \t]+\*\*/) { on = 0 }
    on { id = itemid($0); if (id != "") print id }
  ' | sort -u > "$TMP/need.txt"
  [ -s "$TMP/need.txt" ] || bad "no acceptance criteria found in $PL (expected list items like '1.' or 'AC1:' under an 'Acceptance criteria' heading)"
  cut -f1 "$TMP/rows.tsv" | tr -d '* -' | tr '[:lower:]' '[:upper:]' | sort -u > "$TMP/have.txt"
  while read -r n; do grep -qxF "$n" "$TMP/have.txt" || bad "acceptance criterion $n has no row in the matrix"; done < "$TMP/need.txt"
else
  bad "$PL not found"
fi

# 4. Every check/change area from impact.md is named in a row.
if [ -f "$IM" ]; then
  # lowercase and use -F alone: GNU grep 3.0 on Git Bash aborts on -i combined with -F
  cut -f2 "$TMP/rows.tsv" | tr '[:upper:]' '[:lower:]' > "$TMP/crit.txt"
  tr -d '\r' < "$IM" | awk -F'|' '/^\|/ && NF >= 6 {
    for (i = 2; i <= 4; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i)
    d = tolower($4); if (d ~ /^(check|change)/ && $2 != "Area") print $2
  }' | while read -r area; do
    grep -qF -- "$(printf '%s' "$area" | tr '[:upper:]' '[:lower:]')" "$TMP/crit.txt" || echo "DOD FAIL: impact area '$area' (check or change) has no row in the matrix"
  done > "$TMP/impact.out"
  if [ -s "$TMP/impact.out" ]; then cat "$TMP/impact.out"; FAIL=1; fi
fi

# 5. Open CRITICAL or HIGH findings.
if [ -f "$FI" ]; then
  # Tags and FIXED: are matched ignoring case, so "[critical]" and "[CRITICAL]" are the same finding.
  tr -d '\r' < "$FI" | awk '
    function flush() { if (open && !fixed) print "DOD FAIL: open finding: " head; open = 0; fixed = 0 }
    { low = tolower($0) }
    low ~ /^[ \t]*-[ \t]*\[(critical|high)\]/ { flush(); open = 1; fixed = 0; head = $0; if (low ~ /fixed:/) fixed = 1; next }
    low ~ /^[ \t]*-[ \t]*\[/ || /^#/ || /^[ \t]*$/ { flush(); next }
    open && low ~ /fixed:/ { fixed = 1 }
    END { flush() }' > "$TMP/find.out"
  if [ -s "$TMP/find.out" ]; then cat "$TMP/find.out"; FAIL=1; fi
fi

if [ "$FAIL" -ne 0 ]; then echo "DOD: story $ID is NOT done"; exit 1; fi
echo "DOD OK: story $ID, $(wc -l < "$TMP/rows.tsv" | tr -d ' ') rows, all with evidence and passing, no open CRITICAL or HIGH"
