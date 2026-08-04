# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

| Run | Version | Lint w/e | Tests | Perf | CCN warn | Max CCN | Verdict |
|---|---|---|---|---|---|---|---|
| [`20260804-122657`](20260804-122657/) | 0.1.0 | 0/0 | 696/696 | skip | 9 | 51 | **green** |

## Complexity watch list

Current state as of [`20260804-122657`](20260804-122657/) — not that run's diff.
Every function `lizard` warned on and every file in `layout-§1`'s 1000–1500 on-notice band,
each with a one-line disposition.

| `Artwork.BuildArtSpec` | 51 | `modules/Artwork.lua` | **Peel next.** The worst number here; pure and very well covered, so the risk is comprehension. One helper per fill mode over a shared post-pass. |
| `R.Sanitize` | 40 | `modules/Registry.lua` | **Accepted, with a caveat** — a per-field loop is exactly the shape that lets a field be forgotten, which is finding `F-002`. |

Seven further entries accepted with reasons recorded at 2026-08-04.

**Files in the 1000–1500 band:** `tests/test_artwork.lua` (1356), `modules/Artwork.lua` (1087) — **peel next**, same seam as `BuildArtSpec`; `settings/PanelEditor.lua` (1064) — accepted, long but shallow.
