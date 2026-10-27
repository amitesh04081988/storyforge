#!/usr/bin/env bash
# SessionStart: inject the small memory index (not the whole memory) plus any
# in-progress story, so every new chat starts with project context cheaply.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
cat >/dev/null
IDX="$SF_PROJECT/docs/memory/INDEX.md"
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
PHASE=$(sf_phase); STORY=$(cat "$SF_STATE/story" 2>/dev/null || true)
if [ -n "$STORY" ] && [ -n "$PHASE" ] && [ "$PHASE" != done ]; then
  echo
  echo "## In-progress story: $STORY (phase: $PHASE). Resume with /storyforge:build-story --resume $STORY"
  [ -f "$SF_PROJECT/docs/stories/$STORY/status.md" ] && grep -E '^\s*-\s*\[|fix_cycles|^## Blocked' "$SF_PROJECT/docs/stories/$STORY/status.md" | head -20
fi
exit 0
