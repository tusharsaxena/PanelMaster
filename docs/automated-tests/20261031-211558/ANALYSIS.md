# Analysis — 20261031-211558

- **Addon:** PanelMaster 1.3.0 (run label: `findings-remediation`)
- **Verdict:** green
- **Commit:** 5732e0164388b4c9dea399e96ed952be713aed2f (feat/2026-10-31-findings-remediation)
- **Previous run:** `20261031-202058`

## Headline

Green. `luacheck` is clean over 84 files, the harness runs 1162 cases with 1161 passed, 0 failed and
1 skipped, and `lizard` warns on nothing (max CCN 15, `blindFiles` 0, `crashedFiles` 0). `perf` is
skipped because the addon ships no `tests/perf.lua`, so runtime cost was not measured. The one real
movement is the planned split: `tests/test_libka0s.lua` left the 1000–1500 band, which now holds one
file, and nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261031-202058` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 84 files | [`lint.txt`](lint.txt) | Files 83 → 84; still 0/0 |
| tests | pass | 1161 passed, 1 skipped, 0 failed, 1162 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Totals unchanged; 15 cases moved file, 1 renamed |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC −3, functions −1; averages flat; band files 2 → 1 |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 20287 |
| Functions | 2536 |
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

**tests (pass, one skip).** The skipped case is the kit's diagnostics contract case for an addon
that opts out of turning logging on ([`tests.txt`](tests.txt) line 1151). PanelMaster keeps the
default, so the report turns logging on and the case beside it holds that; the skip is the kit saying
this branch does not apply, not a case that could not run. It is in the total and not in `passed`.
Pre-existing.

**perf (skip).** No offline scenarios exist, so the addon's runtime cost was not measured. This is
the first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"), not a
`performance-§12` exemption. It is a standing condition, not a regression. `manifest.json` marks the
suite as a release gate, so at the tag this skip is NOT EVALUATED rather than a pass.

**complexity (pass).** `lizard` reports no thresholds exceeded and the run is sighted (`blindFiles`
0, `crashedFiles` 0). The same two functions sit exactly at CCN 15 without crossing it, per
[`complexity.txt`](complexity.txt): `R.ApplyArtSize` (`modules/Registry.lua@730-758`) and `splitArgs`
(`tests/test_skin_literals.lua@71-89`). Next highest are the same three functions at 14:
`artLine` (`modules/Diagnostics.lua@182-195`), `Canvas.Render` (`modules/Canvas.lua@786-850`) and
`Artwork.BuildArtSpec` (`modules/ArtworkGeometry.lua@434-518`).

## What moved

This run measures `5732e01`, 8 commits past the previous run's `e63877d`, all of them this branch's
remediation.

- **lint.** 83 → 84 files, the one new suite `tests/test_libka0s_degraded.lua`. Still 0 warnings /
  0 errors.
- **tests.** 1162 → 1162, passed 1161 and skipped 1, none of it moved. [`test-cases.md`](test-cases.md)
  shows `test_libka0s.lua` at 38 cases and the new `test_libka0s_degraded.lua` at 15, against 53 in
  the one file before, and one case reworded after `NS.SkinColor` went: `Skin literals: NS.SkinEscape
  keeps the bytes of the literal it replaced`.
- **perf.** Skipped, as before.
- **complexity.** Total NLOC 20290 → 20287 and functions 2537 → 2536, the `NS.SkinColor` removal;
  the rest of [`complexity.txt`](complexity.txt)'s `core/SkinSetup.lua` block only shifted line
  numbers. Avg NLOC (7.4), avg CCN (2.0), max CCN (15) and avg tokens (59.6) did not move. Warnings
  stayed at 0, over-cap files at 0, and band files fell 2 → 1 as `tests/test_libka0s.lua` left the
  band.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1167 | **Newly crossed; Accepted.** 933 at the 1.2.0 release, 1167 now, from case growth rather than tangle (74 → 85 cases): the `/pm profile` verb (`9bceeab`, +150), the session-row sweep on Reset all (`3060ec4`, +54) and the delete-all profile name (`5c42c0d`, +19). Seam: the profile-verb cases lift out whole into a sibling suite. Re-check trigger 1300. First release run carrying it. |

The disposition is carried forward verbatim and no cell was blank, so no new ruling was owed. The
file did not move in this run and is under its 1300 re-check trigger. This is not a release run, so
it adds no release run to the Accepted count: `tests/test_slash.lua` stays at one. The row for
`tests/test_libka0s.lua` is gone, which closes the deadline `20261031-202058`'s Actions carried.

## Actions

1. `tests/test_slash.lua`: on notice, no action; split the profile-verb cases if it reaches 1300.
