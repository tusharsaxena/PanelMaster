# Analysis — 20261031-202058

- **Addon:** PanelMaster 1.3.0 (run label: `pre-merge`)
- **Verdict:** green
- **Commit:** e63877dbb05d1661c9cd075bb5a777881cde07d9 (feat/2026-10-31-font-pickers-skin-faces)
- **Previous run:** `20261009-191730`

## Headline

Green. `luacheck` is clean over 83 files, the harness runs 1162 cases with 1161 passed, 0 failed and
1 skipped, and `lizard` warns on nothing (max CCN 15, `blindFiles` 0, `crashedFiles` 0). `perf` is
skipped because the addon ships no `tests/perf.lua`, so runtime cost was not measured. Nothing newly
crossed a threshold and no code changed for this run; the two files already in the 1000–1500 band
stay there and both moved a little.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261009-191730` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 83 files | [`lint.txt`](lint.txt) | Files 71 → 83; still 0/0 |
| tests | pass | 1161 passed, 1 skipped, 0 failed, 1162 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total 1064 → 1162 (+98); skipped still 1 |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +2441, functions +315; averages flat apart from tokens |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 20290 |
| Functions | 2537 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 59.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests (pass, one skip).** The skipped case is the kit's diagnostics contract case for an addon
that opts out of turning logging on (`tests.txt` line 1151). PanelMaster keeps the default, so the
report turns logging on and the case beside it holds that; the skip is the kit saying this branch
does not apply, not a case that could not run. It is in the total and not in `passed`. Pre-existing.

**perf (skip).** No offline scenarios exist, so the addon's runtime cost was not measured. This is
the first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"), not a
`performance-§12` exemption. It is a standing condition, not a regression.

**complexity (pass).** `lizard` reports no thresholds exceeded and the run is sighted (`blindFiles`
0, `crashedFiles` 0). Two functions sit exactly at CCN 15 without crossing it, per
[`complexity.txt`](complexity.txt): `R.ApplyArtSize` (`modules/Registry.lua@730-758`), unchanged
from the previous run, and `splitArgs` (`tests/test_skin_literals.lua@71-89`), new since then. Next
highest are three functions at 14: `artLine` (`modules/Diagnostics.lua@182-195`), `Canvas.Render`
(`modules/Canvas.lua@786-850`) and `Artwork.BuildArtSpec` (`modules/ArtworkGeometry.lua@434-518`).

## What moved

This run measures `e63877d`, 52 commits past the previous run's `0fcb643`.

- **lint.** 71 → 83 files, exactly the twelve new authored files: `core/SkinSetup.lua` and eleven
  `tests/` suites. Still 0 warnings / 0 errors.
- **tests.** 1064 → 1162 (+98). The skip count did not move.
- **perf.** Skipped, as before.
- **complexity.** Total NLOC 17849 → 20290 and functions 2222 → 2537. Avg NLOC (7.4), avg CCN (2.0)
  and max CCN (15) did not move, so the addon grew without getting denser. Avg tokens fell
  60.2 → 59.6. Warnings stayed at 0. Band files stayed at 2 and over-cap files at 0:
  `tests/test_libka0s.lua` grew 1184 → 1215 and `tests/test_slash.lua` 1166 → 1167.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1215 | **Accepted, and moving.** Grew 1131 → 1184 since the 1.2.0 release: the `/pm profile` adoption cases (`9bceeab`, +29) and the Options `addonName` pin (`74429c7`, +24). 116 lines short of its 1300 re-check trigger. Second release run carried as Accepted (1.2.0, 1.3.0); a third makes it owed a split or a tracking issue (anti-pattern #53). Peel the `Degraded …` cases into a sibling suite. |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1167 | **Newly crossed; Accepted.** 933 at the 1.2.0 release, 1166 now, from case growth rather than tangle (74 → 85 cases): the `/pm profile` verb (`9bceeab`, +150), the session-row sweep on Reset all (`3060ec4`, +54) and the delete-all profile name (`5c42c0d`, +19). Seam: the profile-verb cases lift out whole into a sibling suite. Re-check trigger 1300. First release run carrying it. |

Both dispositions are carried forward verbatim, and neither cell was blank. Read their figures as
of the 1.3.0 release: `tests/test_libka0s.lua` is now 85 lines short of its 1300 re-check trigger,
not 116, and neither file reached 1300. This is not a release run, so it adds no release run to the
Accepted count: `tests/test_libka0s.lua` stays at two (1.2.0, 1.3.0) and `tests/test_slash.lua` at
one.

## Actions

1. `tests/test_libka0s.lua`: carried from `20261009-191730`'s Actions and still open. One release
   run from its anti-pattern #53 deadline, so split out the `Degraded …` cases before the next
   release, or open a tracking issue.
2. `tests/test_slash.lua`: on notice, no action; split the profile-verb cases if it reaches 1300.
