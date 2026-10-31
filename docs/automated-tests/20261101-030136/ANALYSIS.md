# Analysis — 20261101-030136

- **Addon:** PanelMaster 1.3.0 (run label: `final-pre-merge`)
- **Verdict:** green
- **Commit:** d8024b81a95d61ab06f72c62fe5ebf231dbdc844 (feat/2026-10-31-findings-remediation)
- **Previous run:** `20261101-000723`

## Headline

Green on the final pre-merge tree, which takes the re-cut LibKa0s v1.84.0 and makes `Ka0sMedia_*` the
only media picker. `luacheck` is clean over 84 files, the harness runs 1163 cases with 1162 passed,
0 failed and 1 skipped, and `lizard` warns on nothing (max CCN 15, `blindFiles` 0, `crashedFiles` 0).
`perf` is skipped because the addon ships no `tests/perf.lua`, so runtime cost was not measured.
The case count rose by 1 and nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-000723` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 84 files | [`lint.txt`](lint.txt) | No |
| tests | pass | 1162 passed, 1 skipped, 0 failed, 1163 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total +1, passed +1 |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +1, functions +6; averages flat apart from tokens |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 20294 |
| Functions | 2543 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 59.5 |
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
above it holds the behavior. It reports its reason, and it is counted in neither passed nor failed.

## What moved

This run measures `d8024b8`, 4 commits past the previous run's `d157fe4`: that run's own record
(`2953515`), the re-cut LibKa0s v1.84.0 (`47be2f9`), the picker change (`0b18e26`) and a citation
correction (`d8024b8`).

- **lint.** 84 files, 0 warnings / 0 errors; [`lint.txt`](lint.txt) matches the previous run's line
  for line.
- **tests.** Total 1162 → 1163 and passed 1161 → 1162; failed 0 and skipped 1 did not move. In
  [`test-cases.md`](test-cases.md), `test_libka0s.lua` went 38 → 37: the case holding the `LSM30_Border`
  wiring is gone with the widget. `test_options_groups.lua` went 9 → 11: the preview-picker case was
  renamed to drop "with no plain fallback", and two cases were added, for a library-drawn media row
  being tracked so a scroll closes its list, and for the addon loading no second media widget library.
- **perf.** Not measured in either run, for the same reason.
- **complexity.** NLOC 20293 → 20294 and functions 2537 → 2543. Avg tokens 59.6 → 59.5. Avg NLOC 7.4,
  avg CCN 2.0, max CCN 15, 0 warnings, 1 band file, 0 over cap, `blindFiles` 0 and `crashedFiles` 0 did
  not move. Six more functions over one more line is a small drop in density, not a complexity signal.

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
