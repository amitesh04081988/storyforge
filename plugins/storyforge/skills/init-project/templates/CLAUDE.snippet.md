
## StoryForge
- Build features with `/storyforge:build-story <story>`; resume with `--resume <id>`.
- Project memory lives in `docs/memory/`. `INDEX.md` loads at session start; open other files only when relevant.
- Before touching an external service, read `docs/memory/integrations/<name>.md`.
- Commands and limits are in `storyforge.config.json`.
- Never weaken, skip, or delete a test to make a build pass.
