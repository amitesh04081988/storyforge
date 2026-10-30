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
