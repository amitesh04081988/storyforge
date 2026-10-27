---
name: build-story
description: "Run the full StoryForge pipeline for a user story: recall project memory, product review, plan, impact analysis against the dependency map, write failing tests, implement, code review (optionally multi-model), security review, adversarial 'break it' testing, fix loop, integration tests, Playwright UI tests, verification, feature docs with UML diagrams, memory update, reflection, commit, and optionally ship a PR and babysit CI. Use whenever the user gives a story, feature description, ticket, or says 'build this', 'implement this story', '/build-story', or asks to resume a story run with --resume <id>."
argument-hint: "<story text | path/to/story.md> [--light|--full] | --resume <story-id>"
---

# Build Story

You are the **orchestrator**. You run in the main session and delegate each phase to a subagent from this plugin. You never write production code yourself. You keep the main context small: subagents read and write files under `docs/stories/<id>/`, and they hand back summaries of 10 lines or fewer. Never paste a full file, diff, or log into this session when a path will do.

## 0. Setup

1. Read `storyforge.config.json` at the repo root. If it's missing, run the `init-project` skill first; for an empty repo it sets up the whole project. Then come back to this story. In headless runs, stop with status `needs-init` instead, because setup needs the user's answers.
2. **New story:** derive `<id>` as `YYYYMMDD-<short-kebab-slug>`. **Claim check:** run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/story-check.sh" <id>` (if the variable is empty, find the script with `find ~/.claude/plugins -path '*storyforge/scripts/story-check.sh'`). Exit 3 means another developer already has this story or one with the same slug on an `origin/story/*` branch. Show its output and stop until the user says to continue; in headless runs, mark status `needs-approval` and end the turn. Then create `docs/stories/<id>/story.md` with the story text verbatim. Create a branch `story/<id>` from `base_branch`, or from the current HEAD when `STORYFORGE_QUEUE=1` so queued stories build on each other. If the working tree is dirty, stop and ask.
   **Resume** (`--resume <id>`): read `docs/stories/<id>/status.md` and continue from the first phase not marked `done`. Use the cycle count recorded there.
3. Set the phase lock and initialize status:
   ```bash
   mkdir -p .storyforge && echo "<id>" > .storyforge/story && echo "recall" > .storyforge/phase && echo 0 > .storyforge/stop-blocks && rm -rf .storyforge/ui-ran .storyforge/allow-test-edit .storyforge/allow-scope-edit .storyforge/baseline .storyforge/baseline.json
   ```
   `status.md` starts with the header lines `owner: <git config user.name>`, `phase: recall`, `mode: full`, and `fix_cycles: 0`, followed by a checklist of the phases below. Update it after every phase, and keep `phase:` equal to `.storyforge/phase`. It is what makes a run resumable, and it is what other developers see in `docs/stories/INDEX.md`.

The hooks read `.storyforge/phase`. Set it with `echo <phase> > .storyforge/phase` at the start of every phase. This matters for three reasons:
- During `develop` and `fix`, the edit guard blocks test-file edits.
- During `develop` and `fix`, it also blocks edits outside `scope.txt`.
- The Stop gate runs the tests during `develop`, `fix`, `integrate`, `ui`, and `verify`. In `develop`, `fix`, `integrate`, and `verify` it also runs the configured `lint` and `typecheck`.

## Phases

| # | Phase | Agent / skill | Writes | Done when |
|---|-------|---------------|--------|-----------|
| 1 | recall | `memory-keeper` (recall) | `context.md` | Relevant memory slice saved |
| 2 | product | you, with the `product-review` skill | `product.md` | Premises, scope mode, approach agreed |
| 3 | plan | `planner` | `plan.md`, `scope.txt` | Criteria, design, test plan, integrations, scope |
| 3b | impact | `impact-analyst` | `impact.md`, appended `plan.md` and `scope.txt`, `DEPENDENCIES.md` | Every affected area decided (none, check, or change) with evidence |
| 4 | tests | `test-writer` | test files, `test-report.md` | New tests fail **for the predicted reason** |
| 5 | develop | `developer` | production code | New and existing tests pass |
| 6 | review | `reviewer` (×N models if configured) | `findings.md` § Review | Findings recorded |
| 7 | security | `security-reviewer` | `findings.md` § Security | Findings recorded |
| 8 | break | `breaker` | regression tests, `findings.md` § Break | Attacks run, failures captured as tests |
| 9 | fix | `developer` (fix) | production code | No open CRITICAL or HIGH, all tests pass |
| 10 | integrate | `integration-tester` | integration tests, `findings.md` § Integration | Integration suite passes |
| 11 | ui | `ui-tester` | `e2e/*.spec.ts`, `findings.md` § UI | E2E passes on all viewports; no serious a11y violations |
| 12 | verify | you | `status.md` § Definition of done | Full suite, lint, typecheck, and e2e pass on real output, and every acceptance criterion has evidence |
| 13 | docs | `doc-writer` | `docs/features/<feature>.md` (+ architecture, data model, onboarding) | Doc written from the built code |
| 14 | remember | `memory-keeper` (update) | `docs/memory/**`, `summary.md` | Memory index and touched files updated |
| 15 | reflect | you, with the `reflect` skill (story mode) | `reflect.md` | Process improvements proposed, not applied |
| 16 | commit | you | git commits | Bisectable commits on `story/<id>` |
| 17 | ship | you, with the `ship` skill | PR | Per `ship.mode` |

### How to call each agent

Every agent that touches code reads `.claude/skills/project-conventions/SKILL.md` if it exists. Give each subagent only what it needs: the story id, the paths it must read, the paths it must write, and the commands from the config. For example:

> Story `20261024-csv-export`. Read `docs/stories/20261024-csv-export/{story,context,plan}.md`. Write tests per plan §Test plan. Test command: `npm test`. Return ≤10 lines: tests added, the failure message each produced, anything blocking.

**Models.** Agents have a default model in their frontmatter, and `models.<agent>` in the config overrides it. When you call an agent, pass the config's `models.<agent>` as the `model` parameter if it is set; otherwise let the agent's default apply. By default the judgment-heavy agents (planner, impact-analyst, test-writer, developer, reviewer, security-reviewer, breaker) inherit your model, and the mostly mechanical ones (memory-keeper, doc-writer, integration-tester, ui-tester) run on `sonnet`.

Run phases 6 and 7 in parallel; they don't depend on each other. Phase 8 runs after both, because the breaker reads their findings and attacks the gaps.

### Light mode

Most stories don't need all 17 phases. A one-line fix shouldn't pay for product review, break-it, docs and reflect. After the plan (and impact) is written, choose `mode` and record it in `status.md` as `mode: light` or `mode: full`, stating the reason in one line.

- `--light` or `--full` on the command forces the choice. Otherwise `light_mode` in the config decides: `off` always runs full, `auto` (the default) picks light only when **all** of these hold: the plan changes 3 files or fewer; no integration is touched; § Needs approval is "none"; no UI is touched; there is no migration; the plan does not flag auth, payments, data, or concurrency; and the story is a bug fix, a small tweak, or one small function. If in doubt, run full.
- **Light runs:** recall, plan, impact (only call `impact-analyst` when `impact.sh` shows affected areas; otherwise write a one-line `impact.md`), tests, develop, review (one model, one pass, even if `review.models` lists several), the fix loop, verify with the definition-of-done check, and commit and ship per the config.
- **Light skips**, marking each `skipped: light mode`: product, break, integrate, ui, docs, remember (unless the story produced a decision or a lesson worth keeping), and reflect. Security review also runs when the diff touches auth, sessions, tokens, crypto, payments, uploads, or SQL and query building.
- **Never skipped, in any mode:** failing tests first, the guard checks, the stop gate, review, and the definition-of-done matrix with `dod-check.sh`.
- **Escalate to full** and run the skipped break and security phases when `fix_cycles` reaches 2, when review or security finds a CRITICAL, or when the work grows past 3 files or needs a scope deviation. Record `mode: full (escalated: <reason>)`.

### Product (phase 2)

`product_review` in the config sets when this runs:
- `auto` (the default): run it for new capabilities. Skip it for bug fixes, refactors, and stories that touch 3 or fewer files, marking `skipped: <reason>`.
- `always`, or `off`.

Follow the skill's gate. If the user must agree, stop here.

### Impact (phase 3b)

`echo impact > .storyforge/phase`. Skip this phase, marking `skipped: impact.enabled is false`, when `impact.enabled` is `false` in the config. Otherwise:
- If `docs/memory/DEPENDENCIES.md` is missing or has only `_example` rows, run the `impact-analysis` skill in `map` mode first, so there is a map to look up.
- Call `impact-analyst` with the story id and `impact.max_depth` (default 3). It looks up every area in the plan, decides per area whether it needs no change, a check, or a change, writes `impact.md`, and appends the follow-up work to `plan.md` (§ Impact-driven changes and § Test plan) and the `change` areas' paths to `scope.txt`.
- Any `NEEDS INPUT` row stops the run like a product question: `echo blocked > .storyforge/phase` and ask.
- Run this before the gate below, so the plan the user approves already includes the impact-driven work and the overlap check sees the full scope.

### Gate after plan (phases 3 and 3b)

The planner also writes `scope.txt`: one glob per line for the files and directories the story may change. Then:
- If `require_plan_approval` is `true`, show the user a summary of `plan.md` of 15 lines or fewer and stop until they approve or edit it. In headless runs (`STORYFORGE_HEADLESS=1`), mark status `needs-approval` and end the turn.
- Always stop and ask if the plan touches auth, payments, data deletion, or a migration on existing data, even when approval is off.
- **Overlap check:** run `story-check.sh <id> docs/stories/<id>/scope.txt`. Exit 3 means another open story on `origin/story/*` plans to change the same files. Show its output, `echo blocked > .storyforge/phase`, and stop. The user decides whether to coordinate with that owner, narrow the scope, or continue.
- **Share the claim:** unless `claim.push_early` is `false` in the config, commit only `docs/stories/<id>/` (story, plan, scope, status) as `docs(story): claim <id>` and run `git push -u origin story/<id>`. Skip this when there is no `origin` remote. Pushing early is what lets other developers see that the story is taken.

### Guard (phases 5 and 9)

The edit guard only sees the Edit and Write tools. A shell command (`sed -i`, a redirect, a script) can change a test or an out-of-scope file without it. `guard.sh` closes that by comparing files, so it covers every way a file can change:
1. At the start of `develop`, and at the start of every fix cycle, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh" snapshot`. If the variable is empty, find the script with `find ~/.claude/plugins -path '*storyforge/scripts/guard.sh'`.
2. When the developer returns, run `guard.sh check`. A subagent finishing does not trigger the Stop gate, so you must run this yourself.
3. On a **TEST-LOCK** violation, run `guard.sh restore` (it restores test files and never touches production code), add a CRITICAL gate-integrity finding to `findings.md`, and send the developer back. On a **SCOPE** violation, either revert the change or, if justified, record it in `plan.md` § Deviations, widen `scope.txt`, and snapshot again.
4. After any approved edit to tests (an upheld TEST-DISPUTE), `touch .storyforge/allow-test-edit`, make the edit, remove the file, and snapshot again.

### Review (phase 6)

If `review.models` lists more than one model, run the review skill's multi-model mode: one `reviewer` per model in a single message, then lead judgment by you. Also use it for any story the plan flags as auth, payments, data, or concurrency, even if only one model is configured. In that case use `opus` and `sonnet`.

### Severity

- **CRITICAL:** wrong behavior, data loss, a security hole, or a weakened test. Must be fixed.
- **HIGH:** a real defect that a user or caller can hit (a missed acceptance criterion, an unhandled failure path, broken validation or a broken business rule) that isn't CRITICAL. Must be fixed.
- **INFO:** style, naming, and optional hardening. May be deferred, and the final report counts these as deferred.

### The fix loop (phase 9)

The loop is what makes this autonomous, and its exit conditions are what make it safe.

1. Collect every open CRITICAL and HIGH finding, every failing test, critical or high UI issues from phase 11, and every NEEDS INPUT item the developer can resolve without a product decision.
2. Run `guard.sh snapshot` (see Guard above). Then call `developer` in fix mode with `findings.md` and the failing test names. It must use the `investigate` skill: root cause first, then the fix.
3. **Scope:** if the developer reports a needed file outside `scope.txt` and the deviation is justified, add its glob to `scope.txt` (or `touch .storyforge/allow-scope-edit` for one cycle) and record it in `plan.md` § Deviations.
4. Re-run only what the fix could affect. Run review and security on the changed files, re-run the breaker's regression tests, and re-run the UI specs if a UI issue was fixed. Don't redo the whole pipeline.
5. Run `guard.sh check` and handle violations as described under Guard.
6. Increment `fix_cycles` in `status.md`.

**Exit** when nothing CRITICAL or HIGH is open and tests pass.
**After 2 failed cycles on the same finding**, apply `principle-attack-the-premise`: write down the premise that both fixes assumed, and test that premise before trying a third fix.
**Stop and ask the human** when any of these happens:
- `fix_cycles` reaches `max_fix_cycles`.
- A finding survives the premise check.
- A fix requires changing a test's expected behavior (a `TEST-DISPUTE`).
- A finding needs a product decision.

When you stop, write the open items to `status.md` under `## Blocked`. Never let a fix pass by weakening, skipping, or retrying a test, raising a timeout, or swallowing an error.

### UI (phase 11)

Run it only if `ui.enabled` is true **and** the plan or diff touches UI files (components, pages, templates, styles). Otherwise mark it `skipped: no UI change`. When it runs, `touch .storyforge/ui-ran` so the Stop gate includes e2e in verify. Before calling `ui-tester`, check that the dev server starts with `ui.start_command`. If it doesn't, that's a fix-loop item and not a UI finding.

### Verify and definition of done (phase 12)

Run `test`, `lint`, and `typecheck` from the config yourself, plus `integration_test` if phase 10 ran and `e2e_test` if phase 11 ran. Read the exit codes and the real output. Apply `principle-prove-it-works`: a subagent saying "all tests pass" is not evidence. Paste the pass/fail counts into `status.md`.

Then build the **definition-of-done matrix** in `status.md` under `## Definition of done`. One row for every numbered acceptance criterion in `plan.md`, plus one row for every business rule or validation the story text names, plus one row for every area marked `check` or `change` in `impact.md` (evidence is the named test or command, run now, or the observed result):

| # | Criterion or rule | Evidence (test `path::name`, or command and observed output) | Result |
|---|-------------------|----------------------------------------------------------------|--------|

- Evidence must be something you ran in this phase and read yourself. A test name counts only if that test ran and passed in the run above. For a criterion with no test, run the real flow (a command, request, or the UI) and record what you observed.
- A criterion with no evidence, or with a failing result, is not done. There is no "assumed" or "covered elsewhere".
- The story is done only when every row passes, `findings.md` has no open CRITICAL or HIGH, and all gate commands exit 0.
- **Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dod-check.sh" <id>`.** It checks the matrix with code: every row has evidence and a pass, every numbered criterion in `plan.md` has a row, every `check` or `change` area in `impact.md` is named, and no CRITICAL or HIGH finding is open (a finding counts as closed when `FIXED:` is on its line or the lines under it). Exit 1 means verify failed. The Stop gate runs the same check, so you cannot finish while it fails.

**If verify fails** (a gate command exits non-zero, a row has no evidence or fails, or a CRITICAL or HIGH finding is open), don't stop and don't report success. Run `echo fix > .storyforge/phase`, add each failing row or command to `findings.md` as a HIGH finding, and return to the fix loop (phase 9). Then run verify again. Each pass through the loop counts against `max_fix_cycles`, and the same stop rules apply, so the loop ends either in a fully passing matrix or in `## Blocked` with the failing rows listed.

### Docs, remember, reflect (phases 13-15)

- **Docs:** call `doc-writer` with `docs.level`. Docs come after verify so they describe code that works.
- **Remember:** call `memory-keeper` in update mode.
- **Reflect:** if `reflect.after_each_story` is true, run the `reflect` skill in `story` mode. It writes proposals to `reflect.md` and applies nothing. If the number of finished stories is now a multiple of `reflect.retro_every_n_stories`, also tell the user a retro is due (`/storyforge:reflect retro`).

### Commit and ship (phases 16-17)

1. `echo done > .storyforge/phase`.
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/story-index.sh"` to refresh `docs/stories/INDEX.md` (set this story's `phase:` to `done` first). Commit following the `ship` skill's step 2 (bisectable commits). Include `docs/stories/INDEX.md`, `docs/stories/<id>/`, `docs/memory/`, `docs/features/`, and any e2e snapshots.
3. If `ship.mode` is `pr` or `pr-babysit`, continue with the `ship` skill from step 1, which syncs with the base branch and re-tests. Otherwise stop after committing.
4. Report to the user in 12 lines or fewer: what was built, test counts, findings fixed vs. deferred (INFO only), criteria passed out of total, memory and docs updated, reflect proposals waiting for approval, the PR link if one was opened, and anything blocked.

## Rules

- **Whenever you stop to wait for the human** (plan approval, product gate, blocked fix loop, a product question), first run `echo blocked > .storyforge/phase`. Otherwise the Stop gate will keep you running while tests are red. On resume, set the phase from `status.md`.
- One story per run. If the plan shows the story is too big (more than about 15 files, or more than one integration), split it into stories in `plan.md` and build only the first one.
- Subagents can't call other subagents. All delegation happens from here.
- If a phase produces nothing (for example, no integrations touched in phase 10, or no UI in phase 11), mark it `skipped: <reason>` rather than inventing work.
- Read `docs/memory/INDEX.md` before phase 3 if `context.md` seems thin. Don't read every memory file.
