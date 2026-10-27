---
name: init-project
description: "Set up any repository for StoryForge. If the repo is empty (or holds only a README or requirements), run new-project to interview the user and scaffold it. If code exists, read it to detect the tech stack, confirm it with the user, ask only what the code can't reveal, write storyforge.config.json, scaffold docs/memory, generate a project-specific conventions skill and path rules, set up Playwright for web UIs, and write onboarding and architecture docs. Use for '/storyforge:init-project', 'set up storyforge', 'onboard this repo', or when build-story finds no config."
---

# Init project

## 0. Which mode?

Count the source files, ignoring `.git`, `README*`, `LICENSE`, `docs/`, and requirement or PRD files.
- **None:** this is a new project. Run the `new-project` skill and stop. It calls this skill again once the scaffold builds.
- **Some:** this is an existing project. Continue below.
- **Re-run** (`storyforge.config.json` already exists): refresh the stack detection, conventions, and docs. Never overwrite memory content; only add to it.

## 1. Read the project

Work from evidence and keep reads small. Read manifests and config files, not every source file.
- **Languages and frameworks:** `package.json`, lockfiles, `pyproject.toml`/`requirements*.txt`, `pom.xml`/`build.gradle*`, `go.mod`, `Cargo.toml`, `*.csproj`, `Gemfile`, `composer.json`, `pubspec.yaml`.
- **Shape:** the top 2 directory levels, entry points, and monorepo markers (workspaces, `turbo.json`, `nx.json`).
- **Data:** ORM or migration folders, `docker-compose*.yml` services, DB drivers.
- **Integrations:** SDK imports, HTTP clients with base URLs, env var names in `.env.example` and config (names only).
- **Quality tooling:** test runners, lint, format, and typecheck configs. The CI workflow is the source of truth for the real commands.
- **UI:** a frontend framework, a `pages/`, `app/`, or `src/components/` folder, or an existing Playwright or Cypress setup.
- **Conventions:** read 2-3 representative files per layer (a route or controller, a service, a model, a component, a test) to learn naming, error handling, and structure.

## 2. Confirm, and ask only the gaps

Show the user a stack summary of 12 lines or fewer, with each item tagged as `detected` or `guess`. Ask them to correct it. Then ask only what the code can't tell you, using AskUserQuestion where it's available, at most 3 questions per round:
- Deploy target and environments (dev, staging, prod), and whether any test may touch a shared environment (default: no).
- How to run integration tests: Docker or Testcontainers, sandbox accounts, or recorded contracts.
- For UI: the dev server command, its URL, and how a test user logs in.
- Team rules the code doesn't show: review rules, forbidden libraries, and areas that need human approval.

## 3. Scaffold and configure

Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-project.sh"`. If that variable is empty, find the script with `find ~/.claude/plugins -path '*storyforge/scripts/init-project.sh'`. It never overwrites existing files. Then fill in `storyforge.config.json` with the confirmed commands, run each command once, and note any that fail. If the project has a web UI, set `ui.enabled: true` and fill in `ui.start_command`, `ui.base_url`, and `e2e_test`.

## 4. Generate project conventions

Generate project-specific guidance. **Don't generate new agents per stack.** The StoryForge roles are stack-agnostic. Instead, write:
- **`.claude/skills/project-conventions/SKILL.md`**, from `templates/conventions/SKILL.md`. Fill it with what you observed, citing `file:line` examples to copy. Include only knowledge specific to this project. Claude already knows how the framework works in general. Aim for 120 lines or fewer.
- **`.claude/rules/<area>.md`** with `paths:` frontmatter for area-specific rules (for example `src/api/**`, `src/components/**`, `migrations/**`), so they load only when those files are touched. Each file should be 30 lines or fewer.
- A stack-specific review checklist section inside the conventions skill: the mistakes that matter most in this stack (for example, N+1 queries in Django, unawaited promises in Node, missing `@Transactional` in Spring).

## 5. UI testing setup (web UI only)

Follow the `ui-test` skill's setup section: install Playwright if it's missing (ask first), add the config and a smoke test, and merge `templates/mcp/playwright.json` into the project's `.mcp.json`. That way the Playwright MCP server loads only in UI projects.

## 6. Seed memory and docs

- `docs/memory/ARCHITECTURE.md`, `integrations/<name>.md` per detected service (mark unknowns `?`), and `INDEX.md`.
- Run the `feature-docs` skill in **bootstrap** mode. It writes the architecture diagram, the data model diagram, and `docs/ONBOARDING.md`.
- Append `templates/CLAUDE.snippet.md` to `CLAUDE.md` if it isn't there yet.

Finish with a summary of 10 lines or fewer: the stack, the commands verified, the files generated, and the `?` gaps the user should fill in.
