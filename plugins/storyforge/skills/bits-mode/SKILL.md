---
name: bits-mode
description: "bits-mode is StoryForge's working style and router: concise replies, deliberate parallel subagents, simple code, verified work. It picks the right skill for the task (build-story for a feature, why/investigate for a bug, architect/arena for a design, deslop before commit) and sets the rules every agent follows. Use for /bits-mode, 'work in bits mode', or any task that touches more than one file, makes a design choice, or has an unknown bug cause."
argument-hint: "<task>"
---

# Bits mode

Bundled skills live at `../<name>/SKILL.md` from this file. Put this file's absolute path in every `bits-agent` prompt.

## Start

If the argument is `resume`, follow `playbooks/resume.md` and skip the rest of this section.

1. Tell the user, in your own words, their goal, the problem they are solving, and the smallest change you expect to meet it. Don't wait for confirmation. If the evidence rules out the change they asked for, show it and stop. Put this goal in every subagent brief and open the final report with it.
2. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/feature-map.sh" find <nouns>` and read `docs/memory/INDEX.md` if they exist, so you land in the right place.
3. Route with the table below. Open a todolist with the routed steps. A step you skip stays in the list with `skip: <reason>`.

## Manager

For any request with more than one task, you act as the senior manager: assign each task to the right agent, verify the result yourself, update the feature map, dependency map and memory, and go again until every task is done or blocked. Read and follow `playbooks/manager-loop.md`. It sets the mode per task (`direct`, `light`, or `full`), so a minor change takes the light path, and it keeps the task ledger (`scripts/bits-tasks.sh`) so the loop survives a restart.

- Several independent stories at once, or a queue of PRs: `playbooks/program.md` (one worktree and one headless session per story, independent verification, a merge gate tied to the PR's head commit).
- Resuming after a restart or pausing: `playbooks/resume.md`.
- A single story, or one contained edit, needs no ledger: use the router.

## Deterministic safety and goal contract

- Assess risk before planning, after the plan and after the actual diff. One-file auth, permissions, security, payment, privacy, production migration, concurrency or privileged config changes always require `full` / strict behavior.
- For a coding task, define observable acceptance criteria and required checks before declaring a result. The manager may propose implementation; only executed checks may provide PASS evidence.
- Never mark a task `done` when a required gate is absent or failing, the current revision differs from the verified revision, or an approval is missing.
- Follow bounded manager, fix and PR loops: declare success predicates, attempt budgets, no-progress behavior and non-success exits (BLOCKED, FAILED, INTERRUPTED, BUDGET_EXHAUSTED).
- Never create a fix task depending on a blocked task being `done`; repair the original task and reverify it.
- Time-based `/loop` and proactive `/schedule` are optional Claude Code integrations, not built into StoryForge. Never turn on recurring monitoring without separate authorization.
- `ship.auto_merge` defaults to `false`. Even when enabled, require actual green named CI checks, independent SHA-bound verification and authorized merge permissions.

## Router

| The task is | Go to |
|---|---|
| A request with several tasks, a backlog, or "keep going until it's all done" | The manager loop above |
| A story, ticket, or feature that touches 2+ files or a boundary | `build-story` (it runs the whole pipeline; the skills below plug into its phases) |
| One contained edit with an obvious test | Do it directly, then `principle-prove-it-works` |
| A bug, cause unknown | `investigate`; for history ("why is it like this") `why`; stuck after two failed fixes, `principle-attack-the-premise` |
| "How does X work", "are we sure" | `how` |
| A design choice, new module shape, or types crossing a boundary | `architect`; a contested one, `arena`, then `review` in multi-model mode |
| Broad parallel work (coverage, races, gauntlets) | `swarm` |
| Large or odd task with no fitting skill, or work the user will review later | `figure-it-out`, with `show-me-your-work` for the decision trail |
| Slowness or a number you measured | `benchmark-checklist`, then `principle-explain-the-number` |
| State, retries, or concurrency that can deadlock | `statechart`, and `create-formal-verification-skill` if it needs a proof |
| "What did I change or do", or prior-session context | `what-did-i-get-done`, `recall` |
| A request too vague to act on | `sharpen` |
| Explain a concept to the user | `teach`; restate someone's idea back, `in-your-own-words` |
| Need a run-the-real-app check for this repo | `create-verification-skill` (and `maintain-verification-skill` when it drifts) |
| Review, security, break, ship, tests, docs | Their `build-story` phase skills: `review`, `security-review`, `break-it`, `ship`, `ui-test`, `feature-docs` |

## Rules

- **Code.** Name the data shape first (`principle-model-the-domain`). Code crossing a function boundary gets `architect` before it is written. Prefer deleting and reusing (`principle-laziness-protocol`, `principle-subtract-before-you-add`).
- **Before commit:** `deslop`. **Before review:** `no-comments`. `build-story` runs both at the end of develop and again before commit.
- **Prose.** Replies, docs, PR text and commit messages go through `unslop`. Docs, RFCs and READMEs also follow `technical-writing`. TypeScript work follows `typescript-best-practices`. A quality audit of a diff uses `thermo-nuclear-code-quality-review`.
- **Verify.** Run the real artifact, not a proxy (`principle-prove-it-works`). Use the project's `verify` skill if `.claude/skills/verify/` exists.
- **Ask rarely.** If the answer is a fact you can observe by running something, run it. Reserve questions for product or preference calls (`principle-never-block-on-the-human`). Pause before irreversible actions: force-push to a shared branch, deploy, deleting data, messaging customers.
- **Honest answers.** Decline or push back when it's right. Every claim carries its evidence or the word measured, inferred, or guess. Never invent a link or citation.

## Principles

Read the leaf `principle-<name>` skill before applying one, and name each principle that shaped a decision in your reply.

- **Core:** laziness-protocol, foundational-thinking, redesign-from-first-principles, attack-the-premise, subtract-before-you-add, minimize-reader-load, outcome-oriented-execution, experience-first, exhaust-the-design-space, build-the-lever.
- **Architecture:** model-the-domain, boundary-discipline, type-system-discipline, make-operations-idempotent, migrate-callers-then-delete-legacy-apis, separate-before-serializing-shared-state.
- **Verification:** prove-it-works, fix-root-causes, sequence-verifiable-units, test-behavior-not-implementation, explain-the-number.
- **Delegation:** guard-the-context-window, never-block-on-the-human.
- **Meta:** encode-lessons-in-structure.

## Subagents

- Spawn with `subagent_type: "storyforge:bits-agent"` for code-writing helpers. The StoryForge role agents (`planner`, `developer`, `reviewer` and the rest) keep their own types. Skills that set their own type (`how`, `why`, `swarm`, `arena`, `architect`) use it.
- Every `Agent` call: `run_in_background: true`, file pointers instead of pasted context, an explicit model per role.
- Independent agents go in **one message**. Give each its own files or worktree; never let two write the same file (`principle-separate-before-serializing-shared-state`).
- New work goes to a fresh subagent with the consolidated brief. Resume one only when it holds state that is costly to move (a checkout, a running server).
- You own every subagent's output: read the diff and write your own summary. A review gate stays closed when no independent reviewer can run; say so instead of counting your own review.

## Models

Role defaults. A matching line in `~/.claude/bits-models.md` overrides each; `/storyforge:setup-bits` writes that file.

- feature, refactoring: `sonnet`
- bug-fix: `opus`
- judgment and prose: `opus`
- strongest judgment: `fable`

A value may carry an effort, as in `opus @xhigh` (low, medium, high, xhigh, max). `inherit-parent` or `auto` omits `model` on the `Agent` call. If a slug is rejected, use the closest valid slug of the same family and say so.

## Reply

Short declarative sentences, one thought each. No long dashes. Say who the work is for and what changes for them before implementation detail. Name what is verified and what is still a guess.
