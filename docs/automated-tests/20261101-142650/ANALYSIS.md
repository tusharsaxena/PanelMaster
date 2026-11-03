# Analysis — 20261101-142650

- **Addon:** PanelMaster 1.3.0 (run label: `full-skinning`)
- **Verdict:** green
- **Commit:** 23859cbbd3bc17433203c4a41350ec35a05df306 (feat/2026-11-01-full-skinning)
- **Previous run:** `20261101-030136`

## Headline

Green on the full skinning branch, which takes the local LibKa0s v1.85.0 and puts the Panels editor's
headings and tooltip emphasis on the skin. `luacheck` is clean over 84 files, the harness runs 1167
cases with 1166 passed, 0 failed and 1 skipped, and `lizard` warns on nothing (max CCN 15, `blindFiles`
0, `crashedFiles` 0). `perf` is skipped because the addon ships no `tests/perf.lua`, so runtime cost
was not measured. The case count rose by 4 and nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since `20261101-030136` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 84 files | [`lint.txt`](lint.txt) | No |
| tests | pass | 1166 passed, 1 skipped, 0 failed, 1167 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Total +4, passed +4 |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | No: skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +93, functions +19; averages flat apart from tokens |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 20387 |
| Functions | 2562 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 59.3 |
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

This run measures `23859cb`, past the previous run's `d8024b8`: the M3 record and merge on `master`,
then `FS-PM-RV`, `FS-PM-FIX` and the first `FS-PM-REC`, the docs sync.

- **lint.** 84 files, 0 warnings / 0 errors, unchanged.
- **tests.** Total 1163 → 1167 and passed 1162 → 1166; failed 0 and skipped 1 did not move. In
  [`test-cases.md`](test-cases.md), `test_skin_literals.lua` went 8 → 12: three cases hold the tooltip
  emphasis on Ka0s Default, Obsidian and with the panel ignored, and one holds an editor heading to
  `O.LabelFont`. The `info` case in `test_libka0s.lua` was renamed, because kit revision 49 owes that
  mark on every consumer.
- **perf.** Not measured in either run, for the same reason.
- **complexity.** NLOC 20294 → 20387 and functions 2543 → 2562. Avg tokens 59.5 → 59.3. Avg NLOC 7.4,
  avg CCN 2.0, max CCN 15, 0 warnings, 1 band file, 0 over cap, `blindFiles` 0 and `crashedFiles` 0 did
  not move. The growth is the new cases and the facade members; none of it is a density signal.

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
2. SKIN-20 and SKIN-32 to SKIN-35 are owed in client; `docs/smoke-tests.md` names them.
