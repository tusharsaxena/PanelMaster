# Analysis — 20260807-160022

- **Addon:** PanelMaster 0.1.0 (manifest `release` 1.0.0 — the pre-bump release run, see below)
- **Verdict:** green
- **Commit:** 91de582a9d2aa75ff1c4099559b102d546d4364b (master, dirty)
- **Previous run:** [`20260807-114409`](../20260807-114409/) — the last ordinary run, taken before the profile-switch fix

## Headline

Green, and **the release run for 1.0.0** — the first release this addon has ever had. Every gate
`automated-tests-§3` names is satisfied: `luacheck` clean over 25 files, 717 of 717 harness cases
passing with nothing skipped, `complexity` recorded with **zero** functions above CCN 15.

**`perf` is a skip, and the release gate treats it as passed under the one narrow exception**: this
addon ships no `tests/perf.lua`, so there were no offline scenarios to run. That is the
absence-of-scenarios reason, not a missing interpreter, and not a ratified `performance-§12`
exemption — this addon explicitly does **not** qualify for that one (`modules/Canvas.lua:577` runs a
shared 10Hz `OnUpdate`, which fails criterion (a)). So 1.0.0 ships **verified against three suites,
not four**, and the release notes say so in the `## Version History` row rather than only here.

The numbers moved for the first time in four runs, because this is the first run since a `.lua` file
changed: the profile-switch fix and its tests. Cases 713 → 717, NLOC 10997 → 11061.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260807-114409` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 25 files | [`lint.txt`](lint.txt) | No change — same 25 files, same clean result |
| tests | pass | 717 passed, 0 skipped, 0 failed, 717 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | **+4 cases** — three profile-switch, one deferred-repaint |
| perf | skip | 0 scenarios — no `tests/perf.lua` | none — the suite did not run | No change — permanent skip, see above |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | **NLOC +64, functions +5**; every average and maximum unmoved |

**Complexity, in full** — every field of `lizard` 1.23.0's footer as recorded in
[`manifest.json`](manifest.json) `suites.complexity`:

| Metric | Value | Previous |
|---|---|---|
| Total NLOC | 11061 | 10997 |
| Functions | 1357 | 1352 |
| Avg NLOC / function | 7.2 | 7.2 |
| Avg CCN | 2.0 | 2.0 |
| Max CCN | 15 | 15 |
| Avg tokens / function | 56.2 | 56.2 |
| Warnings (CCN > 15) | 0 | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 | 3 |
| Files over the 1500 cap | 0 | 0 |

**Max CCN is 15, exactly on the line, and has been for four runs.** The gate is *above* 15, so this
passes — but it passes with nothing in hand. Two functions sit there: `R.ApplyArtSize`
(`modules/Registry.lua:639-667`) and `Compat.AddOnFolders` (`core/Compat.lua:34-52`). One added
branch in either turns a green release into a refused one, and neither is a function anybody expects
to be finished with: the first grows with every artwork fill mode, the second with every client
quirk. This is not a finding against 1.0.0 — it is the thing most likely to block 1.0.1.

## What moved

- **lint** — 0/0 over 25 files, identical to the previous three runs. `.luacheckrc` scope unchanged,
  so the comparison is like for like, and the changed files (`modules/Registry.lua`,
  `modules/Unlock.lua`, `settings/Panel.lua`, `settings/PanelEditor.lua`) are inside the checked set
  rather than excluded — the clean run is evidence about this release's code.
- **tests** — 713 → **717**. Four new cases, all covering the profile-switch fix: that a switch drops
  preview's tracked ids before they can delete a real panel, that it drops per-panel unlocks, that it
  drops the editor's selection, and that a repaint deferred while the page was hidden actually lands
  on the next show. The first three were verified to fail against the unfixed `ReloadProfile` before
  being committed. Two existing cases changed rather than being added: the hidden-page case asserted
  the wrong flag name (`ctx.dirty`, which nothing read), and `test_libka0s.lua`'s widget counter was
  scoped to one page's render.
- **perf** — skip, identical, same reason. Fourth consecutive run, and now the first **release** run
  to carry it.
- **complexity** — NLOC +64 and functions +5, which is the new `dropSessionIDs` /
  `Unlock:ForgetPending` / `PanelEditor:ForgetSelection` seams and their tests, less the removed
  `P:RefreshPanels`. Every average, rate and maximum unchanged: the addition is flat code that moved
  totals and not shape.
- **version** — the manifest stamps `addonVersion` **0.1.0** while `release` says **1.0.0**. That is
  correct rather than a defect: `run-automated-tests.sh` reads `addonVersion` from the `.toc`, and
  the gate runs *before* any file is edited so a refusal leaves the repo untouched. `release: "1.0.0"`
  is what ties this bundle to the version, which is what `--release` is for.
- **git dirty** — `true`, and expected: the release run precedes the version edit by design.
- **bundle line endings** — all five artifacts carry equal CR and LF byte counts
  (`complexity.txt` 1418/1418, `lint.txt` 27/27, `manifest.json` 19/19, `test-cases.md` 810/810,
  `tests.txt` 719/719), matching this repo's `* text=auto eol=crlf` pin.

## Complexity watch list

### Functions `lizard` warned on

**None.** Zero functions above CCN 15 — which is what the release gate enforced, so this reading is
the gate's own result rather than an incidental observation. See the max-CCN-15 note above: the
headroom is zero, and that is worth carrying forward even though nothing warns today.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_artwork.lua` | 1356 | **Accepted.** Unchanged this run. The largest suite here because it covers the largest, most branch-heavy module. Split only when `modules/Artwork.lua` is, along the same seams. |
| 1000–1500 (on notice) | `modules/Artwork.lua` | 1188 | **Accepted, and watch the direction.** Unchanged this run — four flat runs now, against 1087 at the baseline. Still 312 lines off the cap. Split along the catalog / geometry seam before the next feature lands in it. |
| 1000–1500 (on notice) | `settings/PanelEditor.lua` | 1091 | **Accepted — and it moved.** 1064 → 1091 (+27), from the profile-switch fix's `ForgetSelection` seam and the bus-policy comment explaining the flag bug. Still long-but-shallow, and still the smallest of the three. First movement in this file across four runs; if the next change also grows it, that is the point to execute the split rather than re-accept. |

Nothing newly crossed a band, no file moved between bands, and no file is over the 1500 cap.
`tests/test_sunnart.lua` at 955 LOC is the nearest thing outside the table; `tests/test_panel.lua`
grew to 700 with the new cases and is not close.

**None of these three has yet been carried as *Accepted* across three consecutive RELEASE runs**,
because 1.0.0 is the first release this addon has had — the `automated-tests-§4` shelf-life clock
(anti-pattern #53) starts here for all three. The ordinary runs they were carried through do not
count against it. At the third release still reading *Accepted*, each is owed a fix or a tracked
deviation ID with an owner.

## Actions

1. **Nothing blocks 1.0.0.** All five gate conditions pass; the release notes carry the perf-skip
   sentence the exception requires.
2. **Watch the CCN-15 ceiling.** `R.ApplyArtSize` and `Compat.AddOnFolders` are exactly on the line.
   A single added branch in either refuses the next release. Worth a deliberate look before 1.0.1
   rather than at the moment a bump is blocked.
3. **`settings/PanelEditor.lua` moved for the first time.** Re-check at the next release: two
   consecutive growth runs is the signal to split rather than re-accept.
4. **The shelf-life clock starts** for all three band entries at this release.
