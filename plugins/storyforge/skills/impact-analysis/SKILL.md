---
name: impact-analysis
description: "Use the dependency map (docs/memory/DEPENDENCIES.md) to find every area a change affects, decide for each whether it needs checking or changing, and turn the ones that need changes into plan items, scope, and tests. Use for 'what does this affect', 'impact of this change', 'dependency matrix', 'which areas should we re-check', 'new task or issue: what else is touched', or the impact phase of build-story. Also builds and repairs the map itself."
argument-hint: "<story-id> | <paths or description of a change> | map"
---

# Impact analysis

The dependency map answers "what depends on this?" without grepping from scratch each time. This skill uses the map, checks what it says against the code, and makes the follow-through happen: affected areas that need changes get planned, scoped, tested, and verified like any other part of the story.

The map is a guide, not proof. It only lists what can be read from the code, plus what people wrote in **Notes**. Treat every affected area as a claim to check, and every unmapped path as a gap to close.

## The map

`docs/memory/DEPENDENCIES.md` is one table, one row per area:

| Area | Kind | Paths | Depends on | Tests | Notes |
|------|------|-------|------------|-------|-------|
| billing | integration | src/billing/** | db | - | Stripe webhooks |

`Depends on` is the only stored edge. "Used by" is computed by `scripts/impact.sh`, so the two never disagree.

## Mode 1: impact of a change (story or issue)

Inputs: `docs/stories/<id>/plan.md` and `scope.txt`, or a list of paths, or a task or issue description you first translate into the files and areas it will probably touch.

1. **Look up.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/impact.sh" --scope docs/stories/<id>/scope.txt` (or pass paths). If the variable is empty, find it with `find ~/.claude/plugins -path '*storyforge/scripts/impact.sh'`. Exit 4 means there is no map: run Mode 3 first, then come back.
2. **Close gaps.** For each `UNMAPPED` path, decide which area owns it, or add a new row. Do this now so the lookup is complete.
3. **Verify the edges that matter.** The map can be stale or incomplete. For each `DIRECT` area, grep the codebase for the symbols, routes, tables, events, config keys, or types the plan changes, and compare with the `AFFECTED` list. Add any dependent the map missed, and note it for the map update.
4. **Decide per affected area.** For each area in `AFFECTED` (and each one you found in step 3), read the code that uses the changed thing, then choose exactly one:
   - **none:** it doesn't use anything that changes. Say why in one line, with `file:line`.
   - **check:** it uses something that changes, but behavior should stay the same. Name the test or the command that proves it. If its Tests column is `-`, that's a gap: add a test.
   - **change:** it breaks or needs an update. Name the file and what changes.
5. **Prove the riskiest fact.** For the one or two areas where "no change needed" is the least certain, apply the `blast-radius` skill and run real code instead of reasoning.
6. **Write `docs/stories/<id>/impact.md`** (40 lines or fewer):

   ```
   # Impact: <story title>
   Changed areas: billing (src/billing/**)
   | Area | Hop | Decision | Evidence or action | Test |
   |------|-----|----------|--------------------|------|
   | orders | 1 | change | create.ts:42 calls charge(amount) and the signature changes | tests/orders/create.test.ts::charges_in_cents |
   | reports | 1 | check | monthly.ts:9 only reads Charge.status, unchanged | run: npm test -- reports |
   | auth | 2 | none | does not import billing; via db only | - |
   Map gaps fixed: src/newthing/** added as area "newthing"
   ```

7. **Follow through for every `change` and every `check` row.**
   - Append to `plan.md` under `## Impact-driven changes`: one numbered item per row, written like an acceptance criterion ("Orders still create a charge after the billing signature change").
   - Add each `check` and `change` test to `plan.md` § Test plan, so `test-writer` covers it.
   - For each `change` row, append the area's paths to `scope.txt` after a `# impact` comment line, so the developer can edit them. Never widen scope for `none` or `check` rows.
   - Add one row per `check` and `change` area to the definition-of-done matrix in verify (see `build-story`).

## Mode 2: update the map after a story

Run by `memory-keeper` in update mode. From the diff, update `DEPENDENCIES.md`:
- New area or moved paths: add or edit its row.
- New or removed imports between areas: edit `Depends on`.
- New runtime link (event, queue, shared table, HTTP call): add it to `Notes`.
- A new test covering an area: update `Tests`.
Only record what is true in the code now. Never store secrets.

## Mode 3: build or repair the map (`map`)

1. Decide the areas from the code layout: top-level modules, packages, services, plus anything that is not code but changes behavior: database schema and migrations, config, external integrations, scheduled jobs, UI. Aim for 5 to 30 areas. Fewer than 5 means areas are too coarse to help. More than 30 means they're too fine.
2. Write the rows with `Kind`, `Paths`, and `Tests` (find where each area's tests live). Seed `Notes` from `docs/memory/integrations/`.
3. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/dep-scan.sh"`. It prints candidate edges from import lines. For each candidate, confirm it in the code, then record it under `Depends on`. Look for edges the scan can't see (events, queues, shared tables, HTTP calls, dynamic imports, reflection) and add them with a note.
4. Run `scripts/impact.sh` on a file in a central area, such as the database layer, and check that the result looks right to a person who knows the system.
5. Mark anything you couldn't confirm with `?` in Notes.

## Limits to tell the user

- Edges come from a text search of import lines and from what people wrote down. Runtime links that leave no import are only as good as the Notes.
- Monorepos with shared libraries need an area for each shared package, or everything shows up as "unmapped".
- A dependent area being listed means "check it", not "it's broken".
