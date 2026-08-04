# Analysis — 20260804-215132

- **Addon:** PanelMaster 0.1.0
- **Verdict:** green
- **Commit:** ee1ad6a6c2f0 (`feat/fix-ccn`), dirty — the branch's closing fixes and this bundle were
  in the working tree when the run was taken, which is what `dirty: true` in `manifest.json` records
- **Started:** 2026-08-04T21:51:32+05:30
- **Previous run:** [`20260804-182223`](../20260804-182223/) — the baseline, taken on `master`

## Headline

The run that closes `feat/fix-ccn`. Both gating suites are clean: `luacheck` reports 0 warnings /
0 errors across 25 files and the headless harness passes 706 of 706 cases. The offline perf runner
is still absent (see below).

The one thing this record exists to say: **`lizard` warns on nothing.** The baseline warned on nine
functions, from `Artwork.BuildArtSpec` at CCN 51 down to two at 17. All nine are gone, and no
threshold was moved and nothing was suppressed to get there — the invocation `lizard` ran under is
identical to the baseline's.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 25 files | [`lint.txt`](lint.txt) | unchanged — 0/0 over the same 25 files |
| tests | pass | 706 passed, 0 failed, 706 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +10 cases, all new; none removed or renamed |
| perf | skip | — | — (not run) | unchanged — still a skip, still not a pass |
| complexity | pass | 0 warnings (was 9) | [`complexity.txt`](complexity.txt) | see below |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the previous one across a change in size: a total that rises because the
addon grew is a different fact from an average that rises because it got denser, and only the
second is a complexity signal.

| Metric | This run | Previous | Moved |
|---|---|---|---|
| Total NLOC | 10936 | 10651 | +285 |
| Functions | 1348 | 1291 | +57 |
| Avg NLOC / function | 7.1 | 7.2 | -0.1 |
| Avg CCN | 2.0 | 2.0 | unchanged |
| Max CCN | 15 | 51 | -36 |
| Avg tokens / function | 55.6 | 57.0 | -1.4 |
| Warnings (CCN > 15) | 0 | 9 | -9 |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 | 0.01 / 0.05 | -0.01 / -0.05 |
| Files in the 1000–1500 band | 3 | 3 | unchanged |
| Files over the 1500 cap | 0 | 0 | unchanged |

`manifest.json` records `maxCcn: 0` for this run because that field carries the highest **warned**
CCN and there were no warnings. The real ceiling across the addon is **15**, read off
[`complexity.txt`](complexity.txt).

`tests/perf.lua` is absent — this addon ships no offline scenarios, so nothing was measured there.
That is a **skip, not a pass**: it is recorded as one in `manifest.json`, and it means this run
says nothing about the addon's runtime cost. `performance-§9`'s zero-overhead evidence does not
exist for this addon, and did not exist at the baseline either.

## What moved

**Complexity.** Nine warnings to zero, by extraction only. Each of the nine became a set of named
file-local helpers or a dispatch table, with the branching that produced the number distributed
across them rather than deleted:

| Function | Was | Now | How |
|---|---|---|---|
| `Artwork.BuildArtSpec` | 51 | 13 | A file-scope `FILL` dispatch table (one arm per fill mode) plus eleven named helpers |
| `R.Sanitize` | 40 | 9 | The repair rules declared as data (`CLAMPED`, `FREE_NUMBERS`, `NONEMPTY_STRINGS`, `POINT_FIELDS`, `ENUM_FIELDS`, `BOOL_FIELDS`) and applied by three loops |
| `(anonymous)` mock `__index` | 33 | 4 | The stub's method chain became a `METHOD` table built once at file load |
| `R:Set` | 29 | 6 | The `elseif kind ==` chain became a `COERCE` table keyed off `C.PANEL_FIELD_TYPE` |
| `Canvas.BuildSpec` | 24 | 6 | `addGeometry` / `addAppearance` / `buildAccentSpec` |
| `S.Themes` | 22 | 1 | `collectRegistered` / `collectKnownPacks` / `clampSections` / a hoisted comparator |
| `D:Diagnose` | 21 | 2 | `addHeader` / `addPanel` / `addFrames` |
| `Sl:CliPanel` | 17 | 12 | `doDeleteAll` / `doFitArt` / `parseFieldValue` |
| `release` | 17 | 6 | `clearBackdrop` / `releaseAccents` / `releaseArt` / `poolName` |

**Size.** +285 NLOC and +57 functions, which is the shape of that trade: splitting a function adds
signatures, and the reasoning each helper carries is written down rather than implied by position.
Average NLOC per function fell 7.2 to 7.1 and average tokens 57.0 to 55.6, so the growth is more,
smaller functions rather than denser ones.

**Tests.** +10 cases, all of them cover for the seams the refactor created: eight pin
`tests/wow_mock.lua`'s frame stub, which every suite in the repo builds its frames through and
which nothing had asserted on before it was rewritten as a dispatch table; one pins
`modules/Canvas.lua`'s frame-pool teardown; one pins `core/DebugLogSetup.lua`'s
active/pooled/orphaned frame tally, and it asserts against a deliberately orphaned frame rather
than against the zero a healthy fixture already reads.

**Behavior.** Nothing intended. The branch is a refactor: no feature, no fix, no version bump, no
CHANGELOG entry.

## Complexity watch list

### Functions `lizard` warned on

None.

The two highest numbers left are `R.ApplyArtSize` (`modules/Registry.lua`) and
`Compat.AddOnFolders` (`core/Compat.lua`), both at exactly **15**. Neither was touched by this
branch — they were under the cap before it and are under the cap now — but a function sitting on
the cap warns the moment anybody adds one branch to it, so they are where this table comes back
from "None." `Artwork.BuildArtSpec` is next at 13.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** The largest suite here (98 cases) because it covers the largest, most branch-heavy module. Split only when `modules/Artwork.lua` is, along the same seams. Unchanged by this branch. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1166 | **Accepted, and watch the direction.** Up 79 lines: driving `BuildArtSpec` from 51 to 13 turned one long function into a dispatch table plus eleven helpers, and the signatures and their reasoning cost lines even though the logic did not change. The file is now 334 lines off the 1500 cap with nothing offsetting its growth. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1064 | **Accepted.** Long but shallow — 59 functions, avg CCN 2.4, none tripping a threshold. Length is inventory, not tangle. Untouched by this branch. |

## Actions

1. **`modules/Artwork.lua` is the one number moving the wrong way.** 1087 to 1166 LOC. Not a
   violation, but the split that fixed the CCN is what grew it, so the same seam is now the length
   argument too. Named here so the next run reads it as a trend rather than as news.
2. **`buildSectionQuads` takes 15 positional arguments** (`modules/Artwork.lua`) — a disclosed
   trade, kept deliberately. A ctx table was measured at +616 bytes/call (+10.8%) on the composite
   render path and reverted; `lizard`'s `parameter_count` threshold is 100 and will never fire on
   it. The exposure is transposition of the six trailing scalars, which nothing in the gate can
   catch, and it is recorded here rather than fixed.
3. Nothing else arising. No lint, test or behavior action falls out of this run.
