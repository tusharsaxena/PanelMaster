# Module map

Every non-vendored file, what it publishes, what it is responsible for, and the load order the TOC
pins. Vendored libraries under `libs/` are consumed, never maintained here.

Load order is fixed by the TOC (`layout`); `core/Compat.lua` is first, `settings/` last.

| File | Publishes | Role |
|---|---|---|
| `core/Compat.lua` | `NS.Compat` | The only caller of deprecated / varying APIs. Addon roster, screen size, UI scale, LibSharedMedia registration and lookup, combat state, cursor test. **Class color is no longer here**: `LibKa0s-Core-1.0` minor 7 owns that lookup for the whole collection (`options-ui-§17`), reached through `Util.ResolveColor`. |
| `core/EnvSetup.lua` | `NS.Meta`, `NS.Version` | The `LibKa0s-Env-1.0` seam: this addon's TOC-metadata reader, which used to head `core/Compat.lua`. Both helpers write their pre-library ladder out as the fallback, so an install without LibKa0s still reads its own TOC. `NS.Version` prefers the TOC over `NS.version` and reads it at CALL time rather than capturing it as an upvalue, because `core/Namespace.lua` publishes it and loads later. Nothing here resolves at load beyond the LibStub lookup, so **this file's TOC position is conventional, not load-bearing** — unlike `core/MediaSetup.lua`'s. `tests/test_envsetup.lua` pins that the seam changes no answer. |
| `core/MediaSetup.lua` | `NS.Icon`, `NS.MediaFont` | The `LibKa0s-Media-1.0` seam: the collection's shared icon set and its monospace face, both of which arrive inside the vendored payload rather than in this addon's `media/`. Two one-line lookups plus `Media.RegisterLSM(addonName)` at file load, which is what puts `JetBrains Mono` and the seven `Ka0s …` bar textures into LibSharedMedia's dropdowns. The library is vendored and cannot know which folder it was copied into, so every call carries `addonName` — the FOLDER name, this file's first vararg, never the `## Title` and never a frame-name prefix. **Loads before `core/Constants.lua`**, which resolves `C.FONT_MONO` from `NS.MediaFont` at load. Both seams answer **nil** with no library, which is a value callers branch on: `C.FONT_MONO` falls back to the client's own `STANDARD_TEXT_FONT`, and the console's title bar falls back to the library's own words. |
| `core/Constants.lua` | `NS.Constants` | Strata, anchor-point, edge and artwork enums (with their derived membership sets and option lists), geometry and scale bounds, the frame ladder, the panel record template, the field type/order/media/enum/color maps, the legacy preview marker the load sweep reads, media paths. |
| `core/Namespace.lua` | `NS.name/version/PREFIX/SCHEMA_VERSION` | Metadata bootstrap. The cyan `[PM]` chat tag lives here. |
| `core/State.lua` | `NS.State` | Session-only runtime state: `debug`, `unlocked`, `unlockedPanels`, `rejectedEvents`. Never persisted. `rejectedEvents` is the list of event names the client refused this session, each recorded once: every registration path appends to it through `NS.SafeRegisterEvent`, and `/pm debug dump` prints it (`events-frames-taint-§1`). Everything here keyed by panel id is dropped by `Registry:ReloadProfile`, because ids are allocated per profile. |
| `core/Util.lua` | `NS.Util` | Path splitting, clamping, rounding, snapping, boolean and color parse/format, name cleaning, deep copy. The secret-safe shared chat printer left this file for `core/CoreSetup.lua`. |
| `core/CoreSetup.lua` | `NS.Core`, `NS.Print`, `NS.Util.print`, `NS.SafeToString`, `NS.IsConcatSafe`, `NS.MakeCloseButton`, `NS.SafeRegisterEvent`, **`NS.LIBKA0S_MISSING`** | The `LibKa0s-Core-1.0` seam: the secret-safe stringifier and the prefixed chat printer, republished under the names this addon has always used. Also publishes **`NS.LIBKA0S_MISSING`**, the one cause clause every other LibKa0s seam appends its own consequence to — a cross-file contract three other files depend on — `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua` and `settings/Slash.lua`, each building its own `UNAVAILABLE` string from it — not an implementation detail of this one, and set OUTSIDE the missing-library branch because they read it on both paths. `NS.SafeRegisterEvent` is the one path every game-event registration takes (`events-frames-taint-§1`): a refused name is appended once to the caller's list and costs only itself. With no library it degrades to a single `pcall` rung that keeps the same record-once rule. Its siblings `SafeRegisterUnitEvent` and `SafeRegisterEvents` are **not re-exported**, because PanelMaster registers no unit events and no event arrays. Core's skin half (`SKIN`, `ApplySkin`) is declined: the only standalone window here is the debug console, which the DebugLog major draws. `MakeCloseButton` is **wrapped** rather than declined or republished — the wrapper's whole purpose is its third argument, `addonName`, without which the library cannot build a texture path and falls back to a multiplication sign. |
| `core/BusSetup.lua` | `NS.BusLib` | The `LibKa0s-Bus-1.0` seam, **`Catalog` only**. `modules/Registry.lua` and `settings/Schema.lua` declare their three messages through the dot-called `NS.BusLib.Catalog(addonName, { KEY = wire name })`, which validates the declaration at load and answers a **strict** table: reading an undeclared key raises at the read (`no bus message named …`), so a publisher's mistyped constant can no longer send `nil` in silence. The record half (`Bus:New`, tracked targets) is **not** adopted — `NS.NewBusTarget` in `core/PanelMaster.lua` stays the receiver factory. With no library, `Catalog` answers the host's own table unchanged: the same wire names, without the strictness. **Loads before `modules/Registry.lua` and `settings/Schema.lua`**, which build their catalogs at file load; `tests/test_surface_parity.lua` pins the stub against the library table. |
| `core/DebugLogSetup.lua` | `NS.DebugLog`, `NS.Debug`, `NS.DebugBuild` | The `LibKa0s-DebugLog-1.0` seam, replacing the 429-line `modules/DebugLog.lua`. The console window, both formatters, the buffer and the enable seam are the library's; what stays this addon's is `NS.DebugBuild` (the same gated sink for a site whose arguments cost something to produce — its builder must be a plain function reference with its arguments passed unbound, since a closure would be allocated at the call site, before the gate, which is the cost being avoided) and `D:Diagnose()` (the structured dump verb, which reports what *this* addon believes is on screen). `NS.Debug` carries the addon's **only** debug gate (`debug-logging-§4`). |
| `core/LifecycleSetup.lua` | `NS.Lifecycle`, `NS.StandDown`, `NS.StandUp`, `NS.IsAddonEnabled`, `NS.RefreshEnabled`, `NS.HOLD_DISABLED`, `NS.HOLD_PERF` | The `LibKa0s-Lifecycle-1.0` seam: the **stand-down latch** (`slash-commands-§7`). One instance, two named holds — `disabled`, taken from `settings.enabled`, and `perf`, which nothing takes here because this addon declines `Perf`. The addon is down whenever at least one hold is taken and up only when the last is released, so releasing one cannot resurrect an addon the other still holds down. `NS.StandDown` unregisters the renderer's three bus subscriptions and the three game events, and the show ladder does the rest: `Canvas:Render` reads `NS.Lifecycle:IsDown()` and `SetMouseoverTracked` drops the 10Hz `OnUpdate` as the tracked set empties. `NS.StandUp` rebuilds **from current state**, never from a snapshot. Degrades to a six-line hold set of its own rather than to a no-op, because a latch stub that does nothing costs the stand-down itself; `tests/test_surface_parity.lua` compares the two member sets. |
| `core/PanelMaster.lua` | `NS.addon`, `NS.bus` | AceAddon registration, the printer reclaim, the bus-target factory, `OnInitialize` / `OnEnable`. `OnEnable` registers nothing itself: it sets the `disabled` hold from the stored path and stands the addon up only if nothing is holding it down, so a disabled addon never registers in the first place. |
| `core/Database.lua` | `NS:InitDB`, `NS:RunMigrations`, `NS:SweepPreviewPanels` | AceDB open on the shared "Default" profile, the migration seam, the sweep of sample panels an older build's test mode left behind, the profile-change callbacks, the `[Init]` summary. `NS:RunMigrations` and `NS:SweepPreviewPanels` are the panel registry's `architecture-§5` **load pass**: the migrations are called only from `NS:InitDB`, the sweep only from `NS:InitDB` and the profile callbacks. |
| `core/LauncherSetup.lua` | `NS.Launcher` | The `LibKa0s-Launcher-1.0` seam (`launcher-§1`): **one** LibDataBroker object, registered twice — with LibDBIcon for the minimap button, and to any broker display the player runs. Both surfaces dispatch into one `OnClick`, so `launcher-§2`'s rung rule is satisfied on both by construction rather than by two implementations agreeing. This addon is on **rung (b)**, which the standard's `ADDONS.md` records: left-click toggles the lock, because unlocking IS this addon's preview and there is no test mode. It writes `state.locked` through `NS.Schema:Set` — the same seam the *Lock frame* checkbox writes through — and never holds a copy of that state. Right-click always opens the settings panel. Hovering shows the library-drawn status tooltip (Launcher minor 3): the descriptor passes `version`, `isEnabled` / `disabledLine` (which also make the library's gate the one disabled refusal), `isLocked` and `leftClickLabel`, and no `isTestMode` or `onTooltipShow`. `minimap` is passed as a **function**, not a table: `db.global.minimap` does not exist at file load and a table captured then is one AceDB later replaces. Degrades three ways, all silent and none fatal: no LibKa0s (a stub answering every member), no LibDataBroker (no object at all), no LibDBIcon (the broker plugin without the button). |
| `defaults/Profile.lua` | `NS.defaults.profile` | Profile defaults, on the shared "Default" profile: the (empty) panel registry, `nextID`, and the settings block. |
| `defaults/Global.lua` | `NS.defaults.global` | Account-wide defaults: `schemaVersion = 0`, the migration runner's floor (the runner writes the real stamp), and LibDBIcon's own `minimap` table. |
| `locales/enUS.lua` | `NS.L` | The canonical locale table and its key-is-the-string fallback. Carries one key, the collection's library-absent line that `Sl:LibraryAbsentLine` formats — see **Localization**. |
| `locales/PostLoad.lua` | — | Derived-key aliases, loaded after every locale file so it reads whatever the active locale resolved. Empty in 1.0.0. |
| `modules/Registry.lua` | `NS.Registry` | **Owns `db.profile.panels`**, and is its `architecture-§5` **registry writer**: the only writer of membership, `nextID`, `id` and `frameName` outside the load pass. Create, delete, rename, reset, copy-from, field edits, sanitizing, name and frame-name uniqueness (the latter on create only — see *Frame names and the pool*), off-screen recovery, profile reload. Sole sender of both panel messages. |
| `modules/Artwork.lua` | `NS.Artwork` | The bundled-art catalog and the pure `BuildArtSpec` geometry — fill math, UV crop/flip/rotation composition, tint resolution. Touches no frames and calls no WoW API. Loads **before** `Canvas`, which reads it. |
| `modules/SunnArtPacks.lua` | `NS.SunnArtPacks` | The known-pack manifest: what the official Sunn packs contain, keyed by theme path, with **measured** section dimensions. Pure data, generated by `tools/sunn/build_manifest.py`. Loads **before** `SunnArt`, which reads it. |
| `modules/SunnArt.lua` | `NS.SunnArt` | The adapter for user-installed **Sunn - Viewport Art** packs. Reads another addon's globals, synthesizes one composed whole-bar catalog row per theme and appends them to `Artwork.Catalog` at `OnEnable`. Discovery only — it draws nothing and ships no pack bytes. |
| `modules/Canvas.lua` | `NS.Canvas` | Turns records into frames. The pure `BuildSpec`, the name-keyed frame pool, the background, border, accent and artwork child frames (the last clipping and re-leveled per render), the four accent bars and their lazy borders, the shared mouseover ticker, targeted and full repaints. |
| `modules/Unlock.lua` | `NS.Unlock` | Unlock mode (outline, label, drag, snap), global and per-panel. It is also this addon's test mode (`options-ui-§15`), so Lock frame is its switch and there is no separate preview. |
| `settings/Schema.lua` | `NS.Schema`, `NS.SchemaRuntime`, `NS.SchemaLib` | The settings schema (one row per setting), and the `LibKa0s-Schema-1.0` seam behind it. Sole sender of `SettingsChanged`. `NS.SchemaRuntime` is the library instance (the path walk, the row index, the single write seam, the bulk bracket, the boot shape check); `NS.Schema:Set`, `:Get`, `:FindRow`, `:Default`, `:Register`, `S.BulkBegin` / `S.BulkEnd` / `S.BulkLine` keep their names and delegate to it. Degrades to `hostSchemaStub`, a write-completing, log-silent stand-in for both the library and the instance, so host writers keep writing on a load without the payload. |
| `settings/Slash.lua` | `NS.Slash`, `NS.COMMANDS` | The `LibKa0s-Slash-1.0` seam plus everything the library does not own. The dispatcher, the generated help index, the landing-page row formatter, the schema CLI (`list`/`get`/`set`/`reset`/`resetall`/`version`) and the type-aware value parser are the library's. **`NS.COMMANDS` stays this addon's** — positional `{ name, description, handler }` triples, passed in rather than owned, because the settings landing page renders the same rows and a library that owned the table would force the options major to resolve the slash major to read it. Every PANEL verb stays too: they act on registry records, not schema rows. Two descriptor adapters: `groupKey` (this schema groups by `row.group`, the library defaults to `row.page`) and `parse` (the library matches an enum case-sensitively; this adapter matches the row's own `values` in any case and passes the stored spelling, so `/pm set settings.defaultStrata low` stores `LOW` and `settings.visibility` takes `incombat` as `inCombat`). |
| `settings/PanelEditor.lua` | `NS.PanelEditor`, `E.TABS` | The Panels page's body: the create box, the panel selector, the editor's **six-tab strip** and the section builder behind each tab, the page's mutation actions and its two bus triggers. The page is bespoke — a panel is a registry record, not a schema row — so the strip is drawn straight onto the chrome band with `H.TabStrip` (`options-ui-§13`) and dispatched on `ctx.activeTab`, rather than partitioned by `H.RenderTabbedSchema`. **The acts that apply to the panel whole are the `General` first tab**: renaming, copying another panel's look, Enabled, Unlock, Reset and Delete sit there rather than under a subject tab, which `options-ui-§14` (standard v2.40.0) allows because it is the tab the page opens on. The chrome band above the strip is bounded at **one row** — the **Panel** picker and the **Create new panel** box — and those two stay put on every tab. Peeled out of `settings/Panel.lua` (`layout-§1`) and drawn with that file's helpers, which it reads from `NS.Panel.__ui`. |
| `settings/OptionsSetup.lua` | `NS.Helpers`, `NS.SetBuildMain` | The `LibKa0s-Options-1.0` seam. `NS.Helpers` **is** the library instance rather than a wrapper (options-ui-§1), which is what lets `settings/Panel.lua` decorate it in place. Holds the descriptor: the write seam (the `LibKa0s-Schema-1.0` instance's own `Get` / `Set` / `ApplyDefault` / `AllRows` and bracket pair, handed over as values), `rowsForPage`, the boot validation, the AceGUI stash and the drag throttle. `buildMain` reaches the landing page through a forward declaration `settings/Panel.lua` fills in, because that file loads after this one. |
| `settings/Panel.lua` | `NS.Panel` | What LibKa0s-Options-1.0 does **not** own: the open-dropdown registry that closes a list on scroll, the paired-button width, the landing page's body, the Profiles page, and the four page builders. The canvas factory, the header and breadcrumb, the lazy Defaults button, the scroll frame, the scrollbar patch, section headings, spacers, tooltips, the five widget makers, the two-column flow engine and the **tab strip** are all the library's now. The General page draws itself with one `H.RenderTabbedSchema` call, whose `afterGroup` hook hangs the **Recover panels** button under the Editing tab. Two library members are wrapped **on the instance** — `RenderField` and `EnsureScroll` — because the flow engine resolves both from the instance table at call time, so a host-side helper beside them is bypassed by every page it draws. Drives the editor through `E:WireBus` / `E:BuildPage` / `E:Rebuild`. |

Ten of the fifteen `LibKa0s` majors are adopted (`Core`, `Env`, `Media`, `DebugLog`, `Slash`,
`Options`, `Launcher`, `Lifecycle`, `Schema`, and `Bus` for its `Catalog` alone,
[#52](https://github.com/tusharsaxena/PanelMaster/issues/52)); `Pool`, `Item` and `Widgets` are
vendored but not consumed here, nor is `Compat` (no member fits, closed issue
[#53](https://github.com/tusharsaxena/PanelMaster/issues/53)), and
`Perf` is declined on structural grounds — see closed issue [`LIBKA0S-31`](https://github.com/tusharsaxena/PanelMaster/issues/31). The
library is vendored whole-folder into `libs/LibKa0s/` and is **never edited here**: a library
problem is fixed in `../LibKa0s` and re-vendored back, because the next re-vendor silently reverts a
local edit and the revert reads as a regression with no cause anywhere in this repo's history.

**`NS.LIBKA0S_MISSING` is a cross-file contract, not an implementation detail.** `core/CoreSetup.lua`
publishes it — *outside* its own missing-library branch, because the later seams read it on **both**
paths — and each of the other three appends its own consequence and its own terminal punctuation:

| Seam | Appends |
|---|---|
| `core/CoreSetup.lua` | `"; running on reduced built-in fallbacks."` — announced once, on the first line the addon prints |
| `core/DebugLogSetup.lua` | `", so the debug console window is unavailable."` |
| `settings/Slash.lua` | `", so the settings CLI (list/get/set/reset) is unavailable."` — the degraded `/pm help` prints it once above a plain `/pm <cmd>  <desc>` row per verb |
| `settings/OptionsSetup.lua` | `", so the settings panel is unavailable."` — said on **every** `/pm config`, never latched |

A degraded install therefore says the same thing about **why** at every site and a different thing
about **what** at each one. The latching differs on purpose, and the rule is what the line rides:
the Core and DebugLog notices ride other output, where repeating would drown the line the user
asked for, so they are once per session; `/pm config`'s line rides nothing — it *is* the answer to a
verb the user invoked — so latching it would make the second invocation read as a broken command. The wording is the whole Ka0s collection's and is not this addon's to
reword — `tests/test_libka0s.lua` pins the clause on both paths.

The TOC order is not arbitrary. Each seam's own header states its constraints; the ones that bind:

- `libs\LibKa0s\LibKa0s.xml` sits **after** LibStub and Ace3. `Core` resolves LibStub; the other
  fourteen resolve `LibKa0s-Core-1.0` and `return` **before** `LibStub:NewLibrary` when it is absent or
  too old, so the major is simply never registered.
- `core/CoreSetup.lua` after `core/Namespace.lua` (which defines `NS.PREFIX`, passed to the printer
  descriptor verbatim) and after `core/Util.lua` (which owns `NS.Util`), and **before**
  `core/PanelMaster.lua`, whose AceConsole embed clobbers `NS.Print` and reclaims it from
  `NS.Util.print`. Publishing on both keys is what keeps that reclaim load-bearing and correct.
  It must also precede the five files taking the printer as a `local print = NS.Print` **file-scope
  upvalue** — `modules/Unlock.lua`, `settings/Schema.lua`, `settings/Slash.lua`,
  `settings/PanelEditor.lua`, `settings/Panel.lua` — or the swap silently no-ops while appearing to
  work.
- `core/MediaSetup.lua` **before** `core/Constants.lua`. `C.FONT_MONO` is resolved from
  `NS.MediaFont` at file load, so a seam published later would leave the constant holding
  `STANDARD_TEXT_FONT` forever — on a working install, with the payload present. It needs nothing
  but its own `addonName` vararg and LibStub, so nothing else constrains where it sits.
- `core/BusSetup.lua` **before** `modules/Registry.lua` and `settings/Schema.lua`, both of which call
  `NS.BusLib.Catalog` at file load. It needs nothing but LibStub; it sits right after
  `core/CoreSetup.lua` by convention. `tests/test_harness.lua` pins the order.
- `core/DebugLogSetup.lua` after `core/Constants.lua` (`C.FONT_MONO`) and `core/CoreSetup.lua`.
  Everything else its descriptor touches is reached through a **closure**, which is what let the
  console move out of `modules/` into `core/` without inverting a dependency.
- `core/LauncherSetup.lua` after `core/Constants.lua`, for `C.ICON_PATH`, which its descriptor
  reads at file load. Everything else it touches — `NS.db`, `NS.Schema`, `NS.Panel` — is reached
  through a **closure**, so the rest of its position is conventional. What actually binds is on the
  other side: `NS.Launcher:Register()` is called from `addon:OnInitialize` **after** `NS:InitDB()`,
  because that is the first moment `db.global.minimap` exists for the closure to answer with.
- `core/LifecycleSetup.lua` after `core/DebugLogSetup.lua`, for `NS.Debug`, which `NS.StandDown` and
  `NS.StandUp` both trace through. Everything else it touches — `NS.db`, `NS.Schema`, `NS.Canvas`,
  `NS.addon` — is reached through a **closure**, so the rest of its position is conventional and
  nothing calls the latch before `addon:OnEnable`.
- `settings/OptionsSetup.lua` after `settings/Schema.lua` and `settings/Slash.lua`, and **before**
  `settings/Panel.lua`, which captures the instance at file scope. `settings/PanelEditor.lua` binds
  its helpers lazily inside its own rebuild, so it pins nothing.

`tests/test_harness.lua` derives the suite's load list from the TOC rather than keeping a second
copy, so a file added to one and not the other cannot go untested.

## tests/

The headless harness (`docs/testing.md`). `tests/_kit/` is the shared kit, vendored from LibKa0s
beside `libs/LibKa0s/` and never edited here, so it is not listed. Case counts live in the generated
`docs/test-cases.md`, not here.

| File | Role |
|---|---|
| `tests/run.lua` | The runner. Loads every source in TOC order, calls the real `OnInitialize` / `OnEnable`, exposes `_G.PM_TEST`, runs every suite; `--list` writes `docs/test-cases.md`. |
| `tests/wow_mock.lua` | The WoW-API mock: an extender over `tests/_kit/mock_base.lua`, overriding only what is this addon's own. |
| `tests/degraded_env.lua` | Not a suite. Builds a whole environment from a partial LibKa0s file list, for the degraded arms of `test_disabled.lua`, `test_launcher.lua`, `test_libka0s.lua`, `test_schema.lua` and `test_surface_parity.lua`. |
| `tests/prose_waivers.lua` | Not a suite. The per-file, per-word waivers the kit's US-English prose gate reads. |

The suites, one per subject:

| Suite | Covers |
|---|---|
| `tests/test_accent.lua` | The accent bars: default look, per-edge geometry, their borders, and how `Canvas` builds them. |
| `tests/test_artwork.lua` | The artwork catalog, `Artwork.BuildArtSpec` and composites, and the artwork child frame. |
| `tests/test_canvas.lua` | `Canvas.BuildSpec`, `Canvas.Render`, the frame pool, the bus repaints and combat visibility. |
| `tests/test_compat.lua` | The `core/Compat.lua` shims: screen size, UI scale, media registration and lookup, cursor test. |
| `tests/test_constants.lua` | The enums, bounds and templates in `core/Constants.lua`. |
| `tests/test_database.lua` | `InitDB`, the migration runner, the preview-panel sweep and the `[Init]` summary. |
| `tests/test_debuglog.lua` | The DebugLog seam: formatters, the `NS.Debug` gate, `NS.DebugBuild`, bulk logging. |
| `tests/test_disabled.lua` | The stand-down latch (a disabled addon unregisters, draws nothing, and stands back up from current state) and `NS.SafeRegisterEvent`'s rejected-event record. |
| `tests/test_docs.lua` | `docs/smoke-tests.md` still carries its non-English-client section. |
| `tests/test_envsetup.lua` | The Env seam: `NS.Meta` / `NS.Version` answer what the deleted shim answered. |
| `tests/test_harness.lua` | The harness itself: suite inventory, TOC-derived load order, load-order pins. |
| `tests/test_launcher.lua` | The Launcher seam: the broker object, both click rungs, the status tooltip (enabled and disabled), the minimap row, the degraded install. |
| `tests/test_libka0s.lua` | Every seam against the live library, the shared cause clause, and the degraded install. |
| `tests/test_lintconfig.lua` | The no-blanket-suppression gate over `.luacheckrc`. |
| `tests/test_media.lua` | Media on the canvas: background and border textures, `Registry.Reset`, `Util.Slugify`. |
| `tests/test_mediasetup.lua` | The Media seam: `NS.Icon`, `NS.MediaFont`, LibSharedMedia registration. |
| `tests/test_options_groups.lua` | The `options-ui-§16` gate over the Panels page's composed blocks. |
| `tests/test_panel.lua` | The settings pages: registration, opening, the Panels page's band, strip and editor. |
| `tests/test_profiles.lua` | `Registry.CopyFrom`, profile switching, and the Profiles page. |
| `tests/test_register.lua` | Every deviation id `docs/ARCHITECTURE.md` cites resolves to an audit bundle. |
| `tests/test_registry.lua` | `Registry` create, set, rename, sanitize, recover and delete. |
| `tests/test_schema.lua` | The schema rows, the Schema seam and its stub, `Schema.Set`, the tab partition. |
| `tests/test_slash.lua` | The Slash seam, the schema CLI, every panel verb and the reserved enable/disable pair. |
| `tests/test_sunnart.lua` | The Sunn adapter: discovery, fallback manifest, fit. |
| `tests/test_surface_parity.lua` | Each degradation stub's member set against the live surface. |
| `tests/test_unlock.lua` | Unlock mode, global and per panel, and grid snapping. |
| `tests/test_util.lua` | `core/Util.lua`'s helpers. |
| `tests/test_vendor_sync.lua` | The vendored-payload gate over `libs/LibKa0s/` and `tests/_kit/`, registered from the kit's `vendor_sync.lua`. |

## tools/

Offline generators, run by hand and never loaded by the client. `update_catalog.py`,
`make_poster.py` and `artwork_cleaner.py`'s `.stamps.tsv` write through a `.tmp` file and
`os.replace`; `artwork_cleaner.py`'s TGAs and `build_manifest.py`'s `modules/SunnArtPacks.lua`
are written in place. `tools/artwork/bin/` (the upscaler) and `tools/artwork/fonts/` (the poster's
pinned faces) are vendored inputs, not tools.

| File | Writes |
|---|---|
| `tools/artwork/artwork_cleaner.py` | A transparent, square, power-of-two 32-bit TGA per source image (`--single` beside the source, `--batch` into a mirrored tree), plus the machine-local `tools/artwork/.stamps.tsv` rebuild record. |
| `tools/artwork/update_catalog.py` | The generated catalog in `modules/Artwork.lua`, from the tree under `media/artwork/` (`--check` writes nothing and fails on drift). |
| `tools/artwork/make_poster.py` | `media/poster/artwork-poster.png` and its `.txt` provenance record, from the same scan as the catalog. |
| `tools/sunn/build_manifest.py` | The generated block in `modules/SunnArtPacks.lua`, from an installed AddOns directory's Sunn packs. |
