#!/usr/bin/env bash
# Look up what a change touches in the dependency map (docs/memory/DEPENDENCIES.md).
#   impact.sh [--depth N] [--map FILE] <path|glob>...
#   impact.sh [--depth N] --scope docs/stories/<id>/scope.txt
# Prints the areas that own the changed paths (DIRECT), every area that depends on them,
# directly or through other areas, up to N hops (AFFECTED), and paths no area owns (UNMAPPED).
# Exit 0 on success, 4 when there is no map yet.
set -uo pipefail
MAP="${STORYFORGE_DEPS:-docs/memory/DEPENDENCIES.md}"
DEPTH=3
INPUTS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --depth) DEPTH="$2"; shift 2;;
    --map) MAP="$2"; shift 2;;
    --scope) shift
             [ -f "$1" ] || { echo "no such scope file: $1"; exit 1; }
             INPUTS="$INPUTS
$(tr -d '\r' < "$1" | grep -vE '^[[:space:]]*(#|$)')"; shift;;
    *) INPUTS="$INPUTS
$1"; shift;;
  esac
done
[ -f "$MAP" ] || { echo "no dependency map at $MAP (run /storyforge:init-project, or copy the template from the plugin)"; exit 4; }
[ -n "$(printf '%s' "$INPUTS" | tr -d '[:space:]')" ] || { echo "usage: $0 [--depth N] <path|glob>... | --scope scope.txt"; exit 1; }

printf '%s\n' "$INPUTS" | grep -v '^$' | tr -d '\r' > "${TMPDIR:-/tmp}/impact-in.$$"
awk -v depth="$DEPTH" -v inputs="${TMPDIR:-/tmp}/impact-in.$$" '
function trim(s) { gsub(/^[ \t`]+|[ \t`]+$/, "", s); return s }
function norm(g) { sub(/\*.*$/, "", g); sub(/\/+$/, "", g); return g }
function hit(p, g,   a, b) {            # does path/glob p fall under, or contain, area glob g?
  a = norm(p); b = norm(g)
  if (a == "" || b == "") return 0
  return (a == b || index(a "/", b "/") == 1 || index(b "/", a "/") == 1)
}
BEGIN { FS = "|" }
FILENAME != inputs && /^\|/ {
  if (NF < 8) next
  name = trim($2)
  if (name == "" || name == "Area" || name ~ /^-+$/ || name ~ /^[<_]/) next
  n++; area[n] = name; kind[n] = trim($3); paths[n] = trim($4); deps[n] = trim($5); tests[n] = trim($6)
  idx[name] = n
}
END {
  # reverse edges: users[d] lists the areas that depend on d
  for (i = 1; i <= n; i++) {
    m = split(deps[i], d, /[ ]*,[ ]*/)
    for (j = 1; j <= m; j++) { dn = trim(d[j]); if (dn != "" && dn != "-") users[dn] = users[dn] "," area[i] }
  }
  nin = 0
  while ((getline line < inputs) > 0) { if (line != "") in_[++nin] = line }
  for (k = 1; k <= nin; k++) {
    found = 0
    for (i = 1; i <= n; i++) {
      m = split(paths[i], g, /[ ]*,[ ]*/)
      for (j = 1; j <= m; j++) if (hit(in_[k], trim(g[j]))) { if (!(area[i] in direct)) { direct[area[i]] = 1; order[++no] = area[i]; lvl[area[i]] = 0 } found = 1; break }
    }
    if (!found) unmapped[++nu] = in_[k]
  }
  # breadth-first walk over reverse edges
  head = 1; tail = no
  for (q = 1; q <= no; q++) queue[q] = order[q]
  while (head <= tail) {
    cur = queue[head++]
    if (lvl[cur] >= depth) continue
    m = split(users[cur], u, ",")
    for (j = 1; j <= m; j++) {
      un = u[j]; if (un == "" || (un in lvl)) continue
      lvl[un] = lvl[cur] + 1; via[un] = cur; queue[++tail] = un
    }
  }
  printf "Dependency map: %d areas. Changed paths: %d. Depth: %d\n", n, nin, depth
  for (q = 1; q <= tail; q++) {
    a = queue[q]; i = idx[a]
    if (lvl[a] == 0) printf "DIRECT   %s (%s)  paths: %s  tests: %s\n", a, kind[i], paths[i], tests[i]
  }
  any = 0
  for (q = 1; q <= tail; q++) {
    a = queue[q]; i = idx[a]
    if (lvl[a] > 0) { any = 1; printf "AFFECTED hop %d  %s (%s)  via %s  paths: %s  tests: %s\n", lvl[a], a, kind[i], via[a], paths[i], tests[i] }
  }
  if (!any) print "AFFECTED none"
  for (k = 1; k <= nu; k++) printf "UNMAPPED %s  (no area owns this path; add it to the map)\n", unmapped[k]
}' "$MAP" "${TMPDIR:-/tmp}/impact-in.$$"
rc=$?
rm -f "${TMPDIR:-/tmp}/impact-in.$$"
exit $rc
