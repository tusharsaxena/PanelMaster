# Analysis — 20260926-193106

- **Addon:** PanelMaster 1.1.1
- **Verdict:** green
- **Commit:** 5119ae11afc150de1fab9ad58135b97e108c5e8c (feat/2026-09-26-automated-tests-sweep), clean
- **Previous run:** `20260926-160448`

## Headline

Both gating suites pass: `luacheck` is clean over 66 files, and the headless harness runs 964 cases
with none failed and none skipped. `perf` is the same permanent skip as every earlier run, since
there is no `tests/perf.lua`, so this run says nothing about runtime cost. `lizard` warns on
nothing. This is the closing run of the 2026-09-26 automated-tests sweep. Its two peels (PM-ATS-01,
PM-ATS-02) took `tests/test_panel.lua` (1491) and `settings/PanelEditor.lua` (1464) out of the
1000–1500 band, which now holds 3 files instead of 5. Nothing new needs action. This is not a
release run.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260926-160448` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 66 files | [`lint.txt`](lint.txt) | Same 0/0, over two more files (64 → 66): the two peel targets |
| tests | pass | 964 passed, 0 skipped, 0 failed, 964 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Unchanged at 964. PM-ATS-01 moved cases between suites and added none |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | Unchanged, skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals up slightly (+50 NLOC, +1 function), averages flat, band 5 → 3 |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 16108 |
| Functions | 1915 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

**perf (skip).** No offline scenarios exist, so the addon's runtime cost was not measured. This
is the first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"), not a
`performance-§12` exemption. It is a standing condition, not a regression. At the release gate it
is **NOT EVALUATED**, not passed.

**complexity (pass, recorded).** `lizard` reports "No thresholds exceeded" (see
[`complexity.txt`](complexity.txt)). The same two functions sit exactly at the CCN-15 threshold
without crossing it: `Compat.AddOnFolders` at `core/Compat.lua@27-45` and `R.ApplyArtSize` at
`modules/Registry.lua@611-639`. Neither changed since the previous run.

## What moved

This run measures `5119ae1`, five commits after `20260926-160448` measured `1763c0c`. Those commits
were the previous run's own record (PM-ATS-00), the LibKa0s v1.62.0 / kit revision 31 re-vendor and
its line-ending repair (PM-ATS-RV, PM-ATS-RVR), and the two peels.

- **lint:** 0/0 both times. The file count rose 64 → 66 because the two peels created
  `tests/test_panels_page.lua` and `settings/PanelEditorTabs.lua`. The exclusions are the same five
  paths (see `RESULTS.md` § Lint).
- **tests:** 964 → 964. PM-ATS-01 moved the built Panels page's cases from `tests/test_panel.lua`
  into `tests/test_panels_page.lua` whole, so the total held. No skips in either run.
- **perf:** skip → skip, same reason.
- **complexity:** NLOC 16058 → 16108 (+50) and functions 1914 → 1915 (+1). This run does not break
  the rise down by file. Avg NLOC (7.4), avg CCN (2.0), avg
  tokens (58.0) and max CCN (15) did not move, and warnings stayed at 0. The band went 5 → 3:
  `tests/test_panel.lua` (1491, 9 under the cap at the previous run) and `settings/PanelEditor.lua`
  (1464) left it. They are now 721 and 746 lines, and their new siblings are 781 and 798, all below
  the band. Nothing crossed into the band and nothing is over the cap.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | Accepted, and watch the direction. Unchanged since `20260807-160022`, 312 lines off the cap. Now the largest shipping file. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | Accepted. It mirrors `modules/Artwork.lua` and has been unchanged across every recorded run. It is the largest file in the repository again. Split only when the module is. |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1131 | Accepted, and moving. Unchanged this run. Its re-check trigger (1300, or the next major adopted) has not fired. Its `Degraded …` cases are the seam. |

The full dispositions are in `RESULTS.md`. None of the three is newly in the band, so none arrived
blank. None is a release-run entry, so the three-consecutive-release-runs shelf life
(`automated-tests-§4`) is not advanced by this run.

## Actions

None new. The two actions the previous run raised (`tests/test_panel.lua` at 1491 past its
re-check trigger, and `settings/PanelEditor.lua` back at 1464) were closed by PM-ATS-01 and
PM-ATS-02, and this run confirms both files left the band. The standing watch-list items above
keep their recorded triggers.
