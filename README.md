# StoryForge

StoryForge is a Claude Code plugin that takes a **user story** and carries it to a finished, tested, reviewed, documented change. It plans, writes failing tests first, implements, reviews, attacks its own work, fixes by root cause, checks everything the change could affect, and refuses to call the story done until every acceptance criterion has evidence.

It also works across a team: stories are claimed on git branches, a story index shows who is doing what, and a dependency map tells every story what else it touches.

- [Install](#install)
- [Quick start](#quick-start)
- [How a story runs](#how-a-story-runs)
- [Worked example: one story, start to finish](#worked-example-one-story-start-to-finish)
- [The dependency matrix and impact analysis](#the-dependency-matrix-and-impact-analysis)
- [Definition of done](#definition-of-done)
- [Working as a team](#working-as-a-team)
- [Configuration reference](#configuration-reference)
- [Scripts](#scripts)
- [Hooks: what is enforced automatically](#hooks-what-is-enforced-automatically)
- [More safeguards](#more-safeguards)
- [How memory works](#how-memory-works-and-saves-tokens)
- [Files StoryForge creates](#files-storyforge-creates)
- [Skills and agents](#skills-and-agents)
- [Where the skills come from](#where-the-skills-come-from)
- [Limits and honest caveats](#limits-and-honest-caveats)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

## Install

In Claude Code:

```
/plugin marketplace add https://gitlab.bitsdev.in/amiteshk/storyforge.git
/plugin install storyforge@storyforge
```

You can also install from a local clone: `/plugin marketplace add /path/to/storyforge`. Update later from the same `/plugin` menu, or reinstall.

**Requirements:** Claude Code, `git`, `bash` (Git Bash on Windows), and `python3` on the PATH (the hooks use it to read the config). Node.js for Playwright (UI stories) and for the transcript finder in `reflect full`. For the PR step you also need `gh` (GitHub) or `glab` (GitLab); without them StoryForge stops after committing.

## Quick start

**1. Set up the repository once** (new or existing):

```
/storyforge:init-project
```

- **Empty repo:** it interviews you, recommends 2 or 3 tech stacks with trade-offs, scaffolds a working app with tests, lint and CI, then continues as below.
- **Existing code:** it reads the manifests, shows you a stack summary tagged `detected` or `guess`, asks only what the code can't tell it (deploy targets, how to run integration tests, UI login, team rules), then writes `storyforge.config.json`, project memory, a conventions skill, onboarding docs, and the **dependency map**.

Open `storyforge.config.json` and check that `test`, `lint`, and `typecheck` are the real commands for your project. The gates only protect you if these are right.

**2. Build a story:**

```
/storyforge:build-story As a customer I can export my orders as a CSV file
```

**3. Check in on it, or resume it:**

```
/storyforge:build-story --resume 20261027-orders-csv-export
```

**Running unattended** (outside a chat, for example overnight or in a queue):

```bash
bash scripts/run-story.sh "As a customer I can export my orders as a CSV file"
bash scripts/run-story.sh --resume 20261027-orders-csv-export
bash scripts/run-story.sh --queue stories.txt      # one story per line, stops at the first that needs a human
```

For unattended runs, add Bash allow rules for your test, lint and git commands in `.claude/settings.json`. Only use `--dangerously-skip-permissions` inside a disposable container.

Unattended runs stop at anything that needs a person (plan approval, a product question, a blocked fix loop) and mark the story `needs-approval` or `## Blocked` instead of guessing.

---

## How a story runs

`build-story` is the orchestrator. It never writes production code itself. It hands each phase to a specialist agent, which reads and writes files under `docs/stories/<id>/` and returns a summary of 10 lines or fewer.

| # | Phase | Who | What happens | Done when |
|---|-------|-----|--------------|-----------|
| 1 | recall | memory-keeper | Pulls the relevant slice of project memory into `context.md` | Memory slice saved |
| 2 | product | you + `product-review` | Challenges the premise, looks for existing code that already does part of it, picks a scope mode | Premises and scope agreed |
| 3 | plan | planner | Numbered acceptance criteria, design, test plan, integrations touched, `scope.txt` | Plan written |
| **3b** | **impact** | **impact-analyst** | **Looks up the plan in the dependency map, decides per affected area: none, check, or change** | **Every affected area decided with evidence** |
| gate | approval | you | You approve the plan (including impact-driven work). Always asked for auth, payments, data deletion, migrations | Approved |
| 4 | tests | test-writer | Writes failing tests from the criteria, proves each fails for the predicted reason | Tests fail correctly |
| 5 | develop | developer | Smallest code that makes the tests pass | Tests pass |
| 6 | review | reviewer | Correctness, edge cases, gate integrity (was a test weakened?), maintainability | Findings recorded |
| 7 | security | security-reviewer | Auth bypass, injection, secrets, SSRF, unsafe deserialization, feature-gate leaks | Findings recorded |
| 8 | break | breaker | Tries to break it: hostile input, double submit, failure injection. Every real failure becomes a regression test | Attacks run |
| 9 | fix | developer | Root-cause fixes, repeated until nothing CRITICAL or HIGH is open (see [the fix loop](#the-fix-loop)) | No CRITICAL or HIGH, tests pass |
| 10 | integrate | integration-tester | Tests each touched integration against its recorded contract | Integration suite passes |
| 11 | ui | ui-tester | Playwright specs from the criteria, on every viewport, with accessibility checks, then an exploratory browser pass (UI stories only) | E2E passes, no serious a11y issues |
| 12 | verify | orchestrator | Runs everything itself and fills the [definition-of-done matrix](#definition-of-done) | Every criterion has evidence |
| 13 | docs | doc-writer | Feature doc with Mermaid diagrams, architecture and data model, onboarding | Docs written from the built code |
| 14 | remember | memory-keeper | Files integrations, decisions, lessons, and **dependency map updates** | Memory updated |
| 15 | reflect | orchestrator | Proposes process improvements (never applies them without approval) | `reflect.md` written |
| 16 | commit | orchestrator | Refreshes `docs/stories/INDEX.md`, makes bisectable commits on `story/<id>` | Committed |
| 17 | ship | orchestrator + `ship` | Per `ship.mode`: stop at commit, open a PR, or open it and watch CI | Per config |

### The fix loop

Phase 9 is what makes StoryForge keep going until the work is right:

1. Collect every open **CRITICAL** and **HIGH** finding, every failing test, and serious UI issues.
2. The developer fixes them by **root cause** (using the `investigate` skill), never by weakening a test.
3. Re-run only what the fix could affect (review, security, the break regression tests, the UI specs).
4. Repeat.

It stops and asks you when: `max_fix_cycles` (default 4) is reached, a finding survives the premise check (after 2 failed fixes on the same finding it writes down the assumption both fixes made and tests it), a fix would need a test's expected behavior to change, or a finding needs a product decision. Open items go under `## Blocked` in `status.md`.

Severity levels:

- **CRITICAL:** wrong behavior, data loss, a security hole, or a weakened test. Must be fixed.
- **HIGH:** a real defect a user or caller can hit (a missed acceptance criterion, an unhandled failure path, a broken validation or business rule). Must be fixed.
- **INFO:** style, naming, optional hardening. May be deferred, and the final report counts these as deferred.

---

## Worked example: one story, start to finish

Story: `As a customer I can export my orders as a CSV file`, in a Node/TypeScript shop app with `orders`, `billing`, `auth` and `db` areas.

**You run:**

```
/storyforge:build-story As a customer I can export my orders as a CSV file
```

**Setup.** StoryForge derives the id `20261027-orders-csv-export`, runs the claim check against other developers' branches (clear), creates the branch `story/20261027-orders-csv-export`, and writes `docs/stories/20261027-orders-csv-export/status.md`:

```
owner: Amitesh Kumar
phase: recall
fix_cycles: 0

- [ ] recall
- [ ] product
- [ ] plan
...
```

**Plan.** The planner writes `plan.md`. The acceptance criteria look like this:

```
1. GET /orders/export returns 200 with Content-Type text/csv for a signed-in customer.
2. The file has a header row and one row per order belonging to that customer only.
3. Amounts are written in the order's currency with two decimals.
4. A signed-out request gets 401 and no data.
5. A customer with 0 orders gets the header row only.
```

and `scope.txt`:

```
src/orders/**
tests/orders/**
```

**Impact (phase 3b).** The impact-analyst runs `impact.sh` on that scope and finds that `reports` (a nightly job) reads from `orders`:

```
Dependency map: 5 areas. Changed paths: 2. Depth: 3
DIRECT   orders (module)  paths: src/orders/**  tests: tests/orders/**
AFFECTED hop 1  reports (job)  via orders  paths: src/reports/**  tests: -
```

It reads `src/reports/monthly.ts`, sees that the report calls `listOrders()`, and checks whether the story changes that function. It writes `impact.md`:

```
# Impact: orders CSV export
Changed areas: orders (src/orders/**)
| Area    | Hop | Decision | Evidence or action                                  | Test |
|---------|-----|----------|-----------------------------------------------------|------|
| reports | 1   | check    | monthly.ts:9 calls listOrders(); we add a filter    | run: npm test -- reports |
|         |     |          | parameter, default unchanged. No test exists: gap.  | (new) reports keeps full order list |
```

Because `reports` has no tests (`tests: -`), the analyst adds one to the plan's test plan, and appends to `plan.md`:

```
## Impact-driven changes
6. The nightly report still returns every order after listOrders() gains an optional filter.
```

**Approval gate.** You see a 15-line plan summary that already includes item 6. You approve.

**Tests, develop.** The test-writer writes failing tests for criteria 1 to 6 and shows each fails for the predicted reason (for example `404 Not Found`, not a typo). The developer then writes the smallest code that passes them. During this phase, hooks stop it from editing test files or files outside `scope.txt`.

**Review, security, break.** The reviewer finds a missing `Content-Disposition` header (HIGH). The security-reviewer finds that the CSV doesn't escape cells starting with `=`, `+`, `-`, `@`, which allows spreadsheet formula injection (CRITICAL). The breaker tries a 50,000-order customer and a double-click on Export; both hold, and it records them under `### Survived`.

**Fix loop.** The developer fixes both findings by root cause and adds regression tests. `fix_cycles: 1`. Nothing CRITICAL or HIGH is open, so the loop exits.

**Verify.** The orchestrator runs `test`, `lint`, `typecheck` and `integration_test` itself, reads the output, and fills the matrix in `status.md`:

```
## Definition of done
| # | Criterion or rule                                  | Evidence                                          | Result |
|---|----------------------------------------------------|---------------------------------------------------|--------|
| 1 | 200 + text/csv for a signed-in customer            | tests/orders/export.test.ts::returns_csv (ran, passed) | pass |
| 2 | Header row, only this customer's orders            | tests/orders/export.test.ts::scopes_to_customer   | pass   |
| 3 | Amounts with two decimals                          | tests/orders/export.test.ts::formats_amounts      | pass   |
| 4 | Signed-out gets 401, no data                       | tests/orders/export.test.ts::requires_auth        | pass   |
| 5 | 0 orders gives header only                         | tests/orders/export.test.ts::empty_export         | pass   |
| 6 | Nightly report unaffected (impact: reports)        | tests/reports/monthly.test.ts::lists_all_orders   | pass   |
| R | Business rule: customers never see others' orders  | tests/orders/export.test.ts::scopes_to_customer   | pass   |
```

If row 6 had no passing test, the story would **not** be done. The phase would go back to `fix`, add a HIGH finding, and the loop would run again.

**Finish.** Docs, memory (including an updated `DEPENDENCIES.md` row for `orders`), reflect, then commits on `story/20261027-orders-csv-export` and a refreshed `docs/stories/INDEX.md`. With `ship.mode: pr`, it also opens the PR. The final report is at most 12 lines:

```
Built: orders CSV export (6 criteria + 1 business rule), 7/7 criteria passed.
Tests: 41 passed (12 new), lint and typecheck clean. Findings fixed: 1 CRITICAL, 1 HIGH. Deferred (INFO): 2.
Impact: reports checked (new test added). Memory + docs updated. Reflect: 1 proposal waiting.
```

---

## The dependency matrix and impact analysis

Every project gets a **dependency map**, `docs/memory/DEPENDENCIES.md`. It answers: "if I change this, what else could break, and what do I need to re-check or change?"

### The format

One table. One row per area (a module, an integration, the database, a job, the UI, config):

```markdown
| Area | Kind | Paths | Depends on | Tests | Notes |
|------|------|-------|------------|-------|-------|
| orders | module | src/orders/** | billing, auth, db | tests/orders/** | emits OrderPlaced |
| billing | integration | src/billing/** | db | - | Stripe webhooks |
| auth | module | src/auth/** | db | - | |
| db | data | src/db/**, migrations/** | - | - | shared |
| reports | job | src/reports/** | orders, billing | - | nightly |
```

| Column | Meaning |
|--------|---------|
| **Area** | A unique name. This is what `Depends on` refers to. |
| **Kind** | `module`, `integration`, `data`, `config`, `job`, or `ui`. |
| **Paths** | The globs this area owns. How a changed file is mapped to an area. |
| **Depends on** | Areas this one needs in order to work. The only stored edge. |
| **Tests** | Where this area is tested. `-` means a gap. |
| **Notes** | Links the code doesn't show: events, queues, shared tables, HTTP calls. |

"Used by" is **computed** from `Depends on`, so the two directions can never disagree.

### Looking up a change

`scripts/impact.sh` takes changed paths (or a story's `scope.txt`) and lists the areas they belong to and everything that depends on them, directly or through other areas:

```bash
$ bash scripts/impact.sh src/billing/charge.ts
Dependency map: 5 areas. Changed paths: 1. Depth: 3
DIRECT   billing (integration)  paths: src/billing/**  tests: -
AFFECTED hop 1  orders (module)  via billing  paths: src/orders/**  tests: tests/orders/**
AFFECTED hop 1  reports (job)  via billing  paths: src/reports/**  tests: -
```

The change is in `billing`. `orders` and `reports` use `billing`, so both need a look. Changes deeper in the graph reach further:

```bash
$ bash scripts/impact.sh --scope docs/stories/20261027-x/scope.txt     # scope: src/auth/** and src/newthing/**
Dependency map: 5 areas. Changed paths: 2. Depth: 3
DIRECT   auth (module)  paths: src/auth/**  tests: -
AFFECTED hop 1  orders (module)  via auth  paths: src/orders/**  tests: tests/orders/**
AFFECTED hop 2  reports (job)  via orders  paths: src/reports/**  tests: -
UNMAPPED src/newthing/**  (no area owns this path; add it to the map)
```

`reports` is two hops away: it doesn't use `auth`, but it uses `orders`, which does. `UNMAPPED` means a path no area owns. The analyst adds a row so the next lookup is complete.

A change to the shared database layer shows why the map matters most there:

```bash
$ bash scripts/impact.sh --depth 1 'migrations/**'
DIRECT   db (data)  paths: src/db/**, migrations/**  tests: -
AFFECTED hop 1  orders (module)  via db  ...
AFFECTED hop 1  billing (integration)  via db  ...
AFFECTED hop 1  auth (module)  via db  ...
```

### What happens with each affected area

The `impact-analyst` doesn't just list areas. For each one it reads the code that uses the changed thing and decides exactly one of:

| Decision | Meaning | What follows |
|----------|---------|--------------|
| **none** | Doesn't use anything that changes | A one-line reason with `file:line` |
| **check** | Uses something that changes, behavior should stay the same | A named test or command proves it. No test? A new one is added |
| **change** | Breaks or needs updating | Becomes a plan item with its own tests. Its paths are added to `scope.txt` so the developer can edit it, and it goes through test-first, review, and the fix loop |

Every `check` and `change` becomes a row in the [definition-of-done matrix](#definition-of-done). The story isn't done until each one has passing evidence. Because `scope.txt` now includes the impact-driven paths, the [overlap check](#working-as-a-team) also protects those files from another developer's story.

### Building and keeping the map current

- **At setup:** `init-project` runs the `impact-analysis` skill in `map` mode. It chooses the areas, then runs `scripts/dep-scan.sh`, which scans import lines and prints **candidate** edges:

  ```bash
  $ bash scripts/dep-scan.sh
  orders -> billing  (1 import lines, e.g. src/orders/create.ts:1)
  orders -> db  (1 import lines, e.g. src/orders/create.ts:1)
  reports -> orders  (1 import lines, e.g. src/reports/monthly.ts:1)
  ```

  Each candidate is confirmed in the code before it is recorded. The scan is a text search, so it can't see events, queues, shared tables, HTTP calls, or dynamic imports. Those go in **Notes** by hand.
- **After each story:** `memory-keeper` updates the map from the diff: new or moved areas, changed edges, new runtime links, new tests.
- **On demand:** `/storyforge:impact-analysis map` rebuilds or repairs it.

### Using it outside a story

Got a bug report or a new task you haven't turned into a story yet? Ask:

```
/storyforge:impact-analysis the checkout page double-charges when billing retries
```

It translates the description into likely files and areas, runs the lookup, and answers with the affected areas and a decision for each, before anything is built.

### Turning it off

Set `"impact": { "enabled": false }` in `storyforge.config.json`. The phase is then marked `skipped`.

---

## Definition of done

A story is done only when **all** of these hold:

1. Every numbered acceptance criterion, every business rule or validation the story names, and every `check` or `change` area from `impact.md` has a row in `status.md` § Definition of done with **evidence from a run in the verify phase**. A test name counts only if that test ran and passed in that run. For a criterion with no test, the orchestrator runs the real flow (a command, a request, the UI) and records what it saw. "Assumed" and "covered elsewhere" are not evidence.
2. `findings.md` has no open CRITICAL or HIGH.
3. `test`, `lint`, `typecheck`, plus `integration_test` and `e2e_test` when those phases ran, all exit 0. The orchestrator runs them itself; a subagent saying "all pass" isn't evidence.

**If verify fails,** StoryForge doesn't stop and doesn't report success. It sets the phase back to `fix`, records each failing row or command as a HIGH finding, and re-enters the fix loop. It ends either with a fully passing matrix or in `## Blocked` with the failing rows listed, after at most `max_fix_cycles` passes.

The **Stop gate** adds a second guard: while a story is in `develop`, `fix`, `integrate`, `ui` or `verify`, Claude can't finish its turn while tests, lint or typecheck fail (the UI phase checks tests and e2e). It gives up after `max_stop_blocks` attempts so it can never loop forever, and tells you what is still failing.

---

## Working as a team

StoryForge uses plain git, with no server and no database. Everything is shared through the repository.

### How it avoids two developers doing the same work

1. **Claim check (before the branch is created).** `scripts/story-check.sh <id>` looks at `origin/story/*` branches. It stops if the exact story id exists, or if the same story name exists under a different date:

   ```
   $ bash scripts/story-check.sh 20261028-csv-export
   DUPLICATE: story/20261027-csv-export has the same slug (owner: Alice).
   Coordinate with the owner, or rebase onto their branch, before continuing.
   ```

2. **Overlap check (after plan and impact).** `scripts/story-check.sh <id> <scope.txt>` compares your scope with every other open story's `scope.txt`:

   ```
   $ bash scripts/story-check.sh 20261028-new docs/stories/20261028-new/scope.txt
   OVERLAP: 'src/orders/export/**' vs 'src/orders/**' in story/20261027-csv-export (owner: Alice)
   Coordinate with the owner, or rebase onto their branch, before continuing.
   ```

   Stories already merged into the base branch are ignored. You decide whether to talk to the owner, narrow the scope, or carry on.

3. **Early claim.** After the plan is approved, StoryForge commits only `docs/stories/<id>/` (story, plan, scope, status) and pushes `story/<id>`, so other developers' checks can see the claim. Turn this off with `"claim": { "push_early": false }`.

### Seeing everything: the story index

`scripts/story-index.sh` writes `docs/stories/INDEX.md` from your working tree **and** all `origin/story/*` branches, so it includes other developers' unmerged stories. `build-story` refreshes it when a story is committed:

```
| Story               | Title                                | Owner | Phase   | Branch                    |
|---------------------|--------------------------------------|-------|---------|---------------------------|
| 20261027-csv-export | As a user I can export orders to CSV | Alice | develop | story/20261027-csv-export |
```

### Shared knowledge

`docs/memory/` is committed, so every developer's runs share the same integrations registry, decisions, lessons, and dependency map. Each story that changes the system updates them, so the next developer starts from what the last one learned.

### What the team features do not do

They only see stories pushed to the shared remote, so developers on forks or working offline aren't visible. The index is a snapshot that refreshes when a story is committed. There is no link to Jira, GitLab issues, or Linear. See [Limits](#limits-and-honest-caveats).

---

## Configuration reference

`storyforge.config.json` at the repo root. `init-project` creates it with defaults.

| Key | Default | What it does |
|-----|---------|--------------|
| `base_branch` | `main` | Branch stories start from and are compared against |
| `test` | `npm test` | Unit test command. Required for the gates |
| `integration_test` | `npm run test:integration` | Run in the integrate and verify phases. Blank to skip |
| `e2e_test` | `npx playwright test` | Run for UI stories |
| `lint`, `typecheck` | `npm run lint`, `npm run typecheck` | Run by verify **and by the Stop gate**. Blank to skip |
| `format` | blank | Formatter run on each edited file |
| `test_globs` | common patterns | Which files count as tests (locked during develop and fix) |
| `ui.enabled` | `false` | Turn on the UI phase |
| `ui.start_command`, `ui.base_url` | `npm run dev`, `http://localhost:3000` | How to start and reach the app for UI tests |
| `ui.viewports` | `desktop`, `mobile` | Viewports the specs run on |
| `ui.visual_snapshots`, `ui.accessibility` | `true`, `true` | Visual and accessibility checks |
| `docs.level` | `light` | How much documentation to write |
| `product_review` | `auto` | `auto` (new capabilities only), `always`, or `off` |
| `review.models` | `["inherit"]` | More than one model runs a multi-model review |
| `scope_lock` | `true` | Block edits outside `scope.txt` during develop and fix |
| `reflect.after_each_story` | `true` | Propose process improvements after each story |
| `reflect.retro_every_n_stories` | `10` | When to suggest a retro |
| `ship.mode` | `commit` | `commit`, `pr`, or `pr-babysit` (opens the PR and fixes CI and review comments) |
| `ship.auto_merge` | `false` | Whether the shipped PR may be merged automatically |
| `impact.enabled` | `true` | Run the impact phase |
| `impact.max_depth` | `3` | How many hops of dependents to follow |
| `claim.push_early` | `true` | Push the story branch after planning so others see the claim |
| `require_plan_approval` | `true` | Stop for your approval after the plan |
| `max_fix_cycles` | `4` | Fix-loop passes before it stops and asks you |
| `max_stop_blocks` | `3` | Times the Stop gate may block before giving up |

---

## Scripts

All live in `plugins/storyforge/scripts/` in this repository. Once the plugin is installed they are in `~/.claude/plugins/cache/storyforge/storyforge/<version>/scripts/`, and inside Claude Code the path is `${CLAUDE_PLUGIN_ROOT}/scripts/`. In this README, `scripts/` stands for that folder. **Run them from your project's root**, because they read `docs/` and `storyforge.config.json` there.

| Script | Purpose | Example |
|--------|---------|---------|
| `init-project.sh` | Scaffolds config, memory, and `.gitignore` entries without overwriting anything | `bash scripts/init-project.sh` |
| `run-story.sh` | Runs `build-story` headless, resumes, or works through a queue file | `bash scripts/run-story.sh --queue stories.txt` |
| `story-check.sh` | Claim check and scope-overlap check against other developers' branches. Exit 3 means conflict | `bash scripts/story-check.sh <id> [scope.txt]` |
| `story-index.sh` | Regenerates `docs/stories/INDEX.md` | `bash scripts/story-index.sh` |
| `impact.sh` | Maps changed paths to areas and their dependents | `bash scripts/impact.sh --depth 2 src/billing/**` |
| `dep-scan.sh` | Suggests dependency edges from import lines | `bash scripts/dep-scan.sh` |

---

## Hooks: what is enforced automatically

These run without Claude choosing to, so they can't be talked around.

| Hook | When | What it does |
|------|------|--------------|
| `session-start` | New chat | Injects the small memory index and any in-progress story, so a new chat has project context |
| `edit-guard` | During `develop` and `fix` | **Test lock:** denies edits to test files, so code can't pass by changing its tests. **Scope lock:** denies edits outside `scope.txt` |
| `post-edit-format` | After an edit | Runs your formatter quietly on the edited file |
| `stop-gate` | When Claude tries to finish, in develop, fix, integrate, ui, verify | Blocks while tests, lint, or typecheck fail. Capped by `max_stop_blocks` |
| `check-careful` | Before shell commands | Asks before destructive commands and denies a small set of catastrophic ones. A best-effort guard, not a security boundary |

Overrides, for the rare justified case: `touch .storyforge/allow-test-edit` or `touch .storyforge/allow-scope-edit` lets one cycle through. A scope deviation must also be recorded in `plan.md` § Deviations.

---

## More safeguards

| Mechanism | What it does |
|-----------|--------------|
| **Subagents** | Each phase runs in its own context. Reviewers can't edit code. |
| **Product review** | Before planning: challenges the premise, finds existing code to reuse, picks a scope mode, and compares minimal, ideal and lateral approaches. `product_review`: `auto`, `always`, or `off`. |
| **Multi-model review** | Set `review.models` to for example `["opus","sonnet"]`: one reviewer per model, merged with lead judgment. Used automatically for auth, payments, data and concurrency stories. |
| **Test value bar** | Every new test must name the regression it catches and why existing coverage misses it. `/storyforge:test-audit` prunes low-value tests. |
| **UI tests** | Committed Playwright specs per acceptance criterion across desktop and mobile, with visual snapshots, axe accessibility checks and console-error checks, then a short exploratory pass with the Playwright MCP. Only when a story touches UI. |
| **Feature docs** | `docs/features/<feature>.md` with Mermaid sequence, state and ER diagrams, written from the built code. `docs.level`: `light` or `full`. |
| **Reflect** | After each story it proposes process improvements (conventions, rules, config, lesson enforcement) and applies them only when you approve. `/storyforge:reflect retro` gives metrics across stories. |
| **Ship** | `ship.mode`: `commit` (default), `pr`, or `pr-babysit`: sync and re-test, bisectable commits, changelog, a reviewer-friendly PR, then fix CI and handle review comments, up to 3 rounds. |
| **Plan approval** | `require_plan_approval`. It also always asks for auth, payments, data deletion and migrations. |

---

## How memory works (and saves tokens)

```
docs/memory/INDEX.md          only this loads at session start (80 lines or fewer, via hook)
docs/memory/ARCHITECTURE.md   opened when needed
docs/memory/DEPENDENCIES.md   the dependency map, opened by the impact phase
docs/memory/DECISIONS.md      D-### records, append-only
docs/memory/LESSONS.md        L-### bug classes and what enforces them
docs/memory/integrations/*.md one per service: contract, auth, quirks, tests, history
docs/stories/<id>/            story, plan, impact, findings, status, summary per run
docs/features/, ONBOARDING.md human docs; never auto-loaded, so they cost no tokens
```

At the start of a story, `memory-keeper` writes a slice of 80 lines or fewer (`context.md`) with only what's relevant. At the end, it files what was actually built and tested. The integration tester re-runs the tests of *other* integrations that share code with the change, which is how past integrations stay working. It's all in git, so it's reviewable and shared with your team.

---

## Files StoryForge creates

```
storyforge.config.json              commands and limits
docs/
  memory/
    INDEX.md                        one line per memory file (loaded at session start)
    ARCHITECTURE.md                 modules and boundaries
    DEPENDENCIES.md                 the dependency map
    DECISIONS.md                    design decisions (D-001, D-002, ...)
    LESSONS.md                      bug classes and how they're prevented (L-001, ...)
    integrations/<name>.md          one file per external service or boundary
  stories/
    INDEX.md                        every story, owner, phase, branch
    <id>/
      story.md  context.md  product.md  plan.md  scope.txt
      impact.md                     affected areas and decisions
      test-report.md  findings.md   review, security, break, integration, UI findings
      status.md                     owner, phase, fix cycles, checklist, definition of done, Blocked
      summary.md  reflect.md
  features/<feature>.md             per-feature docs with Mermaid diagrams
  ONBOARDING.md                     guide for new developers
.claude/skills/project-conventions/ project-specific conventions
.claude/rules/<area>.md             rules loaded only when those paths are touched
.storyforge/                        local run state (gitignored): phase, story, lock files
```

---

## Skills and agents

**Agents** (used by the pipeline): `planner`, `impact-analyst`, `test-writer`, `developer`, `reviewer`, `security-reviewer`, `breaker`, `integration-tester`, `ui-tester`, `doc-writer`, `memory-keeper`.

**Skills** you can call directly:

| Skill | Use it for |
|-------|-----------|
| `build-story` | The full pipeline for a story |
| `init-project` / `new-project` | Set up an existing repo / start from nothing |
| `impact-analysis` | What a change or issue affects; build or repair the dependency map |
| `blast-radius` | Prove, by running real code, why a change is safe |
| `product-review` | Challenge whether a story is the right thing to build |
| `review` / `security-review` / `thermo-nuclear-review` | Review a branch diff, standard or deep |
| `break-it` | Adversarial testing of freshly built code |
| `investigate` | Root-cause debugging, with recipes for flaky and order-dependent tests |
| `tdd` | Test-first work, when you ask for it |
| `test-audit` | Find low-value, duplicate, or can't-fail tests |
| `ui-test` | Playwright end-to-end testing |
| `feature-docs` | Docs with UML, architecture, data model, onboarding |
| `remember` | Read or update project memory |
| `reflect` | Learn from finished work and propose process improvements |
| `correct` | Make a repeated mistake impossible with structure, not more text |
| `ship` | Commits, PR, then watch CI and review comments |

`principle-*` skills (fix root causes, prove it works, subtract before you add, and others) are short rules the agents apply while working.

### Where the skills come from

| Skill | Source |
|-------|--------|
| build-story, new-project, init-project, impact-analysis, ui-test, feature-docs, remember, break-it, security-review | StoryForge (the security and QA taxonomy checklists are from gstack) |
| review | StoryForge, using gstack's checklist and specialists plus pstack's interrogate for multi-model mode |
| ship | merged: gstack ship + pstack fix-ci, get-pr-comments, babysit, make-pr-easy-to-review |
| product-review | merged: gstack office-hours + plan-ceo-review |
| reflect | merged: pstack reflect + gstack retro |
| investigate, test-audit | adapted from gstack |
| tdd, blast-radius, thermo-nuclear-review, correct, 11 × principle-* | pstack |

Built on ideas and files from [gstack](https://github.com/garrytan/gstack) and [pstack-claude](https://github.com/michael-denyer/pstack-claude). See `NOTICE.md`.

---

## Limits and honest caveats

- **The dependency map is a guide, not proof.** Edges come from a text search of import lines and from what people write in Notes. Events, queues, shared tables, HTTP calls, reflection and dynamic imports are only as good as the Notes. A listed dependent means "check it", not "it's broken". The impact-analyst verifies each one against the code, but an area missing from the map can still be missed.
- **Monorepos with shared libraries** need an area per shared package, or changes there show as `UNMAPPED`.
- **"Done" is only as strong as the criteria.** The matrix checks that every criterion and rule has evidence. It can't tell you that the story missed a requirement. The approval gate after the plan is where you catch that.
- **The loop has limits on purpose.** `max_fix_cycles` and `max_stop_blocks` stop it from looping forever. When they trigger, it asks you and lists what is open.
- **Team features see only the shared remote.** Developers on forks or offline aren't visible. There is no sync with Jira, GitLab issues, or Linear.
- **Lint and typecheck gates only work if the commands in the config are real.** If they're blank they're skipped silently.
- **`check-careful` is not a security boundary.** It's best-effort string matching.

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---------|----------------------|
| `No storyforge.config.json` | Run `/storyforge:init-project` first |
| Stop gate blocks but the output is unclear | It prints the last 40 lines of the failing command. Run the same command yourself |
| Edit denied during develop or fix | The test lock or scope lock. If the scope is genuinely too narrow, record a deviation in `plan.md` and `touch .storyforge/allow-scope-edit` |
| `no dependency map at docs/memory/DEPENDENCIES.md` (exit 4) | Run `/storyforge:impact-analysis map`, or `init-project` |
| Everything shows `UNMAPPED` | The Paths globs in the map don't match your layout. Edit the Paths column |
| `story-check.sh` says `could not fetch origin` | No remote or no network. It checked local refs only |
| A story is stuck | Open `docs/stories/<id>/status.md`: `## Blocked` lists exactly what needs you. Fix it, then `--resume <id>` |
| Hooks do nothing on Windows | `python3` must be on the PATH for Git Bash; the hooks use it to read the config |

---

## Contributing

Open a merge request against `main`. Describe the change, how you tested it, and bump the version in both `plugins/storyforge/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Keep skills and agents small and specific, with frontmatter (`name`, `description`) that says when to use them. Changes to hooks or scripts need extra care because they run commands on users' machines.

StoryForge includes ideas and code adapted from gstack and pstack; see `NOTICE.md` and `licenses/`.
