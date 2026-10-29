---
name: ship
description: "Take a finished branch to a mergeable PR: sync with the base branch and re-test, make bisectable commits, update CHANGELOG and version, push, open a reviewer-friendly PR, then watch it: fix failing CI, handle review comments, and resolve merge conflicts until it's green and clean. Use for 'ship it', 'open a PR', 'push this', 'fix CI', 'address PR comments', 'babysit the PR', or the ship phase of build-story."
argument-hint: "[--pr | --babysit <pr-number>]"
---

# Ship

Merged from gstack `/ship` with pstack's `fix-ci`, `get-pr-comments`, `babysit`, and `make-pr-easy-to-review`; see NOTICE.md. It uses the `gh` CLI (or `glab` for GitLab). If neither is authenticated, stop after step 4 and tell the user.

`ship.mode` in `storyforge.config.json` controls how far build-story goes:
- `commit`: stop after step 3 (the default, and the safest).
- `pr`: run steps 1-6.
- `pr-babysit`: run steps 1-7.

## 1. Sync before testing

Run `git fetch origin && git merge origin/<base_branch> --no-edit`. Tests must cover the integrated code, not a stale base.
- Resolve trivial conflicts (CHANGELOG ordering, lockfile regeneration) yourself.
- For anything involving logic, stop and ask, and show both sides.
- After the merge, re-run `test`, `lint`, `typecheck`, and `e2e_test` if UI is enabled. Read the real results.

## 2. Bisectable commits

If the story is still one large uncommitted change, split it into commits in dependency order: schema or migrations, then core logic, then wiring and API, then UI, then tests, then docs. Each commit must build on its own. Use Conventional Commit messages (`feat:`, `fix:`, `chore:`, `docs:`, `test:`). Changes under 50 lines across fewer than 4 files can be one commit. Never create an empty commit.

## 3. Version and changelog

Skip this if the project has neither a CHANGELOG nor a version file.
- Bump: patch for fixes, minor for new features, routes, or migrations. **Ask** before a major bump or anything breaking.
- Write the CHANGELOG entry from `docs/stories/<id>/summary.md`, in user-facing language: what changed for users, not file names.
- Commit as `chore: release vX.Y.Z` (or append to the feature commit if the repo prefers that).

## 4. Push

Run `git push -u origin story/<id>`. **Never force-push** a branch that others may have pulled, and never use `--no-verify`. If a pre-push hook fails, fix the cause.

## 5. Open the PR

`gh pr create --base <base_branch> --title "<type>: <summary>" --body-file <file>`. Write the body to a file; never inline it in the shell. The body should include:
- **TL;DR** (2-3 lines) that matches the actual diff.
- **Acceptance criteria** from `plan.md`, each marked ✅ with the test that proves it. Use `Closes #N` only if every criterion is verified.
- **Where to start reviewing:** the 2-4 core files. List generated or mechanical files separately.
- **Risk:** migrations and their order, feature flags, rollback plan, and the integrations touched.
- **Tests:** counts for unit, integration, and e2e, plus findings fixed vs. deferred (from `findings.md`).
- A link to `docs/features/<feature>.md`.

If the diff is too big to review well (roughly more than 600 changed lines of logic), say so in the PR and suggest how to split it. Don't polish around the problem.

## 6. First CI check

Run `gh pr checks <n> --watch`. If anything fails, go to step 7's CI loop once, even in `pr` mode.

## 7. Babysit loop

Each round, fetch the state with `gh pr view <n> --json mergeable,mergeStateStatus,reviewDecision,statusCheckRollup,reviews,comments`, then handle things in this order:

1. **Merge conflicts** (`mergeStateStatus == DIRTY`): merge the base branch again, resolve the conflicts, and re-test. Don't rebase or force-push a shared branch without asking.
2. **Failing checks:** from `gh pr checks <n> --json name,state,link`, take the first failing job and read its log (`gh run view <run-id> --log-failed`). Find the first actionable error, fix its root cause with the `investigate` skill, then commit and push. Fix one failure at a time.
3. **Review comments:** `gh api repos/{owner}/{repo}/pulls/<n>/comments` plus the review bodies. Group them by actionability.
   - If a comment has one obvious mechanical answer (a rename, a guard, a nit), make the change and quote the comment in the commit message.
   - If it's a judgment call, or the meaning is unclear, don't guess. Reply with what you would do and leave it for the human.
   - For bot findings on security or data, ask by default.

**Stop** when:
- Everything is green, comments are resolved, and the PR merges cleanly. Report it as ready. Merge it yourself only when `ship.auto_merge` is true, and then only if `scripts/pr-watch.sh <pr>` prints READY just before: `gh pr merge <pr> --squash --match-head-commit <head-sha>`, where the sha is the one you verified. A refusal from `--match-head-commit` means the head moved: re-verify, never retry with the flag removed. With it false, report the PR as ready and stop.
- 3 rounds have passed and it still isn't green. Summarize what's still broken and hand back.
- The next fix needs a design decision. Ask.

## Hard rules

- Never weaken or skip a test, mark a failing check as not required, or skip hooks to get green.
- Never push secrets. Run `git diff origin/<base_branch>...HEAD` and scan it for key-shaped strings before the first push.

Report: the PR URL, check status, comments handled vs. deferred, and the commits pushed (SHAs).
