---
name: build-story
description: "Run the full StoryForge pipeline for a user story: recall project memory, product review, plan, write failing tests, implement, code review (optionally multi-model), security review, adversarial 'break it' testing, fix loop, integration tests, Playwright UI tests, verification, feature docs with UML diagrams, memory update, reflection, commit, and optionally ship a PR and babysit CI. Use whenever the user gives a story, feature description, ticket, or says 'build this', 'implement this story', '/build-story', or asks to resume a story run with --resume <id>."
argument-hint: "<story text | path/to/story.md> | --resume <story-id>"
---

# Build Story

You are the **orchestrator**. You run in the main session and delegate each phase to a subagent from this plugin. You never write production code yourself. You keep the main context small: subagents read and write files under `docs/stories/<id>/`, and they hand back summaries of 10 lines or fewer. Never paste a full file, diff, or log into this session when a path will do.

## 0. Setup

1. Read `storyforge.config.json` at the repo root. If it's missing, run the `init-project` skill first; for an empty repo it sets up the whole project. Then come back to this story. In headless runs, stop with status `needs-init` instead, because setup needs the user's answers.
2. **New story:** derive `<id>` as `YYYYMMDD-<short-kebab-slug>`. Create `docs/stories/<id>/story.md` with the story text verbatim. Create a branch `story/<id>` from `base_branch`, or from the current HEAD when `STORYFORGE_QUEUE=1` so queued stories build on each other. If the working tree is dirty, stop and ask.
   **Resume** (`--resume <id>`): read `docs/stories/<id>/status.md` and continue from the first phase not marked `done`. Use the cycle count recorded there.
3. Set the phase lock and initialize status:
   ```bash
   mkdir -p .storyforge && echo "<id>" > .storyforge/story && echo "recall" > .storyforge/phase && echo 0 > .storyforge/stop-blocks && rm -f .storyforge/ui-ran .storyforge/allow-*
   ```
   `status.md` is a checklist of the phases below, plus `fix_cycles: 0`. Update it after every phase. It is what makes a run resumable.

The hooks read `.storyforge/phase`. Set it with `echo <phase> > .storyforge/phase` at the start of every phase. This matters for three reasons:
- During `develop` and `fix`, the edit guard blocks test-file edits.
- During `develop` and `fix`, it also blocks edits outside `scope.txt`.
- The Stop gate runs the tests during `develop`, `fix`, `integrate`, `ui`, and `verify`.

## Phases

| # | Phase | Agent / skill | Writes | Done when |
|---|-------|---------------|--------|-----------|
| 1 | recall | `memory-keeper` (recall) | `context.md` | Relevant memory slice saved |
| 2 | product | you, with the `product-review` skill | `product.md` | Premises, scope mode, approach agreed |
| 3 | plan | `planner` | `plan.md`, `scope.txt` | Criteria, design, test plan, integrations, scope |
| 4 | tests | `test-writer` | test files, `test-report.md` | New tests fail **for the predicted reason** |
| 5 | develop | `developer` | production code | New and existing tests pass |
| 6 | review | `reviewer` (×N models if configured) | `findings.md` § Review | Findings recorded |
| 7 | security | `security-reviewer` | `findings.md` § Security | Findings recorded |
| 8 | break | `breaker` | regression tests, `findings.md` § Break | Attacks run, failures captured as tests |
| 9 | fix | `developer` (fix) | production code | No open CRITICAL, all tests pass |
| 10 | integrate | `integration-tester` | integration tests, `findings.md` § Integration | Integration suite passes |
| 11 | ui | `ui-tester` | `e2e/*.spec.ts`, `findings.md` § UI | E2E passes on all viewports; no serious a11y violations |
| 12 | verify | you | `status.md` | Full suite, lint, typecheck, and e2e pass on real output |
| 13 | docs | `doc-writer` | `docs/features/<feature>.md` (+ architecture, data model, onboarding) | Doc written from the built code |
| 14 | remember | `memory-keeper` (update) | `docs/memory/**`, `summary.md` | Memory index and touched files updated |
| 15 | reflect | you, with the `reflect` skill (story mode) | `reflect.md` | Process improvements proposed, not applied |
| 16 | commit | you | git commits | Bisectable commits on `story/<id>` |
| 17 | ship | you, with the `ship` skill | PR | Per `ship.mode` |

### How to call each agent

Every agent that touches code reads `.claude/skills/project-conventions/SKILL.md` if it exists. Give each subagent only what it needs: the story id, the paths it must read, the paths it must write, and the commands from the config. For example:

> Story `20261024-csv-export`. Read `docs/stories/20261024-csv-export/{story,context,plan}.md`. Write tests per plan §Test plan. Test command: `npm test`. Return ≤10 lines: tests added, the failure message each produced, anything blocking.

Run phases 6 and 7 in parallel; they don't depend on each other. Phase 8 runs after both, because the breaker reads their findings and attacks the gaps.

### Product (phase 2)

`product_review` in the config sets when this runs:
- `auto` (the default): run it for new capabilities. Skip it for bug fixes, refactors, and stories that touch 3 or fewer files, marking `skipped: <reason>`.
- `always`, or `off`.

Follow the skill's gate. If the user must agree, stop here.

### Gate after plan (phase 3)

The planner also writes `scope.txt`: one glob per line for the files and directories the story may change. Then:
- If `require_plan_approval` is `true`, show the user a summary of `plan.md` of 15 lines or fewer and stop until they approve or edit it. In headless runs (`STORYFORGE_HEADLESS=1`), mark status `needs-approval` and end the turn.
- Always stop and ask if the plan touches auth, payments, data deletion, or a migration on existing data, even when approval is off.

### Review (phase 6)

If `review.models` lists more than one model, run the review skill's multi-model mode: one `reviewer` per model in a single message, then lead judgment by you. Also use it for any story the plan flags as auth, payments, data, or concurrency, even if only one model is configured. In that case use `opus` and `sonnet`.

### The fix loop (phase 9)

The loop is what makes this autonomous, and its exit conditions are what make it safe.

1. Collect every open CRITICAL finding, every failing test, critical or high UI issues from phase 11, and every NEEDS INPUT item the developer can resolve without a product decision.
2. Call `developer` in fix mode with `findings.md` and the failing test names. It must use the `investigate` skill: root cause first, then the fix.
3. **Scope:** if the developer reports a needed file outside `scope.txt` and the deviation is justified, add its glob to `scope.txt` (or `touch .storyforge/allow-scope-edit` for one cycle) and record it in `plan.md` § Deviations.
4. Re-run only what the fix could affect. Run review and security on the changed files, re-run the breaker's regression tests, and re-run the UI specs if a UI issue was fixed. Don't redo the whole pipeline.
5. Increment `fix_cycles` in `status.md`.

**Exit** when nothing CRITICAL is open and tests pass.
**After 2 failed cycles on the same finding**, apply `principle-attack-the-premise`: write down the premise that both fixes assumed, and test that premise before trying a third fix.
**Stop and ask the human** when any of these happens:
- `fix_cycles` reaches `max_fix_cycles`.
- A finding survives the premise check.
- A fix requires changing a test's expected behavior (a `TEST-DISPUTE`).
- A finding needs a product decision.

When you stop, write the open items to `status.md` under `## Blocked`. Never let a fix pass by weakening, skipping, or retrying a test, raising a timeout, or swallowing an error.

### UI (phase 11)

Run it only if `ui.enabled` is true **and** the plan or diff touches UI files (components, pages, templates, styles). Otherwise mark it `skipped: no UI change`. When it runs, `touch .storyforge/ui-ran` so the Stop gate includes e2e in verify. Before calling `ui-tester`, check that the dev server starts with `ui.start_command`. If it doesn't, that's a fix-loop item and not a UI finding.

### Verify (phase 12)

Run `test`, `lint`, and `typecheck` from the config yourself, plus `e2e_test` if phase 11 ran. Read the exit codes and the real output. Apply `principle-prove-it-works`: a subagent saying "all tests pass" is not evidence. Paste the pass/fail counts into `status.md`.

### Docs, remember, reflect (phases 13-15)

- **Docs:** call `doc-writer` with `docs.level`. Docs come after verify so they describe code that works.
- **Remember:** call `memory-keeper` in update mode.
- **Reflect:** if `reflect.after_each_story` is true, run the `reflect` skill in `story` mode. It writes proposals to `reflect.md` and applies nothing. If the number of finished stories is now a multiple of `reflect.retro_every_n_stories`, also tell the user a retro is due (`/storyforge:reflect retro`).

### Commit and ship (phases 16-17)

1. `echo done > .storyforge/phase`.
2. Commit following the `ship` skill's step 2 (bisectable commits). Include `docs/stories/<id>/`, `docs/memory/`, `docs/features/`, and any e2e snapshots.
3. If `ship.mode` is `pr` or `pr-babysit`, continue with the `ship` skill from step 1, which syncs with the base branch and re-tests. Otherwise stop after committing.
4. Report to the user in 12 lines or fewer: what was built, test counts, findings fixed vs. deferred, memory and docs updated, reflect proposals waiting for approval, the PR link if one was opened, and anything blocked.

## Rules

- **Whenever you stop to wait for the human** (plan approval, product gate, blocked fix loop, a product question), first run `echo blocked > .storyforge/phase`. Otherwise the Stop gate will keep you running while tests are red. On resume, set the phase from `status.md`.
- One story per run. If the plan shows the story is too big (more than about 15 files, or more than one integration), split it into stories in `plan.md` and build only the first one.
- Subagents can't call other subagents. All delegation happens from here.
- If a phase produces nothing (for example, no integrations touched in phase 10, or no UI in phase 11), mark it `skipped: <reason>` rather than inventing work.
- Read `docs/memory/INDEX.md` before phase 3 if `context.md` seems thin. Don't read every memory file.
