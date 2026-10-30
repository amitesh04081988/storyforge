#!/usr/bin/env bash
# One git worktree per task, so several stories run at once without sharing .storyforge/ state or a branch.
# The worktree sits on a holding branch wt/<id>; build-story (STORYFORGE_QUEUE=1) then creates story/<its-id> from it.
#   worktree.sh add <story-id> [base-branch]   create <repo>.worktrees/<id> on branch wt/<id>; prints the path
#   worktree.sh list                           task worktrees and their branches
#   worktree.sh remove <story-id>              remove it; refuses if it has uncommitted changes
# Run from the main checkout. Exit 0 on success, 1 on a refusal.
set -uo pipefail
CMD="${1:-}"; shift || true
TOP=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not in a git repo"; exit 1; }
ROOT="$TOP.worktrees"
[ ! -L "$ROOT" ] || { echo "refused symlink worktree root"; exit 1; }
valid_id() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$ ]] && [[ "$1" != *".."* ]]; }

case "$CMD" in
  add)
    id="${1:-}"; valid_id "$id" || { echo "invalid worktree id (only letters, numbers, dot, underscore, hyphen)"; exit 1; }
    base="${2:-$(sed -n 's/.*"base_branch"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TOP/storyforge.config.json" 2>/dev/null | head -1)}"
    base="${base:-main}"
    path="$ROOT/$id"
    [ ! -L "$path" ] || { echo "refused symlink worktree path"; exit 1; }
    if [ -d "$path" ]; then echo "$path"; exit 0; fi
    mkdir -p "$ROOT"
    if git show-ref --verify --quiet "refs/heads/wt/$id"; then
      git worktree add "$path" "wt/$id" >/dev/null 2>&1 || { echo "cannot add worktree for existing branch wt/$id"; exit 1; }
    else
      git worktree add -b "wt/$id" "$path" "$base" >/dev/null 2>&1 || { echo "cannot create wt/$id from $base"; exit 1; }
    fi
    echo "$path" ;;
  list) git worktree list --porcelain | awk '/^worktree /{p=$2} /^branch refs\/heads\/wt\//{sub("refs/heads/","",$2); print $2 "\t" p}' ;;
  remove)
    id="${1:-}"; valid_id "$id" || { echo "invalid worktree id"; exit 1; }
    path="$ROOT/$id"; [ ! -L "$path" ] || { echo "refused symlink worktree path"; exit 1; }; [ -d "$path" ] || { echo "no worktree at $path"; exit 1; }
    [ -z "$(git -C "$path" status --porcelain)" ] || { echo "REFUSED: $path has uncommitted changes"; exit 1; }
    git worktree remove "$path" && echo "removed $path (branch wt/$id kept)" ;;
  *) echo "usage: $0 add <id> [base] | list | remove <id>"; exit 1 ;;
esac
