---
name: break-it
description: "Adversarial testing of freshly built code: actively try to break it with boundary and hostile input, concurrency and double-submit, failure injection (slow or erroring dependencies, partial writes), integration faults, and first-run or empty states, then turn each real failure into a regression test. Use for 'break it', 'try to break this', 'stress test', 'chaos test', 'find edge cases', or the break phase of build-story."
---

# Break it

Read `references/red-team.md` (from gstack's red-team specialist) for the attack angles. Then **run** the attacks. That's the difference between this skill and a review.

## Attack menu

Pick the ones that fit the change. Execute each one: a test, a script, a curl, or a CLI call.

- **Input:** empty, null, max size, unicode or RTL, wrong types, negative numbers, duplicate keys, injection strings in every user-controlled field.
- **State:** first run with no data, a record deleted mid-flow, a stale cache, a restart in the middle of an operation.
- **Concurrency:** the same request twice in parallel (double-submit), two writers to one record, a retry after a timeout that actually succeeded (idempotency).
- **Dependencies:** an external call that returns 500, a timeout, malformed JSON, an empty page, or a 429. A DB that's slow or loses its connection.
- **Partial failure:** a crash after step 3 of 5. Does it leave inconsistent state? Is there a rollback or resume path?
- **Auth:** as another user (change the ID), as a downgraded role, with an expired token, with no token.

## Hangs, deadlocks, and slowness

If an attack hangs or slows down, capture evidence before killing the process. Take 3 dumps a few seconds apart and compare them:
- JVM: `jcmd <pid> Thread.print` (or `jstack <pid>`)
- Native or any Linux process: `pstack <pid>` or `gdb -p <pid> -batch -ex "thread apply all bt"`
- Python: `py-spy dump --pid <pid>`
- Node: `kill -USR2 <pid>` with `--report-on-signal`, or `--inspect`

Trim idle and runtime-internal threads before reading. Threads stuck at the same frame in every dump are the lead. Save the dumps to `docs/stories/<id>/dumps/`.

## Output

Every real failure becomes a regression test that fails now. Anything that held up goes under "Survived". Never fix the code in this skill; that's the fix phase's job.
