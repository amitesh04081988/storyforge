#!/usr/bin/env bash
# Scaffold StoryForge files into the current repo without overwriting anything.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$HERE/skills/init-project/templates"
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$ROOT"
cp_new() { if [ -e "$2" ]; then echo "keep   $2"; else mkdir -p "$(dirname "$2")"; cp "$1" "$2"; echo "create $2"; fi; }
cp_new "$T/storyforge.config.json" storyforge.config.json
for f in INDEX ARCHITECTURE DEPENDENCIES DECISIONS LESSONS; do cp_new "$T/memory/$f.md" "docs/memory/$f.md"; done
cp_new "$T/memory/integrations/_TEMPLATE.md" docs/memory/integrations/_TEMPLATE.md
mkdir -p docs/stories docs/features .storyforge
grep -qxF '.storyforge/' .gitignore 2>/dev/null || { echo '.storyforge/' >> .gitignore; echo "update .gitignore"; }
if ! grep -q '^## StoryForge' CLAUDE.md 2>/dev/null; then cat "$T/CLAUDE.snippet.md" >> CLAUDE.md; echo "update CLAUDE.md"; fi
echo "StoryForge scaffold ready. Now fill storyforge.config.json with your real commands."
