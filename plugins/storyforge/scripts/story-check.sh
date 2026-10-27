#!/usr/bin/env bash
# Detect other developers' in-flight stories before you start or while you plan.
#   story-check.sh <story-id>                  same story or same slug already on a story/* branch?
#   story-check.sh <story-id> <scope.txt>      does this scope overlap another open story's scope?
# Reads only git (origin/story/* branches). Exit 0 = clear, 3 = conflict (details on stdout).
set -uo pipefail
ID="${1:-}"; SCOPE="${2:-}"
[ -n "$ID" ] || { echo "usage: $0 <story-id> [scope.txt]"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git fetch -q origin 2>/dev/null || echo "note: could not fetch origin; checked local refs only"

BASE=$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
SLUG="${ID#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-}"
CONFLICTS=0

# Other open story branches: skip our own and any already merged into the base branch.
others() {
  git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/story/*' | while read -r ref; do
    oid="${ref#origin/story/}"
    [ "$oid" = "$ID" ] && continue
    git merge-base --is-ancestor "$ref" "$BASE" 2>/dev/null && continue
    echo "$oid"
  done
}
owner_of() {
  git show "origin/story/$1:docs/stories/$1/status.md" 2>/dev/null | sed -n 's/^owner:[[:space:]]*//p' | head -1
}

if [ -z "$SCOPE" ]; then
  if git show-ref -q --verify "refs/remotes/origin/story/$ID"; then
    echo "CLAIMED: story/$ID already exists on origin (owner: $(owner_of "$ID"))."
    CONFLICTS=1
  fi
  for oid in $(others); do
    if [ "${oid#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-}" = "$SLUG" ]; then
      echo "DUPLICATE: story/$oid has the same slug (owner: $(owner_of "$oid"))."
      CONFLICTS=1
    fi
  done
else
  # Normalize a glob to its directory/file prefix: "src/orders/**" -> "src/orders"
  norm() { printf '%s' "$1" | sed -e 's#\*.*$##' -e 's#/$##'; }
  overlaps() { # prefix-match either way; an empty prefix (e.g. "**") overlaps everything
    [ "$1" = "$2" ] || [ -z "$1" ] || [ -z "$2" ] || case "$1/" in "$2"/*) return 0;; esac; case "$2/" in "$1"/*) return 0;; esac; return 1
  }
  while IFS= read -r mine || [ -n "$mine" ]; do
    mine="${mine%$'\r'}"; [ -z "$mine" ] && continue
    case "$mine" in \#*) continue;; esac
    for oid in $(others); do
      git show "origin/story/$oid:docs/stories/$oid/scope.txt" 2>/dev/null | tr -d '\r' | while IFS= read -r theirs; do
        [ -z "$theirs" ] && continue
        case "$theirs" in \#*) continue;; esac
        if overlaps "$(norm "$mine")" "$(norm "$theirs")"; then
          echo "OVERLAP: '$mine' vs '$theirs' in story/$oid (owner: $(owner_of "$oid"))"
        fi
      done
    done
  done < "$SCOPE" | sort -u > "${TMPDIR:-/tmp}/story-check.$$"
  if [ -s "${TMPDIR:-/tmp}/story-check.$$" ]; then cat "${TMPDIR:-/tmp}/story-check.$$"; CONFLICTS=1; fi
  rm -f "${TMPDIR:-/tmp}/story-check.$$"
fi

if [ "$CONFLICTS" -ne 0 ]; then
  echo "Coordinate with the owner, or rebase onto their branch, before continuing."
  exit 3
fi
echo "clear"
