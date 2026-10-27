---
name: new-project
description: "Start a project from nothing: interview the user about requirements and setup preferences, recommend 2-3 tech stacks with tradeoffs, let them choose, then scaffold a working repo (app skeleton, tests, lint, CI, env handling, Docker if wanted) using official generators, verify it builds and tests pass, and hand off to init-project. Use when the repo is empty or has only a README or requirements doc, or the user says 'new project', 'start from scratch', 'set up a project', or 'what stack should I use'."
---

# New project

Ask in rounds, not as one long form. Use the AskUserQuestion tool where it's available: 2-4 options per question and at most 3 questions per round. Skip any question the requirements doc or the user has already answered. Record every answer in `docs/memory/REQUIREMENTS.md` and `docs/memory/DECISIONS.md` as you go, so nothing is lost if the session ends.

## Round 1: what are we building

If `requirements.md`, a PRD, or a README with requirements exists, read it first, summarize it in 5 lines, and ask only about the gaps.

- **Product type:** web app, API or backend only, mobile, CLI or library, data or ML pipeline.
- **Users and scale:** internal tool, public product, or expected load (for example, 100 users or 100k).
- **Core features:** the 3-5 things it must do. Note which ones need realtime, file uploads, payments, auth, search, background jobs, or AI.
- **Constraints:** deadline, budget, compliance needs (HIPAA, GDPR, PCI), or a must-use language or cloud.

## Round 2: team and operations

- **Team skills:** languages the team already knows. This usually outweighs everything else.
- **Hosting:** Vercel or Netlify, AWS, GCP, Azure, a single VPS, on-prem, or undecided.
- **Data:** relational (default), document, or both, and whether it needs to be managed or self-hosted.
- **Auth:** none, email and password, social or SSO, or an external provider.

## Round 3: recommend a stack

Read `references/stack-guide.md`. Propose **2-3 options**. For each one, give:
- The stack in one line (frontend / backend / database / hosting).
- Why it fits *these* answers. Name the requirement it serves.
- The main tradeoff, and what would make it the wrong choice.
- A rough complexity rating (low, medium, high) for this team.

Put your recommended option first and say why. Let the user pick or mix options. Record the choice as decision D-001, including the alternatives considered.

## Round 4: setup preferences

Read `references/setup-checklist.md`. Ask only about the items whose defaults the user might want to change. Show the defaults together as one list and ask "keep these defaults or change any?" rather than asking about each item.

## Scaffold

1. **Use the official generator** for the chosen framework (for example `npm create vite@<version>`, `npx create-next-app@<version>`, `uv init`, `cargo new`, Spring Initializr, `dotnet new`), with an exact version that's at least two weeks old. Don't hand-write a framework skeleton.
2. Add the items chosen in Round 4: test runner with one passing example test, lint and format, typecheck, `.env.example` with no secrets, a Dockerfile and compose file if chosen, and a CI workflow that runs lint, typecheck, and test.
3. If it's a web UI, add Playwright as the `ui-test` skill describes, with one smoke test that loads the home page.
4. Write a `README.md` covering setup, run, and test.
5. **Prove it works.** Install, build, run the tests, and start the dev server once. Read the real output. Fix anything that fails before you continue.
6. `git init` if needed, then make a first commit: `chore: project scaffold (<stack>)`.

## Hand off

Run the `init-project` skill. It will now detect the stack you just created, write `storyforge.config.json`, generate the project conventions skill, and write the first architecture doc and `ONBOARDING.md`. Then tell the user the project is ready, and suggest they write the first story for `/storyforge:build-story`.
