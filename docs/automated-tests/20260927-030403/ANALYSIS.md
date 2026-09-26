# Analysis — 20260927-030403

- **Addon:** PanelMaster 1.1.1, release run for 1.2.0
- **Verdict:** green
- **Commit:** 83e958f1f7ba649a8a255b96f4455a4225727770 (master), clean
- **Previous run:** `20260926-193106`

## Headline

This is the release run for 1.2.0, and the release gate passes. `luacheck` is clean over 66 files,
the headless harness runs 964 cases with none failed and none skipped, and `lizard` warns on
nothing (max CCN 15). `perf` is skipped because the addon ships no `tests/perf.lua`, so the gate
covered three suites, not four, and this run says nothing about runtime cost. Nothing moved since
the previous run. `modules/Artwork.lua` and `tests/test_artwork.lua` have now been carried as
*Accepted* across three consecutive release runs and are owed a fix or a tracking issue.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260926-193106` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 66 files | [`lint.txt`](lint.txt) | No: same 0/0 over the same 66 files |
| tests | pass | 964 passed, 0 skipped, 0 failed, 964 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No: 964 → 964 |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | No: every footer figure is identical |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 16108 |
| Functions | 1915 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

**Release gate (`automated-tests-§3`), read from [`manifest.json`](manifest.json):**

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | `suites.lint.status` pass, 0 warnings / 0 errors in 66 files |
| Tests | PASS | `suites.tests.status` pass, 0 failed of 964 |
| Perf | PASS (no scenarios) | `suites.perf.status` skip, because the addon ships no `tests/perf.lua`. This is the one sanctioned exception: nothing was measured |
| Complexity | PASS | `suites.complexity.status` pass, `lizard` 1.24.0 ran |
| CCN <= 15 | PASS | `suites.complexity.warnings` 0, max CCN 15 |

**perf (skip).** No offline scenarios exist, so the addon's runtime cost was not measured. This
is the first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"), not a
`performance-§12` exemption. It is a standing condition, not a regression. It satisfies the release
gate only through the no-`tests/perf.lua` exception, and the 1.2.0 row of the README's Version
History says so.

**complexity (pass).** `lizard` reports "No thresholds exceeded" (see
[`complexity.txt`](complexity.txt)). The same two functions sit exactly at the CCN-15 threshold
without crossing it: `Compat.AddOnFolders` at `core/Compat.lua@27-45` and `R.ApplyArtSize` at
`modules/Registry.lua@611-639`. Neither changed since the previous run.

## What moved

This run measures `83e958f`, seven commits after `20260926-193106` measured `5119ae1`. Those
commits are the previous run's own record (PM-ATS-99), a sync-docs pass and its comment-citation
follow-up (PM-ATS-SD, PM-ATS-SDR), the sweep's merge, and three README commits. The only Lua they
touched is comments: 8 lines changed across `core/Constants.lua`, `core/CoreSetup.lua`,
`core/Database.lua`, `tests/test_options_groups.lua`, `tests/test_schema.lua` and
`tests/wow_mock.lua`, all citation refreshes.

- **lint:** 0/0 over 66 files both times. The exclusions are the same five paths (see
  `RESULTS.md` § Lint).
- **tests:** 964 → 964, no skips in either run. The count has now been flat across the last three
  runs, over a stretch of commits that changed docs and comments only.
- **perf:** skip → skip, same reason.
- **complexity:** NLOC 16108, functions 1915, avg NLOC 7.4, avg CCN 2.0, avg tokens 58.0, max
  CCN 15 and 0 warnings, all identical to the previous run. The band holds the same 3 files at the
  same line counts. Nothing crossed into it and nothing is over the cap.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. A release run that passed the gate has none by construction.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | Owed a fix or a tracked deviation ID (anti-pattern #53). Third consecutive release run as *Accepted* (1.0.0, 1.1.0, 1.2.0). Unchanged at 1188, 312 lines off the cap. No issue tracks the catalog / geometry split yet. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | Owed jointly with `modules/Artwork.lua`. Third consecutive release run as *Accepted*. It mirrors the module and peels when the module does. |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1131 | Accepted, and moving. Unchanged this run. Its re-check trigger (1300, or the next major adopted) has not fired. First release run to carry it, so its shelf-life clock starts here. |

The full dispositions are in `RESULTS.md`. None of the three is newly in the band, so none arrived
blank.

## Actions

1. **New here: track or split `modules/Artwork.lua` (with `tests/test_artwork.lua`).** Both have
   used up the three-release shelf life (`automated-tests-§4`, anti-pattern #53). Either open an
   issue for the catalog / geometry split, and change both `RESULTS.md` dispositions to
   *Already tracked as `#<n>`*, or land the split before the next release. The release gate does
   not cover the LOC band, so this does not block 1.2.0.
