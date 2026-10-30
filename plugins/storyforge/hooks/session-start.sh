#!/usr/bin/env bash
# SessionStart: inject the small memory index (not the whole memory) plus any
# in-progress story, so every new chat starts with project context cheaply.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
cat >/dev/null
IDX="$SF_PROJECT/docs/memory/INDEX.md"
if [ -f "$SF_CONFIG" ] && sf_state_tracked; then echo "StoryForge WARNING: $SF_UNTRUSTED_MSG"; fi
[ -f "$SF_CONFIG" ] && sf_find_python
if [ -z "$SF_PY" ] && [ -f "$SF_CONFIG" ]; then
  echo "StoryForge WARNING: $SF_NO_PY_MSG"
fi
if [ ! -f "$SF_CONFIG" ]; then
  echo "StoryForge: this repo is not set up yet. Run /storyforge:init-project (it also scaffolds brand-new projects)."
fi
if [ -f "$IDX" ]; then
  echo "## StoryForge project memory (index only; open files in docs/memory/ when relevant)"
  head -n 80 "$IDX"
fi
if [ -f "$SF_CONFIG" ]; then
  BLANK=""
  for K in test lint typecheck; do [ -z "$(sf_cfg "$K")" ] && BLANK="$BLANK $K"; done
  [ -n "$BLANK" ] && echo "StoryForge WARNING: blank in storyforge.config.json:$BLANK. The gate skips a blank command, so nothing checks it. Set the real command."
fi
PHASE=$(sf_phase); STORY=$(cat "$SF_STATE/story" 2>/dev/null || true)
if [ -n "$STORY" ] && [ -n "$PHASE" ] && [ "$PHASE" != done ]; then
  echo
  echo "## In-progress story: $STORY (phase: $PHASE). Resume with /storyforge:build-story --resume $STORY"
  [ -f "$SF_PROJECT/docs/stories/$STORY/status.md" ] && grep -E '^\s*-\s*\[|fix_cycles|^## Blocked' "$SF_PROJECT/docs/stories/$STORY/status.md" | head -20
fi
if [ -s "$SF_PROJECT/.storyforge/tasks.tsv" ] && [ ! -f "$SF_PROJECT/.storyforge/tasks.sqlite" ]; then
  echo "StoryForge WARNING: legacy tasks.tsv detected; back up and migrate with bits-tasks.sh migrate-legacy before resuming."
fi
TASKS="$SF_PROJECT/.storyforge/tasks.sqlite"
if [ -f "$TASKS" ] && ! STORYFORGE_DB="$TASKS" bash "$(dirname "$0")/../scripts/bits-tasks.sh" status >/dev/null 2>&1; then
  echo
  echo "## Unfinished bits-mode tasks. Continue with /storyforge:bits-mode resume"
  STORYFORGE_DB="$TASKS" bash "$(dirname "$0")/../scripts/bits-tasks.sh" status
fi
exit 0
