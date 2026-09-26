# Analysis — 20260926-160448

- **Addon:** PanelMaster 1.1.1
- **Verdict:** green
- **Commit:** 1763c0c39c226067b4a29d995ef53b1c87a8b0c5 (master), clean
- **Previous run:** `20260924-104311`

## Headline

Both gating suites pass: `luacheck` is clean over 64 files, and the headless harness runs 964 cases
with none failed and none skipped. `perf` is the same permanent skip as every earlier run, because
there is no `tests/perf.lua`, so this run says nothing about runtime cost. `lizard` warns on nothing.
The addon grew by 924 NLOC and 139 functions since `20260924-104311` (22 commits: the diagnostics
rollout, the LibKa0s v1.61.0 NavRail re-vendor and the Panels band fix), and the averages held at
7.4 NLOC and 2.0 CCN, with max CCN 15. One thing needs action: **`tests/test_panel.lua` is at 1491
lines, 9 under the 1500 cap**, and it has crossed its recorded re-check-at-1400 trigger.
`settings/PanelEditor.lua` went back up to 1464. This is not a release run.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260924-104311` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 64 files | [`lint.txt`](lint.txt) | Same 0/0, over three more files (61 → 64) |
| tests | pass | 964 passed, 0 skipped, 0 failed, 964 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +43 cases (921 → 964); still no skips |
| perf | skip | 0 scenarios: `no tests/perf.lua — this addon ships no offline scenarios` | none, because nothing ran | Unchanged, skipped for the same reason |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals up, averages flat, avg tokens down 0.6 |

Every figure above comes from [`manifest.json`](manifest.json) in this bundle.

| Metric | Value |
|---|---|
| Total NLOC | 16058 |
| Functions | 1914 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 58.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 5 |
| Files over the 1500 cap | 0 |

**perf (skip).** No offline scenarios exist, so the runtime cost of the addon was not measured. This
is the first of `automated-tests-§3`'s two sanctioned skip reasons ("nothing to run"). It is not a
`performance-§12` exemption: `CLAUDE.md` records that the `Perf` decline is a ratified deviation
from `performance-§1`, and says §12 is not claimable because of the shared 10Hz `OnUpdate` in
`modules/Canvas.lua`. This is a standing condition, not a regression. At the release gate it is
**NOT EVALUATED**, not passed.

**complexity (pass, recorded).** `lizard` reports "No thresholds exceeded" (see
[`complexity.txt`](complexity.txt)). Two functions sit exactly at the CCN-15 threshold without
crossing it: `Compat.AddOnFolders` at `core/Compat.lua@27-45` and `R.ApplyArtSize` at
`modules/Registry.lua@611-639`. Both are unchanged from the previous run. No length, NLOC or
parameter warnings fired. Under lizard's default limits the widest signature is `subAnchor` at
`modules/Artwork.lua@786-804` with 9 parameters, and the longest function is the test-fixture
`capture` at `tests/test_libka0s.lua@237-858`, which spans 622 lines but holds only 26 NLOC.

## What moved

- **lint:** 0/0 again. Files checked went from 61 to 64 as new files arrived with the diagnostics
  rollout.
- **tests:** 921 → 964 (+43). No skips before or after.
- **perf:** unchanged skip.
- **complexity:** NLOC 15134 → 16058 (+924), functions 1775 → 1914 (+139). Avg NLOC held at 7.4,
  avg CCN at 2.0 and max CCN at 15, and avg tokens went from 58.6 to 58.0. The growth is size
  rather than density.
- **Band files:** still 5 in the 1000–1500 band and 0 over the cap. Line counts are from
  `wc -l` at `1763c0c` versus `bf1291d`, and the attribution is from `git show --numstat`:
  - `tests/test_panel.lua`: 1399 → **1491** (+92, all from `3a7ac19` pm-band-fix-01). It crossed
    its re-check-at-1400 trigger and has 9 lines of headroom.
  - `settings/PanelEditor.lua`: 1447 → **1464** (+17, `3a7ac19`). Headroom is 36 lines, down from 53.
  - `tests/test_libka0s.lua`: 1086 → **1131** (+45, from `0371307` DR-PM-01 and `497cad1` DR-PM-03).
  - `modules/Artwork.lua` (1188) and `tests/test_artwork.lua` (1356) did not change.
- **Tree:** clean at `1763c0c` on `master`. The previous row was dirty (docs only) on the
  remediation branch.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| None. | | | |

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | Accepted, and watch the direction (carried forward). Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1464 | Already tracked as issue #47 (open). Up 17 lines this run, with 36 lines of headroom left. |
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | Accepted (carried forward). Split when `modules/Artwork.lua` is. |
| 1000–1500 (on notice) | `tests/test_libka0s.lua` | 1131 | Accepted, and moving (+45). The re-check at 1300 or at the next adopted major has not fired. |
| 1000–1500 (on notice) | `tests/test_panel.lua` | 1491 | **Re-check trigger fired. Owed a ruling, not re-accepted.** 9 lines under the cap. |

Accepted shelf life: there have been two release runs (`20260807-160022` for 1.0.0 and
`20260910-234511` for 1.1.0), so no Accepted entry can have lasted three consecutive release runs.
None has crossed the `automated-tests-§4` line.

## Actions

1. **`tests/test_panel.lua`.** At 1491 lines it is 9 short of the `layout-§1` cap, and the
   re-check-at-1400 trigger has fired. Either split it along the editor's band and section seams
   now, or fold it explicitly into issue #47's scope. As things stand, #47 names only
   `settings/PanelEditor.lua`, so this is **new here**. The next handful of cases added to this
   suite will cross the cap.
2. **`settings/PanelEditor.lua`.** It is growing again (1464, 36 lines of headroom). This is already
   tracked as #47, and nothing new is owed beyond scheduling it before the next feature touches the
   file.
