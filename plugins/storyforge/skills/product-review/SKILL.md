---
name: product-review
description: "Product and scope review of a story before engineering planning: challenge the premise, find existing code that already solves part of it, pick a scope mode (expand, selective, hold, reduce), compare minimal vs. ideal vs. lateral approaches, and name failure modes and what's out of scope. Use for 'is this the right thing to build', 'challenge this idea', 'scope review', 'CEO review', 'office hours', or the product phase of build-story."
---

# Product review

Merged from gstack `/office-hours` (premise challenge, alternatives) and `/plan-ceo-review` (scope modes, prime directives); see NOTICE.md. This is a review only: write no code. Project-level questions (what to build, which stack) belong to `new-project`. This skill is about **one story**.

**Read:** `docs/stories/<id>/story.md`, `context.md`, and `docs/memory/REQUIREMENTS.md` if it exists. Use Grep to find code related to the story's nouns.

## 1. Premise challenge

Answer each one in a line or two:
1. **Real problem:** what pain does this solve, and for whom? Does the story solve the pain itself, or only a proxy for it?
2. **Cost of doing nothing:** is the pain real now, or hypothetical?
3. **Already exists:** for each sub-problem, what existing code, utility, or flow already solves part of it (`file:line`)? If something would be rebuilt, say why refactoring the existing path is worse.
4. **Distribution:** if the story creates something new that users install or call (CLI, package, endpoint, app), how do they get it?

Write these as premises the user agrees or disagrees with: `PREMISE n: <statement>`.

## 2. Scope mode

Recommend one mode, giving the concrete fact that makes it fit:
- **Expand:** a new capability where doing it fully now is cheap. Name the 1-3 additions worth it.
- **Selective:** add capability but offer each extra separately, with its effort and risk.
- **Hold:** keep the scope and harden it with edge cases, error paths, and observability. This is the default for fixes and refactors.
- **Reduce:** more than about 15 files touched, or several integrations. Propose the minimum viable slice and move the rest into follow-up stories.

## 3. Approaches

Give 2-3 approaches, each with a summary, effort (S/M/L/XL), risk, pros and cons, and what existing code it reuses.
- One must be **minimal**: fewest files, ships fastest.
- One must be **ideal**: the best long-term shape.
- Optionally one **lateral** approach: a different framing of the problem.

Recommend one approach, with the reason tied to the story's goal.

## 4. Must-haves for the plan

- **Failure modes:** every error class this feature can hit (upstream down, bad input, partial write, double submit), with what the user sees and how it's handled. No silent failures.
- **Observability:** the logs, metrics, or alerts needed to know it works in production.
- **Rollout:** a feature flag, migration order, and rollback, if any apply.
- **Not in scope:** an explicit list.

## Output

Write `docs/stories/<id>/product.md`, 60 lines or fewer, covering premises, mode, approaches, recommendation, must-haves, and not in scope. The planner treats it as input.

**Gate:** if a premise is shaky, the mode is Reduce, or the recommended approach differs from what the story asked for, the user must agree before planning. In headless runs, mark the story `needs-approval`. Otherwise continue.
