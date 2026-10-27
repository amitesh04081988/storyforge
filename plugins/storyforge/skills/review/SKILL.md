---
name: review
description: "Pre-merge code review of a branch diff: SQL and data safety, races, trust boundaries, enum completeness, gate integrity (weakened or skipped tests), test value, completeness gaps, and specialist passes for API contracts, migrations, performance, and maintainability. Optional multi-model mode runs reviewers on different models and merges them with lead judgment. Use for 'review this', 'code review', 'review the diff', 'interrogate', 'adversarial review', 'multi-model review', or the review phase of build-story."
---

# Review

1. **Scope.** `git diff <base>...HEAD`, where the base comes from `storyforge.config.json` (`base_branch`) or the user. Note which areas it touches: API, DB/migrations, auth, frontend, background jobs.
2. **Main pass.** Read `references/checklist.md` and work through Pass 1 (CRITICAL), then Pass 2. Gate Integrity always runs. In an autonomous pipeline, a weakened test is the most common way a "fix" cheats.
3. **Specialists.** Read only the files that apply:

| When the diff… | Read |
|---|---|
| changes an API, route, schema, or response shape | `references/specialists/api-contract.md` |
| adds or changes a migration or data backfill | `references/specialists/data-migration.md` |
| touches hot paths, queries in loops, or bundle size | `references/specialists/performance.md` |
| is more than ~150 lines, or adds abstractions | `references/specialists/maintainability.md` |

   The security and red-team specialists belong to the `security-review` and `break-it` skills.

   **Tests in the diff:** check each new test against the value bar in the `test-audit` skill. A test that can't fail, or that duplicates existing coverage, is an INFO finding.
4. **Output.** Use the format in the checklist. Inside build-story, append to `findings.md § Review` as the reviewer agent describes. Outside a pipeline, report to the user.

## Multi-model mode

Different models catch different real bugs. Run this mode when `review.models` in the config lists more than one model, or when the user asks to "interrogate" the change. The reviewer prompt, rubric, code-quality lens, and lead-judgment framework are reused from pstack's `interrogate`; see NOTICE.md.

1. **Intent:** state the change's intent in one paragraph, from `story.md` and `plan.md`.
2. **Spawn** one `reviewer` agent per entry in `review.models`, all in one message, setting each Agent call's `model` to that entry (for example `opus` or `sonnet`). Build each prompt from `references/interrogate/reviewer-prompt.md`. To save tokens, pass the diff as a **path or command** for the reviewer to read, not inline text. Include `references/interrogate/rubric.md` and `references/interrogate/code-quality-review.md`. Every reviewer works through this skill's checklist too, so the modes don't duplicate each other.
3. **Synthesize:** merge findings that describe the same issue, and note which models raised each one. Findings that two or more models raised independently are the strongest signal.
4. **Lead judgment:** sort each finding into Act on / Consider / Noted / Dismissed, using `references/interrogate/lead-judgment.md`. "Act on" becomes CRITICAL in `findings.md`, and "Consider" becomes INFO.

This mode costs roughly one extra review per added model. Use it for risky stories (auth, payments, data, concurrency) rather than for every story.

Cite `file:line` for every finding. Don't report a finding whose research isn't finished. If you can check the other side of a boundary, check it.
