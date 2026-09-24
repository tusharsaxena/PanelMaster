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

`core/` holds the bootstrap, the Compat firewall, the AceDB layer and six of the eight LibKa0s
seams;
`modules/` holds the registry, the artwork catalog, the Sunn adapter, the canvas renderer and unlock
mode; `settings/` holds the schema, the other two seams and the four panel pages. Load order is
fixed by the TOC — `core/Compat.lua` first, `settings/` last — and the LibKa0s seams pin several
steps of it.

File-by-file table and the seam/load-order contract in **[module-map.md](module-map.md)**.

## Settings Schema

Two SavedVariables scopes: `defaults/Profile.lua` carries the panel registry, `nextID` and the
settings block, all profile-scoped (every character starts on the shared "Default" profile,
`core/Database.lua:19`); `defaults/Global.lua` declares `schemaVersion = 0` (the migration runner's floor; the runner writes
the real stamp) and LibDBIcon's own `minimap` table.
`settings/Schema.lua` holds one row per setting and is the sole sender of `SettingsChanged`. It
carries **15 rows in 3 groups**, and since the tabbed-panel pass a `group` is a **tab**
(`options-ui-§13`): `H.RenderTabbedSchema` partitions the rows by `group` in declaration order, so
the array's order is the strip a player sees on the General page — `Master controls` (7),
`Editing` (4), `New panels` (4). Two of the fifteen are session-only `state.*` rows that route
through their own `get`/`set` and are never persisted, and **one** — `global.minimap.shown`, the
*Minimap button* row — is stored but lives in `db.global` rather than `db.profile`, which is the
only row in the schema that does (`launcher-§3`). Its path is its CLI name and reads in the row's
own sense, so `/pm get global.minimap.shown` answers `true` while the button shows; the state is
stored at `db.global.minimap.hide`, LibDBIcon's own key and the only stored one (`S.MINIMAP_STORE`).
The row carries its own `get`/`set`, wired onto it by `S:InstallMaster`. They read and write the
store from the DB root, and they NEGATE, because the row says shown while LibDBIcon's key says
hidden. Nothing is ever written or declared at the row's path (anti-pattern #81), so
`S:Register` skips that path and checks the store against the global defaults instead.

**The runtime is `LibKa0s-Schema-1.0`** (adopted at LibKa0s v1.55.0; `docs/revendor/2026-09-23-v1.55.0/`).
The rows are this addon's. The machinery around them is one library instance, `NS.SchemaRuntime`,
built in `settings/Schema.lua`: the path walk, the row index, the single write seam, the bulk
bracket (`debug-logging-§10`) and the boot shape check. The seam **keeps this addon's names**:
`NS.Schema:Set`, `:Get`, `:FindRow`, `:Default` and `:Register`, plus `S.BulkBegin`, `S.BulkEnd`
and `S.BulkLine`, each delegate to the instance, so no caller moved. The Options and Slash
descriptors take the instance's members **as values** (`set = NS.SchemaRuntime.Set`, and the
same for `get`, `applyDefault`, `findRow`, `allRows` and the bracket pair). That is safe because
nothing sits in front of the seam: the minimap inversion is the row's own `get`/`set`, and a
refusal belongs in a row's `validate`, which `ApplyDefault` reaches too.
Stored rows resolve against the active profile (`resolveRoot`). The refusal texts are this addon's
own (`unknown path: <path>`, `invalid value`), restored through the descriptor's plain-table `L`.
`S:Register` is the instance's `Validate` with a `global.`-aware defaults root, and it counts shape
errors as well as unresolved paths. The profile reset's row count stays host-side
(`S:SnapshotPersisted` / `S:CountChangedSince`), as the design allows.

**Without the library** the seam degrades to `hostSchemaStub`, which stands in for both the
library's pure primitives and the instance. The stub is **write-completing and log-silent**
(`docs/api/Schema/version-1-docs.md`, "The degradation stub"). Reads, writes, each row's `onChange`
and the bracket's depth all work, so the host writers keep writing: `/pm set` and `/pm disable`
where the Slash major survives, Reset All, the page Defaults sweep, and the Registry's bulk verbs.
The stub does not reproduce the per-write `[Set]` line or the bracket's tally, and it skips the
boot shape check silently. This is a documented duplication of a runtime write path, not of a
rendering helper. `tests/test_surface_parity.lua` holds both of its levels to the live surface, and
`tests/test_schema.lua` drives one degraded write per writer kind.

The **first** seven are not literals in that file. `Master controls` is COMPOSED, out of
`LibKa0s-Options-1.0`'s `MasterControls` (`options-ui-§15`), and spliced at the head of the array by
`S:InstallMaster` — which `settings/OptionsSetup.lua` calls the moment the library instance exists,
because that instance is what carries the composer and it is built after this file loads. A row
carries no `widget` field: the flow engine dispatches on `type` alone, so a second field naming the
widget was a selector with no reader.

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
row. The one `architecture-§5` row this addon has covers the fields on a panel, below.
`/pm resetall` and Profiles → Reset Profile (`db:ResetProfile()`), and AceDB's own profile switch
and copy, replace the store wholesale, which is not a registry write; the load pass and
`NS.Registry:ReloadProfile` run after each of them. Each is logged once, by the profile handler in
`core/Database.lua` and worded by the event (`debug-logging-§10`; `docs/debug.md`).

**The fields on a panel: a ratified `architecture-§5` register row.** A panel's appearance and
position fields (`C.PANEL_FIELD_TYPE`, less `name`, which is the registry's own label and routes to
`Rename`) are preferences the player sets on a member, and none of them has a schema row. The field
controls and `/pm panel <name> set` write them through `NS.Registry:Set`, which coerces, writes,
sanitizes and sends `PanelChanged` on its own rather than through `NS.Schema:Set`. It is not the
only writer. `:SetPosition` writes `x`/`y`, and the unlock drag-stop (`modules/Unlock.lua`) writes
`point`/`relPoint` straight onto the live record before calling it, so a drag writes geometry.
`:Reset`, `:CopyFrom` and `:FitToArtwork` rewrite fields and then sanitize. `:Recover` writes
`x`/`y`, and `:ResetPositions` all four anchor fields, onto every record directly, with no
per-record sanitize, and each sends `PanelsChanged` once if anything moved. None of these is the
schema helper. The drag is part of the same set, not a separate case: every anchor field it writes
(`point`, `relPoint`, `x`, `y`) is also set by the editor or `/pm`, so they are preferences.

Since standard v2.43.0 a preference with no row is a missing row. The owner ruled on 2026-09-12
([#49](https://github.com/tusharsaxena/PanelMaster/issues/49)) for a register row rather than
instance-relative rows, because the schema helper addresses paths, not records, and
instance-addressing every per-panel field would be the largest change in the collection for fields
the Registry already validates and announces. The row is `architecture-§5` (the fields on a panel)
in [`## Documented deviations`](#documented-deviations). It retires when the schema helper gains
instance addressing for registry records (an explicit record argument on `NS.Schema:Set`). The
record-backed bind arm in `LibKa0s-Options-1.0` is not that trigger: it changes how a control
binds to a record, not where the write goes.

The panel record, every field on it, the artwork fields and the sanitizing pass are in
**[schema.md](schema.md)**; the pages that edit them in **[settings-panel.md](settings-panel.md)**;
profile behavior in **[profiles.md](profiles.md)**.

## Message bus (`architecture-§4`)

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

`Canvas:Enable()` — which installs those subscriptions — is called from **`OnEnable`**. This is not
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

Schema-driven verbs: `config version get set list reset resetall debug enable disable help` — `resetall` is a
**profile reset** (`options-ui-§12`): confirm-gated, the same act as Profiles → Reset Profile, and it
takes the player's panels with it because `db.profile.panels` is in the profile. Panel verbs: `new
delete rename panels panel unlock lock recover` — no `test` verb, because unlocking is this addon's
test mode (`options-ui-§15`). `enable` and `disable` are **aliases** onto `settings.enabled`, the
path the Master-controls checkbox writes, through the same write seam and holding no state of their
own (`slash-commands-§2`). While the addon is **disabled** the whole reserved surface still answers
— a bare `/pm` opens the settings panel, and the standard's twelve reserved verbs (`help config
version enable disable debug perf get set list reset resetall`, read from `lib.LIVE_VERBS`) stay
live, which standard v2.57.0 restored after v2.56.0 briefly narrowed it. `perf` sits in that set as
a **reservation**, not a command: this addon registers no `perf` verb — `NS.COMMANDS`
(`settings/Slash.lua:285`) holds 19 verbs and none of them is `perf` — so the eleven reserved verbs
it does ship are the ones that behave normally. The only refusal is the addon's own **feature
verbs**, on one tagged line naming `/pm enable`, and that gate is **the library's**:
`settings/Slash.lua` passes `isEnabled` and `brandName` and narrows nothing (no `liveVerbs`). Verb
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
| The object and its click | `core/LauncherSetup.lua` | Left-click toggles the lock (**rung (b)** — unlocking is this addon's preview, so there is no test mode to toggle instead). It writes `state.locked` through `NS.Schema:Set`, the same seam the *Lock frame* checkbox writes through, and holds no copy of that state. Right-click always opens the settings panel. |
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
| `PLAYER_ENTERING_WORLD` | `Canvas:RenderAll()` | Panels are drawn here, not at `OnEnable`: `UIParent`'s size is what recovery measures against and it is not final that early. |
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
repaint still happen. The rejected list is surfaced as the last line of `/pm debug dump`
([debug.md](debug.md)). `NS.StandDown` keeps its bare `UnregisterEvent` calls.

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
| The AceDB handle, `NS.Schema:Set`, and AceDB's three profile callbacks | A profile switch can flip `settings.enabled` with no checkbox and no verb touched, so the addon must be able to re-evaluate the latch there (`core/Database.lua` calls `NS.RefreshEnabled` first, before anything repaints). |
| The launcher's registration | The button stays on the minimap and the broker row stays in the display. What the **left** click does changes: this addon is on rung (b), so it prints the refusal line and writes nothing (`launcher-§2`). Right-click still opens the panel, in either state. |

**Those three survivors are the whole list, and `tests/test_disabled.lua` asserts it by name** — a
fourth registration reddens the suite rather than joining the exemption quietly.

**No secure work, so no pending completion.** `slash-commands-§7` lets a disabled addon keep one
`PLAYER_REGEN_ENABLED` so that secure-attribute and state-driver work refused under lockdown can
finish. This addon has none to hold: every panel is a plain non-secure `CreateFrame("Frame")`, it
calls no `SetAttribute`, registers no state or attribute driver and installs no secure hook. The
stand-down therefore completes in the same turn as the write, every time.

**Restoration is from current state, never from a snapshot** (`performance-§6`): `NS.StandUp`
re-registers and repaints from the registry and the settings *as they are now*, so a panel created
or a setting changed while the addon was off comes back correct.

`tests/test_disabled.lua` is the conformance suite the standard MUSTs, asserting on the
**registration set** rather than on any handler's return value.

## Taint

There is none to speak of, and that is a design property rather than luck: the addon creates only
non-secure frames of its own, never touches a Blizzard frame, never reparents anything, and never
calls a protected API. The single protected call anywhere near it is `Settings.OpenToCategory`, which
is refused under lockdown.

## Known Limitations

Seven, each with its reasoning — CLI names with spaces, a renamed panel's frame name, frame-name
reservation across renames, no per-panel level UI, the hard-cut mouseover fade, player-class-only
coloring, and manual `/pm recover`. All in **[scope.md](scope.md)**.

## Documentation map

Every `.md` under `docs/` appears in exactly one table below (`documentation-§3`). Frozen and
generated directories are named once each and never enumerated per run: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/`, `docs/revendor/`, `docs/superpowers/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon draws, and what it deliberately refuses to become |
| `module-map.md` | Every non-vendored file, what it publishes, and the load order the seams pin |
| `schema.md` | The two SavedVariables scopes, the panel record, artwork fields, sanitizing |
| `settings-panel.md` | The four canvas pages and the three AceGUI widget workarounds |
| `data-flow.md` | Record → spec → frame, the frame ladder and pool, the leftover-sample sweep, combat, events |
| `common-tasks.md` | Add a setting, a verb, a panel field, an artwork entry, a migration |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `slash-dispatch.md` | Present | 19 verbs in `NS.COMMANDS` (threshold is 8) |
| `profiles.md` | Present | AceDB profiles are user-visible — the Profiles settings page |
| `debug.md` | Present | `D:Diagnose()` and `NS.DebugBuild` are the addon's own, beyond the library console |
| `message-bus.md` | Not applicable | Three messages; threshold is more than ten. The table lives in `ARCHITECTURE.md` → `## Message bus` |
| `midnight-quirks.md` | Not applicable | No client-version workaround of the addon's own. The one fixup this addon ever carried was for a vendored **widget**, not a client behavior, and it is no longer this addon's: `lib.__PatchLSM30Border()` (`LibKa0s-Options-1.0` minor 15) owns it for the whole collection, called from `settings/OptionsSetup.lua` |
| `compat-layer.md` | Not applicable | `core/Compat.lua` normalizes the addon roster, screen size, UI scale and LSM (class color moved to `LibKa0s-Core-1.0` minor 7) — no addon-specific shim beyond what the row in `module-map.md` records |
| `perf-analysis/README.md` | Not applicable | `LibKa0s-Perf` is declined on structural grounds ([`LIBKA0S-31`](https://github.com/tusharsaxena/PanelMaster/issues/31)); see `## Documented deviations` and `performance.md` |

### Verification and record

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The performance position and the sweep behind it |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated, never hand-edited |

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

**The `Perf` decline IS a row here, as of 2026-08-25, and it cites `performance-§1` directly.**
It was deliberately withheld until then, on reasoning worth keeping: the obvious row would have
cited `performance-§12`'s no-combat-path exemption, and **this addon does not qualify for it** —
criterion (a) requires no `OnUpdate` handler, and `modules/Canvas.lua:666` installs a shared 10Hz
driver the moment any panel has *Show on mouseover only* ticked, with no combat gate. A `§12` row
would have been a false row, so no row was written and an audit re-filed `performance-§1` every
cycle, which was the correct outcome for as long as the choice was unmade.

The choice is now made, and it is the other one this section allows: a **deliberate deviation from
`performance-§1` itself**, ratified by the owner on a bounded-cost argument, rather than an
exemption claimed under `§12`. `§12` remains unclaimable here and the row below does not claim it.
See [`performance.md`](performance.md) for the cost argument and the committed sweep.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| `performance-§1` (the wiring MUST) | No `core/PerfSetup.lua`, no `PanelMasterPerfDB`, no `perf` verb, no `tests/perf.lua`. The `perf` verb stays **reserved** so it can never mean anything else here. | **Ratified as a deviation from `§1`, NOT as a `§12` exemption — `§12` does not apply and is not claimed.** The addon's one in-combat path is a single shared 10Hz `OnUpdate` (`modules/Canvas.lua:650-656`) whose whole body is, per mouseover-tracked panel, one `NS.Compat.MouseIsOver` and one `SetAlpha`. The cost is bounded by a number the player sets: panels with *Show on mouseover only* ticked, which defaults to `false` (`core/Constants.lua:306`). With none ticked the driver is never created; with the set emptied afterwards the frame survives but its script does not — `SetMouseoverTracked` clears the `OnUpdate` on the untrack that empties the set, and `ensureMouseoverDriver` re-installs it when the set refills, so the dormant cost is no per-frame callback at all. There is no per-record work, no allocation, no scan that grows with saved data, and nothing whose cost a raid can change. Wiring the full harness — a setup file, a second SavedVariables global, a slash verb, a `suspend`/`resume` contract and an offline scenario — to bracket two API calls at 10Hz is a cost the measurement could not repay. Owner's decision, 2026-08-25, over [#31](https://github.com/tusharsaxena/PanelMaster/issues/31) and [#44](https://github.com/tusharsaxena/PanelMaster/issues/44). | 2026-08-25 | Any of: a second `OnUpdate` or repeating ticker; `updateMouseover` growing work that is not O(tracked panels) of two API calls; a panel count that stops being player-bounded; or `performance-§12` gaining a bounded-cost clause upstream, at which point the exemption becomes claimable and this row is replaced by one that cites it. |
| `events-frames-taint-§8` (the pre-formatting **SHOULD**) | Roughly 25 chat and slash lines build their text with `("…"):format(…)` or `..` before handing it to `NS.Print` — `settings/Slash.lua`, `settings/PanelEditor.lua`, `settings/Schema.lua` — rather than the preferred `print("count", n)` varargs form. | **The MUST does not engage here, and this was re-graded, not waived.** §8 scopes the MUST NOT to call sites whose arguments are, or derive from, a return of a named combat-protected API. This addon reads **none** of them: a whole-repo sweep of `core/ modules/ settings/ defaults/ locales/` for the trigger set (`UnitGetTotalAbsorbs`, `UnitGetTotalHealAbsorbs`, `UnitGetIncomingHeals`, `UnitHealth`, `UnitHealthMax`, `UnitThreatSituation`, `UnitDetailedThreatSituation`, the aura amount/`points` fields, `UNIT_AURA`) returns nothing, and the only unit/client APIs it calls at all are `UnitClass` and `C_AddOns.GetAddOnMetadata`. Every one of these lines formats values the addon owns — a panel name, a stored geometry field, a count it computed, a literal — so none can be handed a secret and the residue is the SHOULD, graded Info. Neither of §8's two unrelaxed points is touched: no site calls the global `print()` (every file takes `local print = NS.Print`), and the seam's guarantee is unconditional — `core/CoreSetup.lua` publishes the library's `IsConcatSafe` / `SafeToString` and builds the printer from `lib:New`, so every argument is stringified through the `table.concat` probe whatever a call site hands it. Converting the sites is therefore a readability change with no reachable behavior, and is declined at `1.0.0`. | 2026-08-05 | The first chat or debug line whose arguments include, or derive from, a return of any API in §8's trigger set — that site converts as a MUST, and an audit files it as one. Re-check also when §8's trigger list grows upstream. |
| `localization-§1` | One user-facing string routes through `NS.L`: the collection's library-absent line (`"%s is unavailable: the LibKa0s library did not load."`, `slash-commands-§1`), printed by `Sl:LibraryAbsentLine`. Everything else — every label, tooltip, other slash line and message — is still hardcoded English. | `1.0.0` ships **English-only** — the second of the two terminal compliant states `localization-§3` names, not an open routing gap. Both MUSTs are met unconditionally: the `NS.L` seam is exported with the key-returning metatable fallback (`locales/enUS.lua:6`) and `enUS.lua` ships, so a later pass wraps strings without touching call sites. Reasoned at `locales/enUS.lua:8-14`. Panel **names** are user data and must never route through `NS.L`; neither must the stored `point` / `strata` tokens (`localization-§4`). | 2026-08-05 | The first non-English locale file added to `locales/` — that change routes the strings and retires this row |
| `architecture-§5` (the fields on a panel) | The per-panel appearance and position fields in `C.PANEL_FIELD_TYPE` (`core/Constants.lua`) are preferences the player sets on a member, and none has a schema row. That is every field except `name`, which routes to `R:Rename`: colors, the border, bar and bar-border blocks, textures, size, `strata`, `level`, `scale`, `alpha`, mouseover, `enabled`, the `art*` fields and the anchor (`point`, `relPoint`, `x`, `y`). They are written through `NS.Registry:Set` (the field controls in `settings/PanelEditor.lua` and `/pm panel <name> set`) and `:SetPosition`, and by the whole-record and bulk verbs: `R:Reset`, `R:CopyFrom`, `R:FitToArtwork` (through `R.ApplyArtSize`), `R:Recover`, `R:ResetPositions`, and the unlock-mode drag-stop in `modules/Unlock.lua`, which writes `point`/`relPoint` onto the live record and then calls `:SetPosition`. Each of these coerces, writes and notifies on its own (`PanelChanged` per record; `PanelsChanged` once for `Recover` and `ResetPositions`), none through `NS.Schema:Set`. | The schema helper addresses paths, not records: `NS.Schema:Set` writes a path under the profile, and a panel is a registry record reached by id. Instance-addressing every per-panel field would be the largest change in the collection, for fields the Registry already validates (the `C.PANEL_FIELD_TYPE` coercers plus `R.Sanitize`), logs once at the seam and announces on the bus. Owner's decision, 2026-09-12, over [#49](https://github.com/tusharsaxena/PanelMaster/issues/49). | 2026-09-12 | The schema helper gains instance addressing for registry records (an explicit record argument on `NS.Schema:Set`). The fields then take instance-relative rows, the verbs above become callers of the helper, and this row retires. |

**Retired on 2026-09-12, three rows for one reason: the `options-ui-§16` border, bar and bar-border
blocks.** Each row said a canonical group on the Panels page was typed out in
`settings/PanelEditor.lua`, because `O.BorderGroup` and `O.BarGroup` emitted path-keyed schema rows
and a panel is a registry record with no path, and each carried the trigger *the composer gains a
record-backed arm*. LibKa0s v1.31.0 shipped that arm (`spec.bind`, OptionsCompose minor 4, read by
OptionsWidgets minor 15), so the trigger fired. The three blocks are composed now, each from one
declaration with a `bind` over the live panel record that writes through `NS.Registry:Set`
([#48](https://github.com/tusharsaxena/PanelMaster/issues/48)). The behavior is what `§16` mandates,
and a row for it would be the graveyard `documentation-§3` forbids. `tests/test_options_groups.lua`
holds the new state: no hand-written block on the page, the three composer calls bound, no
`options-ui-§16` row in this table, and a control-by-control characterization of what the composed
blocks draw and write. The `architecture-§5` row above stays. The arm changes how a control binds to a
record, not where the write goes, and that row's trigger is deliberately the schema helper.

**Retired on 2026-09-08, three rows, three different reasons.**

- **`documentation-§4` — pending work in GitHub issues rather than a root `TODO.md`.** The row's
  Why read *"the addon is pre-release, so the rule is not yet engaged"* and its trigger read *"the
  first published release"*. `1.0.0` shipped on 2026-08-07 (`PanelMaster.toc`, `README.md`'s
  Version History, tag `1.0.0-release`), so the trigger fired that day. `documentation-§4` is
  engaged now, and this addon **satisfies it outright** — there is no `TODO.md` at the root or
  under `docs/`, and the backlog is the issue store, which is what the rule asks for. A row for
  compliant behavior is the graveyard `documentation-§3` forbids. `PM-029`.

- **`options-ui-§1` — the Master controls rows a library-less load does not get.** The row
  argued that the stub cannot reproduce what `H.MasterControls` emits without holding a host copy
  of the library's canonical row data, and that the copy is the thing that goes stale.
  `options-ui-§1` now rules exactly that: when the missing content is **composed** the no-copy MUST
  wins, a stub's composer members answer an empty row list, and *"this shape needs no register row,
  and the rows already written for it retire"*. The ruling's three bounds hold here — `LibKa0s` is
  vendored whole so the load that loses the composers loses the schema CLI with it, profile
  defaults merge from `defaults/Profile.lua` and are never read off the schema, and
  `tests/test_libka0s.lua`'s *"the schema loses the composed Master controls rows and NOTHING
  else"* pins the live count, the degraded count and the delta between them rather than one
  number. Nothing about the degraded load changes.

- **`line-endings-§5` — the extension-less binary mark.** The row recorded a genuine collision:
  `§4` MUSTs every binary be marked, `§5` MUSTs this file be byte-identical to the canonical body,
  and `tools/artwork/bin/realesrgan-ncnn-vulkan` has no extension for any `*.ext` line to reach.
  `§5` now carries an **appendix**: a delimited block below the canonical body, marks keyed by
  path, single paths rather than globs, each with a comment saying why no extension reaches it —
  and it says in as many words that a repo **MUST NOT** carry a register row for one, and that a
  row predating the rule is retired by bringing the block into that shape. So the block moved: it
  sat at `.gitattributes:67-71`, **inside** the body, which is the placement the appendix rule
  names as the thing it forbids, because it displaces every line after it and turns a one-decision
  diff into two. The first 81 lines are now byte-identical to the canonical client-bound body and
  the mark is below it under `# --- line-endings-§5 appendix ---`. Verified with the section's own
  check: `diff <(head -n 81 .gitattributes) <canonical>` is empty and
  `tail -n +82 .gitattributes | tr -d '\r' | grep -m1 .` is the delimiter.

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

**Nothing is over the cap today.** Measured 2026-09-23 with

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn
```

The largest authored file is `settings/PanelEditor.lua` at 1476 lines, twenty-four under the cap.

**The 1000–1500 band is not recorded here.** `layout-§1` and `automated-tests-§4` disposition it in
the release watch list and only there: the *Files by `layout-§1` band* table in
[`automated-tests/RESULTS.md`](automated-tests/RESULTS.md), whose rows the runner generates on every
run and whose `Disposition` column is the one authored cell. A file moving between bands therefore
moves on one line of one document. All four files in the band on 2026-09-23 already carry a
disposition there: `settings/PanelEditor.lua` (1476), whose peel is issue
[#47](https://github.com/tusharsaxena/PanelMaster/issues/47) — the appearance editor out from under
the Panels page's chrome band into a sibling under `settings/`; `tests/test_panel.lua` (1353), which
mirrors that file and peels with it; and `modules/Artwork.lua` (1188) with its mirror suite
`tests/test_artwork.lua` (1356), which split together along the catalog / geometry seam. The next
file to reach 1000 arrives in that table with a blank `Disposition` cell, which is the file saying
something crossed and nobody has ruled on it yet.

**Retired on 2026-09-23: this repo's own band gate.** Until the LibKa0s v1.55.0 re-vendor the census
was headed ``Files by the `layout-§1` band``, sat in a `## File sizes` section of its own below this
register, and was read by a local `tests/test_layout_cap.lua` that gated the band as well as the cap,
on the reasoning that with nothing over the cap an over-cap-only gate asserts nothing and the band was
where this addon's question lived. Standard v2.64.0 settles both halves the other way: the heading's
name and its parent under `## Documented deviations` are fixed, so a gate can find it in every repo,
and the band gets no heading in the hub, so its dispositions are not kept in two places that can
disagree. The local gate is deleted, the kit's is declared by the pair form in `tests/run.lua`, and
the band rows moved to the watch list, which already carried a disposition for each of them.
