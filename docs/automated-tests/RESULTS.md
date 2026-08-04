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
| [`20260804-233329`](20260804-233329/) | 0.1.0 | 0/0 | 25 | 706/706 | skip | 10941 | 1348 | 7.1 | 2.0 | 15 | 0 | **green** |
| [`20260804-215132`](20260804-215132/) | 0.1.0 | 0/0 | 25 | 706/706 | skip | 10936 | 1348 | 7.1 | 2.0 | 0 | 0 | **green** |
| [`20260804-182223`](20260804-182223/) | 0.1.0 | 0/0 | 25 | 696/696 | skip | 10651 | 1291 | 7.2 | 2.0 | 51 | 9 | **green** |

† That row's `manifest.json` records `maxCcn: 0`, which is wrong, and the **15** above is read back
from its own frozen [`complexity.txt`](20260804-215132/complexity.txt). The kit derived Max CCN from
`lizard`'s warnings block, which is empty at zero warnings — so the field had no input rather than a
value, and the trend read `51 -> 0 -> 15`, i.e. complexity vanishing and returning. The bundle is
frozen and keeps its wrong number; the trend line is corrected here. The runner was fixed in
`tests/_kit/` (vendored from LibKa0s) to measure the maximum over every function, which is why
`20260804-233329` reports 15 for an unchanged tree.

## Test suite

706 cases as of [`20260804-233329`](20260804-233329/), flat on the run before it and up ten on the
baseline. `test_artwork.lua` is 98 of them, covering the addon's most branch-heavy module; that concentration is why the suite is the largest file in the repo. The ten added at [`20260804-215132`](20260804-215132/) are the CCN work's own cover: eight pin `tests/wow_mock.lua`'s frame stub, which every other suite builds its frames through and which nothing had asserted on before that stub was rewritten from a chain of string compares into a dispatch table; one pins `modules/Canvas.lua`'s frame-pool teardown, and one `core/DebugLogSetup.lua`'s active/pooled/orphaned frame tally — the two seams the same work split into helpers. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 25 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a transient tooling gap. Two things follow, and both are standing facts rather than this run's news: the record says **nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that bracketed instrumentation is free when capture is off — does not exist for it. Adding scenarios is the only thing that changes either.

## Complexity watch list

Current state as of [`20260804-233329`](20260804-233329/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

None.

That is a result, not an empty section. `lizard` reports 0 warnings over 1348 functions, and has at
both of the last two runs; the last run that warned was the baseline
[`20260804-182223`](20260804-182223/), on nine functions. Naming all nine rather than counting them:
`Artwork.BuildArtSpec` (51), `R.Sanitize` (40), the `wow_mock` frame stub's anonymous `__index`
(33), `R:Set` (29), `Canvas.BuildSpec` (24), `S.Themes` (22), `D:Diagnose` (21), `Sl:CliPanel` (17)
and `Canvas`'s `release` (17). Every one is gone. Nothing was suppressed and no threshold was moved:
the nine came down by extraction, and every file-local helper they were split into is under the cap
on its own account rather than by being small enough to hide.

The highest cyclomatic complexity left in the addon is 15, in exactly two functions —
`R.ApplyArtSize` (`modules/Registry.lua`) and `Compat.AddOnFolders` (`core/Compat.lua`), both at the
cap and neither refactored for it. `BuildArtSpec` itself now reads 13. Those two 15s are what the
record should be read against next run: a function sitting exactly on the cap warns the moment
anybody adds one branch to it, so they are where this table comes back from "None."

**A `0` in the Max CCN column above is an instrument fault, not a measurement.** It affects one run
here, [`20260804-215132`](20260804-215132/), and any run recorded before the testkit rev-6
re-vendor. The kit read `CCN_MAX` out of `lizard`'s `!!!! Warnings` block, which is empty the moment
an addon reaches zero warnings, so the field had no input and the manifest stored `0`. The true
figure was always in that same bundle's own `complexity.txt` — for `20260804-215132` it is **15**,
identical to the run after it. The row keeps the `0` it recorded. It is generated evidence and is
not corrected in place: a table edited to read what it should have measured is indistinguishable
from one that measured it, which is the failure `performance-§10` names when it says a hand-edited
record is worse than a wrong one. So the trend column reads `51 -> 0 -> 15`, and this paragraph is
how a reader learns the middle figure is an instrument fault. The whole reading is written up in
[`20260804-233329/ANALYSIS.md`](20260804-233329/ANALYSIS.md).

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** The largest suite here (98 cases) because it covers the largest, most branch-heavy module. Split only when `modules/Artwork.lua` is, along the same seams. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | **Accepted, and watch the direction.** Up 101 lines across this branch (1087 at `20260804-182223`): driving `BuildArtSpec` from 51 to 13 turned one long function into a file-scope fill-dispatch table plus eleven named helpers, and the signatures and their reasoning cost lines even though the logic did not change. That is the trade the branch chose, but the file is now 312 lines off the 1500 band and its growth is no longer offset by anything. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1064 | **Accepted.** Long but shallow — 59 functions, avg CCN 2.4, none tripping a threshold. Length is inventory, not tangle. Untouched by this branch. |
