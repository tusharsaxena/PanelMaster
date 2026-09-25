# Analysis — 20260924-104311

- **Addon:** PanelMaster 1.1.1
- **Verdict:** green
- **Commit:** bf1291da8ba9f851c18dda427a7b472118cfdd1e (feat/2026-09-23-review-audit-remediation), dirty
- **Previous run:** `20260916-184500`

## Headline

Both gating suites pass: `luacheck` is clean over 61 files and the headless harness runs 921 cases
with nothing failed and nothing skipped. `perf` is the same permanent skip as every earlier run,
because there is no `tests/perf.lua`, so this run says nothing about runtime cost. `lizard` warns on
nothing. The addon grew by 1247 NLOC and 151 functions since `20260916-184500`, and every average
held (7.4 NLOC, 2.0 CCN, max 15). The one new fact is on the watch list: `tests/test_libka0s.lua`
entered the 1000–1500 band at 1086 and has been given a disposition. This label is not a release
run. It records the tree at the end of the 2026-09-23 remediation, before a version bump.

**The tree was dirty, and only with documentation.** The run was made after the PM-DOCS sync-docs
edits and before they were committed, as the remediation plan requires. At run time the uncommitted
paths were `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/common-tasks.md`, `docs/performance.md`,
`docs/settings-panel.md` and `docs/testing.md`, and nothing else. None of them is a `.lua` file, so no
figure in this bundle depends on them, and the commit that carries this bundle is `bf1291d` plus
exactly those edits, this bundle and the rolled `RESULTS.md`. Every `RESULTS.md` Disposition cell
written for this run was authored after the runner finished, per Step 3.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260916-184500` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 61 files | [`lint.txt`](lint.txt) | Same 0/0, over two more files (59 → 61) |
| tests | pass | 921 passed, 0 skipped, 0 failed, 921 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +87 cases (834 → 921); still no skips |
| perf | skip | 0 scenarios — `no tests/perf.lua — this addon ships no offline scenarios` | none — nothing ran, so there is no artifact | Unchanged, skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals up, averages flat, avg tokens up 0.5 |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 15134 |
| Functions | 1775 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 5 |
| Files over the 1500 cap | 0 |

**`perf` is a skip, not a pass.** The suite did not run because there is no `tests/perf.lua` to
run. The runner wrote skip reason (1) of `automated-tests-§3`, *nothing to run*. It did not write
reason (2), a ratified `performance-§12` exemption, and it should not have: the Documented-deviations
row in `docs/ARCHITECTURE.md` cites `performance-§1`, and its own text says `§12` does not apply and
is not claimed. So nothing in this bundle measures runtime cost, and no row in it says the addon is
cheap. No tool install would change that. Only offline scenarios in `tests/perf.lua` would.

Every other suite is a clean pass. `lint`'s 0/0 carries its scope in `RESULTS.md` ▸ *Lint*:
`.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/` and `tests/_kit/`. `lizard`
runs with the same vendored carve-out (`-x "./libs/*" -x "./tests/_kit/*"`), so every NLOC figure
here is authored code. The v1.56.0 re-vendor (`b26ab40`) is not part of this run's growth.

## What moved

- **lint**: still 0 warnings / 0 errors, now over **61** files rather than 59
  ([`lint.txt`](lint.txt)). Both new files were clean when they arrived.
- **tests**: **834 → 921**, 87 new cases, `skipped` 0 on both runs. Comparing this bundle's
  [`test-cases.md`](test-cases.md) with the previous run's: `test_schema.lua` 30 → 50,
  `test_disabled.lua` new at 19 (the stand-down latch, `d5ed125`), `test_prose.lua` new at 15 and
  `test_spelling.lua` gone at 3 (the kit's US-English gate replaced this repo's copy, `e30e329`),
  `test_layout_cap.lua` 3 → 13 (the kit's cap gate, `b7edc9f`), `test_compat.lua` 11 → 14,
  `test_database.lua` 21 → 24, `test_surface_parity.lua` 5 → 8, and +1 or +2 in `test_canvas`,
  `test_eol`, `test_launcher`, `test_panel`, `test_profiles`, `test_registry`, `test_slash`,
  `test_unlock` and `test_util`. The additions follow the LibKa0s v1.55.0 Schema adoption and the
  remediation items PM-00 to PM-13. The suite grew because the addon did.
- **perf**: did not move and could not: 0 scenarios on both runs, with the same skip reason.
- **complexity**: totals up, averages flat. NLOC 13887 → **15134** (+1247), functions 1624 → **1775**
  (+151). Avg NLOC / function stays at **7.4** and avg CCN at **2.0**, to the decimal the footer
  prints. Max CCN is **15** on both runs. Avg tokens / function rose **58.1 → 58.6**, which is too
  small to call densification. Warnings stay at 0, with both rates at 0.00.
- **the max-CCN pair**: the same two functions sit at exactly CCN 15, `Compat.AddOnFolders`
  (`core/Compat.lua@27-45`) and `R.ApplyArtSize`, which moved from `modules/Registry.lua@607-635` to
  `@611-639` because the remediation edited code above it. `lizard` warns above 15, not at 15, so
  neither is warned on.
- **the watch-list files**: `settings/PanelEditor.lua` **1476 → 1447**. It peaked at 1487 during
  the remediation and PM-22 trimmed it back. `tests/test_panel.lua` **1353 → 1399**, from PM-06's
  Unlock cases. `tests/test_artwork.lua` is flat at 1356 and `modules/Artwork.lua` flat at 1188.
  **New to the band:** `tests/test_libka0s.lua` at 1086 (971 at `3c4005a`). The band count went from
  4 to 5, and nothing is over the cap.
- **the record's age**: the previous bundle measured `3c4005a`, 60 commits behind this run's HEAD,
  and the runner said so. This run closes that trend gap (`automated-tests-§4`, PanelMaster-A-18).

## Complexity watch list

Current as of this run's own [`complexity.txt`](complexity.txt). The copy of record is
`RESULTS.md` ▸ *Complexity watch list*, where the Disposition column is the one authored cell.

### Functions `lizard` warned on

None. No function is above CCN 15 across 1775 functions ([`manifest.json`](manifest.json),
`suites.complexity.warnings`).

### Files by the `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1447 | Tracked, not accepted: the split is issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47). Down 29 this run, with 53 lines under the cap. One feature change can still cross it. |
| 1000–1500 (on notice) | `tests/test_panel.lua` | 1399 | Accepted. Mirrors `settings/PanelEditor.lua` and peels with #47. One line under its re-check-at-1400 trigger. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | Accepted. Mirror suite for `modules/Artwork.lua`. It has no seam of its own and peels when the module does. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | Accepted, and watch the direction. Unchanged since the 1.0.0 release run. Split on the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1086 | **New.** Accepted. The adoption suite crossed 1000 through PM-09 (+73) and PM-12 (+37). Its 13 `Degraded …` cases are a seam of its own. Re-check at 1300 or at the next adopted major. |

The one entry that **newly** crossed a threshold is `tests/test_libka0s.lua`. The runner wrote its
row into `RESULTS.md` with a blank Disposition cell, and that cell is now filled.

**On shelf life.** `automated-tests-§4` retires a disposition carried as *Accepted* across three
consecutive **release** runs. The record still holds exactly two release runs, `20260807-160022`
(1.0.0) and `20260910-234511` (1.1.0), and this run is not a third (`manifest.json` `release` is
`null`). So no *Accepted* entry has passed its shelf life. Each one is carried forward because its
argument still holds.

## The 1.1.1 release has no bundle, recorded once

`1.1.1-release` is tagged on `dd04000` (2026-09-11, *"Dummy commit to trigger a new build"*). That
commit was tagged with no release bundle, and its TOC still read `## Version: 1.1.0`. The TOC was
aligned to 1.1.1 afterwards, in `940bb11`. `automated-tests-§6` requires a full four-suite bundle
before every release tag, and 1.1.1 does not have one (PanelMaster-A-18).

The gap is closed going forward and not backfilled. **No bundle in this record is stamped for
1.1.1**, and this one does not claim to be. It carries `addonVersion` 1.1.1 because that is what the
TOC reads today, but its `release` is `null`, and a bundle made at this HEAD cannot measure
`dd04000`. The gap closes at the next release, run as a release through `/wow-addon:bump-version`
(`tests/_kit/run-automated-tests.sh --release <X.Y.Z>` under the bounded runner, on a clean tree).
This note is not repeated in later bundles.

## Actions

1. **Owed at the next release:** run the four-suite battery as a **release** run through
   `/wow-addon:bump-version`. That run closes the 1.1.1 gap going forward
   (`automated-tests-§6`).
2. **Still owed:** issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47), peeling the
   appearance editor out of `settings/PanelEditor.lua`. The remediation left 53 lines of headroom
   under the cap. `tests/test_panel.lua` sits one line under its own 1400 trigger and peels with it.
3. **Watch:** `tests/test_libka0s.lua`. If it reaches 1300, or this addon adopts another LibKa0s
   major, lift the `Degraded …` cases into a sibling suite.
4. **Standing gap, no owner:** the addon ships no `tests/perf.lua`, so every run in this record is
   silent about runtime cost. No tooling fix exists for that. It stays with the standing `## Perf`
   section of `RESULTS.md` and is not filed separately.
