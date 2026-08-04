# Analysis — 20260804-182223

- **Addon:** PanelMaster 0.1.0
- **Verdict:** green
- **Commit:** 559e06dcdfaf (master), dirty
- **Started:** 2026-08-04T18:22:23+05:30
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
25 files and the headless harness passes 696 of 696 cases. The offline perf runner is absent (see below). Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 25 files | [`lint.txt`](lint.txt) | — first run |
| tests | pass | 696 passed, 0 failed, 696 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | — first run |
| perf | skip | — | — (not run) | — first run |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | — first run |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the next one across a change in size: a total that rises because the addon
grew is a different fact from an average that rises because it got denser, and only the second is a
complexity signal.

| Metric | Value |
|---|---|
| Total NLOC | 10651 |
| Functions | 1291 |
| Avg NLOC / function | 7.2 |
| Avg CCN | 2.0 |
| Max CCN | 51 |
| Avg tokens / function | 57.0 |
| Warnings (CCN > 15) | 9 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.01 / 0.05 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there. That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run says nothing about the addon's runtime cost.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

| `Artwork.BuildArtSpec` | 51 | `modules/Artwork.lua` | **Peel next.** The worst number here; pure and very well covered, so the risk is comprehension. One helper per fill mode over a shared post-pass. |
| `R.Sanitize` | 40 | `modules/Registry.lua` | **Accepted, with a caveat** — a per-field loop is exactly the shape that lets a field be forgotten, which is finding `F-002`. |

Seven further entries accepted with reasons recorded 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_artwork.lua` (1356), `modules/Artwork.lua` (1087) — **peel next**, same seam; `settings/PanelEditor.lua` (1064) — accepted, long but shallow.

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
