# StoryForge Engineering Architecture

StoryForge is a Claude Code plugin using a skills-based manager, Bash hooks, and Python's standard-library SQLite for single-host task persistence. It is not an always-on server.

## Execution model

```mermaid
flowchart TD
  U[Developer request] --> M[Bits-Mode Manager]
  M --> R[Risk policy]
  M --> T[SQLite task ledger]
  M --> S[Build-story skills]
  S --> A[Specialist agents]
  A --> V[Executable gate runner]
  V --> T
  T --> P[PR watcher / Git]
```

## Bounded loops

| Loop | Progress | Success | Failure/stop |
|---|---|---|---|
| Manager | Claim and verify eligible tasks | All proof-backed tasks done | Blocker or no progress |
| Fix | Code change and rerun gates | Passing required checks | Attempt cap or ambiguity |
| PR | Observe CI and reviewers | Required checks and current SHA | Closed, failed or unavailable |
| Scheduled | Not implemented | Not applicable | Disabled by default |

Task state is transactional and requires configured gate evidence bound to the current clean Git HEAD, base and config. Agents can perform work but cannot establish completion solely by saying it is finished.

## Known boundaries

- The state engine is single-host; it is not a distributed queue or process supervisor.
- The independent gate runner executes configured test/lint/typecheck commands; it cannot automatically attest model-generated security review claims.
- Time-based and proactive Claude Code loops are optional external integrations, not native StoryForge features.
- Cancel records state but does not yet forcibly terminate all child processes.
- Run only in a trusted repository or restricted sandbox. Test and lint commands are executable code.
- Production deployment, destructive migrations, customer messages and privileged actions require explicit approval.

## Core files

- `plugins/storyforge/skills/bits-mode/SKILL.md`: user-facing manager and routing
- `plugins/storyforge/scripts/bits-policy.py`: deterministic risk floor
- `plugins/storyforge/scripts/bits-state.py`: SQLite state, evidence and attempts
- `plugins/storyforge/scripts/verify-run.py`: real executable gate results
- `plugins/storyforge/scripts/pr-watch.sh`: conservative CI decision
- `plugins/storyforge/hooks/stop-gate.sh`: best-effort session gate
- `tests/`: regression fixtures

## What the evidence proves, and what it does not

A task reaches `done` only if every required gate has a `PASS` record for the exact commit, base commit and config hash, from a verifier who differs from the builder.

- **Executed gates** (`test`, `lint`, `typecheck`, `integration_test`, `e2e_test`, `diff`) must come from `verify-run.py`, which runs the configured command and stores its real exit code. `bits-state.py evidence` tags every record with its `source`; a `manual` record never satisfies an executed gate.
- **Attestation gates** (`review`, `security`) are statements by the named verifier. The ledger cannot check them. They are as trustworthy as whoever recorded them.
- **This is not tamper-proof.** The ledger is a local SQLite file, and anything that can run a command in the repository can pass `--source verify-run` or edit the file. The design catches mistakes and skipped steps, not a deliberately hostile agent. Use a sandbox and reviewed branch protection for that.
- **Names are not authenticated.** `builder` and `verifier` are labels. They prove the manager separated the roles, not who actually ran them.

## Pull request readiness

`pr-watch.sh` says READY only when the PR is open, has at least one check, every check passed (`SKIPPED` and `NEUTRAL` count as passing), every name in `STORYFORGE_REQUIRED_CHECKS` exists, and nothing is conflicting or awaiting review. List required names separated by `;` or newlines; names may contain commas. With no policy it never says READY, because it cannot know which checks must exist. A real failure is reported as ACT whether or not a policy is set.
