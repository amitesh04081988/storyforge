---
name: investigate
description: "Systematic root-cause debugging: reproduce, trace, match known bug patterns, test hypotheses with evidence, then make a minimal fix with a regression test. Includes recipes for flaky tests, order-dependent tests, and races. Use for any bug, failing test, error, crash, hang, 'why is this broken', 'debug this', or the fix phase of build-story."
---

# Investigate

Adapted from gstack's `/investigate`. The phases are kept close to the original; gstack's own tooling and telemetry are removed. See NOTICE.md.

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** A symptom fix hides the evidence and lets the fault surface somewhere else. Also apply `principle-fix-root-causes`.

## Phase 1: Root cause investigation

1. **Collect symptoms.** Read the actual error, stack trace, and failing assertion diff.
2. **Read the code.** Trace from the symptom back toward the cause. Before you call two code paths duplicates, read their call sites; they often differ in a guard, transaction, or scope.
3. **Check recent changes.** Run `git log --oneline -20 -- <files>`. If this is a regression, the cause is in the diff.
4. **Reproduce deterministically.** If you can't, gather more evidence before going on. For hangs, capture thread dumps as the `break-it` skill describes.
5. **Check project memory.** Grep `docs/memory/LESSONS.md` and the relevant `docs/memory/integrations/*.md` for this area. A recurring bug in the same files is an architectural smell.

## Phase 2: Pattern analysis

| Pattern | Signature | Where to look |
|---|---|---|
| Race condition | Intermittent, timing-dependent | Concurrent access to shared state. Read `sections/race.md` first |
| Flaky test | Fails sometimes or only in CI | Read `sections/flake.md` before any rerun, timeout, or skip |
| Order-dependent test | Passes alone, fails in the suite | Read `sections/polluter.md` |
| Null propagation | TypeError, NoMethodError | Missing handling of a legitimate empty state |
| State corruption | Inconsistent data, partial updates | Transactions, callbacks, hooks |
| Integration failure | Timeout, unexpected response | Service boundaries. Compare against the integration's memory file |
| Config drift | Works locally, fails elsewhere | Env vars, feature flags, DB state |
| Stale cache | Old data; fixed by clearing the cache | Caches, CDN, persisted state |

Read the matching section in full before Phase 3. A rerun, a longer timeout, or a skip is never a hypothesis.

## Phase 3: Hypothesis testing

1. **Confirm before fixing.** Add a temporary log or assertion at the suspected cause, then run the reproduction. Does the evidence match?
2. **If it's wrong,** go back to Phase 1 with what you learned. Don't guess.
3. **3-strike rule.** After 3 failed hypotheses, stop. Inside build-story, mark the item `NEEDS-HUMAN: 3 hypotheses failed — <summary>`. Interactively, ask whether to keep investigating, escalate, or add instrumentation.

Slow down if you notice any of these: "quick fix for now", proposing a fix before tracing the data flow, or each fix revealing a new problem. That last one means you're working at the wrong layer.

## Phase 4: Implementation

1. Fix the root cause with the smallest change. Don't refactor neighboring code.
2. Fix the **pattern**. Grep for the same fault elsewhere.
3. Add a regression test that fails without the fix and passes with it (the `tdd` skill). Inside build-story's fix phase, test files are locked, so ask the orchestrator to have the breaker or test-writer add it.
4. Run the full suite and read the real counts.
5. If the fix touches more than 5 files, flag the blast radius before you go ahead.

## Phase 5: Verification and report

Reproduce the original scenario and confirm it's fixed. Then report:

```
Symptom / Root cause / Fix (file:line) / Evidence / Regression test / Status: DONE | DONE_WITH_CONCERNS | BLOCKED
```

If the root cause is non-obvious and could recur, add it to `docs/memory/LESSONS.md` as the `remember` skill describes.
