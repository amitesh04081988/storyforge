#!/usr/bin/env bash
# Read the feature map (docs/memory/FEATURES.md).
#   feature-map.sh list                  every feature with status and entry points
#   feature-map.sh find <word|path>...   features whose name, entry, or paths match
#   feature-map.sh check                 rows with no paths, paths matching no file, missing docs; unowned source dirs
# Exit 0 on success, 1 when check finds problems, 4 when there is no map yet.
set -uo pipefail
MAP="${STORYFORGE_FEATURES:-docs/memory/FEATURES.md}"
CMD="${1:-}"; shift || true
[ -f "$MAP" ] || { echo "no feature map at $MAP (run /storyforge:init-project, or copy the template from the plugin)"; exit 4; }

rows() {
  tr -d '\r' < "$MAP" | awk -F'|' '/^\|/ && NF >= 10 {
    for (i = 2; i <= 9; i++) gsub(/^[ \t`]+|[ \t`]+$/, "", $i)
    if ($2 == "Feature" || $2 ~ /^:?-+:?$/ || $2 ~ /^[<_]/ || $2 == "") next
    print $2 "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9
  }'
}

case "$CMD" in
  list) rows | awk -F'\t' '{ printf "%-28s %-11s %s\n", $1, $5, $2 }' ;;
  find)
    [ $# -gt 0 ] || { echo "usage: $0 find <word|path>..."; exit 1; }
    for q in "$@"; do
      rows | awk -F'\t' -v q="$q" 'BEGIN { q = tolower(q) }
        { hay = tolower($1 " " $2 " " $3) }
        index(hay, q) { printf "%s [%s]\n  entry: %s\n  paths: %s\n  area: %s  doc: %s\n  tests: %s\n  stories: %s\n", $1, $5, $2, $3, $4, $6, $7, $8; hit = 1 }
        END { if (!hit) printf "no feature matches \"%s\" (new feature? add a row when the story ships)\n", q }'
    done ;;
  check)
    bad=0
    while IFS=$'\t' read -r name entry paths area status doc tests stories; do
      case "$paths" in ""|"-") echo "NO-PATHS  $name"; bad=1; continue;; esac
      found=0
      IFS=',' read -ra gs <<< "$paths"
      for g in "${gs[@]}"; do g=$(printf '%s' "$g" | sed 's/^ *//;s/ *$//'); [ -n "$(compgen -G "$g" | head -1)" ] && found=1; done
      [ "$found" = 1 ] || { echo "STALE     $name: no file matches $paths"; bad=1; }
      case "$doc" in ""|"-") ;; *) [ -f "$doc" ] || { echo "NO-DOC    $name: $doc missing"; bad=1; };; esac
    done < <(rows)
    exit $bad ;;
  *) echo "usage: $0 list | find <word|path>... | check"; exit 1 ;;
esac
