---
name: remember
description: "Read or update the project's long-term memory in docs/memory: integrations registry, design decisions, architecture map, and lessons from past bugs. Use when the user says 'remember this', 'record this decision', 'what do we know about <integration>', 'recall project context', 'update project memory', or at the start and end of build-story."
---

# Remember: project memory

Memory is plain markdown under `docs/memory/`, committed to git. It's built to be cheap to load. A session starts with only `INDEX.md`, and everything else is opened on demand.

```
docs/memory/
├── INDEX.md            # ≤ 80 lines. One line per file or entry. Loaded at session start by the hook.
├── ARCHITECTURE.md     # Module map: what lives where, and the boundaries. ≤ 150 lines.
├── DECISIONS.md        # Numbered decision records. Append-only; supersede, never delete.
├── LESSONS.md          # Bug classes that happened and how to avoid them.
└── integrations/
    └── <name>.md       # One file per external service or internal boundary.
docs/stories/<id>/      # Per-story archive: story, plan, findings, status, summary.
```

## Formats

**INDEX.md line:** `- [integrations/stripe.md] Stripe payments: checkout + webhooks, signature verified, idempotency keys required`

**DECISIONS.md entry:**
```
## D-014 Use outbox table for webhook delivery (2026-10-24, story 20261024-webhooks)
Context: one line. Decision: one line. Why not <alternative>: one line.
Status: active | superseded by D-0xx
```

**LESSONS.md entry:**
```
## L-007 Double-submit created duplicate orders (story 20261020-checkout)
Cause: no idempotency on POST /orders. Rule: every create endpoint takes an Idempotency-Key.
Enforced by: tests/api/idempotency.test.ts (or "not enforced — judgment")
```

**integrations/<name>.md:**
```
# <Name>
Purpose: … | Owner/module: src/… | Env vars: NAME_ONLY (never values)
## Contract
Auth: … | Base URL per env: … | Endpoints/events used: …
Timeouts/retries: … | Rate limits: … | Idempotency: …
## Quirks and gotchas
- …
## Tests
Integration tests: path | How to run against sandbox: …
## History
- 2026-10-24 story <id>: what changed
```

## Rules

- **Record what is true in the code now.** File facts that were verified by tests or by reading code. Plans and guesses don't go in.
- **Don't duplicate.** Update the existing line or entry instead of adding a near-copy.
- **Keep it small.** If a file grows past its limit, consolidate older entries into a dated summary line.
- **No secrets or personal data.** Ever. Env var names are fine; values never are.
- **Prefer structure over prose.** If a lesson can be enforced by a test, lint, or hook, add the enforcement and point to it (`principle-encode-lessons-in-structure`).
- **Ad-hoc requests.** When the user says "remember X", put it in the right file, update `INDEX.md`, and confirm in one line.
