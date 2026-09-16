# Analysis — 20260916-094518

- **Addon:** PanelMaster 1.1.0
- **Verdict:** green
- **Commit:** 5fa3af7f51325f91afadf4b1626bf6c137482a77 (master), clean
- **Previous run:** `20260910-234511` (the 1.0.0 → 1.1.0 release run)

## Headline

Both gating suites pass: `luacheck` is clean over 57 files and the headless harness runs 798 cases
with nothing failed and nothing skipped. `perf` is the same permanent skip this addon has always
recorded — it ships no `tests/perf.lua` — so this run says nothing about runtime cost, and that is a
gap rather than a clean bill. `lizard` warns on nothing, and although the addon grew by 534 NLOC and
52 functions since the release run, every average held exactly where it was, so this is growth and
not densification. Nothing newly crossed a threshold and there is nothing to act on beyond the
already-tracked `settings/PanelEditor.lua` split.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260910-234511` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 57 files | [`lint.txt`](lint.txt) | Unchanged — same 0/0 over the same 57 files |
| tests | pass | 798 passed, 0 skipped, 0 failed, 798 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +15 cases (783 → 798); still no skips |
| perf | skip | 0 scenarios — `no tests/perf.lua — this addon ships no offline scenarios` | none — nothing ran, so there is no artifact | Unchanged — skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals up, every average flat |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 13359 |
| Functions | 1554 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 4 |
| Files over the 1500 cap | 0 |

**`perf` — a skip, not a pass.** The suite did not run, because there is no `tests/perf.lua` to run.
This is the first of `automated-tests-§3`'s two sanctioned skip reasons, *nothing to run*, and
**not** a `performance-§12` no-combat-path exemption — `CLAUDE.md` states plainly that `§12` is
neither claimed nor claimable here, because `modules/Canvas.lua:644-650` runs a shared 10Hz
`OnUpdate`. What the repo does hold is a ratified deviation from `performance-§1` (the declined
`Perf` major, recorded in `docs/ARCHITECTURE.md` ▸ *Documented deviations*, with the cost argument in
`docs/performance.md`). So: the decision is ratified, and the offline record is still silent about
runtime cost. Nothing in this bundle measures it.

No other suite is anything but a clean pass. `lint`'s 0/0 is reported with its scope in
`RESULTS.md` ▸ *Lint*: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/` and
`tests/_kit/`, so those paths are not in the 57.

## What moved

- **lint** — nothing moved. 0 warnings / 0 errors over 57 files, the same file count as the
  release run. Checked, not assumed.
- **tests** — 783 → 798, fifteen new cases, with `skipped` at 0 on both runs. The suite grew while
  the addon grew, which is the direction that matters; `test-cases.md` in this bundle is the
  authority on which cases those are.
- **perf** — unchanged, and unchanged in the uninformative direction: skipped on both runs for the
  identical reason.
- **complexity** — the totals rose (NLOC 12825 → 13359, functions 1502 → 1554) and every average
  held: avg NLOC/function 7.4 → 7.4, avg CCN 2.0 → 2.0, max CCN 15 → 15. Avg tokens/function moved
  57.4 → 58.4, the only average that moved at all, and by a margin that is noise at this scale.
  Warned functions stayed at 0, band files at 4, over-cap files at 0. Read together: the addon got
  bigger, not denser, which is not a complexity signal.
- **Band movement inside the band.** Neither file entered or left a band, but two grew:
  `settings/PanelEditor.lua` 1414 → 1476 and `tests/test_panel.lua` 1273 → 1353. `PanelEditor.lua`
  is now 24 lines under `layout-§1`'s 1500 cap and is still the largest file in the repository.

## Complexity watch list

### Functions `lizard` warned on

None. `complexity.txt`'s footer records *"No thresholds exceeded"* and `manifest.json` puts
`suites.complexity.warnings` at 0 with a max CCN of exactly 15 — at the line, not over it.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | Accepted, carried forward — flat at 1188 across six runs now and untouched this cycle. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1476 | Already tracked as [#47](https://github.com/tusharsaxena/PanelMaster/issues/47). Grew again this run, 1414 → 1476, leaving 24 lines of headroom under the 1500 cap. Not a re-accept: the split is the open issue. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | Accepted, carried forward — flat since 2026-08-03. It mirrors `modules/Artwork.lua` and has no seam of its own; it peels when that file does. |
| 1000–1500 (on notice) | `tests/test_panel.lua` | 1353 | Accepted, carried forward. Grew 1273 → 1353 tracking `settings/PanelEditor.lua`; it mirrors that file and peels when #47 peels. The "re-check at 1400" trigger it carries has not fired. |

Nothing newly crossed a band this run, so no disposition cell arrived blank.

`lizard` counts every `and`/`or` short-circuit as a decision, so a Lua run of `t.k = rec.k or D.k`
defaulting lines scores high with no visible branching. With a max CCN of 15 across 1554 functions
and an average of 2.0, none of this addon's functions are near a reading where that distinction
would matter — the watch list here is entirely about file size, not tangled control flow.

## Actions

1. **`settings/PanelEditor.lua` — 24 lines of headroom.** 1476 LOC against `layout-§1`'s 1500 cap,
   growing for the third consecutive run. Already owned by issue
   [#47](https://github.com/tusharsaxena/PanelMaster/issues/47); this run narrows the margin rather
   than changing the decision. The next change that touches this file crosses the cap.
2. **Offline perf remains unmeasured.** No `tests/perf.lua` exists, so no run of this battery can say
   anything about runtime cost. The `Perf` decline is ratified as a `performance-§1` deviation, so
   this is a known and accepted state, not a new finding — but it means the release gate reads `perf`
   as NOT EVALUATED rather than passed at the next tag.
3. **Two earlier bundles carry no `ANALYSIS.md`** — `20260807-110543/` and `20260825-103450/`. Per
   `automated-tests-§5` they are **not** backfilled; the gap is noted here once and closed forward.
