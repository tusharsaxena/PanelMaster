# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

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

The **Tests** cell reads `passed/skipped/total`.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260910-234511`](20260910-234511/) | 1.0.0 → 1.1.0 | 0/0 | 57 | 783/0/783 | skip | 12825 | 1502 | 7.4 | 2.0 | 15 | 0 | **green** |
| [`20260908-181416`](20260908-181416/) | 1.0.0 | 0/0 | 55 | 778/0/778 | skip | 12627 | 1494 | 7.4 | 2.0 | 15 | 0 | **green** |
| [`20260825-103450`](20260825-103450/) | 1.0.0 | 0/0 | 27 | 731/731 | skip | 11223 | 1379 | 7.1 | 1.9 | 15 | 0 | **green** |
| [`20260807-160022`](20260807-160022/) | 0.1.0 | 0/0 | 25 | 717/717 | skip | 11061 | 1357 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-114409`](20260807-114409/) | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-110543`](20260807-110543/) | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-023000`](20260807-023000/) | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260804-233329`](20260804-233329/) | 0.1.0 | 0/0 | 25 | 706/706 | skip | 10941 | 1348 | 7.1 | 2.0 | 15 | 0 | **green** |
| [`20260804-215132`](20260804-215132/) | 0.1.0 | 0/0 | 25 | 706/706 | skip | 10936 | 1348 | 7.1 | 2.0 | 0 | 0 | **green** |
| [`20260804-182223`](20260804-182223/) | 0.1.0 | 0/0 | 25 | 696/696 | skip | 10651 | 1291 | 7.2 | 2.0 | 51 | 9 | **green** |

## Test suite

**783 cases** — 783 passed, 0 failed, 0 skipped. The generated inventory
[`20260910-234511/test-cases.md`](20260910-234511/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **778 → 783** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 57 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**This repo ships no `tests/perf.lua`, so `perf` is a permanent `skip`** — the first of
`automated-tests-§3`'s two sanctioned reasons, *nothing to run*, rather than a ratified
`performance-§12` no-combat-path exemption. The record is therefore **silent about runtime
cost**: nothing in this file says this addon is fast or cheap, only that the question was
never asked.

## Complexity watch list

Current as of [`20260910-234511`](20260910-234511/) — **this run's measurement, not its diff.** Max CCN **15** across 1502
functions, **0** of them warned on; 4 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | **Accepted, and watch the direction.** The highest average CCN in the addon at 29 functions. Unchanged at 1188 since 2026-08-04 — five consecutive runs now, against 1087 at the baseline — and untouched by this whole cycle. Five flat runs is not a reversal while nothing is offsetting its growth: it is still 312 lines off the cap. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1414 | **The trigger has fired, and it is tracked: issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47).** The cell this replaces said *"if the next change also grows it, execute the split rather than re-accept"* — the next changes grew it by **397 lines**, 1091 → 1488 across four commits, and it is now **12 lines under `layout-§1`'s 1500 cap** and the largest file in the repository. It also holds the addon's highest-CCN function, `refreshHeaderActs` at exactly 15. No split lands this cycle (`03_SPEC.md` § C22 rules one out), so the disposition is the open issue rather than a fourth re-accept. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** The largest suite here because it covers the largest, most branch-heavy module. Unchanged since 2026-08-03 — five consecutive runs — and no longer the largest file in the repository, which `settings/PanelEditor.lua` took this cycle. Split only when `modules/Artwork.lua` is, along the same seams; a suite that mirrors a module has no seam of its own. |
| 1000–1500 (on notice) | `tests/test_panel.lua` | 1273 | **Accepted.** Newly in the band, and it is the settings work's shadow rather than a suite that drifted: 700 lines at the previous run's commit, 807 when the pages became tabbed, 1076, 1223, then 1222 — it tracked `settings/PanelEditor.lua` up almost line for line. It mirrors that file, so it has no seam of its own and peels when #47 peels. Re-check at 1400. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

