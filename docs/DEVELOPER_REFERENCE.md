# StoryForge — Detailed Reference

> This reference includes historical workflow instructions from earlier versions. For current installation, safety defaults and exact verification behavior, use the root README and ENGINEERING_ARCHITECTURE.md.

## Install

In Claude Code:

```
/plugin marketplace add https://github.com/amitesh04081988/storyforge
/plugin install storyforge@storyforge
```

You can also install from a local clone: `/plugin marketplace add /path/to/storyforge`. Update later from the same `/plugin` menu, or reinstall.

**Requirements:** Claude Code, `git`, `bash` (Git Bash on Windows), and `python3` on the PATH (the hooks use it to read the config). Node.js for Playwright (UI stories) and for the transcript finder in `reflect full`. For the PR step you also need `gh` (GitHub) or `glab` (GitLab); without them StoryForge stops after committing.

## Update an existing install

Updating is two steps: refresh the marketplace (to learn that a new version exists), then update the plugin. A restart is needed to apply it.

```bash
claude plugin list                                  # which version is installed, and its scope
claude plugin marketplace update storyforge         # pull the latest from the repository
claude plugin update storyforge@storyforge          # install the newer version
```

Then **restart Claude Code** (or start a new session). Check that it took:

```bash
claude plugin list                                  # storyforge@storyforge should show the new version
claude plugin details storyforge                    # components in the plugin and their projected token cost
```

The same steps are available inside Claude Code from the `/plugin` menu: update the marketplace, then update `storyforge`.

**Things to know**
- **Scope.** `claude plugin list` shows whether the plugin is installed for a `project` or for the `user`. Update it where it is installed; a project-scoped install has to be updated for each project that uses it.
- **Updates are detected by version number.** If `claude plugin update` says it is already up to date but you expect a newer version, run `claude plugin marketplace update storyforge` first, and check that the version in `.claude-plugin/marketplace.json` on `main` is higher than the installed one.
- **Stories in progress keep working.** Their state lives in your repository (`docs/stories/<id>/status.md`), not in the plugin. After updating, `/storyforge:build-story --resume <id>` continues from the first unfinished phase.

**What to do in a project that is already set up.** No config changes are required: every new setting has a default, and existing files are never overwritten. Read the rows for every version newer than the one you are updating from:

| Version | What changed | Do this |
|-----------------|--------------|---------|
| 0.4 | Definition-of-done matrix, HIGH severity, lint and typecheck in the Stop gate | Check that `lint` and `typecheck` in `storyforge.config.json` are real commands, or blank to skip |
| 0.5 | Story index, claim and overlap checks, `status.md` gets `owner:` and `phase:` | Nothing. `docs/stories/INDEX.md` appears when the next story is committed. Set `claim.push_early` to `false` if you do not want the branch pushed after planning |
| 0.6 | Dependency map and the impact phase | Run `/storyforge:impact-analysis map` once to create `docs/memory/DEPENDENCIES.md`. Without it, the first story builds it. Set `impact.enabled` to `false` to opt out |
| 0.7 | Fail-closed hooks, guard, scripted done check, model tiering, light mode | Make sure `python3`, `python` or `py -3` runs in your shell (see [Troubleshooting](#troubleshooting)). Optionally add `models`, `light_mode` and `guard.ignore` to the config (defaults apply when absent) |
| 0.8 | Feature map and parallel agents | New `docs/memory/FEATURES.md` (the sitemap of features: entry points, paths, docs, tests); `feature-map.sh list/find/check`. Re-run `/storyforge:init-project` to create it. Plans now split into work units that run as parallel agents, and full-mode review runs `opus` and `sonnet` side by side. `parallel.max_workers: 1` restores one-at-a-time
| 0.9 | `bits-mode` router and 40 more skills | New: `/storyforge:bits-mode` picks the right skill for a task. Added `architect`, `arena`, `swarm`, `how`, `why`, `figure-it-out`, `deslop`, `no-comments`, `unslop`, `statechart`, `create-verification-skill`, `benchmark-checklist`, 13 more principles and others. `/storyforge:setup-bits` writes `~/.claude/bits-models.md`. Nothing to migrate
| 0.10 | Manager loop and parallel programs | `/storyforge:bits-mode` now runs a task ledger (`.storyforge/tasks.sqlite`): it assigns each task, verifies it, updates the feature map, dependency map and memory, and repeats until all are done or blocked. Minor tasks take light mode. Independent stories run in parallel, one `git worktree` and one headless session each, and a PR is mergeable only when its verdict was recorded at its current head commit. Needs `gh` and, for parallel stories, the `claude` CLI. Nothing to migrate
| 0.10.1 | Merge gate names its verifier | `bits-tasks.sh pr` now takes two more arguments, `<builder> <verifier>`, and `mergeable` refuses a verdict where they match or are missing. Rows recorded before this have neither, so re-record them. A blank `test`, `lint` or `typecheck` now triggers a warning at session start

To see the new keys next to your own, compare your `storyforge.config.json` with `plugins/storyforge/skills/init-project/templates/storyforge.config.json` in this repository, or run `/storyforge:init-project` again. Re-running it on a set-up project refreshes detection and docs and only adds to memory, never overwrites it.

---

## Quick start

**1. Set up the repository once** (new or existing):

```
/storyforge:init-project
```

- **Empty repo:** it interviews you, recommends 2 or 3 tech stacks with trade-offs, scaffolds a working app with tests, lint and CI, then continues as below.
- **Existing code:** it reads the manifests, shows you a stack summary tagged `detected` or `guess`, asks only what the code can't tell it (deploy targets, how to run integration tests, UI login, team rules), then writes `storyforge.config.json`, project memory, a conventions skill, onboarding docs, and the **dependency map**.

Open `storyforge.config.json` and check that `test`, `lint`, and `typecheck` are the real commands for your project. The gates only protect you if these are right.

**2. Tell bits-mode what you want:**

```
/storyforge:bits-mode Add CSV export for orders, fix the login redirect bug, and update the API docs
```

One sentence works too. It decides what is one story and what is several, how big each is, and what order to do them in.

**3. Come back to it, or resume it:**

```
/storyforge:bits-mode resume
```

It reads its task ledger, the story branches and the open PRs, and carries on from where it stopped.

You can still run a single story directly with `/storyforge:build-story <story>`. That is the engine `bits-mode` uses, and it is the right tool only when you have exactly one story and want no task queue, no parallel runs and no merge gate.

**Running unattended** (outside a chat, for example overnight or in a queue):

```bash
bash scripts/run-story.sh "As a customer I can export my orders as a CSV file"
bash scripts/run-story.sh --resume 20261027-orders-csv-export
bash scripts/run-story.sh --queue stories.txt      # one story per line, stops at the first that needs a human
```

For unattended runs, add Bash allow rules for your test, lint and git commands in `.claude/settings.json`. Only use `--dangerously-skip-permissions` inside a disposable container.

Unattended runs stop at anything that needs a person (plan approval, a product question, a blocked fix loop) and mark the story `needs-approval` or `## Blocked` instead of guessing.

---

## Bits mode: the manager

`/storyforge:bits-mode <task>` is the single entry point. It restates your goal, then routes the task: a story to `build-story`, an unknown bug to `investigate` or `why`, a design choice to `architect` or `arena`, broad parallel work to `swarm`, a vague request to `sharpen`. It is modelled on pstack's `poteto-mode`, rebuilt on StoryForge's pipeline.

**The manager loop** runs when the request has several tasks (`playbooks/manager-loop.md`):

1. **Queue.** Each task goes into a ledger, `.storyforge/tasks.sqlite`, with its dependencies and a mode: `direct` (docs, config, a one-line fix), `light` (a bug fix or small tweak: 3 files or fewer, no auth, payments, data, migration, UI or integration) or `full`.
2. **Assign.** It takes the tasks whose dependencies are done, up to `parallel.max_workers`, and gives each to the right agent or to `build-story`.
3. **Verify.** It runs the config's test, lint and typecheck itself and runs `dod-check.sh`. A report of "done" is not evidence.
4. **Update.** The story's memory phase updates `FEATURES.md`, `DEPENDENCIES.md`, decisions and lessons. Light mode does this too whenever a feature's paths or a dependency changed. Then `feature-map.sh check` and `impact.sh` run on the merged branch.
5. **Repeat** until `bits-tasks.sh status` exits 0. It stops only for a blocked task, a product decision, an irreversible action, or a pass that made no progress. A task that fails twice is blocked and you are asked.

**Parallel stories** (`playbooks/program.md`) give each independent story its own `git worktree` and its own headless `claude -p` session via `run-story.sh`. A subagent cannot spawn subagents, so one session per story is how each story keeps its full set of role agents. Independent verification uses a different model from the one that built the change. A wave of more than two sessions needs your go first, because each session is a full pipeline.

**The merge gate** is code, not judgment. `bits-tasks.sh pr` records what was verified and at which head commit. `bits-tasks.sh mergeable` succeeds only if the verdict is `live-ui-verified` or `unit-test-verified` and was recorded at the PR's current head. `pr-watch.sh` must also say READY (CI green, no conflicts, no review outstanding). With `ship.auto_merge` on (the default), the coordinator merges with `gh pr merge --squash --match-head-commit <sha>`, which GitHub refuses if the head moved. Story sessions are denied `gh pr merge`.

`/storyforge:bits-mode resume` continues after a restart. The session-start hook lists unfinished tasks.

**What it brings with it.** `bits-mode` is also the way into the skills ported from pstack: `architect`, `arena`, `swarm`, `how`, `why`, `figure-it-out`, `deslop`, `no-comments`, `unslop`, `technical-writing`, `typescript-best-practices`, `thermo-nuclear-code-quality-review`, `statechart`, `create-verification-skill`, `benchmark-checklist`, `recall`, `sharpen`, `teach` and more, plus all 23 `principle-*` skills. `/storyforge:setup-bits` writes `~/.claude/bits-models.md`, a per-role model sheet (for example `arena runners: opus, sonnet`).

**Headless runs** need Bash allow rules. Start from `skills/init-project/templates/claude/settings.headless.json`: it allows the project's test commands, local git and the plugin scripts, and denies push, reset, rebase, curl and installs.

### Example: two tasks, start to finish

This is a real run on a small Node library called `textkit` (one function, `capitalize`). The agents ran inside one Claude Code session.

```
/storyforge:bits-mode Add slugify(text) and wordCount(text) to textkit, each exported from src/index.js and listed in the feature map
```

**1. Frame and look.** It restates the goal, then runs `feature-map.sh find slugify wordcount`. Neither exists, so both are new features.

**2. Queue.** Two tasks go in the ledger, both `light` (one new function each, three files or fewer, no auth, data or UI):

```
1  light  slugify
2  light  wordCount
```

Each gets its own git worktree. The manager compares the two plans' scopes and notices they share `src/index.js` and `FEATURES.md`.

**3. Waves, two agents at a time.** Planners, then test-writers, then developers, each pair in a single message. After every wave the manager checks the work itself:

| After | The manager runs | Saw |
|---|---|---|
| tests | `npm test` in each worktree | both fail with "module not found", the predicted reason |
| develop | tests, lint, `feature-map.sh check`, a scope check | 12 of 12 and 11 of 11 pass, every changed file inside the plan's scope |

**4. Verdicts and the merge gate.** It records `unit-test-verified` against each branch's head commit. slugify merges first. wordCount is rebased onto the result:

- `FEATURES.md` merges by itself (rows are one line each, `merge=union`).
- `src/index.js` conflicts, because both stories added an export. Both are kept.
- The rebase changed wordCount's head commit, so the gate **refused its old verdict**: `NOT MERGEABLE: task 2 was verified at 1e0942c… but the PR head is 160e83d…; re-verify` (hashes shortened here).
- It re-ran everything on the new head (21 of 21 tests), recorded a fresh verdict, and only then merged.

**5. Result.** The ledger shows 2 of 2 done, the feature map lists all three functions, and a review run afterwards flagged one real defect: `slugify(undefined)` throws while `capitalize` returns an empty string.

With `build-story` alone you would run the two stories one after another in one checkout. That is slower, and nothing would track both in one ledger, update the shared feature map between them, or hold a merge until its evidence matches the commit being merged.

Not covered by this run: the variant where every story is its own headless `claude -p` session (`playbooks/program.md`). That path exists but has not been run end to end.

### When to use which

| You have | Use |
|---|---|
| A request with several tasks, a backlog, "keep going until it's all done" | `bits-mode` |
| One story, and you want it handled completely | `bits-mode` too: it runs one task through `build-story` |
| Independent stories you want built at the same time | `bits-mode` (one worktree and session per story, with a cost check first) |
| Work you left half-finished, or a restart | `bits-mode resume` |
| A bug with an unknown cause, a design question, "how does this work" | `bits-mode` routes it to `investigate`, `architect`, `how` and the other skills |
| Exactly one story, no queue, no merge gate | `build-story` directly |

---

## How a story runs

_This is the engine `bits-mode` runs for each task. Use it directly only for a single story._

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

Every project also gets a **feature map**, `docs/memory/FEATURES.md`: a sitemap of what the product does. Each row names a feature, how it is reached (route, screen, command, job), the code paths that implement it, its doc, its tests, and the stories that changed it. Agents run `feature-map.sh find <word>` before they plan or code, so they land in the right place instead of building a second copy. `feature-map.sh check` flags rows whose paths no longer exist.

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

The matrix is **checked by a script, not by the model's word**. `scripts/dod-check.sh <id>` fails if any row lacks evidence or a pass, if a criterion in `plan.md` has no row (numbered `1.` or labelled `AC1:`, `AC-2.`, `R3)`; ids are compared ignoring case and dashes), if a `check` or `change` area from `impact.md` isn't named in a row, or if a CRITICAL or HIGH finding is still open (a finding is closed by `FIXED:` on its line or the line under it). Every agent, including the UI and integration testers, writes findings as `- [CRITICAL|HIGH|INFO] ...`, and the check matches the tags ignoring case:

```
$ bash scripts/dod-check.sh 20261027-orders-csv-export
DOD FAIL: row 2 (401 signed-out): no evidence
DOD FAIL: acceptance criterion 4 has no row in the matrix
DOD FAIL: open finding: - [HIGH] src/a.ts:9 — missing header → add it
DOD: story 20261027-orders-csv-export is NOT done
```

**If verify fails,** StoryForge doesn't stop and doesn't report success. It sets the phase back to `fix`, records each failing row or command as a HIGH finding, and re-enters the fix loop. It ends either with a fully passing matrix or in `## Blocked` with the failing rows listed, after at most `max_fix_cycles` passes.

The **Stop gate** adds a second guard: while a story is in `develop`, `fix`, `integrate`, `ui` or `verify`, Claude can't finish its turn while tests, lint or typecheck fail (the UI phase checks tests and e2e). In `develop` and `fix` it also fails on test or out-of-scope file changes (see [the guard](#the-guard-test-and-scope-locks)), and in `verify` it runs `dod-check.sh`. It gives up after `max_stop_blocks` attempts so it can never loop forever, and tells you what is still failing.

---

## Light mode for small stories

Most stories don't need 17 phases. A one-line fix shouldn't pay for product review, break-it, docs and reflect. After the plan and impact are written, StoryForge picks a mode and records it as `mode: light` or `mode: full` in `status.md`, with a one-line reason.

```
/storyforge:build-story Fix: the CSV export shows 0.1 as 0.10000000000000001 --light
/storyforge:build-story Add refunds to the billing flow --full
```

With no flag, `light_mode: "auto"` (the default) chooses light only when **all** of these hold: the plan changes 3 files or fewer, touches no integration, needs no approval (no auth, payments, data deletion or migration), touches no UI, and the story is a bug fix, small tweak or one small function. If in doubt it runs full. `"off"` always runs full.

| | Light | Full |
|---|-------|------|
| Runs | recall, plan, impact (analyst only if dependents exist), tests, develop, **one** review pass, fix loop, verify, commit | all 17 phases |
| Skips | product, break, integrate, UI, docs, memory update, reflect. Security runs only if the diff touches auth, sessions, tokens, crypto, payments, uploads or SQL | nothing |
| **Never skipped** | failing tests first, guard checks, stop gate, review, **the definition-of-done matrix and `dod-check.sh`** | same |

Light mode **escalates to full** automatically when the fix loop reaches 2 cycles, when review or security finds a CRITICAL, or when the work grows past 3 files or needs a scope deviation. The skipped break and security phases then run.

---

## The guard: test and scope locks

During `develop` and `fix` two rules apply: **test files are locked** (code can't pass by changing its tests) and **edits must stay inside `scope.txt`**.

The `edit-guard` hook enforces them for the Edit and Write tools. But a shell command (`sed -i`, a `>` redirect, a script) can change a file without going through those tools. `scripts/guard.sh` closes that gap by comparing files, so it catches every way a file can change:

```bash
bash scripts/guard.sh snapshot     # start of develop and of every fix cycle: hash all files, copy test files
bash scripts/guard.sh check        # after the developer returns, and in the Stop gate
bash scripts/guard.sh restore      # put test files back from the snapshot; never touches production code
```

Example, after a developer rewrote an assertion with `sed -i`, created a test with a redirect, and wrote a file outside the scope:

```
$ bash scripts/guard.sh check
guard: locked files changed outside the allowed path
TEST-LOCK  tests/a.test.ts was modified since the snapshot. Test files are locked; run guard.sh restore, then fix the production code.
TEST-LOCK  tests/b.test.ts was added since the snapshot. ...
SCOPE      config/x.json changed but is outside scope.txt. Revert it, or record the reason in plan.md under Deviations ...
$ bash scripts/guard.sh restore
restored tests/a.test.ts
removed new test file tests/b.test.ts
```

A test-lock violation becomes a CRITICAL gate-integrity finding and the developer is sent back.

**What is not a violation:** generated output and logs (`node_modules`, `dist`, `build`, `coverage`, `test-results`, `playwright-report`, `__pycache__`, `*.log`, `*.tmp`, `.claude/`), lock files such as `package-lock.json` for the scope check, and **snapshot files a test run creates for the first time** (`__snapshots__`, `*.snap`, `*-snapshots`). Add your own patterns with `guard.ignore` in the config. **Changing or deleting an existing snapshot is still a test-lock violation**, because updating a snapshot is how a failing snapshot test gets "fixed" without fixing the code. This is a check after the fact, not a block in the moment: a bad change can exist briefly, but it can't get through verify or the Stop gate.

---

## The feature map

`docs/memory/FEATURES.md` is the sitemap of what the product does. One row per feature:

| Column | Meaning |
|---|---|
| Feature | Unique name |
| Entry | How a user or caller reaches it: route, screen, command, job |
| Paths | Globs that implement it |
| Area | Its `DEPENDENCIES.md` area |
| Status | `live`, `beta`, `planned`, `deprecated` |
| Doc, Tests, Stories | Its doc, its tests, and the stories that changed it |

Agents run `feature-map.sh find <word>` before planning or coding, so they extend what exists instead of building a second copy. The planner records which feature a story extends (or `NEW`), the memory phase updates the row, and `feature-map.sh check` in verify flags rows whose paths no longer exist or whose doc is missing. `init-project` seeds it from the code and sets `merge=union` in `.gitattributes` so rows added by parallel stories merge without conflicts. It answers "what exists and where"; `DEPENDENCIES.md` answers "what breaks if I change it".

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
| `review.models` | `["opus","sonnet"]` | Full mode runs one reviewer per model in parallel; light mode always uses one |
| `parallel.max_workers` | `1` | Most agents launched at once per wave (work units, fix groups). `1` runs everything one at a time |
| `scope_lock` | `true` | Block edits outside `scope.txt` during develop and fix |
| `reflect.after_each_story` | `true` | Propose process improvements after each story |
| `reflect.retro_every_n_stories` | `10` | When to suggest a retro |
| `ship.mode` | `commit` | `commit`, `pr`, or `pr-babysit` (opens the PR and fixes CI and review comments) |
| `ship.auto_merge` | `false` | The orchestrator merges a PR itself, but only when `pr-watch.sh` says READY (CI green, no conflicts, no review outstanding) and, in a bits-mode run, `bits-tasks.sh mergeable` confirms the verdict covers the exact head commit. It merges with `gh pr merge --squash --match-head-commit <sha>`, so a head that moved after verification is refused. Set `false` to merge by hand |
| `impact.enabled` | `true` | Run the impact phase |
| `impact.max_depth` | `3` | How many hops of dependents to follow |
| `claim.push_early` | `true` | Push the story branch after planning so others see the claim |
| `require_plan_approval` | `true` | Stop for your approval after the plan |
| `max_fix_cycles` | `4` | Fix-loop passes before it stops and asks you |
| `max_stop_blocks` | `3` | Times the Stop gate may block before giving up |
| `guard.ignore` | `[]` | Extra glob patterns the guard treats as generated output, on top of the built-in list |
| `light_mode` | `auto` | `auto`, or `off` to always run all phases. `--light` and `--full` on the command override it |
| `models` | memory-keeper, doc-writer, integration-tester, ui-tester on `sonnet` | Model per agent, overriding the agent's default. Agents not listed use their default (planner, impact-analyst, test-writer, developer, reviewer, security-reviewer and breaker inherit your session's model) |

---

## Scripts

All live in `plugins/storyforge/scripts/` in this repository. Once the plugin is installed they are in `~/.claude/plugins/cache/storyforge/storyforge/<version>/scripts/`, and inside Claude Code the path is `${CLAUDE_PLUGIN_ROOT}/scripts/`. In this README, `scripts/` stands for that folder. **Run them from your project's root**, because they read `docs/` and `storyforge.config.json` there.

| Script | Purpose | Example |
|--------|---------|---------|
| `init-project.sh` | Scaffolds config, memory, and `.gitignore` entries without overwriting anything | `bash scripts/init-project.sh` |
| `run-story.sh` | Runs `build-story` headless, resumes, or works through a queue file | `bash scripts/run-story.sh --queue stories.txt` |
| `story-check.sh` | Claim check and scope-overlap check against other developers' branches. Exit 3 means conflict | `bash scripts/story-check.sh <id> [scope.txt]` |
| `story-index.sh` | Regenerates `docs/stories/INDEX.md` | `bash scripts/story-index.sh` |
| `guard.sh` | Snapshot, check and restore for test and scope locks, however a file was changed | `bash scripts/guard.sh check` |
| `dod-check.sh` | Checks a story's definition of done with code. Exit 1 means not done | `bash scripts/dod-check.sh <id>` |
| `impact.sh` | Maps changed paths to areas and their dependents | `bash scripts/impact.sh --depth 2 src/billing/**` |
| `dep-scan.sh` | Suggests dependency edges from import lines | `bash scripts/dep-scan.sh` |
| `feature-map.sh` | Lists, searches and checks the feature map. `check` exits 1 on stale rows | `bash scripts/feature-map.sh find export` |
| `bits-tasks.sh` | The manager's task ledger and merge gate (`add`, `next`, `set`, `pr`, `mergeable`, `status`) | `bash scripts/bits-tasks.sh mergeable 2 <head-sha>` |
| `worktree.sh` | One git worktree per task; refuses to remove one with uncommitted changes | `bash scripts/worktree.sh add <task-id>` |
| `pr-watch.sh` | One-line PR state from `gh`: READY, WAIT, ACT or CLOSED, by exit code | `bash scripts/pr-watch.sh 41` |

---

## Hooks: what is enforced automatically

These run without Claude choosing to, so they can't be talked around.

| Hook | When | What it does |
|------|------|--------------|
| `session-start` | New chat | Injects the small memory index and any in-progress story, so a new chat has project context |
| `edit-guard` | During `develop` and `fix` | **Test lock:** denies edits to test files, so code can't pass by changing its tests. **Scope lock:** denies edits outside `scope.txt`. Only sees the Edit and Write tools; `guard.sh` covers the rest |
| `post-edit-format` | After an edit | Runs your formatter quietly on the edited file |
| `stop-gate` | When Claude tries to finish, in develop, fix, integrate, ui, verify | Blocks while tests, lint or typecheck fail; in develop and fix, while `guard.sh check` fails; in verify, while `dod-check.sh` fails. Capped by `max_stop_blocks` |
| `check-careful` | Before shell commands | Asks before destructive commands and denies a small set of catastrophic ones. A best-effort guard, not a security boundary |

**The hooks fail closed.** They need a working Python 3 (`python3`, `python` or `py -3`; each one is actually run, because on Windows `python3` is often a Microsoft Store shortcut that exists but fails). The working command is remembered in `.storyforge/python` so later hooks skip the slow failing probes (only the exact values `python3`, `python` and `py -3` are accepted from that file, because its content is run as a command), and a hook that has nothing to do (for example the format hook with no formatter configured) never starts Python. With none working, the hooks block and say why instead of silently doing nothing, and the session-start hook warns you.

**The hooks only act on state from a run on this machine.** `.storyforge/` is local run state and is gitignored. If git tracks anything in it, it came from the repository (a clone, a merge, a hostile commit) and not from a run here, so every hook stands down, `guard.sh` refuses, `build-story` stops at setup, and the session-start hook prints a warning. Without this rule a repository could commit `.storyforge/phase` and a test command in `storyforge.config.json` and have the Stop gate run that command when you open it. To fix a repository that tracks it: `git rm -r --cached .storyforge` and add `.storyforge/` to `.gitignore`.

Overrides, for the rare justified case: `touch .storyforge/allow-test-edit` or `touch .storyforge/allow-scope-edit` lets one cycle through (then take a new `guard.sh snapshot`). `touch .storyforge/allow-no-python` lets the hooks stand down when Python really is unavailable. A scope deviation must also be recorded in `plan.md` § Deviations.

---

## More safeguards

| Mechanism | What it does |
|-----------|--------------|
| **Subagents** | Each phase runs in its own context. Reviewers can't edit code. |
| **Model tiering** | Mostly mechanical agents (memory-keeper, doc-writer, integration-tester, ui-tester) default to `sonnet`; the judgment-heavy ones use your session's model. Change any of them with `models` in the config. |
| **Product review** | Before planning: challenges the premise, finds existing code to reuse, picks a scope mode, and compares minimal, ideal and lateral approaches. `product_review`: `auto`, `always`, or `off`. |
| **Multi-model review** | Default in full mode: one reviewer per model in `review.models` (`opus`, `sonnet`), run in parallel with the security review and merged with lead judgment. Auth, payments, data and concurrency stories always get at least two. |
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
    FEATURES.md                     the feature map (sitemap)
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
.storyforge/                        local run state (gitignored): phase, story, lock files, tasks.tsv
.gitattributes                      merge=union for FEATURES.md and DEPENDENCIES.md
<repo>.worktrees/<task-id>/         one worktree per parallel story (outside the repo)
```

---

## Skills and agents

**Agents** (used by the pipeline): `planner`, `impact-analyst`, `test-writer`, `developer`, `reviewer`, `security-reviewer`, `breaker`, `integration-tester`, `ui-tester`, `doc-writer`, `memory-keeper`.

**Skills** you can call directly:

| Skill | Use it for |
|-------|-----------|
| `bits-mode` | Start here: routes a task, or manages a queue of tasks until all are done |
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

Added in 0.9 and 0.10:

| Skill | Use it for |
|-------|-----------|
| `architect` / `arena` / `swarm` | Design the shape first / competing attempts merged / parallel fan-out |
| `how` / `why` / `figure-it-out` | Explain code / trace its history / design a bespoke plan for an odd task |
| `deslop` / `no-comments` / `unslop` | Remove AI-style code, comments and prose |
| `create-verification-skill` / `statechart` / `benchmark-checklist` | Run-the-real-app checks / state machines / vet a performance number |
| `setup-bits` | Choose the model per role |

`principle-*` skills (23 in all: fix root causes, prove it works, subtract before you add, and others) are short rules the agents apply while working. Not listed above: `recall`, `sharpen`, `teach`, `ketchup`, `show-me-your-work`, `what-did-i-get-done`, `technical-writing`, `typescript-best-practices`, `thermo-nuclear-code-quality-review`, and the formal-verification skills.

### Where the skills come from

| Skill | Source |
|-------|--------|
| build-story, new-project, init-project, impact-analysis, ui-test, feature-docs, remember, break-it, security-review | StoryForge (the security and QA taxonomy checklists are from gstack) |
| review | StoryForge, using gstack's checklist and specialists plus pstack's interrogate for multi-model mode |
| ship | merged: gstack ship + pstack fix-ci, get-pr-comments, babysit, make-pr-easy-to-review |
| product-review | merged: gstack office-hours + plan-ceo-review |
| reflect | merged: pstack reflect + gstack retro |
| investigate, test-audit | adapted from gstack |
| tdd, blast-radius, thermo-nuclear-review, correct, 23 × principle-* | pstack |
| architect, arena, swarm, how, why, figure-it-out, deslop, no-comments, unslop, statechart, and the other skills listed above | ported from pstack (MIT), renamed |
| bits-mode, setup-bits, the manager loop, `bits-tasks.sh`, `pr-watch.sh`, `worktree.sh`, `feature-map.sh` | StoryForge, with ideas from pstack's orchestrate, autopilot, shipping and babysit playbooks |

Built on ideas and files from [gstack](https://github.com/garrytan/gstack) and [pstack-claude](https://github.com/michael-denyer/pstack-claude). See `NOTICE.md`.

---

## Limits and honest caveats

- **Parallel headless stories are not yet proven end to end.** The task ledger, worktrees, merge gate, review and edit guard have been exercised on a small project. Running two full `run-story.sh` sessions at once has not, and each session is a full pipeline, so it costs roughly N times one story. Try one small wave first.
- **The merge gate checks who verified, not how well.** A verdict must match the PR's current head commit and must name a builder and a different verifier (a model, or `manager` when the coordinator ran the gates itself). It cannot tell whether the verifier was thorough, and it takes the names on trust. `READY` from `pr-watch.sh` reflects GitHub's CI and review state only.
- **`ship.auto_merge` only matters with `ship.mode` set to `pr` or `pr-babysit`.**
- **The dependency map is a guide, not proof.** Edges come from a text search of import lines and from what people write in Notes. Events, queues, shared tables, HTTP calls, reflection and dynamic imports are only as good as the Notes. A listed dependent means "check it", not "it's broken". The impact-analyst verifies each one against the code, but an area missing from the map can still be missed.
- **Monorepos with shared libraries** need an area per shared package, or changes there show as `UNMAPPED`.
- **"Done" is only as strong as the criteria.** The matrix checks that every criterion and rule has evidence. It can't tell you that the story missed a requirement. The approval gate after the plan is where you catch that.
- **The loop has limits on purpose.** `max_fix_cycles` and `max_stop_blocks` stop it from looping forever. When they trigger, it asks you and lists what is open.
- **Team features see only the shared remote.** Developers on forks or offline aren't visible. There is no sync with Jira, GitLab issues, or Linear.
- **Trust model.** `storyforge.config.json` holds the commands your gates run (your tests, lint and typecheck), so it is trusted the way `package.json` scripts are. Only run StoryForge stories in repositories you trust. The hooks no longer run anything just because a repository supplied state files, but a repository you do build a story in decides what its own test command is.
- **Lint and typecheck gates only work if the commands in the config are real.** A blank command is still skipped, but no longer silently: the session-start hook warns which of `test`, `lint` and `typecheck` are blank, and `build-story` writes `gate skipped: <name> is blank` in `status.md` so the final report says which checks never ran.
- **The guard cannot tell a first-time snapshot from a wrongly written one.** It allows new snapshot files because test runs create them; review new snapshots like any other expected value. It is also a check after the fact. `guard.sh` finds a changed test or out-of-scope file when the developer returns or the Stop gate runs; it does not stop the write in the moment. It also can't see a change that is made and then undone before the next check.
- **Passing tests are not proof of correct code.** The tests come from the same acceptance criteria the code is built from. If a criterion is wrong or missing, tests and code can agree and both be wrong. No mutation testing or coverage measurement is included. The plan-approval gate is where you catch this.
- **Cost.** `build-story` itself is about 15 KB (roughly 3.8K tokens) each time it loads, and its light-mode details load only when light mode is chosen. A full story runs many agents and costs several times a direct prompt. Light mode and cheaper models for mechanical agents reduce this; they don't make it cheaper than a plain prompt for a tiny change.
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
| `No working Python 3 was found` from a hook | Install Python 3 or fix the PATH so `python3`, `python` or `py -3` runs in Git Bash. On Windows, turn off the Microsoft Store "python3" alias or put a real Python first. Until then the hooks block on purpose; `touch .storyforge/allow-no-python` lets them stand down |
| `.storyforge/ is tracked by git` | The run state was committed. Run `git rm -r --cached .storyforge`, add `.storyforge/` to `.gitignore`, and commit. Until then the hooks ignore the state on purpose |
| `guard: no snapshot` | Run `bash scripts/guard.sh snapshot`; `build-story` does this at the start of develop and of every fix cycle |
| `DOD FAIL: ...` | Each line names the row, criterion or finding that is missing. Fix it and run `dod-check.sh` again |

---

## Contributing

Open a merge request against `main`. Describe the change, how you tested it, and bump the version in both `plugins/storyforge/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`. Bump it so installed copies see the change as an update. Keep skills and agents small and specific, with frontmatter (`name`, `description`) that says when to use them. Changes to hooks or scripts need extra care because they run commands on users' machines.

StoryForge includes ideas and code adapted from gstack and pstack; see `NOTICE.md` and `licenses/`.
