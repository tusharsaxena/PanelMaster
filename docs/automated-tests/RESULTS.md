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

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260924-104311`](20260924-104311/) | `bf1291d` | **dirty** | 1.1.1 | 0/0 | 61 | 921/0/921 | skip | 15134 | 1775 | 7.4 | 2.0 | 15 | 0 | **green** |
| [`20260916-184500`](20260916-184500/) | unknown | unknown | 1.1.0 | 0/0 | 59 | 834/0/834 | skip | 13887 | 1624 | 7.4 | 2.0 | 15 | 0 | **green** |
| [`20260916-094518`](20260916-094518/) | unknown | unknown | 1.1.0 | 0/0 | 57 | 798/0/798 | skip | 13359 | 1554 | 7.4 | 2.0 | 15 | 0 | **green** |
| [`20260910-234511`](20260910-234511/) | unknown | unknown | 1.0.0 → 1.1.0 | 0/0 | 57 | 783/0/783 | skip | 12825 | 1502 | 7.4 | 2.0 | 15 | 0 | **green** |
| [`20260908-181416`](20260908-181416/) | unknown | unknown | 1.0.0 | 0/0 | 55 | 778/0/778 | skip | 12627 | 1494 | 7.4 | 2.0 | 15 | 0 | **green** |
| [`20260825-103450`](20260825-103450/) | unknown | unknown | 1.0.0 | 0/0 | 27 | 731/731 | skip | 11223 | 1379 | 7.1 | 1.9 | 15 | 0 | **green** |
| [`20260807-160022`](20260807-160022/) | unknown | unknown | 0.1.0 | 0/0 | 25 | 717/717 | skip | 11061 | 1357 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-114409`](20260807-114409/) | unknown | unknown | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-110543`](20260807-110543/) | unknown | unknown | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260807-023000`](20260807-023000/) | unknown | unknown | 0.1.0 | 0/0 | 25 | 713/713 | skip | 10997 | 1352 | 7.2 | 2.0 | 15 | 0 | **green** |
| [`20260804-233329`](20260804-233329/) | unknown | unknown | 0.1.0 | 0/0 | 25 | 706/706 | skip | 10941 | 1348 | 7.1 | 2.0 | 15 | 0 | **green** |
| [`20260804-215132`](20260804-215132/) | unknown | unknown | 0.1.0 | 0/0 | 25 | 706/706 | skip | 10936 | 1348 | 7.1 | 2.0 | 0 | 0 | **green** |
| [`20260804-182223`](20260804-182223/) | unknown | unknown | 0.1.0 | 0/0 | 25 | 696/696 | skip | 10651 | 1291 | 7.2 | 2.0 | 51 | 9 | **green** |

## Test suite

**921 cases** — 921 passed, 0 failed, 0 skipped. The generated inventory
[`20260924-104311/test-cases.md`](20260924-104311/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **834 → 921** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 61 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 5 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**This repo ships no `tests/perf.lua`, so `perf` is a permanent `skip`** — the first of
`automated-tests-§3`'s two sanctioned reasons, *nothing to run*, rather than a ratified
`performance-§12` no-combat-path exemption. The record is therefore **silent about runtime
cost**: nothing in this file says this addon is fast or cheap, only that the question was
never asked.

## Complexity watch list

Current as of [`20260924-104311`](20260924-104311/) — **this run's measurement, not its diff.** Max CCN **15** across 1775
functions, **0** of them warned on; 5 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | **Accepted, and watch the direction.** The highest average CCN in the addon at 29 functions. Unchanged at 1188 since the 1.0.0 release run `20260807-160022`, against 1087 at the baseline, and untouched by the launcher cycle and by the 2026-09-23 remediation (`20260924-104311`). A run of flat runs is not a reversal while nothing is offsetting its growth: it is still 312 lines off the cap. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1447 | **The trigger has fired, and it is tracked: issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47).** Not a re-accept — the split is the open issue. **Down to 1447** at `20260924-104311`: it peaked at 1487 in the 2026-09-23 remediation (PM-06, the per-panel Unlock tick) and PM-22 trimmed it back, which leaves **53 lines of headroom** under `layout-§1`'s 1500 cap; it is still the largest authored file in the repository. It does **not** hold the addon's densest function: `refreshHeaderActs` was deleted rather than moved (`docs/settings-panel.md:406`), this file's densest function is CCN **8**, and the addon's two CCN-15 functions are `core/Compat.lua@27-45` (`Compat.AddOnFolders`) and `modules/Registry.lua@611-639` (`R.ApplyArtSize`, the same function the previous run cited at `@607-635`, moved down by the remediation's edits above it). The shrink is not a reprieve: one feature change that touches this file still crosses the cap, so #47 stays the next thing that happens to it. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** The largest suite here because it covers the largest, most branch-heavy module. Unchanged since 2026-08-03 — seven consecutive runs, `20260924-104311` included — and no longer the largest file in the repository, which `settings/PanelEditor.lua` took this cycle. Split only when `modules/Artwork.lua` is, along the same seams; a suite that mirrors a module has no seam of its own. |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1086 | **Accepted, new to the band at `20260924-104311`.** The LibKa0s adoption suite: the seams, the degraded install and the `L` trap. It crossed 1000 in the 2026-09-23 remediation, **971 → 1086**, from two adoption items that each belong here: PM-09 (+73, the library-absent routes for `enable` / `disable` / `lock` / `unlock`) and PM-12 (+37, the bus messages declared through `LibKa0s-Bus-1.0`'s `Catalog`). Unlike the two mirror suites it has a seam of its own: its 13 `Degraded …` cases, which already share `tests/degraded_env.lua` with `tests/test_surface_parity.lua`, lift out whole into a sibling suite. Re-check at **1300**, or at the next major this addon adopts, whichever comes first; peel along that seam then. |
| 1000–1500 (on notice) | `tests/test_panel.lua` | 1399 | **Accepted.** The settings work's shadow rather than a suite that drifted: it has tracked `settings/PanelEditor.lua` up almost line for line, **1273 → 1353** at `20260916-094518`, and **1353 → 1399** at `20260924-104311` (PM-06's per-panel Unlock cases, +45, and PM-08, +1), while the file it mirrors went down. It mirrors that file, so it has no seam of its own and peels when #47 peels. **The re-check-at-1400 trigger is one line away and has not fired**; the next case added here fires it, and the re-check it demands is #47's own. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

