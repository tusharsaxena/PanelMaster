# Performance

`documentation-§3` requires this page unconditionally — the question *"how much does this addon
cost?"* gets an answer whether or not a harness is wired.

**Today the answer is: nobody has measured, and this addon is not entitled to skip measuring.**

## State: no harness, no exemption

| | |
|---|---|
| `libs/LibKa0s/Perf.lua` + `PerfPanel.lua` | **vendored** — the ship folder is copied whole, never partially (`library-stack-§7`, anti-pattern #48) |
| `core/PerfSetup.lua` | not present |
| `PanelMasterPerfDB` | not declared — the TOC declares one SavedVariables global, `PanelMasterDB` |
| `perf` slash verb | not registered. The verb stays **reserved** (`slash-commands-§2`) so it can never mean anything else here |
| `tests/perf.lua` | not present — every automated-test bundle records `perf: skip` |
| `docs/perf-runs/` | not present |
| `performance-§12` exemption | **not claimed, and not claimable** — see below |
| `## Documented deviations` row | **none**, deliberately |

`Perf` is the one LibKa0s major this addon declines. The decline is reasoned at
[`pending/LEDGER.md`](pending/LEDGER.md) ▸ `PLAN-06`, which carried `performance-§1`–`§4`
deliberately rather than by oversight. A ledger entry with no register row is **not a ratified
deviation** (`documentation-§3`), so `performance-§1` is an open MUST against this addon and an
audit is right to keep filing it.

## Why `performance-§12` does not apply

The no-combat-path exemption is the narrow, recorded exit from the wiring MUST. It requires
criterion **(a)** — *no `OnUpdate` handler, no repeating ticker, and no event handler doing more
than occasional work while the player is in combat* — proven by a committed whole-repo sweep.

**This addon has an `OnUpdate` handler, and it runs in combat.** `modules/Canvas.lua:565` installs
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

Claiming the exemption anyway would put a false row in the register. The honest choices are to wire
`performance-§1`'s harness and bracket that loop, or to change the rule — not to write the row.

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
| `modules/Canvas.lua:565` | 10Hz gate, then `updateMouseover`: one `MouseIsOver` + `SetAlpha` per mouseover-tracked panel | **yes**, whenever any panel has *Show on mouseover only* ticked |

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
