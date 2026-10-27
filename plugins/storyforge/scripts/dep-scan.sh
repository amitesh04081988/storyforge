#!/usr/bin/env bash
# Suggest dependency edges for docs/memory/DEPENDENCIES.md by scanning import-like lines.
#   dep-scan.sh [--map FILE]
# For every pair of areas in the map (using their Paths), prints "A -> B" when a file in A has an
# import/require/use/include line that names B's directory or file. These are CANDIDATES from a text
# heuristic: confirm each against the code, and add runtime links (events, queues, shared tables,
# dynamic imports, HTTP calls) by hand. Run from the repo root.
set -uo pipefail
MAP="${STORYFORGE_DEPS:-docs/memory/DEPENDENCIES.md}"
[ "${1:-}" = "--map" ] && MAP="$2"
[ -f "$MAP" ] || { echo "no dependency map at $MAP"; exit 4; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo"; exit 1; }

TMP="${TMPDIR:-/tmp}/dep-scan.$$"; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT
# area<TAB>first-path-prefix per area (Paths column, globs trimmed to their directory part)
awk -F'|' '/^\|/ && NF >= 8 {
  n=$2; gsub(/^[ \t`]+|[ \t`]+$/,"",n)
  if (n=="" || n=="Area" || n ~ /^-+$/ || n ~ /^[<_]/) next
  p=$4; gsub(/`/,"",p); m=split(p,g,/[ ]*,[ ]*/)
  for (j=1;j<=m;j++) { x=g[j]; gsub(/^[ \t]+|[ \t]+$/,"",x); sub(/\*.*$/,"",x); sub(/\/+$/,"",x); if (x!="") print n "\t" x }
}' "$MAP" > "$TMP/areas.tsv"
[ -s "$TMP/areas.tsv" ] || { echo "no areas with paths in $MAP"; exit 0; }

IMPORT_RE='^[[:space:]]*(import|from|use|using|export|package)[[:space:]]|^[[:space:]]*#include|require[[:space:]]*\(|^[[:space:]]*(const|let|var)[[:space:]].*require'
found=0
for A in $(cut -f1 "$TMP/areas.tsv" | sort -u); do
  : > "$TMP/imports.txt"
  for dir in $(awk -F'\t' -v a="$A" '$1==a{print $2}' "$TMP/areas.tsv"); do
    git ls-files -z -- "$dir" 2>/dev/null | xargs -0 grep -nHE "$IMPORT_RE" 2>/dev/null >> "$TMP/imports.txt"
  done
  [ -s "$TMP/imports.txt" ] || continue
  for B in $(cut -f1 "$TMP/areas.tsv" | sort -u); do
    [ "$A" = "$B" ] && continue
    hits=0; first=""
    for bp in $(awk -F'\t' -v b="$B" '$1==b{print $2}' "$TMP/areas.tsv"); do
      key=$(basename "$bp"); key="${key%.*}"
      [ -z "$key" ] && continue
      # key as a whole path segment or dotted/dashed name part inside the import line
      M=$(grep -E "[/\\\\.\"'@:-]${key}([/\\\\.\"';:-]|[[:space:]]|\$)|(from|import|use|using)[[:space:]]+${key}([^[:alnum:]_]|\$)" "$TMP/imports.txt" 2>/dev/null)
      c=$(printf '%s\n' "$M" | grep -c .)
      if [ "$c" -gt 0 ]; then hits=$((hits + c)); [ -z "$first" ] && first=$(printf '%s\n' "$M" | head -1 | cut -d: -f1,2); fi
    done
    if [ "$hits" -gt 0 ]; then echo "$A -> $B  ($hits import lines, e.g. $first)"; found=1; fi
  done
done
[ "$found" -eq 1 ] || echo "no candidate edges found"
