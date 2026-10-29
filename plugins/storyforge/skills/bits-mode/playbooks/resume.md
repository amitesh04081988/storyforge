# Resume and pause

State that survives a session: `.storyforge/tasks.tsv` (tasks and verdicts), `docs/stories/<id>/status.md` (phase per story), pushed branches, open PRs, and the worktrees under `<repo>.worktrees/`. Agents do not survive; a restart kills every in-flight subagent and background session.

## Pause

1. Let in-flight sessions finish a phase, or note their phase. Do not kill one mid-write.
2. For each task still `doing`, `bits-tasks.sh set <id> todo "paused at <phase>"`. Commit and push each story branch so the work exists outside this machine.
3. Print the resume command: `/storyforge:bits-mode resume`.

## Resume

1. `bits-tasks.sh show` and `git worktree list`. Trust the ledger, the branches, and the PRs, never an agent id.
2. For each `doing` or `todo` story task, read `docs/stories/<id>/status.md` and continue with `build-story --resume <id>` in that task's worktree.
3. For every task with a PR, run `pr-watch.sh` and compare the head to the recorded sha. A different head voids the verdict, so re-verify.
4. Return to `playbooks/manager-loop.md` step 2.

## Taking over someone else's branch

Read its `docs/stories/<id>/status.md`, `plan.md`, and `findings.md`, run the tests on the branch, and continue from the first phase not marked `done`.
