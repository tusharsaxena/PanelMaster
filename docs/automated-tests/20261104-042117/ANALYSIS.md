# Analysis — 20261104-042117

- **Addon:** PanelMaster 1.3.0
- **Verdict:** green
- **Commit:** 43855eb1c525ba15970b665629912f930ed09462 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** `20261101-201645`

## Headline

Green at the end of round 6 of the full skinning run, on the round 6 sim-checkbox re-cut of LibKa0s
v1.85.0. `luacheck` is clean over 86 files, the harness runs 1195 cases with 1194 passed, 0 failed and
1 skipped, and `lizard` warns on nothing (max CCN 15, `blindFiles` 0, `crashedFiles` 0). `perf` is
skipped because the addon ships no `tests/perf.lua`, so runtime cost was not measured. The case count
rose by 19 and nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-201645` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 86 files | [`lint.txt`](lint.txt) | Files +1 |
| tests | pass | 1194 passed, 1 skipped, 0 failed, 1195 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total +19, passed +19 |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +314, functions +52; avg tokens down slightly |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 20733 |
| Functions | 2635 |
| Avg NLOC / function | 7.3 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Lint, tests and complexity passed cleanly. `perf` is a standing skip, the first sanctioned reason
(`automated-tests-§3`): the addon ships no `tests/perf.lua`, so this record says nothing about runtime
cost, and the release gate reads that suite as NOT EVALUATED. It is pre-existing, not a regression.

The 1 skipped case is the standing diagnostics opt-out case in [`tests.txt`](tests.txt): this addon
keeps the default `Kit.diagnostics.enablesLogging`, so the opt-out branch does not apply and the case
above it holds the behavior. It is the same skip the previous run carried.

## What moved

This run measures `43855eb`, 23 commits past the previous run's `a703eae`: `FS-PM-REC`, a run of
LibKa0s v1.85.0 re-cut refreshes (`SF-RV`, `SF-RV2`, `SG-RV`, `R3-RV`, `R4-RV`, `R4-RV2`, `R4-RV3`,
`R5-RV`, `R6-RV`, `R6-RV2`), the fixes `SF-FIX` (`360a9cb`, `3ecc029`), `R3-FRIZ` (`2b1d5e9`),
`R4-SEP` (`de850d4`), `R6-PV` (`1b61758`, `6cadba0`) and `R6-NAME` (`43855eb`), and the smoke records
`R3-SMOKE`, `R4-RV2` and `R4-RV3`.

- **lint.** 85 → 86 files, the new `tests/test_launcher_skin_entry.lua` (`SF-FIX`, `360a9cb`);
  0 warnings / 0 errors, unchanged.
- **tests.** Total 1176 → 1195 and passed 1175 → 1194; failed 0 and skipped 1 did not move. In
  [`test-cases.md`](test-cases.md), `test_skin_picker.lua` went 13 → 30 (the `R6-PV` eye/unlock-mode
  and preview-list cases), `test_database.lua` went 24 → 25 (`R3-FRIZ`), and
  `test_launcher_skin_entry.lua` is new with 1 case (`SF-FIX`, SF-F2).
- **perf.** Not measured in either run, for the same reason.
- **complexity.** NLOC 20419 → 20733 and functions 2583 → 2635. Avg NLOC 7.3, avg CCN 2.0 and max
  CCN 15 did not move; avg tokens 59.0 → 58.7. 0 warnings, 1 band file, 0 over cap, `blindFiles` 0
  and `crashedFiles` 0 did not move. The totals rose with size while the averages held: no
  complexity signal.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slash.lua` | 1167 | **Newly crossed; Accepted.** Carried forward unchanged in `RESULTS.md`: the entry did not move, re-check trigger 1300. |

No Disposition was owed this run: the runner carried the one entry forward and left no cell blank.

## Actions

1. `tests/test_slash.lua`: on notice, no action; split the profile-verb cases if it reaches 1300.
2. The round 6 in-client smoke checks stay the owner's; this run passes none of them.
