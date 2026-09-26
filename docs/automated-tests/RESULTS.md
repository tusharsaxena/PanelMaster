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
| [`20260926-160448`](20260926-160448/) | `1763c0c` | clean | 1.1.1 | 0/0 | 64 | 964/0/964 | skip | 16058 | 1914 | 7.4 | 2.0 | 15 | 0 | **green** |
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

**964 cases** — 964 passed, 0 failed, 0 skipped. The generated inventory
[`20260926-160448/test-cases.md`](20260926-160448/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **921 → 964** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 64 files** (`luacheck .`).

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

Current as of [`20260926-160448`](20260926-160448/) — **this run's measurement, not its diff.** Max CCN **15** across 1914
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
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1464 | **The trigger has fired, and it is tracked: issue [#47](https://github.com/tusharsaxena/PanelMaster/issues/47) (open).** Not a re-accept — the split is the open issue. **Back up to 1464** at `20260926-160448` (1447 at `20260924-104311`, +17 net from `3a7ac19` pm-band-fix-01, the Panels band row layout), which leaves **36 lines of headroom** under `layout-§1`'s 1500 cap; it is the largest authored non-test file in the repository. Its densest function is still low (the addon's two CCN-15 functions remain `core/Compat.lua@27-45` `Compat.AddOnFolders` and `modules/Registry.lua@611-639` `R.ApplyArtSize`, both at the threshold, neither above it). The file is moving toward the cap again after one small fix; #47 is the next thing that happens to it, before the next feature lands here. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** The largest suite here because it covers the largest, most branch-heavy module. Unchanged since 2026-08-03 — seven consecutive runs, `20260924-104311` included — and no longer the largest file in the repository, which `settings/PanelEditor.lua` took this cycle. Split only when `modules/Artwork.lua` is, along the same seams; a suite that mirrors a module has no seam of its own. |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1131 | **Accepted, and moving.** The LibKa0s adoption suite: the seams, the degraded install and the `L` trap. Entered the band at `20260924-104311` (971 → 1086, PM-09 and PM-12) and grew **1086 → 1131** at `20260926-160448` from the diagnostics rollout (`0371307` DR-PM-01 +34, `497cad1` DR-PM-03 +11 net). Unlike the two mirror suites it has a seam of its own: its `Degraded …` cases, which already share `tests/degraded_env.lua` with `tests/test_surface_parity.lua`, lift out whole into a sibling suite. The recorded re-check trigger was **1300, or the next major this addon adopts**; no new major was adopted (the diagnostics verbs ride majors already in use), so it has not fired — 169 lines remain to 1300. Peel along that seam when it does. |
| 1000–1500 (on notice) | `tests/test_panel.lua` | 1491 | **Peeled after this run: PM-ATS-01 (ATS-05), on the automated-tests sweep branch.** The built Panels page's 18 cases (tab strip, chrome band, editor tabs, swatches) moved whole into `tests/test_panels_page.lua` (780), leaving `tests/test_panel.lua` at 721 with its 47 (registration, opening, repaint policy, panel scale); 65 cases before and after, run in the same order. Both suites leave the band at the next run. The ruling below is what the run recorded. **Re-check trigger FIRED — owed a ruling, not a re-accept.** Grew **1399 → 1491** at `20260926-160448` (+92 net, all from `3a7ac19` pm-band-fix-01's Panels-band cases), which crosses the recorded re-check-at-1400 trigger and leaves **9 lines of headroom** under `layout-§1`'s 1500 cap: it is now the largest authored file in the repository. The earlier reasoning still holds — it mirrors `settings/PanelEditor.lua` and has no seam of its own, so it peels when #47 peels — but #47 now has to carry this file too, or this suite needs its own split (e.g. by the editor's band / section seams) ahead of #47: the next few cases added here cross the cap. Not re-accepted at this run; flagged for the owner. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

