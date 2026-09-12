# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.30.0..v1.31.0` (`5193ebe`, `853c62e`, `09099b1`,
`3162e53`, `f355fdc`, `2b312db`, `30db4ed`), the v1.31.0 block of the library's `CHANGELOG.md`,
`docs/api/Options/version-15.15.4.3-docs.md` (the `Since` markers **W15** and **C4**, against
15.14.3.3) and `docs/api/testkit/version-17-docs.md` (against version 16).

## Class A — reached this addon on the re-vendor alone

| Item | Why it needs nothing here |
|---|---|
| **`OptionsWidgets.lua` minor 15** — a row with no `path` reads and writes through its own `get`/`set` | The gate is `path == nil`. Every row this addon renders through the library today carries a path, so each one is still read and written through the descriptor. Nothing moves until a path-less row is rendered (B1). |
| **`OptionsCompose.lua` minor 4** without `spec.bind` | Path-keyed output is byte-for-byte compose minor 3's (pinned upstream by `tests/fixture_compose_golden.lua`). `settings/Schema.lua`'s `O.MasterControls` call passes no `bind`. |
| **Kit 17's AceEvent `Embed`, AceGUI `WidgetVersions`/`RegisterLayout`** | The local `AceEvent-3.0` wrapper already calls the kit's `Embed` first and lays its own message half over it; the kit's Embed no longer reads its receiver (the upstream fix PanelMaster's wrapper shape caused), so the wrapper is served. The suite total did not move on the copy (785 → 785). |

## Class B — host change required

### B1. `spec.bind` — the record-backed arm (PanelMaster#48)

- **What.** `O.BorderGroup` / `O.BarGroup` take `spec.bind = { set, get | record }` and emit
  path-less rows carrying `field`, `get` and `set`; W15 renders them.
- **Evidence.** `docs/api/Options/version-15.15.4.3-docs.md:41-67` (the arm), `:880-898` (the
  fields), `:900-1017` (the worked example built from this addon's three blocks);
  `libs/LibKa0s/OptionsCompose.lua:90-190` (`bindReader`, `bindRow`, `emit`, `appendExtra`);
  `libs/LibKa0s/OptionsWidgets.lua:770-780` (the `path == nil` gate).
- **Touches.** `settings/PanelEditor.lua` (the three blocks on the *Background and border* and
  *Accent bar* tabs), `tests/test_options_groups.lua` (the register gate inverts into a
  composed-blocks gate), `tests/test_panel.lua` (label cases), `docs/ARCHITECTURE.md` (three
  `options-ui-§16` rows retire), `docs/settings-panel.md`.
- **Recommendation: adopt** (the orchestrator's pre-made decision). It closes a recorded gap: three
  ratified register rows whose re-check trigger is exactly this arm.
- **Blast radius.** **Replaces** code the addon owns: three hand-written blocks of `makeMediaDropdown`
  / `numberField` / `makeColorPair` calls. Everything a player sees on those two tabs is at stake, so
  characterization first.

### B2. Kit 17's `NewAddon`, AceTimer and AceConsole (PanelMaster#50)

- **What.** The kit's `NewAddon(object, name, ...)` honors its mixin list, records the event half per
  target, stamps `Print`/`Printf`, and its AceTimer/AceConsole are real, with cancellable timers on
  `M.__timers` and `AceConsole.commands`.
- **Evidence.** `docs/api/testkit/version-17-docs.md:38-49` (the table), `:347-356` (PanelMaster's
  own migration list); `tests/_kit/mock_base.lua:854-878` (`NewAddon`), `:435-516` (AceTimer),
  `:534-595` (AceConsole), `:600-647` (AceEvent, `M.__badEvents` on the first registrant).
- **Touches.** `tests/wow_mock.lua` (retire the local `AceAddon-3.0`, the local `__fireTimers`, the
  `__chatCommands` recorder), `tests/test_panel.lua:60`, `tests/test_slash.lua:22-23`,
  `tests/test_harness.lua` (a new case).
- **Recommendation: adopt, option 1** (the orchestrator's pre-made decision).
- **Blast radius.** Replaces a harness block several suites depend on. No shipped file.

## Class C — whole-module adoption

None. No major was added, and the one unconsumed major, Perf, is a **settled** decline (#31; the
`performance-§1` row, 2026-08-25). Nothing in v1.31.0 changes its premise.
