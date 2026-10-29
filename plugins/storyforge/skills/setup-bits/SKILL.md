---
name: setup-bits
description: "Configure which models bits-mode and its skills use per role. Writes ~/.claude/bits-models.md. Use for /storyforge:setup-bits, 'configure bits models', or changing the model for arena, swarm, architect, how, why, or review roles."
---

# Setup bits

The override sheet is `~/.claude/bits-models.md`. Each line is `role: model` (or a comma-separated panel). Delete a line to fall back to the skill's default.

1. If `~/.claude/bits-models.md` exists, show it. Otherwise, if `~/.claude/pstack-models.md` exists, offer to copy it, since the format is the same.
2. Ask which roles to change. Roles: `feature, refactoring`, `bug-fix`, `perf-issue`, `hillclimb`, `judgment and prose`, `strongest judgment`, `how explorer`, `how explainer`, `why investigators`, `why synthesizer`, `arena runners`, `arena cross-judge pool`, `architect runners`, `swarm workers`, `interrogate reviewers`. Models are the aliases `Agent` accepts (`opus`, `sonnet`, `haiku`, `fable`) or `inherit-parent`.
3. Write the file, one role per line, plus an optional `default effort: session|low|medium|high|xhigh|max` line. A model may carry an effort: `opus @xhigh`.
4. Print the file back and stop. Do not change any project file.

Example:

```
feature, refactoring: sonnet
bug-fix: opus
arena runners: opus, fable, sonnet, haiku
swarm workers: opus
default effort: session
```
