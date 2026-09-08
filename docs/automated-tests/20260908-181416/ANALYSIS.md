# Analysis — 20260908-181416

- **Addon:** PanelMaster 1.0.0
- **Verdict:** green
- **Commit:** 564acbd (`feat/2026-09-07-audit-review-remediation`), clean
- **Previous run:** [`20260825-103450`](../20260825-103450/)

## Headline

Three suites pass and one is a permanent skip. Lint 0/0 over 55 files, 778 cases with none failed and
none skipped, `lizard` warns on nothing at max CCN 15 across 1494 functions, and `perf` skips because
this repository ships no `tests/perf.lua`.

The result is clean. The thing to read is `settings/PanelEditor.lua`, which grew **397 lines** since
the previous run's commit and now sits **12 lines under `layout-§1`'s 1500 cap**.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260825-103450` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 55 files | [`lint.txt`](lint.txt) | 27 → 55 files; 0/0 unchanged |
| tests | pass | 778 passed, 0 skipped, 0 failed, 778 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 731 → 778 |
| perf | skip | no `tests/perf.lua` | — | Unchanged, and permanent |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | Totals up; band 3 → 4 files |

**On the `perf` skip.** The first of `automated-tests-§3`'s two sanctioned reasons — *nothing to
run* — and not a ratified `performance-§12` exemption. The record is **silent about runtime cost**;
nothing here says this addon is cheap, only that the question was never asked.

**Complexity in full.**

| Metric | `20260825-103450` | This run |
|---|---|---|
| Total NLOC | 11223 | 12627 |
| Functions | 1379 | 1494 |
| Avg NLOC / function | 7.1 | 7.4 |
| Avg CCN | 1.9 | 2.0 |
| Max CCN | 15 | 15 |
| Avg tokens / function | 55.9 | 57.4 |
| Warnings (CCN > 15) | 0 | 0 |
| Files 1000–1500 | 3 | 4 |
| Files over 1500 | 0 | 0 |

Totals up 13% and 8%, averages up by a decimal each. Three functions sit at exactly CCN 15 and none
above: `refreshHeaderActs` (`settings/PanelEditor.lua@1301-1356`), `R.ApplyArtSize`
(`modules/Registry.lua@669-697`) and `Compat.AddOnFolders` (`core/Compat.lua@27-45`). The margin is
narrower than a clean column suggests — a function on the line warns the moment anybody adds a
branch, and a warning blocks the tag rather than the commit.

## The trigger that fired

`settings/PanelEditor.lua`'s disposition read, at the previous run: *"First movement across four
runs; if the next change also grows it, execute the split rather than re-accept."*

The next changes grew it by 397 lines — 1091 → 1187 when the settings pages became tabbed, → 1310
when Create and Edit moved above the tab strip, → 1350 for the page-band build-order fix, → 1488 at
`M4-15`. It is now the largest file in the repository, twelve lines under the cap, and it holds the
addon's highest-CCN function. `tests/test_panel.lua` shadowed it almost line for line, 700 → 1222,
and joined the band on the way.

The split is not available: `03_SPEC.md` § C22 rules out splitting any file this cycle. What the
disposition can honestly be is an owner, and it has one — issue **#47**, *settings/PanelEditor.lua
has crossed its own recorded split trigger (1488, cap 1500)*, already open and triaged at medium.
The cell now cites it rather than re-accepting a fourth time.

## What moved

- **lint** — 27 → 55 files at 0/0, `M4-11` bringing the test tree into scope.
- **tests** — 731 → 778. `docs/test-cases.md` and the README badge already read 778, and the
  bundle's [`test-cases.md`](test-cases.md) is byte-identical to `docs/test-cases.md` at HEAD, so no
  count claim moves in this commit.
- **Band** — three files to four. `settings/PanelEditor.lua` 1091 → 1488, `tests/test_panel.lua`
  700 → 1222 and newly in the band, `modules/Artwork.lua` and `tests/test_artwork.lua` both
  unchanged and untouched by this whole cycle — five consecutive runs flat for each.

## What this run removed from the record, deliberately

The `RESULTS.md` this replaced carried three hand-written passages the runner does not produce, and
they are recorded here rather than lost:

- **The nine functions the baseline warned on**, all since extracted:
  `Artwork.BuildArtSpec` (51), `R.Sanitize` (40), the `wow_mock` frame stub's anonymous `__index`
  (33), `R:Set` (29), `Canvas.BuildSpec` (24), `S.Themes` (22), `D:Diagnose` (21), `Sl:CliPanel`
  (17) and `Canvas`'s `release` (17). `BuildArtSpec` reads 13 today. Nothing was suppressed and no
  threshold moved.
- **The `0` in the Max CCN column on [`20260804-215132`](../20260804-215132/) is an instrument
  fault, not a measurement.** The pre-rev-6 kit read `CCN_MAX` out of `lizard`'s `!!!! Warnings`
  block, which is empty once an addon reaches zero warnings, so the field had no input. That
  bundle's own `complexity.txt` says 15. The row keeps the `0` it recorded — generated evidence is
  not corrected in place, because a table edited to read what it should have measured is
  indistinguishable from one that measured it. The full reading is in
  [`20260804-233329/ANALYSIS.md`](../20260804-233329/ANALYSIS.md).
- **The old file contradicted itself on this addon's version**, describing it as "still at an
  untagged 0.1.0" a few lines from calling [`20260807-160022`](../20260807-160022/) the v1.0.0
  release run. The second is right: that bundle's manifest carries `"release": "1.0.0"` and it is
  the only release run in this record.

## Shelf life

`automated-tests-§4` retires an `Accepted` carried across three consecutive **release** runs. This
record holds exactly one release run, [`20260807-160022`](../20260807-160022/), so the three entries
that predate it have spent **one tick** and are not owed anything yet. Ordinary runs do not count
(anti-pattern #53). `settings/PanelEditor.lua` is off that clock entirely now — its disposition is an
open issue rather than an accept.

## The `ANALYSIS.md` gap, noted once

Three of nine bundles here carry no `ANALYSIS.md`: `20260807-110543`, `20260825-103450`, and until
this file, this one. The first two are not getting one. An analysis written today into a folder
stamped in August would date a reading to a day nobody took it, which is worse than a gap, because a
gap is legible. Fixed forward. Collection-wide the gap stands at 37 of 95 bundles.

## Actions

None in this bundle; the one live item is issue #47 and it is already open, triaged and owned.
