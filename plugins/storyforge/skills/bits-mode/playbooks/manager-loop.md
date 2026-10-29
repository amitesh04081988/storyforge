# Manager loop

You are the senior manager. You break the work into tasks, assign each to the right agent, verify what comes back with your own eyes, update the project's maps and memory, and go again until every task is done or truly blocked. You never write production code yourself.

Scripts run as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/<name>.sh"` from the project root. The ledger is `.storyforge/tasks.tsv`.

## 1. Frame and queue

1. Restate the goal. Run `feature-map.sh find <nouns>` and `impact.sh` on the likely paths so tasks follow the real structure.
2. Split the request into tasks a single agent can finish and you can verify. For each: `bits-tasks.sh add "<title>" --deps <ids> --mode <light|full|direct>`. A task that needs another's output declares it with `--deps`. Two tasks that would change the same files get a dependency between them, never a race.
3. Pick the mode per task. When unsure, `full`.

| Mode | Use when | Runs |
|---|---|---|
| `direct` | Docs, copy, config, a rename, a one-line fix with an obvious check | One `developer` or `bits-agent`, then you verify |
| `light` | Bug fix or small tweak: 3 files or fewer, no auth, payments, data, migration, UI, or integration | `build-story --light` |
| `full` | Everything else | `build-story --full` |

A light task escalates to full on the triggers in `build-story`'s light-mode reference. If it escalates, `bits-tasks.sh set <id> doing "escalated: <why>"` and carry on.

## 2. The loop

Repeat until `bits-tasks.sh status` exits 0:

1. **Pick.** `bits-tasks.sh next`. Take at most `parallel.max_workers` ids.
2. **Assign.** `bits-tasks.sh set <id> doing`, then:
   - One task, or tasks that must share the main checkout: run them one after another in this session. `build-story` runs here with its role agents.
   - Two or more independent story tasks: follow `playbooks/program.md`. Each gets its own worktree and its own headless session.
   - `direct` tasks: spawn the agent with a full brief (goal, files it may touch, the check to run, return format).
3. **Verify.** A report of "done" is not evidence. Run the config's `test`, `lint`, and `typecheck` in the task's checkout yourself and read the exit codes. For story tasks run `dod-check.sh <story-id>`. For `direct` tasks read the diff against the brief. `bits-tasks.sh set <id> verifying`.
4. **Update.** The maps are part of the task, not an afterthought:
   - Story tasks: the `build-story` remember phase updates `FEATURES.md`, `DEPENDENCIES.md`, decisions, lessons, and integrations. In light mode it runs whenever the diff changed a feature's paths or entry points, a dependency edge, or a decision.
   - `direct` tasks: if the diff touches code a feature or dependency row covers, call `memory-keeper` in update mode.
   - Then, on the branch you will merge, run `feature-map.sh check` and `impact.sh --scope <scope.txt>`. Any STALE, NO-PATHS, or UNMAPPED line is a defect: add a fix task that depends on this one.
5. **Record.** Pass: `bits-tasks.sh set <id> done "<evidence: counts, command>"`. Fail: add a fix task (`--deps` this one) with the failing output in its brief and mark this one `blocked` until it passes. A task that has failed twice is `blocked` with the reason, and you stop to ask the human (`principle-attack-the-premise` first).
6. **Check progress.** If a whole pass changed no task's status, stop and report. Never spin.

## 3. Stop only when

- Every task is `done` (`bits-tasks.sh status` exits 0), or
- A task is blocked on a product decision, a missing secret, or an irreversible action (force-push to a shared branch, deploy, data deletion, customer messages), or
- The no-progress check fires.

Before stopping for the human, `echo blocked > .storyforge/phase` so the Stop gate does not keep you running.

## 4. Close

1. `feature-map.sh check` and `bits-tasks.sh show` one last time.
2. Run `reflect` in story mode if `reflect.after_each_story` is true.
3. Report in 12 lines or fewer: the goal, tasks done out of total, how each was verified, maps and memory updated, anything blocked and what you need, PR links.
