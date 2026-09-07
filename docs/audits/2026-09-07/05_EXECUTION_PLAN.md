# 05 — Execution plan (2026-09-07)

Ordered remediation for the **8 root deviations** and **1 dependent** catalogued in
`02_DEVIATIONS.md` (9 entries in total; the headline tally is 8). Designs are in
`04_TECHNICAL_DESIGN.md`. This is the hand-off to a separate remediation engagement — the audit
itself changed nothing.

**Green gate on every commit:** `lua tests/run.lua` (763/763 today) and `luacheck .` (0/0 today).
**Release gate, at the tag only:** all four suites `pass` plus zero functions above CCN 15, read
from the run's `manifest.json`.

---

## Sprint 1 — the one thing a user can reach today

**Goal:** close the only Medium in the bundle. One code change, one doc change, one commit.

| # | Step | ID | Files | Done when |
|---|---|---|---|---|
| 1.1 | Widen the Panels page's chrome block to two rows and move `Enabled`, `Unlock`, `Copy settings from panel`, `Reset`, `Delete` (and, per the design, `Panel name`) into it. Read the added row height from the library, never a literal. | PM-023 | `settings/PanelEditor.lua:1112-1199` | The five acts render above the strip and are reachable with any tab active |
| 1.2 | Delete `sections[TAB_GENERAL]`, drop `TAB_GENERAL` from the tab list, re-point the fallback at `:1058` to `TAB_POSITION`. | PM-023 | `settings/PanelEditor.lua:164-174`, `:565-677`, `:1058` | The strip draws five tabs, each with content |
| 1.3 | Re-register the moved controls' refreshers against the band: `Enabled` in place, `Copy settings from panel` via `SetList`/`SetValue(nil)` on `MSG_PANELS`, `Unlock` deliberately none. | PM-023 | `settings/PanelEditor.lua` | Switching panel updates all five without releasing the band |
| 1.4 | Add the four cases named in `04_TECHNICAL_DESIGN.md` ▸ PM-023 — band contents by label, the five-tab list, band-widget identity across a tab switch, `Delete`/`Reset` reachable with `Artwork` active. | PM-023 | `tests/test_panel.lua` | Suite green; each case dies under its own mutation |
| 1.5 | Rewrite `docs/settings-panel.md:247`/`:257-261` to state the `options-ui-§14` rule and the band's contents; delete the argument for the old placement. Update the Panels row in `README.md:127` if the tab list changed. | PM-023a | `docs/settings-panel.md`, `README.md` | No doc argues for the removed shape |
| 1.6 | Smoke test in-client: open Settings ▸ Panels, select a panel, click through all five tabs, confirm the acts stay put; delete a panel from the `Artwork` tab. | PM-023 | `docs/smoke-tests.md` | Recorded as a smoke case |

**Exit:** `lua tests/run.lua` green with the new cases, `luacheck .` 0/0, one commit.

---

## Sprint 2 — config and record hygiene

**Goal:** the cheap, zero-risk items. Three commits, no shipped Lua touched.

| # | Step | ID | Files | Done when |
|---|---|---|---|---|
| 2.1 | Add `.gitattributes`, `.claude`, `.superpowers` to `.pkgmeta`'s `ignore:` list with the standard's own comments; add a one-line comment recording that `.pkgmeta` is the packager's input and never shipped. | PM-025 | `.pkgmeta:5-12` | Both `AUDIT.md` packaging checks print nothing but `UNACCOUNTED — .git` |
| 2.2 | Retire the `documentation-§4` row from the deviation register. | PM-029 | `docs/ARCHITECTURE.md:199` | Six rows remain, every one with an unfired trigger |
| 2.3 | Add the `options-ui-§16` register row for PM-024 (text drafted in `04_TECHNICAL_DESIGN.md`), so the hand-written groups are ratified rather than re-filed next cycle. | PM-024 | `docs/ARCHITECTURE.md` | The row cites `options-ui-§16` and names the LibKa0s composer as its re-check trigger |
| 2.4 | Write the two missing `ANALYSIS.md` write-ups — or record in `docs/automated-tests/README.md` that non-release runs may ship without one. Do **not** touch the bundles' measured artifacts. | PM-028 | `docs/automated-tests/20260807-110543/`, `…/20260825-103450/` | Every bundle either has a write-up or is covered by a stated policy |

---

## Sprint 3 — the automated-test record

**Goal:** make the record describe the code again, and settle the watch list's own fired condition.
Runs **after** Sprints 1 and 2 so the numbers describe the remediated tree.

| # | Step | ID | Files | Done when |
|---|---|---|---|---|
| 3.1 | On a clean tree, run `tests/_kit/run-automated-tests.sh` from the repo root. Do not hand-edit anything it generates. | PM-027 | new `docs/automated-tests/<stamp>/` | Bundle frozen, `RESULTS.md` row prepended, verdict green |
| 3.2 | Re-anchor the watch-list prose at `docs/automated-tests/RESULTS.md:102` to the new run. | PM-027 | `RESULTS.md` | No "current state as of" points at a superseded run |
| 3.3 | Correct the stale function citations: `:123-124` and `:174-175` name `core/Compat.lua:34(-52)` and `modules/Registry.lua:604-632`/`:639`; today they are `core/Compat.lua:27` and `modules/Registry.lua:658`. | PM-027 | `RESULTS.md` | Every cited line resolves to the named function |
| 3.4 | Add `tests/test_panel.lua` and `tests/test_libka0s.lua` to the `### Files by layout-§1 band` table with a real disposition each. | PM-027 | `RESULTS.md:151-157` | The table lists every file in the band, re-measured after Sprint 1 |
| 3.5 | Settle `settings/PanelEditor.lua`: re-measure it after Sprint 1, then **either** execute the split (page/band/selection versus the `sections[…]` builders) **or** write a fresh argued disposition. Its previous disposition's own condition — *"if the next change also grows it, execute the split rather than re-accept"* — has fired. | PM-027 | `settings/PanelEditor.lua`, `RESULTS.md:157` | The file is split, or the table carries a new dated disposition that engages with the +259 growth |
| 3.6 | Delete the duplicated `### Functions lizard warned on` heading (`RESULTS.md:106` and `:170`). | PM-027 | `RESULTS.md` | One heading, one list |

**Note.** 3.5 may change the file enough to warrant re-running 3.1. If it does, re-run and keep the
later bundle; a record produced before its own remediation is the staleness this sprint exists to
end.

---

## Sprint 4 — the missing guard

**Goal:** the strip-geometry invariance case. Its own sprint because it needs a mock change and a
deliberate red run.

| # | Step | ID | Files | Done when |
|---|---|---|---|---|
| 4.1 | Extend `tests/wow_mock.lua`'s texture stub so `GetHeight()` answers a **per-atlas** height, selected taller than unselected. Override in the consumer mock, never in the vendored `tests/_kit/`. | PM-030 | `tests/wow_mock.lua` | Existing 763 cases still green |
| 4.2 | Add the invariance case: render the Panels strip at a wrapping width and assert the reserved band and every row's y offset are identical for every value of the active tab. Reset the measurement per case with `__resetTabArtHeight`. | PM-030 | `tests/test_panel.lua` | Case green |
| 4.3 | **Verify it can fail.** Temporarily change `TAB_ATLAS[false]` → `TAB_ATLAS[true]` at `libs/LibKa0s/OptionsWidgets.lua:434`, run the suite, see red, then `git checkout -- libs/`. Commit nothing from `libs/`. | PM-030 | throwaway | Red observed and reverted; `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` empty again |

---

## Sprint 5 — upstream, then re-vendor

**Goal:** PM-024's real fix. Lands in `../LibKa0s`, not here.

| # | Step | ID | Files | Done when |
|---|---|---|---|---|
| 5.1 | In `../LibKa0s`, add a record-backed binding arm to `O.BorderGroup` / `O.BarGroup` / `O.FontGroup` — a `bind` spec supplying getter/setter per key instead of a dotted `path`. Strictly additive within the major. Bump `OptionsCompose.lua`'s LibStub minor and its changelog entry together. | PM-024 | `../LibKa0s/LibKa0s/OptionsCompose.lua` | LibKa0s suite green; the schema-backed arm's output is byte-identical before and after |
| 5.2 | Tag LibKa0s, re-vendor here — **whole ship folder plus `testkit/`** — and move `CLAUDE.md:44`'s provenance line in the **same commit** as the bytes. | PM-024 | `libs/LibKa0s/`, `tests/_kit/`, `CLAUDE.md:44` | Both `diff -r` checks empty against the new tag; `tests/test_vendor_sync.lua` green |
| 5.3 | Replace the three hand-written blocks with three composer calls, passing this addon's extras through `extra` and `show = false`. | PM-024 | `settings/PanelEditor.lua:738-757`, `:770-800`, `:814-830` | Row order, labels, ranges and defaults unchanged on screen; suite green |
| 5.4 | Retire the `options-ui-§16` register row added in 2.3. | PM-024 | `docs/ARCHITECTURE.md` | The register carries no row for a rule the addon now meets |

---

## Sprint 6 — renormalize, last

**Goal:** PM-026. Deliberately last so nothing lands afterwards and re-introduces a straggler.

| # | Step | ID | Files | Done when |
|---|---|---|---|---|
| 6.1 | On a clean tree: `git add --renormalize .`, review, commit **alone**. | PM-026 | index-wide | Commit contains only line-ending changes |
| 6.2 | For each path the `03_EVIDENCE.md` §5 command still reports: `rm <path> && git checkout -- <path>`. | PM-026 | 5 paths | — |
| 6.3 | Re-run the check and record `0`. | PM-026 | — | The command prints `0` |
| 6.4 | Re-run the green gate: `lua tests/run.lua`, `luacheck .`. | PM-026 | — | 763/763, 0/0 |

**Note.** Two of the five paths are inside the frozen `docs/revendor/2026-08-25/` bundle. The
freeze is on content; a line-ending correction is not content. Say so in the commit message so the
next reader does not read it as an edited freeze.

---

## Ordering constraints, in one place

- **PM-023 before PM-027.** The record must describe the remediated page, and Sprint 1 changes
  `settings/PanelEditor.lua`'s length, which is the watch-list entry Sprint 3 has to settle.
- **PM-023 before PM-030.** The invariance case renders the tab list Sprint 1 changes.
- **PM-024's register row (2.3) before the next audit**, or PM-024 is re-filed as an open MUST.
- **PM-024's upstream arm before its addon-side arm.** `libs/` is read-only; there is nothing to
  adopt until LibKa0s ships it.
- **PM-026 last.** Renormalization touches every text file; anything landing after it can
  re-introduce a straggler and the count has to be re-taken.
- **No tag** until Sprint 3 has produced a bundle whose `manifest.json` records the current sha.
  `perf` remains a permanent `skip` under the ratified `performance-§1` row, and the release notes
  must say so — a skip is NOT EVALUATED at the release gate, never passed.

## Not in this plan, deliberately

The seven **ratified** rows in `docs/ARCHITECTURE.md` → `## Documented deviations` are settled
decisions and are not remediation items: the `performance-§1` decline, the absent `## What's new`,
the `events-frames-taint-§8` pre-formatting residue, the English-only `localization-§1` position,
the `line-endings-§5` extensionless-binary block, and the `options-ui-§1` composed-row degradation.
The seventh, `documentation-§4`, is retired by step 2.2 — not because it was wrong, but because the
addon now meets the rule outright.
