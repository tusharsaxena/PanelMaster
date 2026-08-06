# Analysis — 20260807-023000

- **Addon:** PanelMaster 0.1.0
- **Verdict:** green
- **Commit:** d91615f2da54 (`master`), clean — [`manifest.json`](manifest.json) records
  `git.dirty: false`, so every figure here was measured against exactly what is committed
- **Started:** 2026-08-07T02:30:00+05:30
- **Previous run:** [`20260804-233329`](../20260804-233329/)

## Headline

Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across 25 files
([`lint.txt`](lint.txt)) and the headless harness passes 713 of 713 with nothing skipped
([`tests.txt`](tests.txt)). The offline perf runner is still absent, so this run measures three
suites of four and says nothing at all about runtime cost.

**This is the first run taken on `master` since the audit-remediation branch landed**, and it is a
documentation-and-harness run rather than a behaviour one. The suite is up seven cases net — eleven
added, four retired or renamed — and every one of them belongs to the kit rev-9 re-vendor or to the
seam-parity work, not to a feature. Complexity is flat where it matters: 0 warnings over 1352
functions, max CCN unchanged at 15, avg CCN unchanged at 2.0. Nothing newly crossed a threshold and
nothing came off the watch list.

## Suites

Every row links its artifact. A skipped suite links nothing — there is no artifact — and says what
was not measured.

| Suite | Status | Result | Artifact | Moved since 20260804-233329 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 25 files | [`lint.txt`](lint.txt) | unchanged — 0/0 over the same 25 files |
| tests | pass | 713 passed, 0 skipped, 0 failed, 713 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | **+7 net** — 706 → 713 (11 added, 4 removed or renamed) |
| perf | **skip** | 0 scenarios — `no tests/perf.lua — this addon ships no offline scenarios` | — (no artifact; nothing was measured) | unchanged — still a skip, still not a pass |
| complexity | pass | 0 warnings, max CCN 15 over 1352 functions | [`complexity.txt`](complexity.txt) | see below |

### Complexity in full

Every field of `lizard`'s footer as [`manifest.json`](manifest.json) records it under
`suites.complexity`, plus the two derived file counts. The **averages** are the point: a total that
rose because the addon grew is a different fact from an average that rose because it got denser, and
only the second is a complexity signal.

| Metric | This run | Previous (`20260804-233329`) | Moved |
|---|---|---|---|
| Total NLOC | 10997 | 10941 | +56 |
| Functions | 1352 | 1348 | +4 |
| Avg NLOC / function | 7.2 | 7.1 | +0.1 |
| Avg CCN | 2.0 | 2.0 | unchanged |
| Max CCN | 15 | 15 | unchanged |
| Avg tokens / function | 56.3 | 55.6 | +0.7 |
| Warnings (CCN > 15) | 0 | 0 | unchanged |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 | 0.00 / 0.00 | unchanged |
| Files in the 1000–1500 band | 3 | 3 | unchanged |
| Files over the 1500 cap | 0 | 0 | unchanged |

**perf is the one suite that is not a clean pass, and it is a skip rather than a failure.** The
addon ships no `tests/perf.lua`, so no scenario ran and nothing was measured.
[`manifest.json`](manifest.json) records `status: "skip"` with the sanctioned `skipReason` — *the
addon ships no offline scenarios* (automated-tests-§3's first sanctioned reason, not the
`performance-§12` exemption, which PanelMaster does not hold). That is a standing condition of this
addon rather than a regression or a transient tooling gap, and it must not be read as `perf clean`.
It also means the **release** gate is not satisfiable on a run shaped like this one: at the tag a
skip is NOT EVALUATED rather than passed.

## What moved

**Tests — +7 net, and none of it behavioural.** [`tests.txt`](tests.txt) goes 706 → 713. Eleven
cases are new:

- four `Parity:` cases, one per seam — Core, DebugLog, Options and Slash — each asserting the
  degraded surface matches the live one;
- three harness cases that follow the kit rev-9 re-vendor: *the runner derives the vendored
  library's load list from LibKa0s.xml*, *every module LibKa0s.xml declares is live in the loaded
  environment*, and *the suite list and tests/test_\*.lua agree in both directions*;
- three database cases — *a v1 SavedVariables file reaches the v1 → v2 body*, *InitDB runs the
  migration runner, so the live DB comes back stamped*, and *an incoming profile is repaired per
  RECORD, not by re-running migrations*;
- one degraded-install case — *`/pm config` answers on EVERY invocation, not once*.

Four came off: two harness cases (*every suite on disk is listed by the runner* / *every suite the
runner lists exists on disk*) collapsed into the single bidirectional case above, and two database
cases were rewritten into the three listed. One case was renamed rather than changed — *libs/LibKa0s
is the LibKa0s release **CLAUDE.md** says this addon bundles*, previously **README**, which is the
provenance line moving to `CLAUDE.md` in `fcdacda`.

**Size — +56 NLOC and +4 functions, all of it in `tests/`.** Per-file, against
[`../20260804-233329/complexity.txt`](../20260804-233329/complexity.txt): `tests/test_libka0s.lua`
472 → 568 NLOC (44 → 51 functions), `tests/test_schema.lua` 157 → 176, `tests/test_harness.lua` 226
→ 241, `tests/test_database.lua` 142 → 157, `tests/test_profiles.lua` 174 → 180. Against that,
`tests/test_vendor_sync.lua` fell 84 → 2 NLOC and 8 → 0 functions: the rev-9 re-vendor moved that
gate's body into `tests/_kit/vendor_sync.lua`, so the consumer-side file is now a two-line
delegation. `settings/Slash.lua` is the only non-test file that grew, 239 → 242.

**Complexity — flat.** Zero warnings before and after, avg CCN 2.0 both runs, max CCN 15 both runs
in the same two functions. Avg NLOC/function and avg tokens/function each ticked up one notch
(7.1 → 7.2, 55.6 → 56.3), which is what adding a block of longish declarative test cases to a corpus
of 1348 short functions looks like. It is not a density signal about the addon's own source: no
module's per-file avg CCN changed at all.

**Lint.** 0/0 over 25 files, flat. The file count has not moved across all four runs.

**Behaviour.** Nothing intended. The eleven commits since the previous run are the audit-remediation
merge, the `.gitattributes` line-ending pin, the documentation tier model, the kit rev-9 re-vendor
and four documentation/citation commits.

## Complexity watch list

### Functions `lizard` warned on

None.

That is a result, not an empty section. [`complexity.txt`](complexity.txt)'s footer reads
`Warning cnt 0` over `Fun Cnt 1352`, and the threshold line is the stock
`cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100` — nothing
was suppressed and no threshold was moved to get there. This is the third consecutive run at zero.

Exactly **two** functions sit on the cap at CCN 15, unchanged from the previous run and named rather
than counted: `R.ApplyArtSize` (`modules/Registry.lua`, lines 604–632) and `Compat.AddOnFolders`
(`core/Compat.lua`, lines 34–52), both read off [`complexity.txt`](complexity.txt). Neither was
touched since. A function sitting exactly on the cap warns the moment anybody adds one branch to it,
so those two are where this table comes back from "None." Below them the addon falls away quickly:
`Artwork.BuildArtSpec` at 13, then `applyAccents`, `buildSectionQuads`, `Sl`, `sources`, `resolve`
and `R.FormatField` at 12.

Both 15s are **dense defaulting and guarding**, not tangled control flow. `lizard` scores every
`and`/`or` short-circuit as a decision, and in Lua a run of `t.k = rec.k or D.k` lines reads high
with no visible branching — which is why neither is a refactor candidate on its CCN alone.

### Files by `layout-§1` band

`lizard` reports NLOC and the band is a LOC rule, so [`manifest.json`](manifest.json) records only
the counts (`bandFiles: 3`, `overCapFiles: 0`), which the runner derives with `wc -l`. The NLOC
column below is this bundle's [`complexity.txt`](complexity.txt); the LOC column is the same `wc -l`
over this run's commit, `d91615f`.

| Band | File | LOC | NLOC | Disposition |
|---|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | 956 | **Accepted.** The largest suite in the repo, 155 functions over 98 cases ([`test-cases.md`](test-cases.md)), because it covers the largest and most branch-heavy module. Byte-identical to the previous run — none of this run's eleven new cases landed here. Split only when `modules/Artwork.lua` is, along the same seams. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | 797 | **Accepted, and watch the direction.** Flat since the previous run — 797 NLOC then and now — which is the first run in this record where it did not grow. It is still 312 lines off the 1500 cap with nothing offsetting its growth, so the disposition carries forward unchanged: split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1064 | 644 | **Accepted.** Long but shallow — 59 functions at avg CCN 2.4 ([`complexity.txt`](complexity.txt)), none tripping a threshold. Length is inventory, not tangle. Unchanged by this run. |

Nothing newly crossed a band at this run; all three entries carry forward, and no file moved between
bands. `tests/test_sunnart.lua` at 955 LOC is the nearest thing outside the table and is not in a
band.

## Actions

1. **`tests/perf.lua` does not exist.** All four runs on record report `perf` as a skip, so the
   addon has no offline runtime-cost evidence at all, and no release can be cut from a run shaped
   like this one without the skip being stated out loud. Owned by **PM-004**
   (`docs/audits/2026-08-04/02_DEVIATIONS.md`, against `performance-§9`) — not new here.
2. **`modules/Artwork.lua` stopped growing, for one run.** 1087 LOC at the baseline, 1188 at the
   previous run, 1188 here. The trend that the last two analyses flagged did not continue, but one
   flat run is not a reversal and the catalog / geometry split is still the fix. Carried forward so
   the next run reads it as a trend rather than as news.
3. **The two functions at CCN 15 are the release gate's whole margin.** `R.ApplyArtSize` and
   `Compat.AddOnFolders` pass today and warn on one added branch, at which point the tag is blocked
   rather than the commit. No action now — named so that a future change to either is read against
   it.
4. **The `RESULTS.md` tests column reads `713/713`, without the skipped figure**
   automated-tests-§4 requires alongside passed and total. It happens to be lossless here — this run
   skipped zero cases, per [`tests.txt`](tests.txt) — but the column cannot express a skip if one
   ever occurs. The lead-in and the table row are both runner-generated and testing-§1 forbids
   editing the vendored kit, so this is a **kit** observation for `LibKa0s`, not something this repo
   fixes. New here.
