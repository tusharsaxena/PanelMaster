# 05 — Execution plan (2026-09-23)

The hand-off to the remediation engagement. It covers **17 roots and 2 dependents** (19 items), of
which 15 roots are MUST failures (17 including the dependents). The grades are one High, fourteen
Low and two Info among the roots, and sixteen Low with the dependents counted. Every step names its
ID(s). **Upstream first, then the whole-folder re-vendor, then the addon.** The green gate
(`lua tests/run.lua` plus `luacheck .`, both through `ka0s-bounded`) must pass at the end of every
step that touches code or tests. `docs/test-cases.md` and the README `[tests]` badge move in the
same commit as any change to the case count.

Baseline at `afb30d7`: 884/0/884 tests, luacheck 0/0 over 60 files, lizard 0 warnings with max CCN
15, the vendored payloads identical to `v1.55.0`, and 29 commits since the newest bundle.

## Sprint 0 — Upstream (LibKa0s, then WowAddonStandards)

- [ ] **0.1 (`PM-041`)** LibKa0s `testkit/test_prose.lua`: add `docs/superpowers/` and
      `docs/investigations/` to `SKIPPED_DIRS`, with a self-test pinning both the exclusion and its
      narrowness. Bump the kit revision (26), write the changelog entry, get the library's kit-sync
      gate green, and tag a patch release.
- [ ] **0.2 (`PM-038`, `PM-048`; proposal only, does not block)** File two items for the
      WowAddonStandards documentation lane: a ruling on migration-stamp ownership, with this addon's
      "runner-stamped, never declared" shape as the worked case; and the grading conflict between
      `AUDIT.md`'s re-vendor check ("High") and its step-5 table.

## Sprint 1 — Re-vendor (after 0.1 is tagged)

- [ ] **1.1 (`PM-041`, `PM-045`)** Re-vendor the **whole** `LibKa0s/` and `testkit/` from the new
      tag. Update the `CLAUDE.md:44` provenance line in the same commit and run
      `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`. Verify both `diff -r`
      against the tag come back empty and `test_vendor_sync` is green.
- [ ] **1.2** Write the tag's bundle `docs/revendor/<date>-v<tag>/` (`01_DELTA.md`, `05_SUMMARY.md`).
- [ ] **1.3 (`PM-048`)** Write **one** consolidated bundle, `docs/revendor/<date>-v1.18.0-to-v1.53.0/`,
      naming the span of 25 tags and the 32 commits since `2026-08-25`. Re-run the playbook's
      two-listing script and confirm it prints nothing. If it does not, make the first line or the
      folder name enumerate the tags the reader needs.
- [ ] **1.4 (`PM-045`)** Re-point `DEPENDENCIES.md:63`'s `tests/_kit/framework.lua` citations
      against the payload just vendored, adding function names next to the line numbers.

## Sprint 2 — The High (`PM-034`, `PM-034a`)

- [ ] **2.1 (`PM-034a`)** Extend `tests/test_disabled.lua` step 5 with routes A, B and C. Assert 0
      shown and 0 mouse-enabled panel frames, plus outlines restored on re-enable. Add a
      `red under` comment. **Run it and watch it fail** against the unfixed `Canvas:Render`.
- [ ] **2.2 (`PM-034`)** In `modules/Canvas.lua:Render`, gate `Unlock:Decorate` on
      `NS.Lifecycle:IsDown()` and call `Unlock:StripOverlay(f)` when the addon is down
      (`04_TECHNICAL_DESIGN.md` C1). Get the suite green.
- [ ] **2.3** Add the unlock-then-disable case to `docs/smoke-tests.md`. Regenerate
      `docs/test-cases.md` and the badge.

## Sprint 3 — Code and test hygiene (`PM-035`, `PM-040`, `PM-036`, `PM-037`)

- [ ] **3.1 (`PM-035`)** Add `safeRegister` with a per-event `pcall` and a session
      `NS.State.rejectedEvents` list, surfaced in `D:Diagnose()`. Route the four registrations
      through it. Write the test first with the kit's `M.__badEvents`.
- [ ] **3.2 (`PM-040`)** Add the Lifecycle parity case (real partial load, grep named in the
      comment) and the `Kit.setSurfaceSource` row. That brings the parity cases from 6 to 7; update
      `tests/test_surface_parity.lua:3`.
- [ ] **3.3 (`PM-036`, `PM-037`)** Annotate `PanelMaster.toc:56` (`core\Util.lua` needs
      `NS.Constants` at load) and `:97` (`settings\Slash.lua` needs `NS.SchemaRuntime` at load). Add
      one conventional-group note per unannotated group.

## Sprint 4 — Register and docs

- [ ] **4.1 (`PM-038`, `PM-038a`)** Add the `toc-file-§2` / `savedvariables-§1` register row (the
      text is in the design, D1). Fix `docs/ARCHITECTURE.md:34` and `docs/common-tasks.md:12-13`.
- [ ] **4.2 (`PM-039`)** Get the owner's decision on the `architecture-§5` row: adopt instance
      addressing and retire the row, or re-word the trigger to the host-side condition and re-date
      it. Either way, file or cite a `state:triaged` issue.
- [ ] **4.3 (`PM-031`)** Write `docs/compat-layer.md` covering the 8 shims. Flip the map row at
      `docs/ARCHITECTURE.md:327` to *Present*.
- [ ] **4.4 (`PM-042`)** Spill `docs/ARCHITECTURE.md:47-78` to `docs/schema.md`, collapse the
      retired-row narratives (`:380-428`), and rename `## Message bus` → `## Message Bus` and
      `## Taint` → `## Taint Notes`. The target is under 400 lines (from 471), with Settings Schema
      under ~60 (from 102).
- [ ] **4.5 (`PM-043`)** Add `tests/` and `tools/` tables to `docs/module-map.md`, covering the 28
      unmapped test-tree files and the 3 unmapped generators.
- [ ] **4.6 (`PM-044`)** Sweep the stale inventories and comments: `docs/ARCHITECTURE.md:21-24`
      and `:339`, `docs/testing.md:106`, `:340-351` (restating 7 parity cases after 3.2),
      `docs/module-map.md:69-70`, `settings/PanelEditor.lua:178-190` and `:1191-1223`, and
      `.gitignore:6`. Recount with `grep -c`, never by hand.
- [ ] **4.7 (`PM-046`)** README: write the placeholders at `:51` and `:79-80` bare, end Usage on
      the configuration signpost, and merge the disabled-state paragraphs. Run the de-AI pass.
- [ ] **4.8 (`PM-041`, host half)** Once 1.1 has landed, restore line 5 of the two
      `docs/superpowers/specs/*` files from `e30e329^`, and confirm `test_prose` stays green.

## Sprint 5 — Store and record

- [ ] **5.1 (`PM-047`)** Close #19, #20, #22 and #23 as `state:done`, and #24 as
      `state:will-not-do`, each with a one-line evidence comment. Space the API writes out.
- [ ] **5.2 (`PM-033`)** At the next release, produce the full four-suite release bundle. Kit 25
      emits the SHA and clean/dirty cells. Carry the four band dispositions forward, and note in
      that bundle's `ANALYSIS.md` that 1.1.1 has no release bundle. Do not backfill it.

## Exit check

- [ ] `lua tests/run.lua` green, with the count raised by the cases added in 2.1, 3.1 and 3.2, and
      `docs/test-cases.md` and the badge matching it.
- [ ] `luacheck .` 0/0. `lizard` shows no new warning.
- [ ] Both `diff -r` checks against the new tag empty. The line-ending check (e) = 0. The re-vendor
      two-listing check prints nothing.
- [ ] Every register row's trigger has been re-evaluated (`audit-review-history`).
- [ ] A follow-up `/wow-addon:standards-audit` finds none of `PM-031`, `PM-034` … `PM-048` open,
      apart from anything an owner's decision (4.2) has turned into a ratified row.

| Sprint | IDs | Upstream? |
|---|---|---|
| 0 | PM-041 (kit), PM-038 / PM-048 (standard proposals) | **yes** |
| 1 | PM-041 delivery, PM-045, PM-048 | re-vendor |
| 2 | PM-034, PM-034a | — |
| 3 | PM-035, PM-040, PM-036, PM-037 | — |
| 4 | PM-038, PM-038a, PM-039, PM-031, PM-042, PM-043, PM-044, PM-046, PM-041 (host) | — |
| 5 | PM-047, PM-033 | — |

Every ID in `02_DEVIATIONS.md` (17 roots and 2 dependents) has at least one step. Four of them
are split across an upstream half and a host half, and appear in each: `PM-041` (0.1, 1.1, 4.8),
`PM-045` (1.1, 1.4), `PM-048` (0.2, 1.3) and `PM-038` (0.2, 4.1).
