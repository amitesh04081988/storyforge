# Third-party material

StoryForge reuses files from two MIT-licensed projects. Their license texts are in `licenses/`.

**gstack**, © 2026 Garry Tan. https://github.com/garrytan/gstack (commit 6f7488a)

| StoryForge path | Status |
|---|---|
| hooks/vendor/gstack-careful/check-careful.sh, hook-extract.sh | as-is |
| skills/review/references/specialists/{api-contract,data-migration,maintainability,performance}.md | as-is |
| skills/security-review/references/security.md | as-is (review/specialists/security.md) |
| skills/break-it/references/red-team.md | as-is (review/specialists/red-team.md) |
| skills/investigate/sections/{polluter,race}.md | as-is |
| skills/investigate/sections/flake.md | adapted: gstack-only commands removed |
| skills/review/references/checklist.md | adapted: gstack helper-binary steps replaced with plain git equivalents |
| skills/ui-test/references/issue-taxonomy.md | adapted: browser-tool references changed to Playwright MCP equivalents (qa/references/issue-taxonomy.md) |
| skills/test-audit/SKILL.md | adapted from test-audit: value bar, low-value catalog, and audit workflow kept; gstack state paths and helpers replaced with git |
| skills/ship/SKILL.md | merged: release flow ideas from ship (sync before test, bisectable commits, version/changelog, never force-push) |
| skills/product-review/SKILL.md | merged: premise challenge and alternatives from office-hours; scope modes and prime directives from plan-ceo-review |
| skills/reflect/SKILL.md (retro mode) | merged: metrics approach from retro |
| hooks/edit-guard.sh (scope lock) | idea from freeze; implementation original |
| skills/investigate/SKILL.md | adapted: phases and Iron Law kept; preamble, telemetry, and gstack tooling removed |

**pstack-claude**, © 2026 Lauren Tan, © 2026 Michael Denyer. https://github.com/michael-denyer/pstack-claude (commit 356c6e0). Original pstack by Lauren Tan (poteto).

| StoryForge path | Status |
|---|---|
| skills/tdd, thermo-nuclear-review, correct | as-is |
| skills/principle-{fix-root-causes,test-behavior-not-implementation,encode-lessons-in-structure,guard-the-context-window} | as-is |
| skills/principle-prove-it-works | as-is, minus one reference to a skill not included |
| skills/principle-{make-operations-idempotent,subtract-before-you-add,migrate-callers-then-delete-legacy-apis,sequence-verifiable-units,minimize-reader-load} | as-is |
| skills/principle-attack-the-premise | as-is, links to principles not included replaced with plain text |
| skills/review/references/interrogate/* | as-is (interrogate references); interrogate's workflow merged into skills/review/SKILL.md multi-model mode |
| skills/reflect/references/*, skills/reflect/scripts/*.mjs | as-is, except synthesizer routing to a skill-creation plugin not included |
| skills/reflect/SKILL.md | merged: reflect workflow and approval gate |
| skills/ship/SKILL.md | merged: fix-ci, get-pr-comments, babysit, make-pr-easy-to-review |
| skills/correct | as-is, except the rule table now lives in docs/memory/LESSONS.md |
| skills/blast-radius | adapted: references to pstack skills not included (why/how/arena/unslop) replaced with plain instructions |

Everything else (build-story, new-project, init-project, ui-test, feature-docs, remember, break-it, security-review, the review skill body, the agents, the StoryForge hooks, and scripts) is original to StoryForge. Where a row says "merged", the skill is a new text that combines the named sources' workflows; no two StoryForge skills cover the same job.

The Playwright MCP server (`@playwright/mcp`, Apache-2.0, by Microsoft) is not bundled. It's only referenced in the project `.mcp.json` template and is fetched by npx at runtime.
