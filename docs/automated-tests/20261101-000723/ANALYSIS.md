# Analysis — 20261101-000723

- **Addon:** PanelMaster 1.3.0 (run label: `v1.84.0-adoption`)
- **Verdict:** green
- **Commit:** d157fe494003da8d92853bfce88a6d2ad2ab6f9c (feat/2026-10-31-findings-remediation)
- **Previous run:** `20261031-211558`

## Headline

Green on the LibKa0s v1.84.0 re-vendor. `luacheck` is clean over 84 files, the harness runs 1162 cases
with 1161 passed, 0 failed and 1 skipped, and `lizard` warns on nothing (max CCN 15, `blindFiles` 0,
`crashedFiles` 0). `perf` is skipped because the addon ships no `tests/perf.lua`, so runtime cost was
not measured. The only movement is NLOC +6 and functions +1, and nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261031-211558` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 84 files | [`lint.txt`](lint.txt) | No |
| tests | pass | 1161 passed, 1 skipped, 0 failed, 1162 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No: the case inventory is identical |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +6, functions +1; averages flat |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 20293 |
| Functions | 2537 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 59.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests (pass, one skip).** The skipped case is the kit's diagnostics contract case for an addon that
opts out of turning logging on ([`tests.txt`](tests.txt) line 1151). PanelMaster keeps the default, so
the report turns logging on and the case beside it holds that; the skip is the kit saying this branch
does not apply, not a case that could not run. It is in the total and not in `passed`. Pre-existing.

**perf (skip).** No offline scenarios exist, so the addon's runtime cost was not measured. This is the
first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"), not a `performance-§12`
exemption. It is a standing condition, not a regression. `manifest.json` marks the suite as a release
gate, so at the tag this skip is NOT EVALUATED rather than a pass.

**complexity (pass).** `lizard` reports no thresholds exceeded and the run is sighted (`blindFiles` 0,
`crashedFiles` 0). The same two functions sit exactly at CCN 15 without crossing it, per
[`complexity.txt`](complexity.txt): `R.ApplyArtSize` (`modules/Registry.lua@730-758`) and `splitArgs`
(`tests/test_skin_literals.lua@71-89`). The next highest are the same three functions at 14: `artLine`
(`modules/Diagnostics.lua@182-195`), `Canvas.Render` (`modules/Canvas.lua@786-850`) and
`Artwork.BuildArtSpec` (`modules/ArtworkGeometry.lua@434-518`).

## What moved

This run measures `d157fe4`, 3 commits past the previous run's `5732e01`: that run's own record, the
LibKa0s v1.84.0 re-vendor (`5b4bb84`) and the tripwire change (`d157fe4`).

- **lint.** 84 files, 0 warnings / 0 errors; [`lint.txt`](lint.txt) matches the previous run's
  line for line.
- **tests.** 1162 cases, 1161 passed and 1 skipped; [`test-cases.md`](test-cases.md) matches the
  previous run's line for line. So the re-vendor added and removed no case, and `RESULTS.md`'s
  generated note that the count has been flat for 3 runs is a fact about these remediation commits,
  which moved NLOC by 3 net since `20261031-202058` and functions by 0.
- **perf.** Skipped, as before.
- **complexity.** Total NLOC 20287 → 20293 and functions 2536 → 2537, both accounted for in
  [`complexity.txt`](complexity.txt): one new function, `PositionBlock` in
  `settings/OptionsSetup.lua` (1 NLOC), and one anonymous function in `tests/test_libka0s.lua` grown
  from 13 to 18 NLOC. No other function's NLOC, CCN, tokens or parameters changed. Avg NLOC (7.4), avg
  CCN (2.0), max CCN (15) and avg tokens (59.6) did not move, nor did warnings (0), band files (1) or
  over-cap files (0).

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1167 | **Newly crossed; Accepted.** 933 at the 1.2.0 release, 1167 now, from case growth rather than tangle (74 → 85 cases): the `/pm profile` verb (`9bceeab`, +150), the session-row sweep on Reset all (`3060ec4`, +54) and the delete-all profile name (`5c42c0d`, +19). Seam: the profile-verb cases lift out whole into a sibling suite. Re-check trigger 1300. First release run carrying it. |

The disposition is carried forward verbatim and no cell was blank, so no new ruling was owed. The file
did not move in this run and is under its 1300 re-check trigger. This is not a release run, so it adds
no release run to the Accepted count: `tests/test_slash.lua` stays at one.

## Actions

1. `tests/test_slash.lua`: on notice, no action; split the profile-verb cases if it reaches 1300.
