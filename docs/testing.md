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

**`luacheck`'s figure is SCOPED, not repo-wide**, and reading it as repo-wide is how a clean run
gets mistaken for a clean checkout. `.luacheckrc` excludes `libs/` (vendored code is not this
addon's to lint), `tests/`, `_dev/` and the frozen bundles under `docs/`. Before quoting 0/0,
confirm what was actually opened:

```sh
luacheck . 2>&1 | tail -1        # and read the FILE COUNT it reports
```

## The vendor gate

Neither gate above can see a stale vendored copy. `libs/LibKa0s/` and `tests/_kit/` are copied
whole-folder from the sibling `../LibKa0s` repo and are **never edited here** — but the library's
own suite passes against the library, and this addon's suite passes against a stale copy that still
works. Nothing goes red. Run these four whenever `../LibKa0s` has moved, and read them in pairs:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s    # content — MUST be empty
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                        # bytes   — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit      # content — MUST be empty
diff -r ../LibKa0s/testkit tests/_kit                          # bytes   — SHOULD be empty
```

| Result | What it means | What to do |
|---|---|---|
| Both empty | The vendored copies are exactly what the library ships. | Nothing. |
| Content empty, bytes differ | A **line-ending** divergence, not a code one. `../LibKa0s` pins `* text=auto eol=crlf`; this repo has no `.gitattributes` at all and its working tree is LF (see `LIBKA0S-09` in [`pending/LEDGER.md`](pending/LEDGER.md)). | Re-normalize whichever side drifted — `git add --renormalize .`. **Never** edit `libs/`, and note that re-vendoring will not converge it either: it just moves the wrong endings downstream. |
| Content differs | A real **fork** in a vendored folder, which is the forbidden state. | Re-vendor: `cp -r ../LibKa0s/LibKa0s/. libs/LibKa0s/`, whole-folder, never a file at a time. Four of the five majors resolve `LibKa0s-Core-1.0` before registering and refuse against an older minor than they name, so a partial copy silently loses whole modules. If the fork was a fix, it belongs upstream in `../LibKa0s` and comes back through a re-vendor. |

A fifth check answers "which LibKa0s is this?" without grepping minors out of source: `README.md`'s
`Bundles [LibKa0s] vX.Y.Z (MIT).` line, which moves with every re-vendor.

## The artwork gate

Two committed files are **generated from `media/artwork/`**: the catalog block in
`modules/Artwork.lua` and the contact sheet at `media/poster/artwork-poster.png`.
Neither gate above can see either one go stale. `luacheck` only walks Lua, and the harness derives
its load list from the TOC and cannot shell out to Python — so a piece added, renamed or deleted
without a regeneration leaves the suite green while the addon and its own README describe a set that
no longer exists. Run both whenever anything under `media/artwork/` has moved:

```sh
python3 tools/artwork/update_catalog.py --check   # exit 1 if modules/Artwork.lua is out of date
python3 tools/artwork/make_poster.py --check      # exit 1 if the poster is missing or out of date
```

**This is deliberately NOT part of the green gate**, on the precedent `testing-§7` sets for keeping
a benchmark suite outside it: the gate is Lua-only by design, and hooking a Python subprocess into
`tests/run.lua` to close this would buy staleness detection at the cost of the harness's one
dependency. It is written down here instead,
and the exposure is recorded as `ARTWORK-05` in [`pending/LEDGER.md`](pending/LEDGER.md).

The two fail differently, and the difference is the reason both are listed. A stale **catalog** is
loud — `tests/test_artwork.lua` asserts every row points at a file that exists, so a deletion goes
red on the next `lua tests/run.lua`. A stale **poster** is silent by construction: it is a PNG that
nothing loads, so it stays wrong indefinitely and only a reader notices.

`make_poster.py --check` compares the poster's **pixels**, not its bytes, so it does not go red
merely because your Pillow or zlib differs from whoever generated the committed file; when it does
go red it prints which toolchain component moved, read from `media/poster/artwork-poster.txt`. Two
things other than `media/artwork/` legitimately stale it: a **version bump**, since the poster is
stamped with the TOC's `## Version:`, and any edit to `make_poster.py`'s layout.

## The Sunn manifest

A third committed file is generated: the block in `modules/SunnArtPacks.lua`, which records what the
official Sunn - Viewport Art packs contain so the adapter survives SunnArt itself being disabled.

```sh
python3 tools/sunn/build_manifest.py --addons "/path/to/_retail_/Interface/AddOns"
python3 tools/sunn/build_manifest.py --addons "…" --check    # exit 1 if the manifest is stale
```

**This one cannot be checked on a clean clone at all**, which is what separates it from the artwork
gate above. `update_catalog.py` reads `media/artwork/`, which is in this repo; this reads *somebody's
WoW installation* with the packs installed, so `--check` is only meaningful on a machine that has
them and CI can never run it. Rerun it when a pack is updated or a new official pack appears.

The exposure is genuinely smaller than `ARTWORK-05`'s, and the reason is worth knowing before
worrying about it: a manifest row is consulted **only** when live registration is absent, live
registration overrides it per theme, and a row whose pack folder is not installed is never offered.
So a stale manifest costs a theme that draws nothing — never a wrong picture, and never a theme
offered to someone who does not have it. Recorded as `ARTWORK-10` in
[`pending/LEDGER.md`](pending/LEDGER.md).

The generator also warns, on stderr, when a pack's declared section count disagrees with the files
on disk, or when one theme's sections differ in size. Both are worth reading rather than ignoring —
they mean the pack changed shape — and neither is fatal: it trusts the files.

## Automated test records — the consolidated run

All four out-of-game suites go through one vendored runner, and every run is recorded
(`automated-tests`):

```sh
tests/_kit/run-automated-tests.sh                            # all four, writes a bundle
tests/_kit/run-automated-tests.sh --suite complexity          # a subset
tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle   # the green gate; writes nothing
```

| Suite | Command | Gates? |
|---|---|---|
| `lint` | `luacheck .` | **yes** |
| `tests` | `lua tests/run.lua` | **yes** |
| `perf` | `lua tests/perf.lua` | no — recorded only |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no — recorded only |

**`perf` and `complexity` never fail a run.** They are measured, recorded and diffed — a threshold
that fails a run teaches everyone to reach for `--no-verify`, after which the gate protects nothing
and the habit remains. They contribute `amber`, which is a signal rather than a stop. **A missing
tool is a skip recorded with its reason**, never a pass.

The runner is **vendored** from `LibKa0s`'s `testkit/`; never edit `tests/_kit/`. A kit fix goes
upstream and is re-vendored.

**At release, not at commit.** A full bundle is produced as part of every version bump, before the
tag, with an `ANALYSIS.md` write-up. Commits are gated on lint + tests only.

Results live in [`automated-tests/`](./automated-tests/): `RESULTS.md` is one row per run across all
four suites plus the current complexity watch list — **one file, overwritten in place**, so its git
history is the trend line — and each `<YYYYMMDD-HHMMSS>/` is a frozen bundle of that run's raw
output. Bundles are never edited and never pruned.

`docs/complexity.md` was this addon's standalone complexity report through standard v2.18.0; it is
**retired** — its raw output is each bundle's `complexity.txt` and its trend line is `RESULTS.md`.

## Local toolchain

WoW runs Lua 5.1, so the harness targets 5.1.

```sh
sudo apt-get update && sudo apt-get install -y lua5.1 luarocks
sudo luarocks install luacheck
```

Syntax-check a single file with `luac -p path/to/file.lua`.

Everything else this repo needs — `lizard`, `git`, and the Python side of the artwork and Sunn
pipelines with the vendored upscaler's system libraries — is in
[`../DEPENDENCIES.md`](../DEPENDENCIES.md), with an install command and a verification command for
each. That file answers *what to install*; this one answers *how to verify*.

## How the harness works

```
tests/
  _kit/              -- the SHARED kit, vendored from ../LibKa0s/testkit; never edited here
    framework.lua    -- the case registry, the assertions and the --list renderer
    loader.lua       -- loads each source with loadfile + setfenv over the mock env
    mock_base.lua    -- the base WoW/Ace mock every Ka0s addon starts from
  run.lua            -- a thin consumer of the kit; also the --list inventory mode
  wow_mock.lua       -- this addon's mock, EXTENDING _kit/mock_base.lua (a fresh env per run)
  test_<module>.lua  -- one suite per module
```

The registry, the assertions, the `--list` renderer and the source loader are **not this addon's** —
they are the shared kit under `tests/_kit/`, vendored whole-folder alongside `libs/LibKa0s/` and
covered by the same vendor gate and the same never-edit-it rule. `run.lua` is a thin consumer
(`Kit.expose` + `Kit.run`) that keeps no copy of either load order: the addon's own files come from
the TOC via `Loader.tocFiles`, and the vendored library's come from `libs/LibKa0s/LibKa0s.xml` via
`Loader.xmlFiles`, which is how a `libs\` line the TOC scan deliberately skips still gets loaded.
The library half **was** hand-listed here, and it was hand-listed short — six of the eight scripts
the XML pulls in — which nothing could see: a short load list does not raise, it leaves the missing
modules undefined for whichever cases never reach them.

`wow_mock.lua` **extends** `_kit/mock_base.lua` rather than replacing it. The base is the only source
of a `LibStub` with a real `NewLibrary` — without which no vendored LibKa0s major registers headlessly
— and of a fireable AceGUI, which is what makes the schema → widget → write path reachable at all.
The host overrides only what is genuinely its own, and that file's header states the reason for each
override one by one; the *Mock fidelity that is load-bearing* list below is the short form.

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
- `_kit/loader.lua` reproduces the `local addonName, NS = ...` header by calling each chunk as
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
