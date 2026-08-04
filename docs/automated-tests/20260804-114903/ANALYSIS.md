# Analysis — 20260804-114903

- **Addon:** PanelMaster 0.1.0
- **Verdict:** green
- **Commit:** 8efb499c9db6 (master), dirty
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
25 files and the headless harness passes 696 of 696 cases. The offline perf runner is absent (see below). Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Moved since previous run |
|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 25 files (`lint.txt`) | — first run |
| tests | pass | 696 passed, 0 failed, 696 total (`tests.txt`) | — first run |
| perf | skip | skip | — first run |
| complexity | pass | 9 warnings, max CCN 51, 10651 NLOC / 1291 functions (`complexity.txt`) | — first run |

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured here. That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says nothing about the addon's runtime cost.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

| `Artwork.BuildArtSpec` | 51 | `modules/Artwork.lua` | **Peel next.** The worst number here; pure and very well covered, so the risk is comprehension. One helper per fill mode over a shared post-pass. |
| `R.Sanitize` | 40 | `modules/Registry.lua` | **Accepted, with a caveat** — a per-field loop is exactly the shape that lets a field be forgotten, which is finding `F-002`. |

Seven further entries accepted with reasons recorded at 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_artwork.lua` (1356), `modules/Artwork.lua` (1087) — **peel next**, same seam as `BuildArtSpec`; `settings/PanelEditor.lua` (1064) — accepted, long but shallow.

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
