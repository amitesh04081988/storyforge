# Light mode

Read this only when you have chosen `mode: light`. It says what runs, what is skipped, and when to switch to full.

**Runs:** recall, plan, impact, tests, develop, review, the fix loop, verify, commit and ship per the config.
- Impact: call `impact-analyst` only when `impact.sh` shows affected areas. Otherwise write a one-line `impact.md` ("no dependents").
- Review: one reviewer, one pass, even if `review.models` lists several.
- Verify: the full definition-of-done matrix and `dod-check.sh`, exactly as in full mode.

**Skips**, marking each `skipped: light mode` in `status.md`: product, break, integrate, ui, docs, remember, reflect.
- Remember still runs when the story produced a decision or a lesson worth keeping.
- Security review still runs when the diff touches auth, sessions, tokens, crypto, payments, uploads, or SQL and query building.

**Never skipped, in any mode:** failing tests first, the guard checks, the Stop gate, review, and the definition-of-done matrix with `dod-check.sh`.

**Escalate to full** when any of these happens: `fix_cycles` reaches 2; review or security finds a CRITICAL; the work grows past 3 files; a scope deviation is needed. Run the skipped break and security phases, and set `mode: full (escalated: <reason>)` in `status.md`.
