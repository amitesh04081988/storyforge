#!/usr/bin/env bash
# The task ledger for bits-mode's manager loop: .storyforge/tasks.tsv (run state, gitignored).
#   bits-tasks.sh add "<title>" [--deps 1,2] [--mode light|full|direct]   prints the new id
#   bits-tasks.sh next                  ids that are todo with every dependency done (one per line)
#   bits-tasks.sh set <id> <todo|doing|verifying|done|blocked> ["note"]
#   bits-tasks.sh pr <id> <number> <head-sha> <verdict> <builder> <verifier>   record a PR, what was verified at that head, and by whom
#   bits-tasks.sh mergeable <id> <current-head-sha>       exit 0 only if the verdict covers that exact head
#   bits-tasks.sh show                  the ledger
#   bits-tasks.sh status                counts; exit 0 only when every task is done
# Columns: id, status, mode, deps, title, note, pr, sha, verdict, builder, verifier.
# builder and verifier name who wrote the change and who checked it (a model, an agent, or "manager"). They must differ.
# Verdicts that allow a merge: live-ui-verified, unit-test-verified. Anything else (type-check-only, verifier-blocked, verifier-failed) does not.
set -uo pipefail
F="${STORYFORGE_TASKS:-.storyforge/tasks.tsv}"
CMD="${1:-}"; shift || true
mkdir -p "$(dirname "$F")"; touch "$F"
clean() { printf '%s' "$1" | tr '\t\r\n' '   '; }

case "$CMD" in
  add)
    title=$(clean "${1:-}"); [ -n "$title" ] || { echo "usage: $0 add \"<title>\" [--deps 1,2] [--mode light|full|direct]"; exit 1; }
    shift; deps="-"; mode="full"
    while [ $# -gt 0 ]; do
      case "$1" in
        --deps) deps="${2:--}"; shift 2;;
        --mode) mode="${2:-full}"; shift 2;;
        *) echo "unknown option: $1"; exit 1;;
      esac
    done
    case "$mode" in light|full|direct) ;; *) echo "mode must be light, full, or direct"; exit 1;; esac
    id=$(( $(awk -F'\t' 'END { print NR }' "$F") + 1 ))
    printf '%s\ttodo\t%s\t%s\t%s\t-\t-\t-\t-\t-\t-\n' "$id" "$mode" "$deps" "$title" >> "$F"
    echo "$id" ;;
  next)
    awk -F'\t' '
      { st[$1] = $2; dep[$1] = $4; order[++n] = $1 }
      END {
        for (i = 1; i <= n; i++) {
          id = order[i]; if (st[id] != "todo") continue
          ok = 1; m = split(dep[id], d, ",")
          for (j = 1; j <= m; j++) if (d[j] != "-" && d[j] != "" && st[d[j]] != "done") ok = 0
          if (ok) print id
        }
      }' "$F" ;;
  set)
    id="${1:-}"; st="${2:-}"; note=$(clean "${3:--}")
    case "$st" in todo|doing|verifying|done|blocked) ;; *) echo "usage: $0 set <id> <todo|doing|verifying|done|blocked> [note]"; exit 1;; esac
    grep -q "^$id	" "$F" || { echo "no task $id"; exit 1; }
    awk -F'\t' -v OFS='\t' -v id="$id" -v st="$st" -v note="$note" '$1 == id { $2 = st; $6 = note } { print }' "$F" > "$F.tmp" && mv "$F.tmp" "$F" ;;
  pr)
    id="${1:-}"; num="${2:-}"; sha="${3:-}"; verdict="${4:-}"; builder=$(clean "${5:-}"); verifier=$(clean "${6:-}")
    [ -n "$id" ] && [ -n "$num" ] && [ -n "$sha" ] && [ -n "$verdict" ] && [ -n "$builder" ] && [ -n "$verifier" ] || { echo "usage: $0 pr <id> <number> <head-sha> <verdict> <builder> <verifier>"; exit 1; }
    grep -q "^$id	" "$F" || { echo "no task $id"; exit 1; }
    awk -F'	' -v OFS='	' -v id="$id" -v n="$num" -v sha="$sha" -v v="$verdict" -v b="$builder" -v w="$verifier" '$1 == id { $7 = n; $8 = sha; $9 = v; $10 = b; $11 = w } { print }' "$F" > "$F.tmp" && mv "$F.tmp" "$F" ;;
  mergeable)
    id="${1:-}"; cur="${2:-}"
    [ -n "$id" ] && [ -n "$cur" ] || { echo "usage: $0 mergeable <id> <current-head-sha>"; exit 1; }
    row=$(awk -F'	' -v id="$id" '$1 == id' "$F"); [ -n "$row" ] || { echo "NOT MERGEABLE: no task $id"; exit 1; }
    sha=$(printf '%s' "$row" | cut -f8); verdict=$(printf '%s' "$row" | cut -f9)
    case "$verdict" in live-ui-verified|unit-test-verified) ;; *) echo "NOT MERGEABLE: task $id verdict is '$verdict'"; exit 1;; esac
    [ "$sha" = "$cur" ] || { echo "NOT MERGEABLE: task $id was verified at $sha but the PR head is $cur; re-verify"; exit 1; }
    builder=$(printf '%s' "$row" | cut -f10); verifier=$(printf '%s' "$row" | cut -f11)
    { [ -n "$builder" ] && [ "$builder" != "-" ] && [ -n "$verifier" ] && [ "$verifier" != "-" ]; } || { echo "NOT MERGEABLE: task $id has no builder and verifier recorded"; exit 1; }
    [ "$builder" != "$verifier" ] || { echo "NOT MERGEABLE: task $id was verified by '$verifier', the same as the builder; use a different model or the manager's own run"; exit 1; }
    echo "mergeable: task $id verified at $sha ($verdict) by $verifier, built by $builder" ;;
  show) column -t -s "$(printf '\t')" "$F" 2>/dev/null || cat "$F" ;;
  status)
    awk -F'\t' '{ c[$2]++; n++ }
      END { printf "tasks: %d  todo: %d  doing: %d  verifying: %d  blocked: %d  done: %d\n", n, c["todo"], c["doing"], c["verifying"], c["blocked"], c["done"]; exit (n > 0 && c["done"] == n) ? 0 : 1 }' "$F" ;;
  *) echo "usage: $0 add | next | set | pr | mergeable | show | status"; exit 1;;
esac
