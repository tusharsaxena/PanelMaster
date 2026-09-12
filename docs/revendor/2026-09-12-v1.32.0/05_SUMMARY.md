# 05 — Summary: LibKa0s v1.31.0 → v1.32.0

## The move

| | |
|---|---|
| From | v1.31.0 |
| To | **v1.32.0**, local tag object `f5f41c9` at `e18dd12`, never pushed |
| Files under `LibKa0s/` that moved | `Options.lua` (`MINOR` 15 → **16**), `Slash.lua` (`MINOR` 7 → **8**) |
| Every other minor | unchanged: Core 7, Env 1, Pool 3, Item 1, Media 3, Widgets 9, DebugLog 12, OptionsWidgets 15, OptionsCompose 4, OptionsScroll 3, Perf 11, PerfPanel 5 |
| Kit revision | **17 → 17**, `testkit/` did not move |
| Files removed upstream | none |
| Cross-major skew found | none after the copy |

## What reached this addon for free

Nothing observable. A host that supplies neither new field runs the old walks exactly, and on the
copy alone every one of the 794 cases stayed green.

## What was adopted

| Item | Commit | Cases |
|---|---|---|
| Re-vendor (both payloads, provenance line) | `c3479a9` | 794 → 794 |
| The bulk bracket and the five bulk acts, tests first | `f25a8af` | 794 → 805 |
| Docs and this bundle | this commit | 805 → 805 |

**What each act logs now** (`debug-logging-§10`, standard v2.44.0; `docs/debug.md` has the table):

| Act | Before | Now |
|---|---|---|
| `R:Reset` | `[Panel] reset '<panel>' (id n)` | `[Set] reset '<panel>': N rows` |
| `R:CopyFrom` | `[Panel] '<dst>' copied settings from '<src>'` | `[Set] copy from '<src>' to '<dst>': N rows` |
| `R:ResetPositions` | nothing | `[Set] reset positions: N panels` |
| `R:Recover` | nothing | `[Set] recover positions: N panels` |
| `Sl:DoResetAll` | `[Profile] switched to '<name>', N panels` | `[Set] reset profile '<name>' to defaults (N rows)`, once, from `OnProfileReset` |
| Profiles ▸ Copy From | `[Profile] switched to …` | `[Set] copied profile '<src>' → '<dst>'` |
| Profiles ▸ switch | `[Profile] switched to '<name>', N panels` | unchanged |

N counts only what the act changed. An act that changes nothing still logs its one line, with `0`.

**Upstream observation.** `bulkEnd`'s `count` is the rows `applyDefault` returned, rows already at
their default included, so a host cannot use it as §10's N. This addon tallies at its own seam and
ignores `count`. Hosts across the collection will each write that tally; a `changed` figure from the
library would need the host to say what "changed" means, so the tally is probably rightly the host's.

## What was declined

Nothing. The Slash pair was not wired because nothing reaches that walk here (`03_DECISIONS.md`).
No issue was filed.

## Gates

| Stage | `lua tests/run.lua` | `luacheck .` | `lizard -C 15` |
|---|---|---|---|
| Baseline, `19a94af` | 794 passed, 0 failed | 0 / 0 in 57 files | — |
| Copy + provenance line (`c3479a9`) | 794 passed, 0 failed | 0 / 0 | — |
| Tests first, before the change | 794 passed, **10 failed** (the new cases, as intended) | — | — |
| Bracket and acts (`f25a8af`) | **805 passed, 0 failed, 0 skipped** | **0 / 0** | clean |
| Docs and bundle | 805 passed, 0 failed | 0 / 0 | clean |

`modules/Registry.lua` is 999 lines and `settings/PanelEditor.lua` 1476. Every file these commits
touched carries CRLF with CR == LF.
