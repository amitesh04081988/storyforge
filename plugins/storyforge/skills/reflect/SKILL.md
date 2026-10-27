---
name: reflect
description: "Learn from finished work and improve the process: after a story, or across many stories as a retro, find what went wrong or was slow (fix cycles, blocked phases, test disputes, repeated corrections, recurring bug classes) and turn each durable lesson into a concrete edit to the project's conventions, rules, config, or memory, with user approval. Use for 'reflect', 'retro', 'what can we improve', 'why does it keep failing', 'learn from this', or the reflect phase of build-story."
argument-hint: "[story <id> | retro [--since 14d] | full]"
---

# Reflect

Merged from pstack `reflect` (transcript reviewers, synthesizer, approval gate) and gstack `/retro` (metrics across work); see NOTICE.md. Reflection is different from `remember`: memory records **facts about the project**, while reflect improves **how the work gets done**.

## Modes

| Mode | When | Cost |
|---|---|---|
| `story <id>` | Automatically after each story (`reflect.after_each_story`) | Low: one pass, no subagents |
| `retro` | Every `reflect.retro_every_n_stories` stories, or on request | Medium |
| `full` | On request, after a rough session | High: 3 reviewers + a synthesizer over the transcript |

## Evidence

- **story:** `docs/stories/<id>/status.md` (fix cycles, blocked items, stop-gate blocks), `findings.md` (categories, `TEST-DISPUTE`, `NEEDS-HUMAN`, items that survived 2 cycles), and `plan.md` § Deviations.
- **retro:** all `docs/stories/*/status.md` and `findings.md` files in the window, plus `git log --since=<window> --numstat`. Compute:
  - Stories done vs. blocked, and the average fix cycles.
  - Which phase blocks most, and findings by category (security, race, contract, UI...).
  - Hotspot files that changed in 3 or more stories. Recurring hotspots are an architecture smell.
  - Repeated `LESSONS.md` classes, and tests retired or added.
- **full:** the session transcript. Find it with `node "${CLAUDE_PLUGIN_ROOT}/skills/reflect/scripts/claude-project-dir.mjs"`, then `find-transcript.mjs "<dir>" "<opening prompt fragment>"`. Never read transcripts from other projects. If the transcript can't be found, write a neutral digest instead: prompts, corrections, tool calls, and files touched, with no diagnosis.

## Analyze

- **story and retro:** apply the judgment lens from `references/judgment-reviewer.md` yourself, using the evidence above in place of the transcript.
- **full:** spawn three read-only reviewers in parallel with `references/judgment-reviewer.md`, `references/tooling-reviewer.md`, and `references/divergent-reviewer.md`. Then one synthesizer with `references/synthesizer.md`.

For every finding, apply the synthesizer's criteria: durable, specific, decision-changing, and not already covered. Then apply `principle-encode-lessons-in-structure`. If a lint, test, hook, or config value can enforce a lesson, propose that rather than more prose.

## Route each accepted lesson

| Lesson about… | Edit |
|---|---|
| How code is written here | `.claude/skills/project-conventions/SKILL.md` or a `.claude/rules/*.md` file |
| A recurring bug class | Run the `correct` skill to make it impossible (architecture, then types, then a lint, then a test), recorded in `LESSONS.md` with "Enforced by" |
| Pipeline limits or behavior | `storyforge.config.json` (for example `max_fix_cycles`, `ui`, `docs.level`) |
| Something every session needs | One line in `CLAUDE.md`, only if it truly applies to every session |
| A StoryForge skill or agent itself | `docs/memory/STORYFORGE_FEEDBACK.md`. Plugin files get overwritten on update, so improvements go upstream to your StoryForge repo from there |

## Approval

Show the Accepted / Rejected / Backlog list and **wait for approval** before editing anything. These edits change every future run. In build-story's automatic `story` mode or in headless runs, write the proposals to `docs/stories/<id>/reflect.md` and apply nothing. The user applies them later with `/storyforge:reflect apply <id>`.

## Retro report

For `retro` mode, also write `docs/retro-<date>.md` (60 lines or fewer) with the metrics table, the 3 biggest friction points with evidence, what improved since the last retro, and the proposed edits.
