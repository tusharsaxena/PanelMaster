# Analysis — 20260807-114409

- **Addon:** PanelMaster 0.1.0
- **Verdict:** green
- **Commit:** 69ceb3cbe3f8119d22c833e1ab43c7e69fbc0a9a (master), clean
- **Previous run:** [`20260807-110543`](../20260807-110543/)

## Headline

Green. Both gating suites pass — `luacheck` clean over 25 files, 713 of 713 cases passing with zero
skipped — and every recorded figure is byte-for-byte what the previous run measured, which is the
expected reading: the only commits between the two runs were the LibKa0s v1.8.2 / test-kit revision
10 re-vendor and two `.gitattributes` edits, and none of them touched a line of linted or measured
addon source. `perf` remains a permanent skip because the addon ships no `tests/perf.lua`. The one
thing this run says that the previous one could not is about the **kit**, not the addon: revision
10's `normalize_eol` pass is confirmed working, and every artifact in this bundle was written CRLF by
the runner itself rather than by git's checkout filter.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since `20260807-110543` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 25 files | [`lint.txt`](lint.txt) | No change |
| tests | pass | 713 passed, 0 skipped, 0 failed, 713 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | No change |
| perf | skip | 0 scenarios — no `tests/perf.lua` | — (no artifact) | No change; standing fact |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | No change on any of the ten metrics |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every field of `lizard`'s footer — totals *and* averages — plus the two derived counts. All ten
values are read from [`manifest.json`](manifest.json)'s `suites.complexity` and confirmed against
[`complexity.txt`](complexity.txt)'s footer.

| Metric | Value |
|---|---|
| Total NLOC | 10997 |
| Functions | 1352 |
| Avg NLOC / function | 7.2 |
| Avg CCN | 2.0 |
| Max CCN | 15 |
| Avg tokens / function | 56.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

**`perf` is the one suite that is not a clean pass, and it is a skip rather than a failure.** The
manifest records `skipReason: "no tests/perf.lua — this addon ships no offline scenarios"` — the
**first** of automated-tests-§3's two sanctioned reasons, not the `performance-§12` no-combat-path
exemption, which PanelMaster does not hold. This is a standing fact about the addon and not a tooling
gap on this machine: `lua5.1`, `luacheck` 1.2.0 and `lizard` 1.23.0 were all present, and the other
three suites ran on them. What was not measured is the addon's runtime cost, in full — there is no
`performance-§9` zero-overhead evidence for PanelMaster, and no tag can be cut from a run shaped like
this one without the skip being said out loud, because at the release gate a skip is NOT EVALUATED
rather than passed. Tracked as **PM-004**.

## What moved

Nothing moved. That is the finding, and it is worth stating per suite rather than left to silence:

- **lint** — 0 warnings / 0 errors over 25 files, unchanged, and now flat across all six runs on
  record.
- **tests** — 713 passed / 0 skipped / 713 total, identical to the previous two runs. The suite last
  grew at [`20260807-023000`](../20260807-023000/) (+7). Three consecutive runs at the same count is
  not yet a coverage concern, because the addon has not grown across them either.
- **perf** — skip, unchanged, and unchanged for the same reason as every prior run.
- **complexity** — every one of the ten metrics above is identical to the previous run: 10997 NLOC,
  1352 functions, avg NLOC 7.2, avg CCN 2.0, max CCN 15, avg tokens 56.3, 0 warnings, both warning
  rates 0.00, 3 band files, 0 over cap. No file changed band and no function crossed CCN 15.

**Why flatness is the expected reading here, and not a stuck harness.** The three commits since the
previous run are `43e6e22` (re-vendor LibKa0s v1.8.2, test kit revision 10), `b6e7db8` and `69ceb3c`
(both `.gitattributes`). `.luacheckrc` excludes `libs/` and `tests/`, so neither vendored payload is
in lint's scope; and revision 10's change is confined to the shell runner, which `lizard` does not
measure. A tree that did not change in any measured file, producing identical numbers, is the
harness working. The previous run also recorded `dirty: true` against sha `90d9974` while this one is
clean at `69ceb3c` — the same source, once as a working tree and once as a commit.

**The kit-revision evidence, which is this run's actual news.** Revision 10 added a `normalize_eol`
pass so the bundle is written with the line ending `.gitattributes` declares, rather than always LF.
PanelMaster is CRLF-pinned (`* text=auto eol=crlf`), so every file here must carry equal CR and LF
byte counts, and every file does: `complexity.txt` 1413/1413, `lint.txt` 27/27, `manifest.json`
19/19, `test-cases.md` 806/806, `tests.txt` 715/715. The earlier bundles read CRLF in a working tree
too, but that proves nothing about the runner — they are committed, so git's checkout filter
converted them on the way to disk. This bundle is **untracked** and has never passed through git in
either direction, so its CRLF is the runner's own output and nothing else's. `file(1)` was not used
for any of this: it reports nothing about line terminators for JSON or for a one-line file, so it
passes files it never examined (`line-endings-§7`).

## Complexity watch list

### Functions `lizard` warned on

None.

`lizard` reports 0 warnings over 1352 functions, now at four consecutive runs
([`complexity.txt`](complexity.txt) closes with `No thresholds exceeded`). The highest CCN in the
addon is 15, in exactly two functions — `Compat.AddOnFolders` (`core/Compat.lua:34-52`) and
`R.ApplyArtSize` (`modules/Registry.lua:604-632`) — both sitting exactly on the cap and neither
touched since the baseline. Both are **dense defaulting and guarding rather than tangled control
flow**: `lizard` scores every `and`/`or` short-circuit as a decision, so a run of `t.k = rec.k or D.k`
lines reads high with no branching visible on the page, and neither is a refactor candidate on its
CCN alone. They remain the release gate's entire margin — one added branch in either warns, and that
blocks the **tag**, not the commit.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** 956 NLOC / 155 functions / avg CCN 1.4. The largest suite here because it covers the most branch-heavy module. Byte-identical across the last three runs. Split only when `modules/Artwork.lua` is, along the same seams. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | **Accepted, and watch the direction.** 797 NLOC / 29 functions / avg CCN 4.7 — the highest average in the addon. Flat across three runs now, against 1087 LOC at the baseline. Still 312 lines off the 1500 band with nothing offsetting its growth; split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1064 | **Accepted.** 644 NLOC / 59 functions / avg CCN 2.4, none tripping a threshold. Long but shallow — length is inventory, not tangle. Unchanged since the baseline. |

Nothing newly crossed a band at this run, no file moved between bands, and no file is over the 1500
cap. `tests/test_sunnart.lua` at 955 LOC is the nearest file outside the table.

**On the shelf life of these dispositions.** automated-tests-§4 retires an `Accepted` carried across
three consecutive **release** runs. Every `manifest.json` in this record — all six — has
`release: null`, and the addon is still at an untagged 0.1.0, so that clock has not started for any
entry above. These three are on their sixth *run* and their first release will be their first tick.
Nothing is owed a fix or a deviation ID on shelf-life grounds today.

## Actions

1. **`tests/perf.lua` does not exist** — the addon records nothing about runtime cost, and the `perf`
   gate is NOT EVALUATED at any future tag until it does. Already owned as **PM-004**; not new here.
2. **`modules/Artwork.lua`** — split along the catalog / geometry seam before the next feature lands
   in it. Not a threshold breach; a direction call, carried forward from the previous run and still
   true.

No new action arises from this run.
