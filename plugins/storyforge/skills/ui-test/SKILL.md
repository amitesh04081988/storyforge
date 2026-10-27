---
name: ui-test
description: "UI and end-to-end testing with Playwright: set up Playwright in a project, turn acceptance criteria into committed e2e specs with role-based locators, run them across viewports with traces, visual snapshots, and accessibility checks, then do a short exploratory QA pass with the Playwright MCP browser to catch what scripted tests miss. Use for 'test the UI', 'e2e tests', 'playwright', 'QA this feature', 'check it in the browser', or the ui phase of build-story."
---

# UI test

Committed Playwright specs are the main output. They run in CI on every future change, and that's what keeps defects from reaching QA. The MCP browser is for exploration only. It costs a lot of tokens and isn't repeatable, so keep that pass short.

## Setup (once per project; init-project calls this)

1. If Playwright is missing, ask before installing. Install `@playwright/test` at an exact version that's at least two weeks old, then run `npx playwright install --with-deps chromium`. Add other browsers only if the user wants them.
2. Create `playwright.config.ts` from `templates/playwright.config.ts`. Set `baseURL` and `webServer.command` from `storyforge.config.json` → `ui`.
3. Create `e2e/smoke.spec.ts` (the home page loads and has no console errors) and `e2e/fixtures.ts` (a logged-in page fixture using the project's test login).
4. If `ui.accessibility` is true, install `@axe-core/playwright` at a pinned version of the same age.
5. Merge `skills/init-project/templates/mcp/playwright.json` into the project's `.mcp.json`.
6. Run the smoke test and confirm it passes. Add the e2e step to CI.

## Writing specs for a story

Read `plan.md` § Acceptance criteria. Write one spec file per feature: `e2e/<feature>.spec.ts`.

- **One test per user-visible criterion**, plus empty, error, and loading states, plus at least one abuse case (double-click submit, back button mid-flow, refresh after submit).
- **Locators:** use `getByRole`, `getByLabel`, and `getByText` first, then `getByTestId`. Never use CSS or XPath chains tied to layout. If an element has no accessible name, that's a bug: add a label, which fixes accessibility too.
- **Waiting:** use web-first assertions (`await expect(locator).toBeVisible()`). Never use `waitForTimeout`.
- **Data:** each test creates its own data through the API or fixtures and doesn't depend on test order. Never touch production.
- **Network faults:** use `page.route()` to simulate a 500, a slow response, or an empty list for the integrations the story touches.
- **Viewports:** run on desktop, plus a mobile project if `ui.viewports` includes mobile.
- **Visual snapshots** (if enabled): call `toHaveScreenshot()` on key screens, with animations disabled and dynamic regions masked. The first run creates the baselines; commit them.
- **Accessibility** (if enabled): run an `AxeBuilder` scan on each new screen. Serious or critical violations fail the test.
- Collect console errors in the fixture and fail on any unexpected one.

Run `e2e_test`. On failure, read the trace (`npx playwright show-trace` isn't available headless, so read `test-results/**/error-context.md` and the screenshots) before you conclude anything.

## Exploratory pass (Playwright MCP, at most about 15 actions)

After the specs pass, start the app and explore the new feature the way a QA tester would, using `references/issue-taxonomy.md` § Per-Page Exploration Checklist. Look for what the specs don't cover: layout on narrow widths, focus order with Tab, unclear error text, dead ends, and console noise. Every real issue becomes a new spec that fails now. Issues found only by eye go in findings with a screenshot path.

## Output

Inside build-story, append to `findings.md` under `## UI`:
`- [CRITICAL|HIGH|INFO] <category> — what happens → expected (spec: e2e/x.spec.ts::name | screenshot: path)`
Rate each issue with the taxonomy's severity levels, then write it with the tag build-story reads: taxonomy **critical** → `CRITICAL`, **high** → `HIGH`, **medium** and **low** → `INFO`. The done check blocks on every open CRITICAL and HIGH, so an issue written with any other tag is not seen. Also list the screens and criteria covered.
