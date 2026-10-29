#!/usr/bin/env bash
# Headless StoryForge runner (the "loop" outside a chat).
#   run-story.sh "As a user I can export my orders to CSV"
#   run-story.sh -f stories/csv-export.md
#   run-story.sh --resume 20261024-csv-export
#   run-story.sh --queue stories.txt        # one story per line; stops at the first that needs a human
# Extra claude flags: STORYFORGE_CLAUDE_FLAGS (default: --permission-mode acceptEdits)
# Unattended runs also need Bash allow rules in .claude/settings.json for your test/lint/git commands.
# Start from skills/init-project/templates/claude/settings.headless.json: it allows the project's test commands, local git,
# and the plugin scripts, and denies push, reset, rebase, curl, and installs. Adjust the test commands to your stack.
set -uo pipefail
FLAGS=${STORYFORGE_CLAUDE_FLAGS:---permission-mode acceptEdits}
MAX_TURNS=${STORYFORGE_MAX_TURNS:-200}
command -v claude >/dev/null || { echo "claude CLI not found"; exit 1; }
[ -f storyforge.config.json ] || { echo "No storyforge.config.json. Run /storyforge:init-project interactively first (setup needs your answers)."; exit 1; }

run_one() {
  local arg="$1"
  echo "▶ storyforge: $arg"
  # shellcheck disable=SC2086
  STORYFORGE_HEADLESS=1 STORYFORGE_QUEUE=${STORYFORGE_QUEUE:-0} claude -p "/storyforge:build-story $arg" --max-turns "$MAX_TURNS" $FLAGS
  local id; id=$(cat .storyforge/story 2>/dev/null || true)
  local st="docs/stories/$id/status.md"
  if [ -n "$id" ] && [ -f "$st" ] && grep -qiE 'needs-approval|^## Blocked' "$st"; then
    echo "⏸  $id needs a human — see $st"; return 2
  fi
  [ "$(cat .storyforge/phase 2>/dev/null)" = done ] && echo "✔ $id done" || { echo "⚠ $id did not reach done — resume with: $0 --resume $id"; return 1; }
}

case "${1:-}" in
  -f) run_one "$2" ;;
  --resume) run_one "--resume $2" ;;
  --queue) export STORYFORGE_QUEUE=1; while IFS= read -r line || [ -n "$line" ]; do
             [ -z "$line" ] || [ "${line#\#}" != "$line" ] && continue
             run_one "$line" || { echo "queue stopped"; exit 1; }
           done < "$2" ;;
  "") echo "usage: $0 \"story\" | -f file | --resume id | --queue file"; exit 1 ;;
  *) run_one "$*" ;;
esac
