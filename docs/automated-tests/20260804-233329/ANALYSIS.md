# Analysis — 20260804-233329

- **Addon:** PanelMaster 0.1.0
- **Verdict:** green
- **Commit:** 645868a3f0cf (`feat/fix-ccn`), dirty — the branch's last commit plus this bundle were in
  the working tree when the run was taken, which is what `dirty: true` in
  [`manifest.json`](manifest.json) records
- **Started:** 2026-08-04T23:33:29+05:30
- **Previous run:** [`20260804-215132`](../20260804-215132/)

## Headline

Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across 25 files and the
headless harness passes 706 of 706. The offline perf runner is still absent, so this run measures
three suites of four and says nothing about runtime cost.

**This is the run that closes the CCN work.** `lizard` warns on nothing across 1348 functions and
the highest cyclomatic complexity anywhere in the addon is **15** — at the cap, not over it. The
previous run had the same ceiling in the same two functions; what it did not have was an instrument
that could report it. The kit derived Max CCN from `lizard`'s `!!!! Warnings` block, which is empty
once an addon reaches zero warnings, so the field had no input and
[`../20260804-215132/manifest.json`](../20260804-215132/manifest.json) records `maxCcn: 0`. The
re-vendored runner measures the maximum over every function row, which is why an unchanged ceiling
reads 15 here. The code did not move; the measurement did.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260804-215132 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 25 files | [`lint.txt`](lint.txt) | unchanged — 0/0 over the same 25 files |
| tests | pass | 706 passed, 0 failed, 706 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged — 706, none added, removed or renamed |
| perf | **skip** | 0 scenarios — `no tests/perf.lua — this addon ships no offline scenarios` | — (no artifact; nothing was measured) | unchanged — still a skip, still not a pass |
| complexity | pass | 0 warnings, max CCN 15 over 1348 functions | [`complexity.txt`](complexity.txt) | see below |

### Complexity in full

Every field of `lizard`'s footer as [`manifest.json`](manifest.json) records it under
`suites.complexity`, plus the two derived file counts. The **averages** are the point: a total that
rose because the addon grew is a different fact from an average that rose because it got denser, and
only the second is a complexity signal.

| Metric | This run | Previous (`20260804-215132`) | Moved |
|---|---|---|---|
| Total NLOC | 10941 | 10936 | +5 |
| Functions | 1348 | 1348 | unchanged |
| Avg NLOC / function | 7.1 | 7.1 | unchanged |
| Avg CCN | 2.0 | 2.0 | unchanged |
| Max CCN | 15 | 15 — its manifest records `0`; read back from that bundle's own [`complexity.txt`](../20260804-215132/complexity.txt) | unchanged: the instrument changed, not the ceiling |
| Avg tokens / function | 55.6 | 55.6 | unchanged |
| Warnings (CCN > 15) | 0 | 0 | unchanged |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 | 0.00 / 0.00 | unchanged |
| Files in the 1000–1500 band | 3 | 3 | unchanged |
| Files over the 1500 cap | 0 | 0 | unchanged |

**perf is the one suite that is not a clean pass, and it is a skip rather than a failure.** The
addon ships no `tests/perf.lua`, so no scenario ran and nothing was measured. That is a standing
condition of this addon, not a regression and not a transient tooling gap: `performance-§9`'s
zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist
for PanelMaster, and did not at either previous run. It is recorded as `skip` in
[`manifest.json`](manifest.json) and must not be read as `perf clean`.

## What moved

**Complexity — nothing in the code, everything in the reading.** Zero warnings before, zero
warnings after; 1348 functions before and after; avg CCN, avg NLOC and avg tokens identical to the
digit. The only figure that changed shape is Max CCN, from a recorded `0` to a recorded `15`, and
that is the kit fix landing rather than complexity returning. A reader following the trend column in
[`../RESULTS.md`](../RESULTS.md) sees `51 -> 0 -> 15` and should read it as `51 -> 15 -> 15`.

**Size.** +5 NLOC and no change in function count — the whole footprint of the one commit between
the two runs. [`complexity.txt`](complexity.txt) puts `modules/Artwork.lua` at 797 NLOC against 792
at the previous run.

**`buildSectionQuads` traded its argument list for a table.** This bundle's
[`complexity.txt`](complexity.txt) reports it as `31 12 329 3 42` at `./modules/Artwork.lua` —
**3 parameters**, where [`../20260804-215132/complexity.txt`](../20260804-215132/complexity.txt)
recorded `29 12 275 15 40`, i.e. **15**. CCN is unchanged at 12. This supersedes Action item 2 of
the previous run's [`ANALYSIS.md`](../20260804-215132/ANALYSIS.md), which recorded the
fifteen-argument signature as a disclosed and deliberate trade; the argument list became one named
`bar` table after that run was frozen. Both bundles are honest snapshots either side of the change,
and neither is edited.

**Tests.** 706, flat. The suite grew ten cases at the previous run and none at this one, which is
what a commit that changes one signature and no behavior should look like.

**Lint.** 0/0 over 25 files, flat.

**Behavior.** Nothing intended. The branch is a refactor: no feature, no fix, no version bump, no
CHANGELOG entry.

## Complexity watch list

### Functions `lizard` warned on

None.

That is a result. [`complexity.txt`](complexity.txt)'s footer reads `Warning cnt 0` over `Fun Cnt
1348`, and the threshold line is the stock `cyclomatic_complexity > 15 or length > 1000 or nloc >
1000000 or parameter_count > 100` — nothing was suppressed and no threshold was moved to get there.

Exactly **two** functions sit on the cap at CCN 15, and both are named here rather than counted:
`R.ApplyArtSize` (`modules/Registry.lua`, lines 604–632) and `Compat.AddOnFolders`
(`core/Compat.lua`, lines 34–52), both read off [`complexity.txt`](complexity.txt). Neither was
touched by this branch. A function sitting exactly on the cap warns the moment anybody adds one
branch to it, so those two are where this table comes back from "None." Below them the addon falls
away quickly: `Artwork.BuildArtSpec` at 13, then `applyAccents`, `buildSectionQuads`, `Sl`,
`sources`, `resolve` and `R.FormatField` at 12.

### Files by `layout-§1` band

`lizard` reports NLOC and the band is a LOC rule, so [`manifest.json`](manifest.json) records only
the counts (`bandFiles: 3`, `overCapFiles: 0`), which the runner derives with `wc -l`. The NLOC
column below is this bundle's [`complexity.txt`](complexity.txt); the LOC column is the same `wc -l`
over this run's commit, `645868a`.

| Band | File | LOC | NLOC | Disposition |
|---|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | 956 | **Accepted.** The largest suite in the repo, 98 of the 706 cases ([`test-cases.md`](test-cases.md)), because it covers the largest and most branch-heavy module. Unchanged by this run. Split only when `modules/Artwork.lua` is, along the same seams. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | 797 | **Accepted, and watch the direction.** Up 22 lines since the previous run and 101 across the branch: the extraction that drove `BuildArtSpec` from 51 to 13 bought its CCN with signatures and comments. The file is now 312 lines off the 1500 cap with nothing offsetting its growth. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1064 | 644 | **Accepted.** Long but shallow — 59 functions at avg CCN 2.4 ([`complexity.txt`](complexity.txt)), none tripping a threshold. Length is inventory, not tangle. Untouched by this branch. |

Nothing newly crossed a band at this run; all three entries carry forward.

## Actions

1. **`modules/Artwork.lua` is still the one number moving the wrong way** — 1087 LOC at the
   baseline, 1188 here. Not a violation and not new; carried forward from the previous run's
   analysis so the next run reads it as a trend rather than as news. The fix is the catalog /
   geometry split, and nothing in `docs/pending/LEDGER.md` owns it: it is new here.
2. **`tests/perf.lua` does not exist.** Every run so far records `perf` as a skip, so the addon has
   no offline runtime-cost evidence at all. Adding scenarios is the only thing that changes that
   column. New here; no deviation ID or review finding owns it.
3. **The two functions at CCN 15 are the release gate's whole margin.** `R.ApplyArtSize` and
   `Compat.AddOnFolders` pass today and warn on one added branch. No action now — named so that a
   future change to either is read against it.
