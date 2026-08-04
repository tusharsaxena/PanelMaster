# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —
they are read and compared, not thresholded. A `skip` is a suite that did not run at all,
which is never the same as a pass.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-182223`](20260804-182223/) | 0.1.0 | 0/0 | 25 | 696/696 | skip | 10651 | 1291 | 7.2 | 2.0 | 51 | 9 | **green** |

## Test suite

696 cases. `test_artwork.lua` is 155 of them, covering the addon's most branch-heavy module; that concentration is why the suite is the largest file in the repo. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 25 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-182223`](20260804-182223/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Artwork.BuildArtSpec` | 51 | `modules/Artwork.lua` | **Peel next.** The worst number here. Pure and very well covered, so the risk is comprehension: one helper per fill mode over the shared position/crop/flip post-pass. |
| `R.Sanitize` | 40 | `modules/Registry.lua` | **Accepted, with a caveat.** A flat field-by-field repair loop; the caveat is that per-field is exactly the shape that lets a field be *forgotten* — which is finding **F-002**. |
| `(anonymous)` mock `__index` | 33 | `tests/wow_mock.lua` | **Accepted.** One branch per method name, deliberately explicit; a dispatch table would lower the number and make the file harder to read. |
| `R:Set` | 29 | `modules/Registry.lua` | **Accepted.** The single write seam every panel edit routes through, so its branching *is* the per-field validation the design centralises. |
| `Canvas.BuildSpec` | 24 | `modules/Canvas.lua` | **Accepted for now, watch it.** Where every new panel feature lands; peel by feature group if it passes 30. |
| `S.Themes` | 22 | `modules/SunnArt.lua` | **Accepted.** Merges four theme sources in a fixed precedence that reproduces SunnArt's own; simplifying it is how the inverted merge order was introduced once. |
| `D:Diagnose` | 21 | `core/DebugLogSetup.lua` | **Accepted.** One branch per line it can emit, on a `/pm debug diagnose` path a human types. |
| `Sl:CliPanel` | 17 | `settings/Slash.lua` | **Accepted, adjacent to open work.** `PM-007` and `F-005` both touch this function's neighbourhood; do those first and re-read the number. |
| `release` | 17 | `modules/Canvas.lua` | **Accepted.** Frame-pool teardown: one reset per property the renderer can set. A property missed here leaks into the next panel. |

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** The largest suite here (155 cases) because it covers the largest, most branch-heavy module. Split only when `modules/Artwork.lua` is, along the same seams. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1087 | **Peel next**, together with `Artwork.BuildArtSpec` — same file, same seam. Already named by `PM-011`. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1064 | **Accepted.** Long but shallow — 59 functions, avg CCN 2.4, none tripping a threshold. Length is inventory, not tangle. |
