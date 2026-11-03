# Analysis — 20261101-201645

- **Addon:** PanelMaster 1.3.0
- **Verdict:** green
- **Commit:** a703eae2e9f1430e3d40989c6cf039c6956e2127 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** `20261101-142650`

## Headline

Green on the re-cut local LibKa0s v1.85.0 (kit revision 50), with the kit's typed-value gate and
probe-skin switch test adopted. `luacheck` is clean over 85 files, the harness runs 1176 cases with
1175 passed, 0 failed and 1 skipped, and `lizard` warns on nothing (max CCN 15, `blindFiles` 0,
`crashedFiles` 0). `perf` is skipped because the addon ships no `tests/perf.lua`, so runtime cost was
not measured. The case count rose by 9 and nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-142650` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 85 files | [`lint.txt`](lint.txt) | Files +1 |
| tests | pass | 1175 passed, 1 skipped, 0 failed, 1176 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total +9, passed +9 |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +32, functions +21; avg NLOC and tokens down slightly |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 20419 |
| Functions | 2583 |
| Avg NLOC / function | 7.3 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 59.0 |
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
above it holds the behavior. Neither kit skin suite skips: both are wired.

## What moved

This run measures `a703eae`, past the previous run's `23859cb`: `FS-PM-REC` for that run, `FS-PM-FIX`
(`22cac9d`) and `FS-PM-GATE`.

- **lint.** 84 → 85 files, the new `tests/skin_surfaces.lua`; 0 warnings / 0 errors, unchanged.
- **tests.** Total 1167 → 1176 and passed 1166 → 1175; failed 0 and skipped 1 did not move. In
  [`test-cases.md`](test-cases.md), `test_skin_literals.lua` went 12 → 9, its three gate cases retired
  into the kit, `test_skin_values.lua` adds 3 and `test_skin_switch.lua` adds 9: the falsifiable case
  and eight surface cases over six declared surfaces, the two unlock surfaces running in both passes.
- **perf.** Not measured in either run, for the same reason.
- **complexity.** NLOC 20387 → 20419 and functions 2562 → 2583. Avg NLOC 7.4 → 7.3 and avg tokens
  59.3 → 59.0. Avg CCN 2.0, max CCN 15, 0 warnings, 1 band file, 0 over cap, `blindFiles` 0 and
  `crashedFiles` 0 did not move. More functions at lower density: the growth is small fixtures, not a
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
2. SKIN-20 and SKIN-32 to SKIN-35 stay owed in client; `docs/smoke-tests.md` names them. This run
   changed no check's expected result.
