# Analysis — 20261009-191730

- **Addon:** PanelMaster 1.2.0 (release run for 1.3.0)
- **Verdict:** green
- **Commit:** 0fcb643d9bf049d5774210dd3e43460bb8232819 (master)
- **Previous run:** `20260927-032003`

## Headline

Green, and it passes the release gate for 1.3.0. `luacheck` is clean over 71 files, the harness runs
1064 cases with 1063 passed, 0 failed and 1 skipped, and `lizard` warns on nothing (max CCN 15,
`blindFiles` 0). `perf` is skipped because the addon ships no `tests/perf.lua`, so runtime cost was
not measured. One file newly entered the 1000–1500 band: `tests/test_slash.lua` (1166 LOC).

## Suites

| Suite | Status | Result | Artifact | Moved since `20260927-032003` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 71 files | [`lint.txt`](lint.txt) | Files 68 → 71; still 0/0 |
| tests | pass | 1063 passed, 1 skipped, 0 failed, 1064 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total 964 → 1064 (+100); skipped 0 → 1 |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +1711, functions +305, band files 1 → 2; averages flat apart from tokens |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 17849 |
| Functions | 2222 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 60.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

**tests (pass, one skip).** The skipped case is the kit's diagnostics contract case for an addon
that opts out of turning logging on (`tests.txt` line 1053). PanelMaster keeps the default, so the
report turns logging on and the case beside it holds that; the skip is the kit saying this branch
does not apply, not a case that could not run. It is in the total and not in `passed`.

**perf (skip).** No offline scenarios exist, so the addon's runtime cost was not measured. This is
the first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"), not a
`performance-§12` exemption, which `CLAUDE.md` states is not claimable here. It is a standing
condition, not a regression. The 1.3.0 release notes say so.

**complexity (pass).** `lizard` reports no thresholds exceeded and the run is sighted (`blindFiles`
0). One function sits exactly at CCN 15 without crossing it: `R.ApplyArtSize` at
`modules/Registry.lua@730-758` (it was at 611-639; the file grew above it). `Compat.AddOnFolders`,
at 15 in the previous run, is down to CCN 9 (`core/Compat.lua@27-43`) after PM-09 deleted its
bare-global AddOns fallbacks. Next highest are three functions at 14:
`artLine` (`modules/Diagnostics.lua@182-195`), `Artwork.BuildArtSpec`
(`modules/ArtworkGeometry.lua@434-518`) and `Canvas.Render` (`modules/Canvas.lua@778-842`).

## What moved

This run measures `0fcb643`, 69 commits past the `1.2.0-release` tag: the `/pm profile` verb, the
frame level slider, the debug-log coverage work, five LibKa0s re-vendors up to v1.71.0 (kit 38),
and the 2026-10-07 review remediation PM-01..PM-12.

- **lint.** 68 → 71 files, exactly the three new files: `settings/PanelSchema.lua`,
  `tests/test_library_debug.lua` and `tests/test_panel_schema.lua`. Still 0 warnings / 0 errors.
- **tests.** 964 → 1064. Two new suites (`test_panel_schema.lua` 21, `test_library_debug.lua` 11)
  and growth across existing ones, largest in `test_debuglog.lua` (35 → 52), `test_slash.lua`
  (74 → 85) and `test_registry.lua` (45 → 54); `test_lizard_sighted.lua` (8) arrived with kit 35.
  The flat-at-964 streak the previous record flagged is over.
- **perf.** Skipped, as before.
- **complexity.** Total NLOC 16138 → 17849 and functions 1917 → 2222. Avg NLOC (7.4), avg CCN (2.0)
  and max CCN (15) did not move, so the addon grew without getting denser. Avg tokens rose
  58.0 → 60.2, a small rise in function length by tokens that the NLOC average does not show.
  Band files 1 → 2: `tests/test_libka0s.lua` grew 1131 → 1184 and `tests/test_slash.lua` crossed in
  at 1166.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1184 | **Accepted, and moving.** Grew 1131 → 1184 since the 1.2.0 release: the `/pm profile` adoption cases (`9bceeab`, +29) and the Options `addonName` pin (`74429c7`, +24). 116 lines short of its 1300 re-check trigger. Second release run carried as Accepted (1.2.0, 1.3.0); a third makes it owed a split or a tracking issue (anti-pattern #53). Peel the `Degraded …` cases into a sibling suite. |
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1166 | **Newly crossed; Accepted.** 933 at the 1.2.0 release, 1166 now, from case growth rather than tangle (74 → 85 cases): the `/pm profile` verb (`9bceeab`, +150), the session-row sweep on Reset all (`3060ec4`, +54) and the delete-all profile name (`5c42c0d`, +19). Seam: the profile-verb cases lift out whole into a sibling suite. Re-check trigger 1300. First release run carrying it. |

## Actions

1. `tests/test_libka0s.lua`: one release run from its anti-pattern #53 deadline. Split out the
   `Degraded …` cases before the next release, or open a tracking issue. New here.
2. `tests/test_slash.lua`: newly on notice. No action this release; split the profile-verb cases
   if it reaches 1300. New here.
