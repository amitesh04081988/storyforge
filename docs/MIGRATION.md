# StoryForge TSV-to-SQLite migration

Older installs use `.storyforge/tasks.tsv`; the newer `bits-tasks.sh` uses `.storyforge/tasks.sqlite`.

1. Stop existing StoryForge sessions, and back up `.storyforge/tasks.tsv`, worktrees and open PRs.
2. Ensure the destination SQLite ledger is empty, then run:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bits-tasks.sh" migrate-legacy .storyforge/tasks.tsv
```

3. The importer validates task IDs/dependencies, preserves titles and modes, and imports atomically. Old `done` rows become `blocked` because they have no current SHA-bound proof; active rows become `interrupted`.
4. Inspect `bits-tasks.sh show`, reconcile non-idempotent side effects, and reverify tasks on the current revision.
5. Keep the TSV backup until the migration is accepted. No implicit migration or silent success is allowed.

SQLite is for one local host; running several managers on different machines against copied DBs is not supported.

## Compatibility notes

- **Ledgers from earlier versions.** `migrate-legacy` accepts rows with 6, 9 or 11 columns (versions 0.10.0, 0.10.0 with a PR, and 0.10.1 onward). Missing columns are filled with `-`.
- **Blank gate commands now block.** `test`, `lint` and `typecheck` in `storyforge.config.json` are required. A blank value used to be skipped and now reports `BLOCKED`. If a project genuinely has no typecheck, set it to an explicit no-op such as `true`, so the choice is visible.
- **Python and bash.** `bits-tasks.sh` finds a working Python 3 (`python3`, `python`, `py -3`) and `verify-run.py` finds Git Bash on Windows. Call `bits-tasks.sh verify` and `bits-tasks.sh policy` instead of invoking the `.py` files directly.
- **Required CI checks.** Set `STORYFORGE_REQUIRED_CHECKS` (separated by `;`) to the check names your branch protection requires. Without it `pr-watch.sh` never reports READY.
- **Auto-merge.** `ship.auto_merge` defaults to `true` for new projects. A merge still needs READY from `pr-watch.sh` and a verdict recorded at the PR's current head commit, and it uses `--match-head-commit`. Existing configs are not changed. Set it to `false` to merge by hand.
