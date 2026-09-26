# Analysis — 20260927-032003

- **Addon:** PanelMaster 1.2.0
- **Verdict:** green
- **Commit:** 8cda106b5096fa627e36ab68a3735a23206a41e2 (master), clean
- **Previous run:** `20260927-030403` (the 1.2.0 release run)

## Headline

Green. `luacheck` is clean over 68 files, the headless harness runs 964 cases with none failed and
none skipped, and `lizard` warns on nothing (max CCN 15). `perf` is skipped because the addon ships
no `tests/perf.lua`, so this run says nothing about runtime cost. The Artwork splits did what they
were for: `modules/Artwork.lua` and `tests/test_artwork.lua` are out of the 1000–1500 band, which
drops from 3 files to 1, and the case inventory is unchanged at 964, name for name.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260927-030403` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 68 files | [`lint.txt`](lint.txt) | Files 66 → 68 (the two new split files); still 0/0 |
| tests | pass | 964 passed, 0 skipped, 0 failed, 964 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No: 964 → 964; the cases are re-homed, not added (see below) |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +30, functions +2, band files 3 → 1; averages and max unchanged |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 16138 |
| Functions | 1917 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |

**perf (skip).** No offline scenarios exist, so the addon's runtime cost was not measured. This is
the first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"), not a
`performance-§12` exemption. It is a standing condition, not a regression.

**complexity (pass).** `lizard` reports "No thresholds exceeded" (see
[`complexity.txt`](complexity.txt)). The same two functions sit exactly at CCN 15 without crossing
it, both untouched by the splits: `Compat.AddOnFolders` at `core/Compat.lua@27-45` and
`R.ApplyArtSize` at `modules/Registry.lua@611-639`. The highest-CCN function that moved is
`Artwork.BuildArtSpec`, now at `modules/ArtworkGeometry.lua@434-518` with CCN 13.

## What moved

This run measures `8cda106`, three commits after the release run measured `83e958f`: the 1.2.0
release commit `3173f1c` (version constants, release notes and the release bundle), then the two
splits, `bca7fab` (`modules/Artwork.lua` → `modules/Artwork.lua` + `modules/ArtworkGeometry.lua`)
and `8cda106` (`tests/test_artwork.lua` → `tests/test_artwork.lua` +
`tests/test_artwork_geometry.lua`).

- **lint.** 66 → 68 files, which is exactly the two new files. Still 0 warnings / 0 errors, and
  the `.luacheckrc` exclusions are unchanged.
- **tests.** 964 → 964. In [`test-cases.md`](test-cases.md) the `test_artwork.lua (98)` group of
  the previous run is now `test_artwork.lua (46)` plus `test_artwork_geometry.lua (52)`. A sorted
  diff of the case names against the release run's inventory shows no case added, removed or
  renamed; only the totals rows differ. The count is now flat across four runs, which the generated
  `## Test suite` section flags. Here that is expected: none of the commits since the last count
  change added behavior.
- **perf.** Skipped, as before.
- **complexity.** Total NLOC 16108 → 16138 (+30) and functions 1915 → 1917 (+2): the new module's
  header and aliases, and the second suite's scaffolding. Avg NLOC (7.4), avg CCN (2.0), avg tokens
  (58.0) and max CCN (15) did not move, so the addon grew by a file's overhead and did not get
  denser. Per file, from `lizard`'s file table: `modules/Artwork.lua` went from 797 NLOC / 29
  functions to 567 NLOC / 4 functions. What remains is mostly catalog table data plus four lookup
  functions (`Artwork.Entry`, `resolve`, `Artwork.List` and an anonymous function inside it, CCN 5
  to 12), so the file's per-file average CCN of 8.8 is an average over four functions, not a density
  signal. `modules/ArtworkGeometry.lua` is 235 NLOC / 25 functions. `tests/test_artwork.lua` went
  from 956 NLOC / 155 functions to 511 / 69, and `tests/test_artwork_geometry.lua` is 470 / 88. The
  band count fell 3 → 1: only `tests/test_libka0s.lua` (1131 LOC, unchanged) remains on notice.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1131 | **Accepted, and moving.** Unchanged at 1131 at this run, 169 lines short of its 1300 re-check trigger; no new major adopted. Its shelf-life clock started at the 1.2.0 release run `20260927-030403` (one release run so far). Peel the `Degraded …` cases into a sibling suite when the trigger fires. |

`modules/Artwork.lua` and `tests/test_artwork.lua` left the band at this run. Both were carried as
*Accepted* across three release runs (1.0.0, 1.1.0 and 1.2.0) and were owed a fix under
anti-pattern #53. The splits are that fix, and this run is the measurement that confirms it.

## Actions

None. The anti-pattern #53 debt the release run named is discharged. `tests/test_libka0s.lua` has
a recorded trigger and is one release run into its shelf life.
