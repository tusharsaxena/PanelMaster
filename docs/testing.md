# Testing — Ka0s Panel Master

How to verify the addon. This is the contributor-facing page; the player-facing `README.md`
deliberately carries none of it, only the `[tests]` badge.

## The green gate

Both of these must pass **before every commit**. A commit with red tests or lint errors is
forbidden, and a logic change without a covering test is not done.

```sh
lua tests/run.lua     # all suites green; exits non-zero on any failure
luacheck .            # 0 errors, 0 warnings
```

## Local toolchain

WoW runs Lua 5.1, so the harness targets 5.1.

```sh
sudo apt-get update && sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck
```

Syntax-check a single file with `luac -p path/to/file.lua`.

## How the harness works

```
tests/
  run.lua            -- the runner + micro-framework; also the --list inventory mode
  loader.lua         -- loads each source with loadfile + setfenv over the mock env
  wow_mock.lua       -- the WoW API mock builder (a fresh env per run)
  test_<module>.lua  -- one suite per module
```

- `run.lua` builds the addon environment once by loading every source **in TOC order**, then calls
  `NS.addon:OnInitialize()` and `NS.addon:OnEnable()` — the addon's **real** lifecycle entry points.
  It exposes `NS`, the mocks and the assertion helpers to the suites through `_G.PM_TEST`, runs each
  case under `pcall`, and exits non-zero on any failure.

  **Never reproduce the lifecycle by hand here.** An earlier version of this harness listed the setup
  steps itself (`InitDB`, `Schema:Register`, `Slash:Register`, `Panel:Register`, `Canvas:Enable`),
  and because it called `Canvas:Enable()` directly, every bus test passed against wiring `OnEnable`
  did not actually do. In-game the result was that nothing was live: no settings change or panel edit
  reached the renderer, and only the two paths calling `Canvas:RenderAll()` directly (lock/unlock and
  test mode) repainted anything. Calling the real functions means a step dropped from either entry
  point fails the suite instead of hiding in it.
- `loader.lua` reproduces the `local addonName, NS = ...` header by calling each chunk as
  `chunk("PanelMaster", NS)` under an environment where WoW globals resolve to the mock table first
  and fall back to real `_G`.
- `wow_mock.lua` stubs time, combat, metadata and UI APIs plus a universal frame.

### Mock fidelity that is load-bearing

Do not "simplify" any of these — each exists because a lazier stub hides a whole bug class:

- **The frame stub models visibility, geometry, color and scripts.** A blanket self-returning no-op
  would make `IsShown()` permanently truthy and `GetPoint()` hand back the frame, so "we applied the
  stored position" and "we applied garbage" would look identical. Position and size *are* the product
  here, so they have to be real state. Scripts are recorded rather than dropped so the drag handler
  can actually be fired.
- **It also records the frame NAME, the backdrop and the applied textures/colors.** The name is this
  addon's public anchor contract (`PanelMaster_Panel_<slug>`), and a stub that dropped `CreateFrame`'s
  name argument would make it untestable. `SetBackdrop` / `SetBackdropBorderColor` /
  `SetColorTexture` / `SetVertexColor` are kept because "which edge texture, at what thickness, in
  what color" is exactly what the border and class-color suites assert on — and because the border
  color is only correct if it is applied *after* the backdrop, which is unprovable against a no-op.
- **Child regions are fresh stubs, not the parent.** A texture that *was* the frame would make all
  four border edges share one color slot.
- **`SetTexCoord` keeps the eight-argument form verbatim, and the artwork extras are recorded too** —
  the blend mode, `SetTexture`'s wrap arguments and `SetClipsChildren`. The coordinate list is the
  whole output of the artwork crop/flip/rotation math, so a stub that collapsed it to four numbers
  would make every fill type unprovable. The wrap arguments are the one part of a tiled spec the
  renderer cannot infer from the numbers, and the blend mode is asserted precisely *because* it is
  no longer a setting: the artwork texture is pooled, so a mode set on one panel would otherwise
  leak into the next panel that reuses the frame.
- **`UIParent` carries a real 1920×1080 size.** A 0×0 screen makes `Compat.GetScreenSize` return nil
  and silently skips every off-screen-recovery test.
- **The AceAddon mock stamps AceConsole's colliding `:Print` mixin**, so the tests exercise the real
  printer-reclaim path (`architecture-§2`, anti-pattern #36).
- **The message bus keys callbacks by `(message, target)`** and fans `SendMessage` out to every
  target, so a test can catch two receivers clobbering each other on a shared target.
- **`Settings.RegisterCanvasLayout(Sub)category` keeps each frame it is handed** in
  `mocks.__settingsPanels`, so `test_panel.lua` can assert the `OnCommit` / `OnDefault` / `OnRefresh`
  contract on what the framework actually received (`options-ui-§1`).
- **AceDB's CALLBACK surface is modeled, not stubbed.** Switching profiles swaps `db.profile`
  wholesale, so `mocks.__switchProfile(name)` replaces the table and then fires `OnProfileChanged`
  exactly as AceDB does. Without that, "the previous profile's panels stayed on screen" — the actual
  failure mode — would be untestable. The mock also reproduces AceDB's own `defaultProfile` rule
  (`true` → the shared `"Default"`) and records what the addon asked for, since which profile every
  character lands on is a product decision a fixed-name stub would hide.
- **AceConfig / AceDBOptions / AceConfigDialog are present**, with `mocks.__profileOptions` recording
  what was registered. "We handed AceDB's own options table to the Profiles page" is that page's
  entire contract, and there is nothing else to assert about it headlessly.
- **LibSharedMedia is deliberately absent** from the mock library table. It is an `OptionalDep`, so
  the default headless environment is the one without it — which makes the soft-fallback path the
  tested path (`library-stack-§6`).

A suite reads:

```lua
local T = _G.PM_TEST
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual

test("Registry.New: creates a panel with the template's shape", function()
  assertEqual(NS.Registry:New("Chat BG").width, NS.Constants.PANEL_TEMPLATE.width)
end)
```

`assertNear` is available for the geometry and color maths, where an exact `==` would be a false
failure.

### Shared state

The suites share one addon environment, so any case that touches the registry starts by emptying it
(`R:DeleteAll()`, and `Canvas:RenderAll()` where frames matter). A case that inherits the previous
one's panels passes or fails depending on the order it ran in, which is the worst kind of flake.

## Writing tests

Test-first: write or extend a **failing** test that pins the intended behavior, then implement until
it passes. Pure, testable logic — the registry's CRUD and sanitizing, `Canvas.BuildSpec`, the snap
maths, off-screen recovery, schema read/write, the debug formatters and every slash output shape — is
exercised headlessly. Genuinely in-client behavior (how a panel actually looks, dragging with a real
mouse, strata against other addons' frames) belongs in [`smoke-tests.md`](smoke-tests.md), which
complements rather than replaces the unit suites.

A few suites assert against the **source files** rather than behavior — one sender per bus message,
no `WOW_PROJECT_ID` branching. Those rules only break when someone adds a line years later, which is
exactly when nobody is looking.

## The case inventory

[`test-cases.md`](test-cases.md) is the **generated**, authoritative enumeration of every case and
the addon's authoritative pass count. Never hand-edit it. Whenever a case is added, removed or
renamed — or the count moves — regenerate it and update the README's `[tests]` badge **in the same
change**:

```sh
lua tests/run.lua --list > docs/test-cases.md
```

There is no CI. This is deliberately local and hand-run.
