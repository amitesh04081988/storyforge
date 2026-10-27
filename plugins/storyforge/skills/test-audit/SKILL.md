---
name: test-audit
description: "Judge test value: the bar every new test must clear, and an audit that finds low-value, duplicate, or can't-fail tests (and test-only production code) to rewrite, fold into existing tests, or retire, with evidence and user approval per batch. Use for 'audit the tests', 'are these tests useful', 'too many tests', 'flaky or useless tests', when reviewing tests in a diff, or periodically after several stories."
argument-hint: "[paths | --since <ref>] [--max-candidates N]"
---

# Test audit

Adapted from gstack `/test-audit`, with gstack's state paths and helpers replaced by plain git; see NOTICE.md. AI writes tests quickly, so suites bloat quickly. This skill keeps each test earning its place. It works together with `principle-test-behavior-not-implementation`: that principle covers *what* to assert, and this skill covers *whether* a test should exist.

## Test value bar

A new test must answer all four questions; otherwise extend an existing test or drop it. The test-writer, breaker, and ui-tester apply this to every test they add, and the reviewer checks it.

1. What observable behavior, invariant, or contract does it protect?
2. What credible regression would make it fail?
3. Why doesn't existing coverage already catch that? Prefer adding a row to an existing table-driven test or fixture over writing a near-duplicate.
4. Does it need a production seam (an export, flag, wrapper, or hook) that no production caller needs? If so, test at the real boundary instead.

A test that breaks under a refactor that preserves behavior is asserting implementation. Rewrite it at the owning boundary, unless exact output is the declared contract (goldens, wire formats).

## Low-value catalog

A match fails the bar unless the test guards a named contract:
- No assertions (a coverage probe).
- Self-comparisons, or an expected value computed by the code under test.
- Copied fixtures, inventories, or export lists.
- Greps of exact source, imports, or strings that aren't a declared contract.
- Private-helper or call-shape tests that duplicate a test at a real boundary.
- Duplicate invocations of the same contract, or per-caller replays of a shared helper's tests.
- Tests whose only purpose is keeping a test-only export or wrapper alive, and production code whose only callers are tests.

**Always keep** a test that independently enforces a public API, protocol, config, migration, storage, security, default value, generated output, or architecture contract. Never retire anything reachable from a package entry point. Being slow or static is not a reason to delete a test. Skip any test marked `test-value: keep reason="..."`.

## Audit workflow (read-only until approved)

1. **Scope:** the given paths, otherwise the whole repo. With more than 300 test files, default to `--since $(git merge-base HEAD origin/<base_branch>)`. Budget about 8 minutes for discovery, then write a partial report that can be resumed.
2. **Mechanical shortlist:** list test files with `git ls-files`, then flag files with no assertion keywords (`expect|assert|should|refute|must|t.Error`), files that read source as text, files with export-list equality, and near-duplicates (the same checksum after stripping whitespace). A shortlist entry is a lead, not a verdict.
3. **Evidence:** for each candidate, read the test, the production code it covers, its callers, and overlapping tests. Give a verdict of `retain` (name the contract it guards), `rewrite` (at the owning boundary), `extend` (fold it into an existing table or fixture), or `retire`. A retire verdict needs a complete card: what it detects, non-test callers (with the `git grep` command and hit count), the stronger proof that already covers it, history (`git log --follow`), what removing it unlocks, and the validation command.
4. **Report:** write `docs/test-audit-<date>.md` grouped by area, with production and test lines of code removed per batch, shown separately.
5. **Approve per batch:** one question per batch: approve, skip, or stop. In headless runs, write the report only.
6. **Apply** only approved batches. Remove production code only if typecheck or build passes without it. Grep alone isn't enough evidence. Then run the affected tests and report `git diff --numstat`.
