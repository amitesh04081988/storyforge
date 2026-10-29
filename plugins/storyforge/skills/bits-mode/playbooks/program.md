# Program: many stories at once

Use this from the manager loop when two or more story tasks are independent. Throughput comes from one worktree and one headless session per task. Quality still comes from `build-story`'s gates inside each one.

A subagent cannot spawn subagents, so an "owner agent" cannot run `build-story` for you. Each story therefore runs as its own `claude -p` session through `run-story.sh`, which can spawn its own role agents. Those sessions need the permission setup in `run-story.sh`'s header (Bash allow rules for test, lint, and git commands).

## Start a wave

1. Check the tasks do not overlap: `story-check.sh` on each planned scope, plus `impact.sh`. Overlap becomes a `--deps` edge, not a race.
2. For each task id:
   ```bash
   path=$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh" add <task-id>)
   ( cd "$path" && STORYFORGE_QUEUE=1 bash "${CLAUDE_PLUGIN_ROOT}/scripts/run-story.sh" -f <story-file> ) 
   ```
   Run each with the Bash tool's `run_in_background`, in one message for the whole wave. Write the story file first (goal, acceptance, scope hints). Set `ship.mode` to `pr` in the config so each session ends with a PR.
3. Keep at most `parallel.max_workers` sessions in flight. Refill as they finish.
4. **Cost gate.** Each session is a full pipeline with its own agents, so a wave of N stories costs roughly N times one story. Before launching a wave of more than two sessions, tell the human the number of sessions, the mode of each (light stories are far cheaper), and the ceiling of two fix cycles per task, then wait for a go. A wave of one or two sessions, or a size the request already named, proceeds. For a first run on a new project, run one story before fanning out.

## Drain

When a background session exits, read its status, never its summary:
- `run-story.sh` exit 0 and `docs/stories/<id>/status.md` says `done`: go to Verify.
- Exit 2 (needs a human): read `## Blocked`, mark the task `blocked`, route around it.
- Exit 1: `--resume` once; a second failure marks the task `blocked`.

## Verify, independent of the author

For each finished PR, spawn a verifier on a different model than the one that built it (`review.models` has two). In the task's worktree it runs `test`, `lint`, `typecheck`, `dod-check.sh`, and the project's `verify` skill if present, on the exact PR head. Then record what was proven at that head:

```bash
sha=$(git -C "$path" rev-parse HEAD)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/bits-tasks.sh" pr <id> <pr-number> "$sha" <verdict>
```

Verdicts: `live-ui-verified`, `unit-test-verified`, `type-check-only`, `verifier-blocked`, `verifier-failed`. Behavior changes need better than `type-check-only`. `verifier-failed` gets a fix task, not a re-run.

## Babysit and merge

1. `pr-watch.sh <pr>`: READY (exit 0), WAIT (1), ACT (2), CLOSED (3), error (4). On ACT, read the failure (`gh run view --log-failed`, review comments) and send a fix agent into that worktree. A new commit changes the head, so Verify runs again.
2. A PR merges only when both hold at the same moment: `pr-watch.sh` says READY and `bits-tasks.sh mergeable <id> $(git -C "$path" rev-parse HEAD)` exits 0. A verdict for an older head does not count.
3. When `ship.auto_merge` is true (the default), you merge, once per PR and only after both gates in step 2 pass: `gh pr merge <pr> --squash --match-head-commit "$(git -C "$path" rev-parse HEAD)"`. The story sessions never merge (the headless settings deny `gh pr merge`); only this coordinating session does. If `--match-head-commit` refuses, the head moved: go back to Verify. When it is false, report the merge-ready PRs and let the human click merge. Land in dependency order; after each merge, update the main checkout, then `feature-map.sh check` and `impact.sh` on main.
4. When the base moves, rebase the story onto it. `init-project` sets `merge=union` in `.gitattributes` for `FEATURES.md` and `DEPENDENCIES.md`, so rows added by different stories merge without a conflict (two stories editing the same row still need a human look). Code conflicts, such as two stories adding an export to the same `index` file, stay real: resolve them keeping both intents, and the new head voids the old verdict, so re-verify it before it can merge.
5. After a merge, `bits-tasks.sh set <id> done "<PR link>"`, `worktree.sh remove <task-id>`, and start tasks whose dependencies are now done from the updated base.

## Never

Merge on green CI alone. Merge a PR you wrote and verified yourself. Rebase or retarget another session's branch. Force-push. Let a session edit outside its worktree.
