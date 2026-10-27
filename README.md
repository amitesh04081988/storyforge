# StoryForge

A Claude Code plugin that takes a user story through the whole delivery loop and remembers what it learned:

```
setup:  empty repo → interview → stack options → scaffold      existing repo → detect stack → confirm → conventions skill
story:  recall → product review → plan + scope (approve) → failing tests → implement → review (1..N models) + security
        → break it → fix loop ⟲ → integration tests → Playwright UI tests → verify → feature docs (UML)
        → update memory → reflect → commit → ship PR + babysit CI (optional)
```

It's built on ideas and files from [gstack](https://github.com/garrytan/gstack) and [pstack-claude](https://github.com/michael-denyer/pstack-claude). The best parts of each were reused as-is; see `NOTICE.md`.

## Install

Push this folder to GitHub, then run this in Claude Code:

```
/plugin marketplace add <you>/storyforge
/plugin install storyforge@storyforge
```

You can also install from a local path: `/plugin marketplace add /path/to/storyforge`.

Then run this once in each project:

```
/storyforge:init-project
```

What it does depends on the repo:

- **Empty repo** (or only a README or requirements doc): it interviews you in short rounds about what you're building, your team, hosting, data, and auth. Then it recommends 2–3 stacks with tradeoffs and lets you choose. It asks your setup preferences against a list of sensible defaults, scaffolds the project with official generators, and checks that it builds and the tests pass before committing.
- **Existing repo:** it reads manifests, CI, and representative files to detect the stack. It confirms the result with you and asks only what code can't show (deploy target, test environments, test logins, team rules).

Both paths end the same way. It writes `storyforge.config.json` and generates a project-specific `.claude/skills/project-conventions` skill plus path-scoped `.claude/rules/`. It sets up Playwright and its MCP server for web UIs, seeds `docs/memory/`, and writes `docs/architecture.md`, `docs/data-model.md`, and `docs/ONBOARDING.md`. Fill in the `?` gaps it leaves; that's the knowledge only you have.

It doesn't generate new agents per stack, because the roles are the same for every stack. The project-specific knowledge goes in the conventions skill, which every agent reads.

## Use

**Interactive:**
```
/storyforge:build-story As a customer I can export my orders as CSV, filtered by date range
/storyforge:build-story --resume 20261024-csv-export
```

**Headless (the loop runs outside a chat):**
```
plugins/storyforge/scripts/run-story.sh "As a customer I can export…"
plugins/storyforge/scripts/run-story.sh --queue stories.txt   # one per line; stops at the first that needs you
```
For unattended runs, add Bash allow rules for your test, lint, and git commands in `.claude/settings.json`. Only use `--dangerously-skip-permissions` inside a disposable container.

## How it stays on track

| Mechanism | What it does |
|---|---|
| **Subagents** (`agents/`) | Planner, test-writer, developer, reviewer, security-reviewer, breaker, integration-tester, memory-keeper. Each runs in its own context, and reviewers can't edit code. |
| **Edit guard** (`hooks/edit-guard.sh`) | During `develop` and `fix`, it blocks test-file edits, so code can't pass by changing its tests. It also blocks edits outside the planned `scope.txt` (`scope_lock`). |
| **Stop gate** (`hooks/stop-gate.sh`) | Won't let the session finish while tests fail in the build phases. Capped by `max_stop_blocks` so it can't loop forever. |
| **Fix-loop limits** | `max_fix_cycles`. The run stops and asks you if the same finding survives 2 cycles or a fix needs a product decision. |
| **Destructive-command guard** | gstack's `careful` hook asks before `rm -rf`, `DROP TABLE`, a force-push, and similar commands. |
| **UI tests** (`ui-tester`) | Committed Playwright specs per acceptance criterion across desktop and mobile, with visual snapshots, axe accessibility checks, and console-error checks. Then a short exploratory pass with the Playwright MCP. Runs only when a story touches UI. |
| **Feature docs** (`doc-writer`) | `docs/features/<feature>.md` with Mermaid sequence, state, and ER diagrams, written from the built code. Architecture and onboarding docs are updated when the system's shape changes. `docs.level`: `light` or `full`. |
| **Product review** | Challenges the premise, finds existing code to reuse, picks a scope mode, and compares minimal, ideal, and lateral approaches before planning (`product_review`: `auto`, `always`, or `off`). |
| **Multi-model review** | Set `review.models` to e.g. `["opus","sonnet"]`: one reviewer per model, merged with lead judgment. It's used automatically for auth, payments, data, and concurrency stories. |
| **Test value bar** | Every new test must name the regression it catches and why existing coverage misses it. `/storyforge:test-audit` prunes low-value tests. |
| **Reflect** | After each story it proposes process improvements (conventions, rules, config, lesson enforcement) and applies them only when you approve. `/storyforge:reflect retro` gives metrics across stories. |
| **Ship** (`ship.mode`) | `commit` (default), `pr`, or `pr-babysit`: sync and re-test, bisectable commits, changelog, a reviewer-friendly PR, then fix CI and handle review comments, up to 3 rounds. |
| **Plan approval** | `require_plan_approval`. It also always asks for auth, payments, data deletion, and migrations. |

## How memory works (and saves tokens)

```
docs/memory/INDEX.md          ← only this loads at session start (≤ 80 lines, via hook)
docs/memory/ARCHITECTURE.md   ← opened when needed
docs/memory/DECISIONS.md      ← D-### records, append-only
docs/memory/LESSONS.md        ← L-### bug classes + what enforces them
docs/memory/integrations/*.md ← one per service: contract, auth, quirks, tests, history
docs/stories/<id>/            ← story, plan, findings, status, summary per run
docs/features/, ONBOARDING.md ← human docs; never auto-loaded, so they cost no tokens
```

At the start of a story, `memory-keeper` writes a slice of 80 lines or fewer (`context.md`) with only what's relevant. At the end, it files what was actually built and tested. The integration tester re-runs the tests of *other* integrations that share code with the change, which is how past integrations stay working. It's all in git, so it's reviewable and shared with your team.

## Skills included

| Skill | Source |
|---|---|
| build-story, new-project, init-project, ui-test, feature-docs, remember, break-it, security-review | StoryForge (the security and QA taxonomy checklists are from gstack) |
| review | StoryForge, using gstack's checklist and specialists plus pstack's interrogate for multi-model mode |
| ship | merged: gstack ship + pstack fix-ci, get-pr-comments, babysit, make-pr-easy-to-review |
| product-review | merged: gstack office-hours + plan-ceo-review |
| reflect | merged: pstack reflect + gstack retro |
| investigate, test-audit | adapted from gstack |
| tdd, blast-radius, thermo-nuclear-review, correct, 11 × principle-* | pstack |

## Configuration (`storyforge.config.json`)

`base_branch`, `test`, `integration_test`, `e2e_test`, `lint`, `typecheck`, `format`, `test_globs`, `ui` (`enabled`, `start_command`, `base_url`, `viewports`, `visual_snapshots`, `accessibility`), `docs.level`, `product_review`, `review.models`, `scope_lock`, `reflect` (`after_each_story`, `retro_every_n_stories`), `ship` (`mode`, `auto_merge`), `require_plan_approval`, `max_fix_cycles`, `max_stop_blocks`.

## Requirements

Claude Code, git, bash, and python3 (used by the hooks to parse JSON). Node.js for Playwright and for the transcript finder in `reflect full`. The `gh` CLI for the ship stage.
