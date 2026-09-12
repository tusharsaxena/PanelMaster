# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.29.0..v1.30.0` (`7aaf1fe`, `aaef20a`, `e5f6906`,
`e369e0f`), the v1.30.0 block of the library's `CHANGELOG.md`, and
`docs/api/testkit/version-16-docs.md`. No `LibKa0s/` major moved, so there is no `Since` marker to
diff. All four items are kit-side.

## Class A — reached this addon on the re-vendor alone

| Item | Why it needs nothing here |
|---|---|
| **#27 `AceGUI:Release`** (+ `widget:Release`, raising on a double release) | This addon calls only `ReleaseChildren`, which the kit already modeled, and never `AceGUI:Release`. No suite reads `__released`. Delivered, not offered. |
| **#28 the runner-mode case** | `tests/test_vendor_sync.lua:43` is a bare `VendorSync.register(_G.PM_TEST, {})`, so the new case `the automated-test runner is recorded executable (100755)` registered itself and passes. The runner was already `100755`. This is the **+1** the library's changelog measured (783 → 784). |

## Class B — host change required

### B1. #29 — AceEvent's event half on an Embed target

- **What.** The kit's `AceEvent:Embed` now stamps `RegisterEvent` / `UnregisterEvent` /
  `UnregisterAllEvents`, recorded on `obj.__events` and validated as CallbackHandler validates.
- **Evidence.** Library `CHANGELOG.md`, v1.30.0, "AceEvent's event half on an embed (#29)";
  `tests/_kit/mock_base.lua:232-244` (`embedEvents`) and `:593-612` (the kit's Embed).
- **Why it does not arrive on its own.** `tests/wow_mock.lua:565-571` replaced the kit's Embed
  wholesale. Its event half was two `or function() end` no-ops with no `UnregisterAllEvents` and
  nothing recorded. The override itself has to stay, because it routes the bus through the local
  `msgRegistry`, exposed as `M.__msgRegistry`, which `tests/test_canvas.lua:298,307` read. The kit's
  bus registry is private.
- **Touches.** `tests/wow_mock.lua` only. No production file.
- **Recommendation: adopt.** Delete the two no-op lines and have the local Embed call the kit's Embed
  first, then lay `embedBus` over it. That gives the kit's contract without giving up the local
  message registry. No production code registers an event on a bus target today (`NS.NewBusTarget`,
  `core/PanelMaster.lua:20-26`, has two callers, `modules/Canvas.lua:854` and
  `settings/PanelEditor.lua:1380`, and both register messages only), so the validation cannot fire
  on a live path.
- **Blast radius.** Replaces harness code the addon owns, in one function. No shipped code.

### B2. #30 — `Printf` beside `Print` on the NewAddon target

- **What.** The kit's `NewAddon` stamps an AceConsole-shaped `Printf` beside `Print`, so an addon
  that forgets to reclaim `NS.Printf` fails headlessly.
- **Evidence.** Library `CHANGELOG.md`, v1.30.0, "`Printf` beside `Print` (#30)";
  `tests/_kit/mock_base.lua:570-578`.
- **Why it does not arrive.** `tests/wow_mock.lua:518-548` replaces the kit's `NewAddon` wholesale,
  so neither the kit's `Printf` nor its recorded event half reaches `NS.addon`. The local version
  exists for things the suites read: the mock-global `M.__events` (`tests/test_panel.lua:60`),
  `M.__chatCommands` (`tests/test_slash.lua:22-23`), the `M.__badEvents` raise, and cancellable
  timers (`M.__timers` / `M.__fireTimers`).
- **Exposure today: none.** This addon defines no `NS.Printf` (no `Printf` anywhere under `core/`,
  `modules/` or `settings/`), so there is nothing for the clobber to break. It reclaims `NS.Print` at
  `core/PanelMaster.lua:13`.
- **Recommendation: decline for now.** Getting the kit's `NewAddon` means migrating the harness: move
  `test_panel.lua:60` to `NS.addon.__events`, rebuild `__chatCommands`, `__badEvents` and the timer
  model as layers over the kit's target, and re-assert the Print-reclaim cases. That is a harness
  migration, and the orchestrator's standing answer declines those.
- **Blast radius.** Replaces a harness block that several suites depend on.

## Class C — whole-module adoption

None. No major was added, and the one unconsumed major, Perf, is a **settled** decline (#31; the
`performance-§1` row, 2026-08-25). Kit 16 does not change its premise.
