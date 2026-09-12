# 05 — Summary: LibKa0s v1.30.0 → v1.31.0

## The move

| | |
|---|---|
| From | v1.30.0 |
| To | **v1.31.0**: first taken at `30db4ed`, then **re-taken at `e7e1962`** during this run (below) |
| Files under `LibKa0s/` that moved | `OptionsWidgets.lua` (`WIDGETS_MINOR` 14 → **15**), `OptionsCompose.lua` (`COMPOSE_MINOR` 3 → **4**), `Perf.lua` (`MINOR` 10 → **11**, in the re-take) |
| Every other minor | unchanged: Core 7, Env 1, Pool 3, Item 1, Media 3, Widgets 9, DebugLog 12, Slash 7, Options 15, OptionsScroll 3, PerfPanel 5 |
| Kit revision | **16 → 17** (`README.md`, `framework.lua`, `mock_base.lua`) |
| Files removed upstream | none |
| Cross-major skew found | none after the copy |

## The tag moved under this run

The library re-took `v1.31.0` at 15:18 on its review-fixed tree, after `e0ec23b` had copied the first
take. The vendor gate caught it: after `097e783`, `test_vendor_sync` went red on `OptionsCompose.lua`
and `tests/_kit/README.md`. Both payloads were copied again, whole, from the re-taken tag. Five files
changed (`OptionsCompose.lua`, `OptionsWidgets.lua`, `Perf.lua`, the kit's `mock_base.lua` and
`README.md`), both diffs came back empty, and the provenance line did not move, because the tag name
did not. Every #48 and #50 case stayed green against the new bytes. Nothing in the review reaches this
addon's behavior: a bound row's `get(key)` for `disabledIf` and `pairWith` keyed by `field` are unused
here, Perf is declined, and the kit's timer handle now says `cancelled` (AceTimer's own spelling),
which no case here reads.

**Upstream observation.** `OptionsCompose.lua` and `OptionsWidgets.lua` changed under the same tag
name and the same LibStub minors (4 and 15). A consumer that vendored the first take carries different
code under the same minor, and only a vendor gate like this one can tell the two apart.

## What reached this addon for free

- **OptionsWidgets minor 15 and OptionsCompose minor 4, for every path-keyed row.** The `path == nil`
  gate and the golden-fixture pin upstream mean nothing this addon rendered through the library
  moved on the copy.
- **Kit 17's AceEvent `Embed` no longer reads its receiver.** The shape of this addon's old wrapper
  is what caught that upstream; the copy alone kept 785 cases green.

## What was adopted

| Candidate | Commit | Cases |
|---|---|---|
| Re-vendor (both payloads, provenance line) | `e0ec23b` | 785 → 785 |
| B1 — `spec.bind`: the three Panels-page blocks compose, three `options-ui-§16` register rows retire (#48) | `5f04c5f` | 785 → 789 |
| B2 — the harness migrates onto kit 17's Ace fakes (#50) | `097e783` | 789 → 792 |
| Second copy, from the re-taken tag (this summary's commit) | — | 792 → 792 |

**B1, what a player sees.** Kept by retuning the composed rows: labels, tooltips, ranges (border
thickness still reaches 32), media lists and their order, **Bar opacity** as a 0–1 ratio. Changed,
because no row field can express the old behavior: the three composed swatches (both **Border
color**s and **Bar color**) no longer gain a gray `(opacity)` suffix while **Use class color** is
ticked (their tooltip already says the alpha applies); a live color drag commits through the
library's 50 ms throttle instead of on every event; and without AceGUI-3.0-SharedMediaWidgets the
three media pickers fall back to a plain Dropdown, where the hand-written picker asked AceGUI for an
unregistered `LSM30_*` type. None of it is confirmed in a live client; `docs/smoke-tests.md` 5c step
4d is the check.

## What was declined

Nothing. No issue was filed.

## Skipped or unreached

Nothing unreached. Perf remains a settled decline (#31).

## Gates

| Stage | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| Baseline, `b884ca8` | 785 passed, 0 failed | 0 / 0 in 57 files |
| Copy + provenance line (`e0ec23b`) | 785 passed, 0 failed | 0 / 0 |
| #48 characterization, before the swap | 789 passed; the three new gate cases red as intended | 0 / 0 |
| #48 (`5f04c5f`) | 789 passed, 0 failed | 0 / 0 |
| #50 characterization, before the migration | 791 passed; the #50 case red as intended | 0 / 0 |
| #50 (`097e783`) | 792 passed, 0 failed | 0 / 0 |
| Tag re-taken upstream, before the second copy | 790 passed, **2 failed** (the two vendor-sync cases, correctly) | 0 / 0 |
| Second copy | **792 passed, 0 failed, 0 skipped** | **0 / 0** |

`lizard -C 15` reports no function over 15 in any file these commits touched. `luacheck` excludes
`libs/` and `tests/_kit/` (`.luacheckrc`); the payload's own gate is upstream.

## Not pushed

Committed only, on `fix/2026-09-12-triage`.
