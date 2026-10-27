# Setup checklist (defaults)

Show these as one list. The user changes only what they care about.

| Item | Default |
|---|---|
| Repo layout | Single repo; monorepo (pnpm/turbo, uv workspaces, Gradle multi-project) only for more than one app |
| Package manager | pnpm (JS/TS), uv (Python), Gradle (JVM), Go modules, cargo |
| Language strictness | TypeScript `strict: true`; Python type hints + mypy or pyright |
| Unit test runner | Vitest (TS), pytest (Py), JUnit 5 (JVM), `go test`, `cargo test` |
| Integration tests | A separate command; DB via Docker or Testcontainers |
| E2E / UI tests | Playwright, for any web UI |
| Lint and format | ESLint + Prettier, or Biome (TS); Ruff (Py); ktlint/Spotless (JVM); gofmt + golangci-lint |
| Git hooks | Lint and format on staged files (lefthook or pre-commit) |
| Env and secrets | `.env.example` committed, `.env` gitignored, config validated at startup |
| Containers | Dockerfile + docker-compose for app + DB in local dev |
| CI | GitHub Actions: install → lint → typecheck → unit → integration → e2e (if UI) |
| Branching | Trunk-based: short-lived branches, PRs into `main` |
| Commit style | Conventional Commits |
| Logging | Structured JSON logs; never log secrets or personal data |
| Error tracking | A placeholder hook, wired to a provider later |
| API style | REST + OpenAPI spec (generated or hand-written) |
| DB migrations | The ORM's migration tool; migrations committed |
| License | Ask for public repos; none for private |
