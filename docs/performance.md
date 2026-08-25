# Performance

`documentation-§3` requires this page unconditionally — the question *"how much does this addon
cost?"* gets an answer whether or not a harness is wired.

**The answer is: the one in-combat path is two API calls per tracked panel at 10Hz, the panel
count is set by the player and defaults to none, and wiring a harness to bracket that is a cost the
measurement could not repay. That is a ratified deviation from `performance-§1`, decided
2026-08-25 — not a `performance-§12` exemption, which this addon does not qualify for.**

Until 2026-08-25 this page said "nobody has measured, and this addon is not entitled to skip
measuring", and no register row existed, so an audit re-filed `performance-§1` every cycle. That
was correct while the choice was unmade. It is recorded rather than deleted because the reasoning
below — why `§12` does not apply — is unchanged and still load-bearing.

## State: no harness, a ratified `§1` deviation, and still no `§12` exemption

| | |
|---|---|
| `libs/LibKa0s/Perf.lua` + `PerfPanel.lua` | **vendored** — the ship folder is copied whole, never partially (`library-stack-§7`, anti-pattern #48) |
| `core/PerfSetup.lua` | not present |
| `PanelMasterPerfDB` | not declared — the TOC declares one SavedVariables global, `PanelMasterDB` |
| `perf` slash verb | not registered. The verb stays **reserved** (`slash-commands-§2`) so it can never mean anything else here |
| `tests/perf.lua` | not present — every automated-test bundle records `perf: skip` |
| `docs/perf-analysis/` | not present |
| `performance-§12` exemption | **not claimed, and not claimable** — see below. The deviation below does not rest on it |
| `## Documented deviations` row | **present** since 2026-08-25, citing `performance-§1` directly |

`Perf` is the one LibKa0s major this addon declines. The decline is reasoned in
[`PLAN-06`](https://github.com/tusharsaxena/PanelMaster/issues/24), which carried `performance-§1`–`§4`
deliberately rather than by oversight. It now also carries a row in
[`ARCHITECTURE.md`](ARCHITECTURE.md)'s `## Documented deviations`, which is what makes it ratified
(`documentation-§3`) — an issue alone never was.

## Why `performance-§12` does not apply

The no-combat-path exemption is the narrow, recorded exit from the wiring MUST. It requires
criterion **(a)** — *no `OnUpdate` handler, no repeating ticker, and no event handler doing more
than occasional work while the player is in combat* — proven by a committed whole-repo sweep.

**This addon has an `OnUpdate` handler, and it runs in combat.** `modules/Canvas.lua:577` installs
a single shared driver the first time any panel is tracked for mouseover:

```lua
mouseoverDriver:SetScript("OnUpdate", function(_, delta)
  elapsed = elapsed + (delta or 0)
  if elapsed < MOUSEOVER_INTERVAL then return end   -- 0.1 == 10Hz
  elapsed = 0
  updateMouseover()
end)
```

`updateMouseover` walks every mouseover-tracked panel and calls `NS.Compat.MouseIsOver(f)` on each,
setting alpha. There is no `InCombatLockdown` gate and none is wanted — the whole point of the fade
is that it keeps working while the player is busy.

The driver exists only once a panel has **Show on mouseover only** ticked (`mouseover` defaults to
`false`, `core/Constants.lua:306`), and it is never destroyed afterwards. That makes it a
user-reachable hot path, not dead code, so:

- **(a) fails.** There is an `OnUpdate` handler doing per-frame-budget work in combat.
- **(b) fails with it.** A declared bucket around `updateMouseover` would not read `0.000` by
  construction; it would read whatever a `MouseIsOver` call per tracked panel at 10Hz costs, which
  is exactly the number nobody has.
- **(c) does not apply.** This addon records nothing that `suspend` could suppress.

Claiming the exemption anyway would put a false row in the register, and none was written for as
long as the choice was open.

## What was decided instead, and why it is not the same claim

The register's job is ratified deviations from the standard, and `§12` is only one route to one. A
row that cites **`performance-§1` directly** says something different and true: this addon is
required to wire the harness, it does not, and here is the owner's reason.

The reason is the shape of the one path, not a claim that the path does not exist:

- **The body is two calls per tracked panel.** `updateMouseover` does one
  `NS.Compat.MouseIsOver(f)` and one `SetAlpha(...)` for each panel in the tracked set. There is no
  per-record work, no allocation, no string building, and no scan that grows with saved data.
- **The set is bounded by a number the player sets.** A panel joins it only with *Show on mouseover
  only* ticked, and `mouseover` defaults to `false` (`core/Constants.lua:306`). With none ticked
  `ensureMouseoverDriver` is never called and the frame does not exist. Emptied afterwards, the
  driver accumulates `delta` and returns.
- **Nothing a raid does changes it.** Group size, combat log volume and saved-data size are all
  irrelevant to this loop, which is what separates it from the paths `performance-§1` exists for.

Against that: a `core/PerfSetup.lua` with a full degradation stub, a second SavedVariables global,
a slash verb, a `suspend`/`resume` contract that must make the host inert without `/reload`, an
offline `tests/perf.lua`, and a `docs/perf-analysis/` tree — to bracket two API calls at 10Hz.

**This is a judgment, and it is recorded as one.** It is not a proof that the cost is zero; nobody
has a number, and the row does not claim one. What it claims is that the number cannot be large
enough to repay the wiring, given a body that cannot grow without the re-check trigger firing.

The re-check trigger is in the register row and is deliberately narrow: a second `OnUpdate` or
repeating ticker, `updateMouseover` growing work that is not O(tracked panels) of two API calls, a
panel count that stops being player-bounded, or `performance-§12` gaining a bounded-cost clause
upstream — at which point the exemption becomes claimable and the `§1` row is replaced by one that
cites it.

## The committed sweep

`performance-§12` asks for this as evidence. It is committed here because it is the artefact that
settles the question either way, and re-running it is how anyone checks whether the answer has
changed.

```sh
grep -rn "RegisterEvent\|RegisterUnitEvent\|RegisterBucketEvent" core modules settings defaults locales
grep -rn 'SetScript("OnUpdate"\|HookScript("OnUpdate"' core modules settings defaults locales
grep -rn "C_Timer" core modules settings defaults locales
grep -rn "ScheduleRepeatingTimer\|ScheduleTimer" core modules settings
```

### `OnUpdate` — 1 hit

| Site | Per-tick work | Runs in combat? |
|---|---|---|
| `modules/Canvas.lua:577` | 10Hz gate, then `updateMouseover`: one `MouseIsOver` + `SetAlpha` per mouseover-tracked panel | **yes**, whenever any panel has *Show on mouseover only* ticked |

### `RegisterEvent` — 4 hits

| Site | Event | Work | Runs in combat? |
|---|---|---|---|
| `core/LSMPatch.lua:31` | `PLAYER_LOGIN` | re-registers one AceGUI widget type, then `UnregisterAllEvents` | no — fires once, before any combat |
| `core/PanelMaster.lua:51` | `PLAYER_LOGIN` | `NS.Panel:Register()` — builds the settings category | no — once |
| `core/PanelMaster.lua:72` | `PLAYER_ENTERING_WORLD` | `NS.Canvas:RenderAll()` | login and each zone change; not a combat path |
| `core/PanelMaster.lua:73` | `PLAYER_REGEN_ENABLED` | `NS.Unlock:ResumePending()` | fires on **leaving** combat, by definition |

### `C_Timer` — 0 hits

None. The one scheduling seam is `settings/OptionsSetup.lua:113`, which forwards to the addon's
AceTimer embed for a **one-shot** panel-refresh delay — not a repeating ticker.

### `ScheduleRepeatingTimer` — 0 hits

None.

## What re-opens this page

- A capture of the mouseover driver, once `performance-§1`'s harness is wired — at which point this
  page becomes the addon's real performance page: which paths are bracketed and why.
- The mouseover fade being replaced by an `OnEnter`/`OnLeave` design, which would remove the only
  `OnUpdate` in the repo and make the `performance-§12` question worth asking again from a clean
  sweep.
