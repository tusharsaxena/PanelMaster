# Architecture — Ka0s Panel Master

Engineer context for the addon, and the **hub** of its doc set: each section below summarizes and
links, it does not store (`documentation-§3`).

Built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards). Read the
root [CLAUDE.md](../CLAUDE.md) first.

## Overview

A backdrop-panel creator, in the lineage of kgPanels and ElvUI's panels. The user creates named
rectangles with a color, a border, a size, a position and a layer, and the addon draws them behind the
rest of the UI. That is the whole product.

**It does not host anything.** A panel is scenery, not a container — which is why the addon needs no
secure frames, no combat gating on its render path, and no taint story. Full boundary in
**[scope.md](scope.md)**.

## Module Map

`core/` holds the bootstrap, the Compat firewall, the AceDB layer and eight of the eleven LibKa0s
seams; `modules/` holds the registry, the artwork catalog, the Sunn adapter, the canvas renderer
and unlock mode; `settings/` holds the schema, the other three seams and the four panel pages. Load
order is fixed by the TOC — `core/Compat.lua` first, `settings/` last — and the LibKa0s seams pin
several steps of it.

File-by-file table and the seam/load-order contract in **[module-map.md](module-map.md)**.

## Settings Schema

Two SavedVariables scopes: `defaults/Profile.lua` (the panel registry, `nextID`, the settings block;
profile-scoped) and `defaults/Global.lua` (`schemaVersion = 0` and LibDBIcon's `minimap` table).
`settings/Schema.lua` holds **22 rows in 4 tabs** — `Master controls` (7, composed), `Moving panels` (4),
`New panels` (4) and the Skin tab's seven `skin.*` rows (all `skipRender`, drawn by the library's
`O.AppearanceTab`; [§ Skins](#skins)) — on a `LibKa0s-Schema-1.0` runtime behind this addon's own seam names, and is the
sole sender of `SettingsChanged`. The same runtime also holds the **50 per-panel `panel.<field>`
rows** that `settings/PanelSchema.lua` generates (below); they are hidden from every profile
surface. `global.minimap.shown` is the one `db.global` row, and it inverts.

**The panel registry (`architecture-§5`).** The panel set is the addon's one structural registry:
the player creates and deletes panels at runtime, the defaults ship it empty, and no schema row
names a panel's existence.

- **Storage keys.** `db.profile.panels` is an array of records whose order is the array index, and
  `db.profile.nextID` is the monotonic id counter; each record's stamped `id` and `frameName` are
  its identity, and `name` is a unique label.
- **Writer.** `modules/Registry.lua` (`NS.Registry`) is the one registry writer: its local `create`,
  behind `New`, mints `rec.id` from `nextID`, stamps `frameName` and appends; its local
  `destroy`, behind `Delete`, and `DeleteAll` remove; `Rename` relabels
  `name` and leaves `id` and `frameName` alone; there is no duplicate or reorder operation.
- **Load pass.** `NS:RunMigrations` and `NS:SweepPreviewPanels`, both in `core/Database.lua`. The
  migration runner's v1 → v2 body backfills `frameName`, and it is called only from `NS:InitDB`.
  The sweep drops sample panels an older build's test mode left in a profile (the only use left of
  `C.PREVIEW_FIELD`), and it is called from `NS:InitDB`, right after the
  migrations, and from the `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` callbacks.
  Neither is called from a slash verb or a control.

Nothing else writes membership or bookkeeping, so membership carries no `Documented deviations`
row, and since PanelMaster#54 neither do the fields on a panel (below).
`/pm resetall` and Profiles → Reset Profile (`db:ResetProfile()`), and AceDB's own profile switch
and copy, replace the store wholesale, which is not a registry write; the load pass and
`NS.Registry:ReloadProfile` run after each of them. Each is logged once, by the profile handler in
`core/Database.lua` and worded by the event (`debug-logging-§10`; `docs/debug.md`).

**The fields on a panel are instance-addressed schema rows**
([#54](https://github.com/tusharsaxena/PanelMaster/issues/54)). `settings/PanelSchema.lua` generates
one `panel.<field>` row per `C.PANEL_FIELD_ORDER` field but `name`, and `S.ResolveRoot` maps the
write's instance id, the panel id, to that panel's record. `NS.Registry:Set`, `:SetPosition`
(which Unlock's drag-stop calls with the point it ended on) and every whole-record and bulk verb
(`:Reset`, `:CopyFrom`, `:FitToArtwork`, `:Recover`, `:ResetPositions`) write through
`SchemaRuntime.Set` / `SetMany` with that id. The rows validate and repair the value, the seam logs
`[Set] panel.<field> = <value> on '<name>'` once, and the Registry's `announce` sends
`PanelChanged` (one per act), or holds it back so a sweep sends one `PanelsChanged`. The rows carry
`hidden` and `skipRender`, and the Slash and Options descriptors read `S.ProfileRows` /
`S.FindProfileRow`, so `/pm list|get|set|reset`, the General page, the reset snapshot and the
diagnostics dump never see them. `name` and `frameName` are identity and have no row.

The schema runtime, its degradation stub, the Master controls composition, the panel record and
every field on it, and the instance rows, are in **[schema.md](schema.md#the-schema-runtime)**.

## Message Bus

Three messages, one sender each, consumers registering on their **own** AceEvent target via
`NS.NewBusTarget()`. CallbackHandler keys callbacks by `(message, target)`, so two consumers sharing
a target would silently clobber each other.

| Message | Sender | Meaning | Consumers |
|---|---|---|---|
| `Ka0s_PanelMaster_PanelsChanged` | `modules/Registry.lua` | The **set** changed (add / delete / rename) — rebuild everything. | `Canvas`, the Panels settings page |
| `Ka0s_PanelMaster_PanelChanged` | `modules/Registry.lua` | **One** panel's fields changed — repaint just it. | `Canvas` |
| `Ka0s_PanelMaster_SettingsChanged` | `settings/Schema.lua` | An addon-level setting changed **in a way a panel can show**. | `Canvas` |

The three wire names are declared **once each**, through `LibKa0s-Bus-1.0`'s `Catalog`
(`core/BusSetup.lua`): `NS.Registry.MSG` (`PANELS`, `PANEL`) and `NS.Schema.MSG` (`SETTINGS`). The
catalog validates the declaration at load and answers a **strict** table, so every reader —
senders and the `Canvas` / Panels-page receivers alike — reads `MSG.<KEY>` and a mistyped key raises
at the read instead of sending or subscribing to `nil`. Only `Catalog` is adopted; the receiver
factory stays `NS.NewBusTarget`. With no library the catalog is the plain table, with the same wire
names.

Not every row broadcasts: `settings.snapToGrid` and `settings.gridSize` carry no `onChange`, because
`Unlock.SnapPosition` reads them live at drag-stop and nothing renders from them. Announcing would
repaint every panel on each tick of the Grid size slider for no visible difference.

The split between the two panel messages is what lets a drag repaint one frame instead of all of
them. A test asserts that no other file sends any of the three.

`Canvas:Enable()`, which installs those subscriptions, is called from **`NS.StandUp`**
(`core/LifecycleSetup.lua`). `OnEnable` runs that stand-up whenever nothing holds the addon down. This is not
incidental: an early build omitted it, so every message broadcast into a bus with no listener and
nothing was live. The only repaints left were the two paths that call `Canvas:RenderAll()` directly
(lock/unlock and test mode), which is why panels appeared frozen until test mode was toggled. The
test harness hid it by calling `Canvas:Enable()` itself; it now drives the real `OnInitialize` /
`OnEnable`, so a dropped step fails the suite.

## Slash Commands

`/pm` (and the `/panelmaster` alias) via AceConsole. Every verb comes from `NS.COMMANDS` in
`settings/Slash.lua`, so the help index and the settings landing page's command list are generated
from one table and cannot drift. No hand-kept copy of the descriptions is carried anywhere: `slash-dispatch.md` names the verbs to
structure its own prose, and that is the only list of them outside the table.

Schema-driven verbs: `config version get set list reset resetall debug diagnostics enable disable help` — `resetall` is a
**profile reset** (`options-ui-§12`): confirm-gated, the same act as Profiles → Reset Profile, and it
takes the player's panels with it because `db.profile.panels` is in the profile. Profile verb:
`profile` — bare lists the profiles with the current one marked, `profile <name>` switches to an
**existing** profile (quotes stripped, case and inner spaces kept; an unknown name is refused with the
list, never created). The row is this addon's and the behavior is `LibKa0s-Slash-1.0`'s
`CliProfile` (minor 17), reached through the descriptor's `profiles` field; the switch lands in
AceDB's `SetProfile`, so the same `OnProfileChanged` handler a Profiles-page switch runs does the
rebuild and writes the one `[Profile]` line. Panel verbs: `new
delete rename panels panel unlock lock recover` — no `test` verb, because unlocking is this addon's
test mode (`options-ui-§15`). `enable` and `disable` are **aliases** onto `settings.enabled`, the
path the Master-controls checkbox writes, through the same write seam and holding no state of their
own (`slash-commands-§2`). While the addon is **disabled** the whole reserved surface still answers
— a bare `/pm` opens the settings panel, and the standard's thirteen reserved verbs (`help config
version enable disable debug perf diagnostics get set list reset resetall`, read from
`lib.LIVE_VERBS`) stay live, which standard v2.57.0 restored after v2.56.0 briefly narrowed it, and
so does `profile`, the one host verb this addon adds to its own live set so a player can switch to a
profile where the addon is enabled without opening the panel.
`perf` sits in that set as a **reservation**, not a command: this addon does not register it —
`NS.COMMANDS` (`settings/Slash.lua:381`) holds 21 verbs and `perf` is not among them — so the
twelve reserved verbs it does ship, `diagnostics` among them (`debug-logging-§14`), are the ones
that behave normally. The only
refusal is the addon's own **feature verbs**, on one tagged line naming `/pm enable`, and that gate is **the library's**:
`settings/Slash.lua` passes `isEnabled` and `brandName`, and a `liveVerbs` that is
`lib.LIVE_VERBS` plus `profile` and narrows nothing. Verb
detail and the host/library split in
**[slash-dispatch.md](slash-dispatch.md)**; what *disabled* actually means in
**[The disabled state](#the-disabled-state-is-total-slash-commands-7)** below.

## The launcher (`launcher-§1`)

**Owner: `core/LauncherSetup.lua`**, which publishes `NS.Launcher` — a `LibKa0s-Launcher-1.0`
instance. `NS.Launcher:Register()` is called once, from `addon:OnInitialize`, after `NS:InitDB()`.

It is **one** LibDataBroker-1.1 object of `type = "launcher"`, registered twice: with
LibDBIcon-1.0, which draws the minimap button, and under the same name for any broker display the
player runs (Titan Panel, ElvUI data texts, Bazooka), which draws its own row from that same object.
One `OnClick`, one icon, one label — so `launcher-§2`'s click rule holds on both surfaces by
construction rather than by two implementations agreeing. The name is the **folder** name,
`PanelMaster`, because LibDBIcon keys the button's saved position by it.

| Part | Where it lives | Note |
|---|---|---|
| The object and its clicks | `core/LauncherSetup.lua` → the library | `LibKa0s-Launcher-1.0` minor 4 (`launcher-§2`, standard v2.67.0) owns both buttons. **Left-click opens the settings panel**, in either state. **Right-click opens the options menu** — the client's context menu, titled `Ka0s Panel Master` — with the entries **Enabled · Locked** (the row the standard's `ADDONS.md` records): *Enabled* is `isEnabled` + `setEnabled` → `NS.Slash:CliEnable`, the body of `/pm enable` / `/pm disable`; *Locked* is `isLocked` + `toggleLock` → `NS.Slash:CliLock`, the body of `/pm lock` / `/pm unlock`, which writes `state.locked` through the same seam the *Lock frame* checkbox writes through. No *Test mode* (unlocking is this addon's preview; there is no test mode) and no *Show window* (no primary window). The descriptor holds no copy of either state. `tests/test_launcher.lua` drives the menu through `tests/mock_menu.lua`. |
| The status tooltip | `core/LauncherSetup.lua` → the library | Drawn by `LibKa0s-Launcher-1.0` (`launcher-§1`; minor 3, hints fixed at minor 4) on every hover, **disabled included**; the descriptor only answers it, read on every show: `version` (`NS.Version`, the TOC's `## Version`), `isEnabled` (the master switch, `NS.IsAddonEnabled`), `isLocked` (`state.locked`, the *Lock frame* row). The hints are the library's fixed `Left-click: Open settings` / `Right-click: Options menu`. No `isTestMode` (there is no test mode) and no `onTooltipShow` (nothing of its own to add). `tests/test_launcher.lua` pins every line through the object's `OnTooltipShow`. |
| The icon | `C.ICON_PATH` (`core/Constants.lua`) | `media/logos/panelmaster.logo.128.tga`, the same file the TOC's `## IconTexture` names (`launcher-§4`). `tests/test_constants.lua` asserts the two spellings name one file and reads its header bytes. |
| The broker label | `core/LauncherSetup.lua` | `Ka0s Panel Master` — the **brand name in plain text** (`launcher-§1`), which is what a broker display prints in its row beside the other ten Ka0s addons. Deliberately **not** the TOC `## Title` and not wired to it (a Title may carry color escapes, and one in the collection does), and not the folder name, which is the registration `name` above. A literal here, with no escape sequence of any kind. |
| The visibility row | `settings/Schema.lua` | *Minimap button*, composed by `MasterControls`' `minimapPath` — `/pm get global.minimap.shown`. Stored at `db.global.minimap.hide` — LibDBIcon's own table, handed to the library whole. `S:Get`/`S:Set` **negate**: the row says shown, the key says hidden. No `shown` key is ever stored. |
| The stored default | `defaults/Global.lua` | `minimap = { hide = false }`, **declared** rather than seeded, which is what materializes the table (`architecture-§5`). `minimapPos` is LibDBIcon's to write and has no row. |
| The libraries | `libs/LibDataBroker-1.1`, `libs/LibDBIcon-1.0` | Vendored and listed in the TOC's `# Libraries` block. Both are resolved with `LibStub(..., true)` at Register time, so a client missing either degrades by name and raises nothing. |

**The scope is global on purpose.** A minimap button belongs to the installation: a profile switch
must not move a player's buttons. This addon owes **no migration**: it has never stored a minimap
table anywhere, so nothing has to be carried out of `db.profile`.

**Surviving a reset is a property of the setting, not a consequence of that scope** (`launcher-§3`,
amended at standard v2.54.0). Whether the button is shown is a per-installation display preference,
in the same class as the position LibDBIcon keeps in the same table, so it must survive **both**
`options-ui-§12`'s *Reset all settings* **and** a page-scoped **Defaults** button. Read against this
code, neither reaches it, and the two reasons are different:

| Reset | Reaches `global.minimap.shown` (stored at `db.global.minimap.hide`)? | Why |
|---|---|---|
| *Reset all settings* — `/pm resetall`, the header **Defaults** button, the composed *Reset all settings* button | no | All three funnel into `Sl:DoResetAll`, which is `db:ResetProfile()` on the active profile. This addon **has** a profile and keeps everything the player configures in it, so the store AceDB replaces is `db.profile`; `db.global` is a different table. |
| The General page's **Defaults** button, and the Blizzard footer control that forwards to it | no | It is **not** the library's row walk here. `settings/Panel.lua` rebinds `ctx.panel.defaultsOnClick` to `P:RestoreDefaults`, which is the same profile reset, and `O.CreatePanel`'s `OnDefault` forwards to that same closure. `O.RestoreDefaults` *would* reach the row — `rowsForPage("general")` answers the whole schema and the composed row is spliced at its head — but nothing in this addon calls it. |

No exemption is owed and none is invented. `tests/test_launcher.lua` drives **both** controls for
real against a hidden button and asserts it is still hidden, so dropping the `defaultsOnClick`
rebinding turns the suite red instead of quietly un-hiding buttons.

## Event Subscriptions

| Event | Handler | Why |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `Canvas:RenderAll()`, then `NS.ArmSkinPicker()` | Panels are drawn here, not at `OnEnable`: every panel is anchored to `UIParent`, and `UIParent`'s final size and the frame anchors are settled by this event, not that early. (Off-screen recovery is on demand only, `/pm recover`.) The first-run skin picker's login start is armed here, once per session, two seconds in (`core/SkinSetup.lua`). |
| `PLAYER_REGEN_ENABLED` | `Unlock:ResumePending()`, then `Canvas:RenderForCombat(false)` | Replays a combat-deferred unlock, and repaints if `settings.visibility` is one of the two modes that depend on the combat state. |
| `PLAYER_REGEN_DISABLED` | `Canvas:RenderForCombat(true)` | The other half of the general-visibility rule (`options-ui-§15`). Panels are non-secure, so showing or hiding one at the start of a pull needs no gate. |
| `PLAYER_LOGIN` | `Panel:Register()` | A second **eager** attempt at settings-category registration. Subscribed from `OnInitialize`, not `OnEnable`: AceAddon runs `OnEnable` from inside its own `PLAYER_LOGIN` handler, and subscribing mid-dispatch misses that firing. |

The render pipeline these drive, and the combat gating around unlock and the options panel, are in
**[data-flow.md](data-flow.md)**.

**The first three are registered by `NS.StandUp` and unregistered by `NS.StandDown`, not by
`OnEnable`** — see the next section. `PLAYER_LOGIN` is the exception, because it is setup.

**Every registration is pcalled through Core** (`events-frames-taint-§1`): all four go through
`NS.SafeRegisterEvent` (`core/CoreSetup.lua`), so a name the client refuses is appended once to
`NS.State.rejectedEvents` and costs only itself; the other registrations, `Canvas:Enable()` and the
repaint still happen. The rejected list is surfaced as the `events` section, the last section of
the `/pm diagnostics` report ([debug.md](debug.md)). `NS.StandDown` keeps its bare `UnregisterEvent` calls. The first-run skin picker's combat hold is a fifth, separate registration: a one-shot `PLAYER_REGEN_ENABLED` on a private target of `core/SkinSetup.lua`'s, also through `NS.SafeRegisterEvent`, made only while a start waits out combat and dropped by the stand-down.

## The disabled state is total (`slash-commands-§7`)

**Disabled means the addon is not running.** Not hidden, not quiet, not skipping a repaint. Until
this was adopted, *disabled* here was a **draw gate**: `settings.enabled ~= false` was one rung of
`Canvas.BuildSpec`'s show ladder and one condition on the slash verbs, and nothing else changed —
every bus subscription stayed registered, all three game events above stayed registered, and the
shared 10Hz mouseover `OnUpdate` kept ticking over panels nobody could see. The addon had stopped
*reacting*; it had not stopped *watching*, and it went on paying the dispatch for both.

**Owner: `core/LifecycleSetup.lua`**, which publishes `NS.Lifecycle` — one `LibKa0s-Lifecycle-1.0`
instance — plus `NS.StandDown`, `NS.StandUp`, `NS.IsAddonEnabled` and `NS.RefreshEnabled`.

**Two named holds on one latch.** The addon is stood down whenever at least one hold is taken and
stood up only when the last is released, so **releasing one hold cannot resurrect an addon the other
still holds down**. `disabled` is taken from `settings.enabled`; `perf` is the hold
`LibKa0s-Perf-1.0`'s suspended arm takes — nothing takes it here today, because this addon declines
`Perf` (the ratified `performance-§1` row below), and the latch is still the right shape because a
second teardown path beside the first is the anti-pattern (#85), not an implementation detail.

| Stands down | How |
|---|---|
| The renderer's three bus subscriptions | `Canvas:Disable()` — actually unregistered, and the target dropped. Not gated: a handler that early-returns still pays the dispatch. |
| `PLAYER_ENTERING_WORLD`, `PLAYER_REGEN_ENABLED`, `PLAYER_REGEN_DISABLED` | `NS.StandDown` unregisters each by name; `NS.StandUp` re-registers them. |
| The shared 10Hz mouseover `OnUpdate` | Through the show ladder: `Canvas:Render` passes `spec.shown and spec.mouseover`, so the tracked set empties and `SetMouseoverTracked` takes the script off the driver frame. |
| Every panel frame | **At the source** — one rung in `Canvas:Render` reading `NS.Lifecycle:IsDown()`. Never an imperative sweep of `Hide()`: a hidden frame comes back on the next combat transition or settings change. |

| Survives, because it is SETUP | Why |
|---|---|
| The chat command, the dispatcher and `NS.COMMANDS` | Without them `/pm enable` does not exist and the switch goes one way. |
| The settings-category registration and the panel body | Including the `PLAYER_LOGIN` bootstrap above, which is that registration's deferred half and reads nothing about panels, and the Panels page's own two bus subscriptions (`NS.PanelEditor.__evPanels`), which keep an **open** page in step with the store and are addon messages the client never dispatches. |
| The AceDB handle, `NS.Schema:Set`, and AceDB's three profile callbacks | A profile switch can flip `settings.enabled` with no checkbox and no verb touched, so the addon must be able to re-evaluate the latch there (`core/Database.lua` calls `NS.RefreshEnabled` before anything repaints a panel; only the skin picker's hide and the new profile's skin run ahead of it, because the settings pages a stood-down addon still shows wear the skin). |
| The launcher's registration | The button stays on the minimap and the broker row stays in the display. Left-click still opens the settings panel (`launcher-§2`: the panel is setup). The right-click menu's *Enabled* entry stays live; *Locked* is grayed and reads `Locked (enable the addon first)`, and a grayed entry writes nothing. The hover tooltip still shows, reading **Enabled: No**. |

**Those three survivors are the whole list, and `tests/test_disabled.lua` asserts it by name** — a
fourth registration reddens the suite rather than joining the exemption quietly.

**No secure work, so no pending completion.** `slash-commands-§7` lets a disabled addon keep one
`PLAYER_REGEN_ENABLED` so that secure-attribute and state-driver work refused under lockdown can
finish. This addon has none to hold: every panel is a plain non-secure `CreateFrame("Frame")`, it
calls no `SetAttribute`, registers no state or attribute driver and installs no secure hook. The
stand-down therefore completes in the same turn as the write, every time. The unlock module's
combat queue is a UX deferral, not secure work: the stand-down drops it
(`NS.Unlock:DropPending`), and while the addon is down an unlock applies at once instead of queueing.

**Restoration is from current state, never from a snapshot** (`performance-§6`): `NS.StandUp`
re-registers and repaints from the registry and the settings *as they are now*, so a panel created
or a setting changed while the addon was off comes back correct.

`tests/test_disabled.lua` is the conformance suite the standard MUSTs, asserting on the
**registration set** rather than on any handler's return value.

## Skins

PanelMaster wears the collection's skins (skinning-§3) since the skinning rollout (Ka0sAddonsCommonTasks
`docs/2026-10-29-SKINNING_ROLLOUT/`, items PM-RV to PM-05; Loot History's pattern, cut to what this
addon draws).

- **The seam.** `core/SkinSetup.lua` registers the owner `"PanelMaster"` at file load and publishes
  `NS.Skin`, the read and write seams `NS.SkinChoice` / `NS.WriteSkinChoice` (both through
  `NS.Schema`) and the apply helpers ([module-map.md](module-map.md)). The choice is seven
  per-profile keys under `profile.skin` ([schema.md](schema.md)): `source`, `skin`, the Scope's
  `ignorePanel` (**on** for a new profile, the collection's default) and `ignoreFonts`, the
  overrides `font` and `texture`, and `pickerSeen`. `NS.ApplySkinChoice` runs right after
  `NS:InitDB` and first on every profile event, so a switch, copy or reset re-applies the choice.
- **The Skin tab.** The library's `O.AppearanceTab`, the General page's **last** tab (there is no
  Keybindings tab here), keyed `Appearance` so it takes the `skin.*` rows' group
  ([settings-panel.md](settings-panel.md)).
- **What follows the skin.** The library's own surfaces for this owner: the landing, General and
  Profiles chrome, the AceGUI widgets acquired through the Options proxy, the debug console and its
  copy window. This addon's own: the unlock overlay (outline `list.dropLine`, label `S.Text`
  `accent`, repainted on `OnLooksChanged`), the Panels picker's *(disabled)* marker
  (`text.disabled`), and the AceGUI widgets the Panels editor and AceConfigDialog acquire past the
  proxy (`NS.SkinPaintAce` / `NS.SkinPaintAceTree`; the kept band repainted in place). The settings
  pages are painted only while **Ignore settings panel** is off. Ka0s Default is a skin like any
  other: since LibKa0s v1.81.0 nothing keeps the game's look under it (the retired `stockDefault`),
  so the unignored tab strip and paging arrows wear the Ka0s look, and the game's look is the WoW
  Default skin. The debug console and its copy window are windows, not the settings panel: they wear
  the skin whatever **Ignore settings panel** says, and **Ignore fonts** reaches their title-bar
  words. This addon has no settings-page `S.Text` string and no owned Widgets control, so it passes
  no `panel` flag; the *(disabled)* marker is its one token read on a settings page, and
  `NS.SkinPanelEscape` gates it on `Skin:GetIgnore(owner)`.
- **What does not.** The panels themselves — fill, border, accent bars, accent border, artwork and
  class colors — are the player's content (decision D1): no `fromSkin` companions and **no one-time
  HUD style reset**, so no skin and no upgrade restyles a saved layout. New panels start from the
  template, not the skin (D2). StaticPopups, GameTooltip's frame, `ColorPickerFrame`, the
  LibSharedMedia pull-outs and the minimap button stay stock (skinning-§7); chat lines keep their
  colors (X7); the editor tooltips' inline yellow is content markup (X9); the console keeps its
  monospace face.
- **The first-run skin picker.** `NS.MaybeShowSkinPicker` shows the library's `O.SkinPicker` while
  the profile's `skin.pickerSeen` is false and the latch is up: once per session two seconds after
  the first `PLAYER_ENTERING_WORLD`, and after every profile event; in combat it waits for
  `PLAYER_REGEN_ENABLED`. It is titled *Choose a skin*, with this addon's label (`NS.BRAND`, from
  `RegisterOwner`) on its own line above the dropdown (the library's `frame.ownerLabel`). It has no eye (no window or test mode to preview in, X6), so `CLAUDE.md`
  declares only the `settings` icon. Only the player's close marks it seen; the stand-down and a
  profile event take it down unseen.
- **EllesmereUI.** The library's provider (`skin.source = "eui"`); `EllesmereUI` is in the TOC's
  `OptionalDeps`. PanelMaster has no bridge of its own.
- **The color gate.** `tests/test_skin_literals.lua` fails on a color literal outside
  `core/SkinSetup.lua` and its reasoned allow-list (anti-pattern #107).

## Frame layering

The whole stack is stated once, in the header comment of `NS.Constants.LAYERS`
(`core/Constants.lua`, `frame-layering-§5`); every `SetFrameStrata` and `SetFrameLevel` in the addon
reads that table, and `tests/test_layers.lua` pins it. The addon's tiers:

- **Panels (T1b, player-layered backdrops).** The record's `strata` (any of the eight, see the
  register below) and level `level × LAYERS.PANEL_STRIDE`, with a ten-rung internal ladder: artwork
  below the fill, fill, artwork above the fill, border, accent container, accent bars, accent bar
  border, artwork above all, unlock overlay. A new frame states `LAYERS.STRATA.BACKDROP` (`LOW`) at
  creation. Panels on the same strata and level can interleave, and the Frame level tooltip says so.
- **Unlock overlay (T2, edit chrome).** Its own strata while unlocked, `max(panel, HIGH)`, fixed and
  re-lifted on every render; mouse-off, which is what allows the `HIGH` floor.
- **The addon's confirmations (T6).** Blizzard's StaticPopups at `DIALOG`, never re-strata'd. While
  one is shown, an unlocked panel at `DIALOG` or above goes mouse-off and is re-armed by a render
  when the last popup closes.
- **Library and Blizzard tiers it relies on.** The debug console (`DIALOG`), the first-run skin
  picker (`DIALOG`), its copy window
  (`FULLSCREEN`), AceGUI pullouts and the color picker (`FULLSCREEN_DIALOG`), LSM pullouts and
  tooltips (`TOOLTIP`), the Settings panel (`HIGH`) and the LibDBIcon button (`MEDIUM`).

## Taint Notes

There is none to speak of, and that is a design property rather than luck: the addon creates only
non-secure frames of its own, never touches a Blizzard frame, never reparents anything, and never
calls a protected API. The single protected call anywhere near it is `Settings.OpenToCategory`, which
is refused under lockdown.

## Known Limitations

Seven, each with its reasoning — CLI names with spaces, a renamed panel's frame name, frame-name
reservation across renames, the hard-cut mouseover fade, player-class-only coloring, the Panels
list's ASCII-only sort, and manual `/pm recover`. All in **[scope.md](scope.md)**.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`). Frozen and
generated directories are named once each and never enumerated per run: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/`, `docs/revendor/`, `docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon draws, and what it deliberately refuses to become |
| `module-map.md` | Every non-vendored file, what it publishes, and the load order the seams pin |
| `schema.md` | The two SavedVariables scopes, the panel record, the skin keys, artwork fields, sanitizing, the schema runtime and its stub |
| `settings-panel.md` | The four canvas pages and the three AceGUI widget workarounds |
| `data-flow.md` | Record → spec → frame, the frame ladder and pool, the leftover-sample sweep, combat, events |
| `common-tasks.md` | Add a setting, a verb, a panel field, an artwork entry, a migration |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | 21 verbs in `NS.COMMANDS` (threshold is 8) |
| `profiles.md` | Present | AceDB profiles are user-visible — the Profiles settings page |
| `debug.md` | Present | The diagnostics report's sections (`modules/Diagnostics.lua`) `NS.DebugBuild`, `NS.DebugOnce` and the tag-by-tag Coverage map are the addon's own, beyond the library console |
| `message-bus.md` | Not applicable | Three messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message Bus` |
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own. The one fixup this addon ever carried was for a vendored **widget**, not a client behavior, and it is no longer this addon's: `lib.__PatchLSM30Border()` (`LibKa0s-Options-1.0` minor 15) owns it for the whole collection, called from `settings/OptionsSetup.lua` |
| `compat-layer.md` | Present | 8 shims in `core/Compat.lua` (threshold is 3) |
| `perf-analysis/README.md` | Not applicable | `LibKa0s-Perf` is declined on structural grounds ([`LIBKA0S-31`](https://github.com/tusharsaxena/PanelMaster/issues/31)); see `## Documented deviations` and `performance.md` |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The performance position and the sweep behind it |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, except the watch list's authored Disposition column |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `rendering.md` | Mouseover fade, the four accent bars, the artwork pipeline, the Sunn composite adapter |
| `artwork-spec.md` | Authoring artwork for the addon: folder tree, naming, the cleaner, source-image choice |
| `localization.md` | The `NS.L` seam, the key-is-the-string rule, and the 1.0.0 unwrapped position |
| `media.md` | What ships under `media/`, and why each asset is there |

## Documented deviations

The **single home** for a ratified deviation from the Ka0s WoW Addon Standard (`documentation-§3`).
A decision may be *reasoned* at length in this repo's GitHub issues or in a frozen
audit bundle, and the **Why** column cites that id — but a deviation that is not in this table is
**not ratified**, and an audit that cannot find it re-files it as an open MUST failure every cycle.

This is not a graveyard. A row whose cited rule the standard has since changed — so the behavior is
now mandated or permitted outright — is **retired**, not kept for the history.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§1` (the wiring MUST) | No `core/PerfSetup.lua`, no `PanelMasterPerfDB`, no `perf` verb, no `tests/perf.lua`. The `perf` verb stays **reserved** so it can never mean anything else here. | **Ratified as a deviation from `§1`, NOT as a `§12` exemption — `§12` does not apply and is not claimed.** The addon's one in-combat path is a single shared 10Hz `OnUpdate` (`modules/Canvas.lua:654-659`) whose whole body is, per mouseover-tracked panel, one `NS.Compat.MouseIsOver` and one `SetAlpha`. The cost is bounded by a number the player sets: panels with *Fade unless hovered* (the `mouseover` field) ticked, which defaults to `false` (`core/Constants.lua:369`). With none ticked the driver is never created; with the set emptied afterwards the frame survives but its script does not — `SetMouseoverTracked` clears the `OnUpdate` on the untrack that empties the set, and `ensureMouseoverDriver` re-installs it when the set refills, so the dormant cost is no per-frame callback at all. There is no per-record work, no allocation, no scan that grows with saved data, and nothing whose cost a raid can change. Wiring the full harness — a setup file, a second SavedVariables global, a slash verb, a `suspend`/`resume` contract and an offline scenario — to bracket two API calls at 10Hz is a cost the measurement could not repay. Owner's decision, 2026-08-25, over [#31](https://github.com/tusharsaxena/PanelMaster/issues/31) and [#44](https://github.com/tusharsaxena/PanelMaster/issues/44). | 2026-08-25 | Any of: a second `OnUpdate` or repeating ticker; `updateMouseover` growing work that is not O(tracked panels) of two API calls; a panel count that stops being player-bounded; or `performance-§12` gaining a bounded-cost clause upstream, at which point the exemption becomes claimable and this row is replaced by one that cites it. |
| `events-frames-taint-§8` (the pre-formatting **SHOULD**) | Roughly 25 chat and slash lines build their text with `("…"):format(…)` or `..` before handing it to `NS.Print` — `settings/Slash.lua`, `settings/PanelEditor.lua`, `settings/PanelEditorTabs.lua`, `settings/Schema.lua` — rather than the preferred `print("count", n)` varargs form. | **The MUST does not engage here, and this was re-graded, not waived.** §8 scopes the MUST NOT to call sites whose arguments are, or derive from, a return of a named combat-protected API. This addon reads **none** of them: a whole-repo sweep of `core/ modules/ settings/ defaults/ locales/` for the trigger set (`UnitGetTotalAbsorbs`, `UnitGetTotalHealAbsorbs`, `UnitGetIncomingHeals`, `UnitHealth`, `UnitHealthMax`, `UnitThreatSituation`, `UnitDetailedThreatSituation`, the aura amount/`points` fields, `UNIT_AURA`) returns nothing, and the only unit and AddOns APIs it calls at all are `UnitAffectingCombat` (`core/Compat.lua`) and the `C_AddOns` readers `GetAddOnMetadata`, `GetNumAddOns` and `GetAddOnInfo` (the class color resolves through the library's `ResolveColor`). Every one of these lines formats values the addon owns — a panel name, a stored geometry field, a count it computed, a literal — so none can be handed a secret and the residue is the SHOULD, graded Info. Neither of §8's two unrelaxed points is touched: no site calls the global `print()` (every file takes `local print = NS.Print`), and the seam's guarantee is unconditional — `core/CoreSetup.lua` publishes the library's `IsConcatSafe` / `SafeToString` and builds the printer from `lib:New`, so every argument is stringified through the `table.concat` probe whatever a call site hands it. Converting the sites is therefore a readability change with no reachable behavior, and is declined at `1.0.0`. | 2026-08-05 | The first chat or debug line whose arguments include, or derive from, a return of any API in §8's trigger set — that site converts as a MUST, and an audit files it as one. Re-check also when §8's trigger list grows upstream. |
| `frame-layering-§1` (player-chosen strata: `BACKGROUND` to `HIGH` only) | A panel's **Frame strata** and **Default frame strata** offer all eight strata, `DIALOG` to `TOOLTIP` included, and a panel's level is the player's too. | PanelMaster is the standard's own example of a **player-layered backdrop**, whose purpose is letting the player compose strata and level, and `§1` lets such an addon offer every strata as a row here. A high-strata backdrop is a legitimate choice (`core/Constants.lua`'s `C.STRATA` comment); both rows' tooltip is the library's `O.StrataTooltip(C.STRATA)`, which says what `DIALOG` and above cover. What `§1` asks in return is met: the four confirmation popups stay answerable while panels are unlocked (`NS.Unlock:PopupShown` / `PopupHidden`, `tests/test_layers.lua`). The debug console and the Settings window are not covered by that hand-off; `/pm lock` is their escape. Decided in the 2026-10-24 frame-strata run (`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`, PanelMaster analysis). | 2026-10-24 | The standard dropping or narrowing the player-layered backdrop variant, or this addon's value set changing (which is a migration). |
| `localization-§1` | Two user-facing strings route through `NS.L`: the collection's library-absent line (`"%s is unavailable: the LibKa0s library did not load."`, `slash-commands-§1`), printed by `Sl:LibraryAbsentLine` and by the degraded DebugLog stub's `RunDiagnostics` (`core/DebugLogSetup.lua`), and the `profile` verb's `NS.COMMANDS` description. (The launcher tooltip's two left-click hints went with Launcher minor 4, whose hints are the library's.) Everything else — every label, tooltip, other slash line and message — is still hardcoded English. | `1.0.0` ships **English-only** — the second of the two terminal compliant states `localization-§3` names, not an open routing gap. Both MUSTs are met unconditionally: the `NS.L` seam is exported with the key-returning metatable fallback (`locales/enUS.lua:6`) and `enUS.lua` ships, so a later pass wraps strings without touching call sites. Reasoned at `locales/enUS.lua:8-10`. Panel **names** are user data and must never route through `NS.L`; neither must the stored `point` / `strata` tokens (`localization-§4`). | 2026-08-05 | The first non-English locale file added to `locales/` — that change routes the strings and retires this row |

**Retired rows** (one entry each; the reasoning is in the cited issue or bundle):

- `architecture-§5` (the fields on a panel) — retired 2026-10-01: its trigger is met. `S.ResolveRoot`
  maps the panel id to the record, `NS.Schema:Set` / `:Get` forward the id, and every per-panel field
  write goes through `SchemaRuntime.Set` / `SetMany` as a `panel.<field>` row, which reverses the
  2026-09-24 keep on the owner's "fix now"
  ([#54](https://github.com/tusharsaxena/PanelMaster/issues/54), over
  [#49](https://github.com/tusharsaxena/PanelMaster/issues/49)).

- `options-ui-§16` ×3 (border, bar and bar-border blocks) — retired 2026-09-12: the composer's
  record-backed `bind` arm shipped, so the blocks compose now
  ([#48](https://github.com/tusharsaxena/PanelMaster/issues/48); `docs/revendor/2026-09-12-v1.31.0/`;
  pinned by `tests/test_options_groups.lua`).
- `documentation-§4` (no root `TODO.md`) — retired 2026-09-08: `1.0.0` shipped and the addon
  satisfies the rule outright. PM-029 (`docs/audits/2026-09-07/`, closed in `docs/audits/2026-09-08/`).
- `options-ui-§1` (Master controls absent on a library-less load) — retired 2026-09-08: the rule now
  says the composed no-copy shape needs no row. Same `M5-02` pass as PM-029 (`docs/audits/2026-09-08/`).
- `line-endings-§5` (extension-less binary mark) — retired 2026-09-08: the mark moved to the
  `§5` appendix block below the canonical body. Same `M5-02` pass as PM-029 (`docs/audits/2026-09-08/`).

### Files over the 1500-line cap

`layout-§1` caps every **authored** `.lua` file this repository tracks at 1500 lines — `tests/`
included, with vendored code (`libs/`, `tests/_kit/`) the only carve-out that reaches anything here.
Nothing in this repo is generated non-shipping data, so the second carve-out has no instance and
`tests/run.lua` sets no `Kit.layoutCap`. A file **over** the cap has three terminal states and no
others: peeled, an open issue naming the seam a peel would follow, or a ratified row in the register
above carrying a re-check trigger. This census records which one each breach sits in. The kit's gate,
`tests/_kit/test_layout_cap.lua` (kit revision 25, LibKa0s v1.55.0), reads it from here and fails the
suite on an over-cap file it does not name, on a row naming a file that is no longer over the cap,
and on a heading that is missing, misplaced or standing empty.

**Nothing is over the cap today.** Measure it, rather than trusting a figure written here, with

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

The first line after the total is the largest authored file; while it reads under 1500, this
census stays empty. The 1000–1500 band is not recorded here: `layout-§1` and `automated-tests-§4`
disposition it only in the *Files by `layout-§1` band* table of
[`automated-tests/RESULTS.md`](automated-tests/RESULTS.md), whose rows the runner generates and whose
`Disposition` cell is the one authored field (past peels are in
[#47](https://github.com/tusharsaxena/PanelMaster/issues/47) and the automated-test bundles).

**Retired on 2026-09-23: this repo's own band gate** — the kit's `test_layout_cap.lua` took the
cap, and the band moved to the watch list (`docs/revendor/2026-09-23-v1.55.0/`).
