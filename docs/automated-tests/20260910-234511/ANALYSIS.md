# Analysis — 20260910-234511

- **Addon:** PanelMaster 1.0.0 → 1.1.0
- **Verdict:** green
- **Commit:** 17c82ea6b272 (master), clean
- **Previous run:** [`20260908-181416`](../20260908-181416/)

## Headline

The release run for **1.1.0**. Lint, tests and complexity are green with zero functions above CCN 15; **perf did not run** — no `tests/perf.lua` ships here, so three suites were measured. Five new test cases, two new lint files, 198 more NLOC, and every complexity average unchanged.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260908-181416` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 57 files | [`lint.txt`](lint.txt) | see below |
| tests | pass | 783 passed, 0 skipped, 0 failed, 783 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | see below |
| perf | skip | not measured — no `tests/perf.lua` in this addon | — | not measured in either run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 12825 |
| Functions | 1502 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 57.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 4 |
| Files over the 1500 cap | 0 |

**perf is the one suite that is not a clean pass, and it is a skip rather than a failure.** `manifest.json` records the reason verbatim: *"no tests/perf.lua — this addon ships no offline scenarios"*. Nothing ran, so nothing was measured — this is a pre-existing condition of the addon, not a regression in this run, and it is stated in the release notes as well as here. The release gate's perf condition is satisfied by the no-scenarios exception, which means this tag rests on three measured suites.

## What moved

- **lint** — 57 files, up two from 55. Still 0 warnings / 0 errors.
- **tests** — 783 passed, up 5 from 778. No skips, no failures.
- **perf** — skipped in both runs: there is no `tests/perf.lua`. Not measured.
- **complexity** — NLOC 12627 → 12825 (+198) over 1494 → 1502 functions (+8). Avg NLOC 7.4, avg CCN 2.0, avg tokens 57.4 — all identical to the previous run. Max CCN 15, zero warnings. Four band files in both runs, none over the cap.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

4 file(s) in the 1000–1500 on-notice band, 0 over the 1500 cap. Each carries a disposition in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). The band is not part of the release gate.

## Actions

None new. `settings/PanelEditor.lua` remains the fired trigger, tracked as issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47). `modules/Artwork.lua` has now carried **Accepted** since the 1.0.0 release run — the second release in that state, and the third would owe it a fix or a deviation ID.
