# Analysis — 20260916-184500

- **Addon:** PanelMaster 1.1.0
- **Verdict:** green
- **Commit:** 3c4005abd6ae7266f56c289b9f78b910b032665d (master), clean
- **Previous run:** `20260916-094518` (this morning, the run before the launcher work landed)

## Headline

Both gating suites pass: `luacheck` is clean over 59 files and the headless harness runs 834 cases
with nothing failed and nothing skipped. `perf` is the same permanent skip this addon has always
recorded — it ships no `tests/perf.lua` — so this run is silent about runtime cost, which is a gap
and not a clean bill. `lizard` warns on nothing; the addon grew by 528 NLOC and 70 functions since
this morning and every average held (7.4 NLOC, 2.0 CCN, max 15), with average tokens per function
easing 58.4 → 58.1, so this is growth and not densification. Nothing newly crossed a threshold. One
thing to act on is not a number but a stale sentence: the carried `settings/PanelEditor.lua`
disposition still named `refreshHeaderActs` as the addon's densest function, and that function no
longer exists — corrected below and in `RESULTS.md`.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260916-094518` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 59 files | [`lint.txt`](lint.txt) | Same 0/0, over two more files (57 → 59) |
| tests | pass | 834 passed, 0 skipped, 0 failed, 834 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +36 cases (798 → 834); still no skips |
| perf | skip | 0 scenarios — `no tests/perf.lua — this addon ships no offline scenarios` | none — nothing ran, so there is no artifact | Unchanged — skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals up, every average flat or easing |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 13887 |
| Functions | 1624 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 4 |
| Files over the 1500 cap | 0 |

**`perf` — a skip, not a pass.** The suite did not run, because there is no `tests/perf.lua` to run.
That is the first of `automated-tests-§3`'s two sanctioned skip reasons, *nothing to run*, and
**not** a ratified `performance-§12` no-combat-path exemption. Nothing in this bundle measures
runtime cost, and no row in it should be read as saying the addon is cheap. Install hint: there is
no tool to install — the fix is for the addon to ship offline scenarios in `tests/perf.lua`.

No other suite is anything but a clean pass. `lint`'s 0/0 is reported with its scope in `RESULTS.md`
▸ *Lint*: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/` and
`tests/_kit/`, so those paths are not among the 59. `lizard` is run with the same shape of
carve-out (`-x "./libs/*" -x "./tests/_kit/*"`, [`complexity.txt`](complexity.txt)), so every NLOC
figure here is authored code: none of this run's growth is the re-vendored library.

## What moved

- **lint** — still 0 warnings / 0 errors, now over **59** files rather than 57
  ([`lint.txt`](lint.txt)). The two additions are the launcher's own files, `core/LauncherSetup.lua`
  and `tests/test_launcher.lua`, both clean on arrival.
- **tests** — **798 → 834**, thirty-six new cases, `skipped` 0 on both runs. Comparing this bundle's
  [`test-cases.md`](test-cases.md) against the previous run's: `test_launcher.lua` is new at 23
  cases, `test_slash.lua` 64 → 73, `test_constants.lua` 16 → 19, `test_surface_parity.lua` 4 → 5.
  All four track the launcher work committed today (`4c94388`, `a3df89c`, `417a5da`) on top of the
  LibKa0s v1.39.0 re-vendor (`dd600fe`) — the suite grew because the addon did, which is the
  direction that matters.
- **perf** — did not move and could not: 0 scenarios both runs, same skip reason.
- **complexity** — totals up, averages flat. NLOC 13359 → **13887** (+528), functions 1554 → **1624**
  (+70); avg NLOC / function **7.4** and avg CCN **2.0** are unchanged to the decimal the footer
  prints, max CCN is **15** on both runs, and avg tokens / function eased **58.4 → 58.1**. Warnings
  stay at 0 with both rates at 0.00. New code landing at the existing density is the reading here.
- **the max-CCN pair** — unchanged and worth naming, because a carried disposition got it wrong.
  The two functions at exactly CCN 15 are `Compat.AddOnFolders`
  (`core/Compat.lua@27-45`) and `R.ApplyArtSize` (`modules/Registry.lua@607-635`), identical in both
  bundles' `complexity.txt`. Neither is warned on — `lizard` warns above 15, not at it.
- **the watch-list files** — all four flat. `settings/PanelEditor.lua` 1476,
  `tests/test_artwork.lua` 1356, `tests/test_panel.lua` 1353, `modules/Artwork.lua` 1188; none moved
  this run, and the band count stayed at 4 with 0 over the cap.
- **the commit under test** — HEAD is `3c4005a`, *"The Master controls comment counts its own rows
  correctly"*, which rewrote one comment block in `settings/Schema.lua` that gave three different
  counts for the same tab. It is comment-only, and the numbers here agree: it is not why anything in
  this run moved. The movement is the launcher cycle underneath it.

## Complexity watch list

Current as of this run's own [`complexity.txt`](complexity.txt); the generated copy of record is
`RESULTS.md` ▸ *Complexity watch list*, where the Disposition column is the one authored cell.

### Functions `lizard` warned on

None. Zero functions above CCN 15 across 1624 functions ([`manifest.json`](manifest.json),
`suites.complexity.warnings`).

### Files by the `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1476 | Tracked, not accepted: the split is issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47). Flat this run at 1476, still the largest authored file and still 24 lines under the cap. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | Accepted. Mirror suite for `modules/Artwork.lua`; it has no seam of its own and peels when the module does. |
| 1000–1500 (on notice) | `tests/test_panel.lua` | 1353 | Accepted. Flat this run after tracking `settings/PanelEditor.lua` up last run; peels with #47. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | Accepted, and watch the direction. Unchanged since the 1.0.0 release run; split on the catalog / geometry seam before the next feature lands in it. |

Nothing **newly** crossed either threshold this run: the band membership and every LOC in it are the
same four rows and the same four numbers as `20260916-094518`.

**On shelf life.** `automated-tests-§4` retires a disposition carried as *Accepted* across three
consecutive **release** runs. This record contains exactly two release runs — `20260807-160022`
(1.0.0) and `20260910-234511` (1.1.0), the only two bundles whose `manifest.json` has a non-null
`release` — so no entry here can yet have crossed that line, and none is re-accepted past its shelf
life. The three *Accepted* rows above are carried forward on their own still-true arguments.

**On reading these CCNs.** `lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a
run of `t.k = rec.k or D.k` defaulting lines scores high with no visible branching. Both CCN-15
functions are that shape rather than tangled control flow: `Compat.AddOnFolders`
(`core/Compat.lua@27-45`) is 17 NLOC of API-presence guarding across client flavours, and
`R.ApplyArtSize` (`modules/Registry.lua@607-635`) is 17 NLOC of field defaulting before a sizing
call. Dense defaulting/guarding, not tangle — which is why neither has a peel action against it.

## Actions

1. **Correction, applied.** The `settings/PanelEditor.lua` disposition in `RESULTS.md` was carrying
   the clause *"It also holds the addon's highest-CCN function, `refreshHeaderActs` at exactly 15"*.
   That function no longer exists: it was deleted rather than moved when the header actions stopped
   being rebuilt (`docs/settings-panel.md:406`), and it is absent from this bundle's and the
   previous bundle's `complexity.txt` alike — so the clause was already stale one run ago. This
   run's densest function in that file is CCN **8**. The clause is removed and the "grew again this
   run, 1414 → 1476" reading is re-anchored to the run it was true of. Frozen bundles are untouched;
   per the playbook's hard rules, the earlier reading stands as what was believed at the time and
   this is where it is said.
2. **Still owed, unchanged:** issue
   [#47](https://github.com/tusharsaxena/PanelMaster/issues/47) — peel the appearance editor out of
   `settings/PanelEditor.lua`. 24 lines of headroom; the next feature commit into that file crosses
   `layout-§1`'s cap. Nothing new here, and nothing in this run made it more urgent than it was.
3. **Standing gap, no owner:** the addon ships no `tests/perf.lua`, so every run in this record is
   silent about runtime cost. It is not a tooling problem and no install fixes it. It is named here
   rather than filed, because it is already the standing `## Perf` section's subject in
   `RESULTS.md`.
