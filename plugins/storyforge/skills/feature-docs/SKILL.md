---
name: feature-docs
description: "Write knowledge-transfer documentation from the code as built: a per-feature doc with Mermaid sequence, flow, and state diagrams; project-level architecture (C4-style), data model (ER), and class diagrams; and an ONBOARDING.md guide for new developers. Use for 'document this feature', 'UML', 'sequence diagram', 'architecture diagram', 'ER diagram', 'onboarding doc', 'knowledge transfer', 'docs for new developers', the docs phase of build-story, or bootstrap from init-project."
---

# Feature docs

Docs describe **what the code does now**. Write them after the build, from the code and tests, never from the plan alone. Use Mermaid inside markdown: GitHub renders it, it diffs cleanly, and it's easy to update. These docs are for humans, so they are **not** loaded at session start and cost no tokens unless someone opens them.

```
docs/
├── ONBOARDING.md            # start here for new developers
├── architecture.md          # system context + containers + key flows
├── data-model.md            # ER diagram + table notes
└── features/<feature>.md    # one per feature
```

## Per-feature doc (the docs phase of build-story)

Use `templates/feature.md`. Fill in only the sections that apply:
- **What it does** for the user (3-5 lines) and the acceptance criteria it satisfies.
- **Sequence diagram** of the main flow, through the real components (UI → API → service → DB/integration). Use real names from the code, and include the main error branch (`alt`).
- **Flow or state diagram** if the feature has branching logic or a lifecycle (for example, order states).
- **Data changes:** a small ER fragment for the new or changed tables.
- **Class diagram** only for non-trivial domain logic (5 or more collaborating classes). Skip it for plain CRUD.
- **Key files:** `path` with a one-line role each. **Integrations** link to `docs/memory/integrations/*.md`. **Tests** list where the unit, integration, and e2e tests are.
- **Gotchas:** non-obvious behavior, taken from `findings.md` and the fix loop.

When `docs.level` is `light`, write the What section, the sequence diagram, Key files, and Tests, in 80 lines or fewer. When it's `full`, write every applicable section. If the feature changed the system's shape, also update `architecture.md` and `data-model.md`.

## Bootstrap (init-project, or "document the whole project")

1. `architecture.md`: a system context diagram (users, the system, external services) and a container diagram (apps, DB, queues, third parties). Use Mermaid `flowchart` with subgraphs; it renders everywhere. Then add the 2-3 most important request flows as sequence diagrams.
2. `data-model.md`: a Mermaid `erDiagram` built from the migrations, schema, or ORM models. Show keys and relationships, and only the important columns.
3. `ONBOARDING.md` from `templates/onboarding.md`. Every command in it must be one you **ran successfully**. A wrong setup step costs a new developer a day.

## Rules

- Before saving, check every Mermaid block for syntax errors: quote labels that contain special characters, keep one statement per line, and avoid reserved words as node ids (like `end`). If `npx -y @mermaid-js/mermaid-cli` is available, render each diagram to confirm it.
- Keep diagrams readable: about 12 nodes or fewer. Split a bigger one.
- Use real names from the code: files, classes, endpoints, tables. If something isn't in the code, it doesn't go in the doc.
- No secrets, real user data, or internal hostnames that shouldn't be shared.
- Link instead of duplicating. Integration contracts live in `docs/memory/integrations/`, and decisions in `DECISIONS.md`.
