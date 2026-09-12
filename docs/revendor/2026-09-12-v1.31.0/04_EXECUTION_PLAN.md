# 04 — Execution plan

Written before either candidate touched code. Each is one commit on `fix/2026-09-12-triage`, with
`lua tests/run.lua` and `luacheck .` green before it lands.

## B1 — #48, the three blocks compose through `spec.bind`

**Files.** `settings/PanelEditor.lua`, `tests/test_options_groups.lua`, `tests/test_panel.lua`,
`docs/ARCHITECTURE.md`, `docs/settings-panel.md` (and any doc that names the hand-written blocks).

**Characterization first.** A case that renders the *Background and border* and *Accent bar* tabs of
a real record and pins, per block: the field each control writes, in row order; the label; the
widget type; and a get/set round trip through `NS.Registry` (the control reads the live record, and
a `__fire`d change lands in the record through `Registry:Set`, colors as `{ r, g, b, a }` arrays).
It is written against the hand-written blocks and must stay green across the swap unchanged except
where a player-visible change is accepted and named.

**Change.** One `recordBind(rec)` over the live record by id, writing through `NS.Registry:Set` and
converting the one row type whose shape differs (color: `{ r, g, b, a }` array ↔ named keys). Three
composer calls, `O.BorderGroup` × 2 and `O.BarGroup`, with `keys` mapping the canonical leaves onto the
stored fields and this addon's own rows as `extra`. The composed rows are retuned before rendering
wherever a row field can keep what players see today (labels, tooltips, `max`, `isPercent`,
the media lists). Rendered with `O.RenderField` into the editor's own rows, two to a line.

**The assertion that proves it.** The characterization case above (same fields, same order, same
labels, same round trips), plus the register gate in `tests/test_options_groups.lua` turned around: no
hand-written `options-ui-§16` block remains in the editor, and no `options-ui-§16` row remains in the
register.

## B2 — #50, the harness migrates onto kit 17

**Files.** `tests/wow_mock.lua`, `tests/test_panel.lua`, `tests/test_slash.lua`,
`tests/test_harness.lua`.

**Characterization first.** Pin what the suites read off the current harness before it moves: the
`PLAYER_LOGIN` retry is recorded, `/pm` and `/panelmaster` are registered, `OptionsSetup`'s
throttle timer is cancellable and counted by `M.__fireTimers`, a bad event raises, and `NS.Print`
is the addon's own after `NewAddon`.

**Change.** Drop the local `AceAddon-3.0`, the local `__timers`/`__fireTimers` and `__chatCommands`;
the kit's `NewAddon` builds `NS.addon` from its mixin list. Keep the frame stub, the profile-switching
AceDB, the chat capture, the Settings registry, `C_AddOns`, the `SetTitle`/`editbox` wraps, the
AceConfig fakes and the no-op `C_Timer.After`. Port `tests/test_panel.lua:60` to
`NS.addon.__events` and `tests/test_slash.lua:22-23` to `AceConsole.commands`.

**The assertion that proves it.** A new case: `NS.addon` carries the kit's `Printf` and
`UnregisterAllEvents`, and its `__events` is per target. The *extends mock_base* case stays green.
