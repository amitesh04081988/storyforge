---
name: build-story
description: "Run the full StoryForge pipeline for a user story: recall project memory, product review, plan, impact analysis against the dependency map, write failing tests, implement, code review (optionally multi-model), security review, adversarial 'break it' testing, fix loop, integration tests, Playwright UI tests, verification, feature docs with UML diagrams, memory update, reflection, commit, and optionally ship a PR and babysit CI. Use whenever the user gives a story, feature description, ticket, or says 'build this', 'implement this story', '/build-story', or asks to resume a story run with --resume <id>."
argument-hint: "<story text | path/to/story.md> [--light|--full] | --resume <story-id>"
---

# Build Story

You are the **orchestrator**, running in the main session. You delegate each phase to a subagent from this plugin and never write production code yourself. Keep the main context small: subagents read and write files under `docs/stories/<id>/` and return summaries of 10 lines or fewer. Never paste a full file, diff, or log here when a path will do.

Scripts named below (`story-check.sh`, `guard.sh`, `dod-check.sh`, `story-index.sh`, `impact.sh`) run as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh" <args>`. If that variable is empty, find one with `find ~/.claude/plugins -path '*storyforge/scripts/<name>.sh'`. Run them from the project root.

## 0. Setup

1. Read `storyforge.config.json`. If it's missing, run the `init-project` skill first, then return. In headless runs (`STORYFORGE_HEADLESS=1`) stop with status `needs-init`.
2. **New story:** derive `<id>` as `YYYYMMDD-<short-kebab-slug>`. Run `story-check.sh <id>`; exit 3 means another developer has this story or slug on an `origin/story/*` branch. Show its output and stop until the user says to continue (headless: status `needs-approval`). Then write `docs/stories/<id>/story.md` with the story text verbatim and create branch `story/<id>` from `base_branch` (from the current HEAD when `STORYFORGE_QUEUE=1`). If the working tree is dirty, stop and ask.
   **Resume** (`--resume <id>`): read `docs/stories/<id>/status.md` and continue from the first phase not marked `done`, keeping the recorded cycle count.
3. If `git ls-files .storyforge` prints anything, stop: tracked run state is ignored by the hooks, so no gate would protect this run. Tell the user to run `git rm -r --cached .storyforge` and add `.storyforge/` to `.gitignore`. Otherwise set the phase lock and initialize status:
   ```bash
   mkdir -p .storyforge && echo "<id>" > .storyforge/story && echo "recall" > .storyforge/phase && echo 0 > .storyforge/stop-blocks && rm -rf .storyforge/ui-ran .storyforge/allow-test-edit .storyforge/allow-scope-edit .storyforge/baseline .storyforge/baseline.json
   ```
   `status.md` starts with `owner: <git config user.name>`, `phase: recall`, `mode: full`, `fix_cycles: 0`, then a checklist of the phases. Update it after every phase and keep `phase:` equal to `.storyforge/phase`. It makes the run resumable and feeds `docs/stories/INDEX.md`.

The hooks read `.storyforge/phase`; run `echo <phase> > .storyforge/phase` at the start of every phase. In `develop` and `fix` the edit guard blocks test-file edits and edits outside `scope.txt`. The Stop gate runs the tests in `develop`, `fix`, `integrate`, `ui`, and `verify`, plus `lint` and `typecheck` in all of those except `ui`.

## Phases

| # | Phase | Agent / skill | Writes | Done when |
|---|-------|---------------|--------|-----------|
| 1 | recall | `memory-keeper` (recall) | `context.md` | Relevant memory slice and feature-map rows saved |
| 2 | product | you, with `product-review` | `product.md` | Premises, scope mode, approach agreed |
| 3 | plan | `planner` | `plan.md`, `scope.txt` | Criteria, design, test plan, integrations, scope |
| 3b | impact | `impact-analyst` | `impact.md`, appended `plan.md` and `scope.txt`, `DEPENDENCIES.md` | Every affected area decided (none, check, change) with evidence |
| 4 | tests | `test-writer` | test files, `test-report.md` | New tests fail **for the predicted reason** |
| 5 | develop | `developer` | production code | New and existing tests pass |
| 6 | review | `reviewer` (×N models if configured) | `findings.md` § Review | Findings recorded |
| 7 | security | `security-reviewer` | `findings.md` § Security | Findings recorded |
| 8 | break | `breaker` | regression tests, `findings.md` § Break | Attacks run, failures captured as tests |
| 9 | fix | `developer` (fix) | production code | No open CRITICAL or HIGH, all tests pass |
| 10 | integrate | `integration-tester` | integration tests, `findings.md` § Integration | Integration suite passes |
| 11 | ui | `ui-tester` | `e2e/*.spec.ts`, `findings.md` § UI | E2E passes on all viewports; no serious a11y violations |
| 12 | verify | you | `status.md` § Definition of done | Gates pass on real output and every criterion has evidence |
| 13 | docs | `doc-writer` | `docs/features/<feature>.md` (+ architecture, data model, onboarding) | Doc written from the built code |
| 14 | remember | `memory-keeper` (update) | `docs/memory/**` incl. `FEATURES.md`, `summary.md` | Memory index, feature map, and touched files updated |
| 15 | reflect | you, with `reflect` (story mode) | `reflect.md` | Improvements proposed, not applied |
| 16 | commit | you | git commits | Bisectable commits on `story/<id>` |
| 17 | ship | you, with `ship` | PR | Per `ship.mode` |

### Calling agents

Every code-touching agent reads `.claude/skills/project-conventions/SKILL.md` if it exists. Give each subagent only the story id, the paths to read and write, and the config commands. Example:

> Story `20261024-csv-export`. Read `docs/stories/20261024-csv-export/{story,context,plan}.md`. Write tests per plan §Test plan. Test command: `npm test`. Return ≤10 lines: tests added, the failure message each produced, anything blocking.

**Models:** each agent has a default model in its frontmatter; `models.<agent>` in the config overrides it. Pass that value as the `model` parameter when it is set. Defaults: memory-keeper, doc-writer, integration-tester and ui-tester run on `sonnet`; the rest inherit your model.

### Design and polish (bits-mode skills)

- **Design, in plan (3):** when the plan changes more than 3 files or crosses a module boundary, run the `architect` skill first so `plan.md` § Design carries real types and signatures; for a contested or high-risk shape, `arena`, then the `review` skill in multi-model mode. Skip with `skipped: small change` otherwise.
- **Polish, end of develop (5) and again before commit (16):** run `deslop` on the diff, then `no-comments`, then re-run the tests. Both only remove; if tests fail, the removal was wrong.
- **Unknown bug cause in fix (9):** `investigate` first; if the history matters, `why`. Two failed fixes on one finding means `principle-attack-the-premise`.
- **Verify (12):** if `.claude/skills/verify/` exists, run the changed feature through it; if the repo has none and the story touches a runnable surface, suggest `create-verification-skill` in the report.
- **Docs (13):** for state machines, retries, or concurrency, add a `statechart`; docs and PR text go through `unslop` and `technical-writing`.

### Parallel agents

Send every agent of one wave in a **single message** with several Agent calls, so they run at the same time. Waves, each waiting for the previous one:
- **tests (4) and develop (5):** one `test-writer` then one `developer` per `plan.md` § Work units, up to `parallel.max_workers`. Name the unit in each prompt. Units own disjoint globs, so the guard still holds; `guard.sh snapshot` once before the wave and `guard.sh check` once after. One unit means one agent. If two units turn out to share a file, run them one after the other.
- **review (6) and security (7):** in the same message, with the reviewers from the Review section below.
- **break (8):** after the wave above, because the breaker attacks the gaps it found.
- **fix (9):** group open findings by file. Disjoint groups go to parallel `developer`s in fix mode; findings that share a file go to one.
- **integrate (10) and ui (11):** in the same message when both run.
- **docs (13) and remember (14):** in the same message.

Set `parallel.max_workers` to 1 in the config to run everything one at a time. The orchestrator alone writes `status.md`, so parallel agents never write the same file.

### Mode: light or full

Most stories don't need all 17 phases. After the plan and impact are written, choose `mode` and record it in `status.md` with a one-line reason. `--light` or `--full` forces it; otherwise `light_mode` decides (`off` = always full). `auto` picks **light** only when all of these hold: the plan changes 3 files or fewer; no integration is touched; § Needs approval is "none"; no UI and no migration; the plan flags no auth, payments, data, or concurrency; and the story is a bug fix, a small tweak, or one small function. If in doubt, full. In light mode, read `references/light-mode.md` and follow it.

### Product (phase 2)

`product_review`: `auto` (default) runs it for new capabilities and skips bug fixes, refactors, and stories touching 3 or fewer files (mark `skipped: <reason>`); `always`; `off`. Follow the skill's gate; stop if the user must agree.

### Impact (phase 3b)

`echo impact > .storyforge/phase`. Skip with `skipped: impact.enabled is false` when disabled in the config. Otherwise:
- If `docs/memory/DEPENDENCIES.md` is missing or has only `_example` rows, run `impact-analysis` in `map` mode first.
- Call `impact-analyst` with the story id and `impact.max_depth` (default 3). It writes `impact.md`, appends the follow-up work to `plan.md` (§ Impact-driven changes, § Test plan), and adds `change` areas' paths to `scope.txt`.
- A `NEEDS INPUT` row stops the run like a product question.

### Gate after plan

Run it after phase 3b, so the user approves the plan including impact-driven work and the overlap check sees the full scope.
- If `require_plan_approval` is `true`, show a summary of `plan.md` of 15 lines or fewer and stop until approved or edited (headless: status `needs-approval`). Always stop and ask when the plan touches auth, payments, data deletion, or a migration on existing data, even if approval is off.
- **Overlap check:** `story-check.sh <id> docs/stories/<id>/scope.txt`. Exit 3 means another open story plans to change the same files. Show its output and stop; the user decides whether to coordinate, narrow the scope, or continue.
- **Share the claim:** unless `claim.push_early` is `false` or there is no `origin`, commit only `docs/stories/<id>/` as `docs(story): claim <id>` and `git push -u origin story/<id>`, so other developers can see the story is taken.

### Guard (phases 5 and 9)

The edit guard only sees the Edit and Write tools; a shell command (`sed -i`, a redirect, a script) can change a test or out-of-scope file without it. `guard.sh` compares files, so it catches any change:
1. Run `guard.sh snapshot` at the start of `develop` and of every fix cycle.
2. When the developer returns, run `guard.sh check`. A subagent finishing does not trigger the Stop gate, so you must run it.
3. **TEST-LOCK** violation: run `guard.sh restore` (tests only, never production code), add a CRITICAL gate-integrity finding, send the developer back. **SCOPE** violation: revert it, or if justified record it in `plan.md` § Deviations, widen `scope.txt`, and snapshot again.
4. After an approved test edit (an upheld TEST-DISPUTE): `touch .storyforge/allow-test-edit`, edit, remove the file, snapshot again.

Generated output, logs, and first-run snapshot files are not violations; changing an existing snapshot is.

### Review (phase 6)

In full mode, run the review skill's multi-model mode: one `reviewer` per model in `review.models` (default `opus` and `sonnet`) in a single message together with the security reviewer, then your lead judgment. A one-entry list means one reviewer. Any story the plan flags as auth, payments, data, or concurrency gets at least `opus` and `sonnet`.

### Severity and the fix loop (phase 9)

**CRITICAL:** wrong behavior, data loss, a security hole, or a weakened test. **HIGH:** a real defect a user or caller can hit (missed criterion, unhandled failure path, broken validation or business rule). Both must be fixed. **INFO:** style and optional hardening; may be deferred.

The loop is what makes this autonomous, and its exit conditions make it safe:
1. Collect every open CRITICAL and HIGH finding, failing test, critical or high UI issue, and NEEDS INPUT item the developer can resolve without a product decision.
2. `guard.sh snapshot`, then call `developer` in fix mode with `findings.md` and the failing test names. It must use the `investigate` skill: root cause first.
3. If the developer needs a file outside `scope.txt` and it is justified, add its glob (or `touch .storyforge/allow-scope-edit` for one cycle) and record it in `plan.md` § Deviations.
4. Re-run only what the fix could affect: review and security on changed files, the breaker's regression tests, the UI specs if a UI issue was fixed.
5. `guard.sh check`; handle violations as above. Increment `fix_cycles`.

**Exit** when nothing CRITICAL or HIGH is open and tests pass. **After 2 failed cycles on one finding**, apply `principle-attack-the-premise`: write down the premise both fixes assumed and test it before a third fix. **Stop and ask the human** when `fix_cycles` reaches `max_fix_cycles`, a finding survives the premise check, a fix needs a test's expected behavior changed (`TEST-DISPUTE`), or a finding needs a product decision. Write open items under `## Blocked` in `status.md`. Never pass by weakening, skipping, or retrying a test, raising a timeout, or swallowing an error.

### UI (phase 11)

Run only if `ui.enabled` is true **and** the plan or diff touches UI files; otherwise `skipped: no UI change`. When it runs, `touch .storyforge/ui-ran` so the Stop gate includes e2e in verify. Check that the dev server starts with `ui.start_command` first; if it doesn't, that's a fix-loop item, not a UI finding.

### Verify and definition of done (phase 12)

Run `test`, `lint`, `typecheck`, plus `integration_test` if phase 10 ran and `e2e_test` if phase 11 ran, yourself. Read the exit codes and real output (`principle-prove-it-works`: a subagent saying "all pass" is not evidence) and paste the counts into `status.md`.

Run `feature-map.sh check` too and read its output. Then build the matrix under `## Definition of done` in `status.md`: one row for every acceptance criterion in `plan.md` (number or label such as `AC1`), every business rule or validation the story names, and every area marked `check` or `change` in `impact.md`:

| # | Criterion or rule | Evidence (test `path::name`, or command and observed output) | Result |
|---|-------------------|----------------------------------------------------------------|--------|

Evidence must be something you ran in this phase and read yourself; a test name counts only if it ran and passed in the run above. For a criterion with no test, run the real flow and record what you saw. No evidence or a failing result means not done; "assumed" and "covered elsewhere" don't count.

Run `dod-check.sh <id>`. It checks every row has evidence and a pass, every plan criterion and `check`/`change` area has a row, and no CRITICAL or HIGH finding is open (closed by `FIXED:` on its line or the line under it). The Stop gate runs it too.

**If verify fails** (a gate command exits non-zero, a row lacks evidence or fails, or a CRITICAL or HIGH is open), don't stop and don't report success: `echo fix > .storyforge/phase`, add each failing row or command to `findings.md` as a HIGH finding, return to phase 9, then verify again. Each pass counts against `max_fix_cycles`, so the loop ends in a fully passing matrix or in `## Blocked` with the failing rows.

### Docs, remember, reflect (13-15)

- **Docs:** `doc-writer` with `docs.level`, after verify so docs describe working code.
- **Remember:** `memory-keeper` in update mode.
- **Reflect:** if `reflect.after_each_story`, run `reflect` in `story` mode (proposals only). When finished stories reach a multiple of `reflect.retro_every_n_stories`, tell the user a retro is due (`/storyforge:reflect retro`).

### Commit and ship (16-17)

1. `echo done > .storyforge/phase`.
2. Set this story's `phase:` to `done`, run `story-index.sh`, then commit per the `ship` skill's step 2 (bisectable commits), including `docs/stories/INDEX.md`, `docs/stories/<id>/`, `docs/memory/`, `docs/features/`, and e2e snapshots.
3. If `ship.mode` is `pr` or `pr-babysit`, continue with `ship` from step 1 (it syncs with the base branch and re-tests). Otherwise stop after committing.
4. Report in 12 lines or fewer: what was built, test counts, findings fixed vs. deferred (INFO only), criteria passed out of total, memory and docs updated, reflect proposals waiting, the PR link, anything blocked.

## Rules

- **Whenever you stop for the human** (plan approval, product gate, blocked loop, a question), first `echo blocked > .storyforge/phase`, or the Stop gate keeps you running while tests are red. On resume, restore the phase from `status.md`.
- One story per run. If the plan is too big (about 15 files, or more than one integration), split it into stories in `plan.md` and build only the first.
- Subagents can't call other subagents; all delegation happens here.
- A phase that produces nothing is marked `skipped: <reason>`, not padded with invented work.
- The feature map (`docs/memory/FEATURES.md`) is how every agent finds where a feature lives: `feature-map.sh find <word>` before planning or coding, and the keeper updates it in phase 14. Run `feature-map.sh check` in verify; a row for the story's feature that reports STALE or NO-PATHS is a HIGH finding.
- Read `docs/memory/INDEX.md` before phase 3 if `context.md` seems thin. Don't read every memory file.
