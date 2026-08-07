# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260807-160022`](20260807-160022/) | 0.1.0 | 0/0 | 25 | 717/717 | skip | 11061 | 1357 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-114409`](20260807-114409/) | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-110543`](20260807-110543/) | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-023000`](20260807-023000/) | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
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

713 cases as of [`20260807-114409`](20260807-114409/), and **flat across the last three runs** —
713 at `20260807-023000`, `20260807-110543` and this one. That is not yet a coverage gap: the addon
has not grown across those three either (10997 NLOC / 1352 functions, identical at all three), and
the only commits between them were the LibKa0s v1.8.2 / test-kit revision 10 re-vendor and two
`.gitattributes` edits. It becomes worth a second look the moment shipped source moves and this
number does not. Against the baseline the suite is up seventeen.

**Zero skipped**, and that figure is load-bearing. Each run's `tests.txt` closes with
`713 passed, 0 failed, 0 skipped, 713 total`, and a skip is folded into neither the passed figure nor
the failed one. The `Tests` column above is generated as `passed/total` and does not carry the
skipped figure alongside them; it is lossless only while that figure is zero, and the column is the
vendored runner's to widen (`testing-§1`), not this repo's.

`test_artwork.lua` is 98 of the cases, covering the addon's most branch-heavy module; that
concentration is why the suite is the largest file in the repo. The seven net added at
[`20260807-023000`](20260807-023000/) are the audit-remediation branch's own cover: four seam-parity
cases (Core, DebugLog, Options, Slash — each asserting the degraded surface matches the live one),
three harness cases following the kit re-vendor, three database cases pinning that a v1
SavedVariables file actually reaches the v1 → v2 migration body, and one degraded-install case that
`/pm config` answers on every invocation rather than once. Four older cases came off against them:
two harness cases collapsed into one bidirectional check, and two database cases were rewritten. One
case was renamed only — it now reads *the LibKa0s release `CLAUDE.md` says this addon bundles*,
because the provenance line moved out of the README. The generated inventory `test-cases.md` in each
bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 25 files: 0 warnings, 0 errors — flat across all six runs on record.

**What is in scope is narrower than `luacheck .` suggests, and worth stating plainly.**
`.luacheckrc` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }`,
so the 25 files are the addon's shipped source only — `core/` (10), `defaults/` (2), `locales/` (2),
`modules/` (6) and `settings/` (5), exactly as [`lint.txt`](20260807-114409/lint.txt) enumerates
them. `libs/` and `tests/_kit/` are vendored and are not this repo's to fix. **`tests/` is excluded
too**, which is the exclusion a reader would not guess: roughly 6,000 lines of harness and suites —
more than half the repo's Lua — are never linted, and no `0/0` row can show that. The two `ignore`
entries are narrow (`212/self`, `212/event`, both unused-argument codes), and `std` is `lua51` with
an explicit `read_globals` list rather than a permissive default.

That exclusion set also explains why the v1.8.2 re-vendor moved nothing here: the whole of the
changed payload sits in `libs/` and `tests/`, neither of which lint reads.

## Perf

This addon ships no `tests/perf.lua`, so the `perf` column is a permanent `skip` rather than a
transient tooling gap — automated-tests-§3's **first** sanctioned skip reason, not the
`performance-§12` no-combat-path exemption, which PanelMaster does not hold and has not applied for.
The distinction matters to a reader: the toolchain is not the problem. `lua5.1`, `luacheck` 1.2.0 and
`lizard` 1.23.0 are all installed and all three of the other suites ran on them at every run on
record; there is simply nothing for this one to execute.

Two things follow, and both are standing facts rather than any one run's news: the record says
**nothing** about the addon's runtime cost, and `performance-§9`'s zero-overhead evidence — that
bracketed instrumentation is free when capture is off — does not exist for it. It also means no tag
can be cut from a run shaped like this one without the skip being stated out loud, because at the
release gate a skip is NOT EVALUATED rather than passed. Adding scenarios is the only thing that
changes any of it; the gap is tracked as **PM-004**.

## Complexity watch list

Current state as of [`20260807-114409`](20260807-114409/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

That is a result, not an empty section. `lizard` reports 0 warnings over 1352 functions, and has now
at four consecutive runs; the last run that warned was the baseline
[`20260804-182223`](20260804-182223/), on nine functions. Naming all nine rather than counting them:
`Artwork.BuildArtSpec` (51), `R.Sanitize` (40), the `wow_mock` frame stub's anonymous `__index`
(33), `R:Set` (29), `Canvas.BuildSpec` (24), `S.Themes` (22), `D:Diagnose` (21), `Sl:CliPanel` (17)
and `Canvas`'s `release` (17). Every one is gone. Nothing was suppressed and no threshold was moved:
the nine came down by extraction, and every file-local helper they were split into is under the cap
on its own account rather than by being small enough to hide.

The highest cyclomatic complexity left in the addon is 15, in exactly two functions —
`Compat.AddOnFolders` (`core/Compat.lua:34-52`) and `R.ApplyArtSize`
(`modules/Registry.lua:604-632`) — both at the cap, neither refactored for it, and neither touched
since the baseline. `BuildArtSpec` itself now reads 13. Both 15s are **dense defaulting and guarding
rather than tangled control flow**: `lizard` counts every `and`/`or` short-circuit as a decision, so
a run of `t.k = rec.k or D.k` lines scores high with no visible branching, and neither function is a
refactor candidate on its CCN alone. They are still the release gate's whole margin — a function
sitting exactly on the cap warns the moment anybody adds one branch to it, and that blocks the
**tag**, not the commit. They are where this table comes back from "None."

**On the shelf life of these dispositions.** automated-tests-§4 retires an `Accepted` carried across
three consecutive **release** runs. No run in this record is a release run — every `manifest.json`
here has `release: null`, and the addon is still at an untagged 0.1.0 — so that clock has not
started for any entry below. The three file entries are on their sixth *run* and their first
release will be their first tick. Nothing is owed a fix or a tracked deviation ID on shelf-life
grounds today.

**A `0` in the Max CCN column above is an instrument fault, not a measurement.** It affects one run
here, [`20260804-215132`](20260804-215132/), and any run recorded before the testkit rev-6
re-vendor. The kit read `CCN_MAX` out of `lizard`'s `!!!! Warnings` block, which is empty the moment
an addon reaches zero warnings, so the field had no input and the manifest stored `0`. The true
figure was always in that same bundle's own `complexity.txt` — for `20260804-215132` it is **15**,
identical to the four runs after it. The row keeps the `0` it recorded. It is generated evidence and
is not corrected in place: a table edited to read what it should have measured is indistinguishable
from one that measured it, which is the failure `performance-§10` names when it says a hand-edited
record is worse than a wrong one. So the trend column reads `51 -> 0 -> 15 -> 15 -> 15 -> 15`, and
this paragraph is how a reader learns the second figure is an instrument fault. The whole reading is
written up in [`20260804-233329/ANALYSIS.md`](20260804-233329/ANALYSIS.md).

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** 956 NLOC / 155 functions / avg CCN 1.4. The largest suite here (98 cases) because it covers the largest, most branch-heavy module. Byte-identical across the last three runs. Split only when `modules/Artwork.lua` is, along the same seams. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | **Accepted, and watch the direction.** 797 NLOC / 29 functions / avg CCN 4.7 — the highest average in the addon. Flat across three runs now, against 1087 LOC at the baseline. Three flat runs is not a reversal while nothing is offsetting its growth: the file is still 312 lines off the 1500 band. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1091 | **Accepted — and it MOVED at `20260807-160022`.** 1064 → 1091 (+27), from the profile-switch fix's `ForgetSelection` seam and the bus-policy comment recording why the page never re-rendered. Still long but shallow, and still the smallest of the three. First movement across four runs; if the next change also grows it, execute the split rather than re-accept. |

Nothing newly crossed a band at [`20260807-160022`](20260807-160022/) — the **v1.0.0 release run** —
no file moved between bands, and no file is over the 1500 cap. One entry did move within its band:
`settings/PanelEditor.lua`, above. `tests/test_sunnart.lua` at 955 LOC is the nearest thing outside
the table; `tests/test_panel.lua` grew to 700 with the release's new cases and is not close.

**The `automated-tests-§4` shelf-life clock starts at v1.0.0 for all three entries.** None has yet
been carried as *Accepted* across three consecutive RELEASE runs, because 1.0.0 is the first release
this addon has had — the ordinary runs they were carried through do not count against it
(anti-pattern #53). At the third release still reading *Accepted*, each is owed a fix or a tracked
deviation ID with an owner.

### Functions `lizard` warned on

**None**, at every run recorded above. Worth one line beyond that, because the margin is not what a
clean column suggests: **max CCN has been exactly 15 for four consecutive runs**, and the release
gate is *above* 15. Two functions sit on the line — `R.ApplyArtSize` (`modules/Registry.lua:639`)
and `Compat.AddOnFolders` (`core/Compat.lua:34`) — and both are the kind that grow: the first with
each artwork fill mode, the second with each client quirk. A single added branch in either turns a
green release into a refused one.
