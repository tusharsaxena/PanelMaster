# Architecture — Ka0s Panel Master

How the addon is put together: the module map, the data model, the message bus, the slash surface,
the event wiring, and the decisions worth knowing before changing anything.

Built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards). Read the
root [CLAUDE.md](../CLAUDE.md) and [agent-context.md](agent-context.md) first.

## What it is

A backdrop-panel creator, in the lineage of kgPanels and ElvUI's panels. The user creates named
rectangles with a colour, a border, a size, a position and a layer, and the addon draws them behind
the rest of the UI. That is the whole product.

**It does not host anything.** A panel is not a container: nothing is reparented into it, no other
addon's frames are moved, and no Blizzard frame is touched. It is scenery — a visual grouping cue
behind frames that stay exactly where their own addons put them. This constraint is why the addon
needs no secure frames, no combat gating on its render path, and no taint story.

## Module map

Load order is fixed by the TOC (`layout`); `core/Compat.lua` is first, `settings/` last.

| File | Publishes | Role |
|---|---|---|
| `core/Compat.lua` | `NS.Compat` | The only caller of deprecated / varying APIs. Addon metadata, screen size, UI scale, LibSharedMedia registration and lookup, class colour, cursor test, backdrop-mixin presence. |
| `core/LSMPatch.lua` | — | Upstream fixup for the vendored `LSM30_Border` widget's misaligned preview tile. Lives in `core/`, not `libs/`, so a lib refresh cannot blow it away. |
| `core/Constants.lua` | `NS.Constants` | Strata and anchor-point enums, geometry bounds, the panel record template, the field type/order maps, preview specs, media paths. |
| `core/Namespace.lua` | `NS.name/version/PREFIX/SCHEMA_VERSION` | Metadata bootstrap. The cyan `[PM]` chat tag lives here. |
| `core/State.lua` | `NS.State` | Session-only runtime state: `debug`, `unlocked`, `unlockedPanels`, `preview`, `previewIDs`. Never persisted. |
| `core/Util.lua` | `NS.Util`, `NS.Print` | Path splitting, clamping, rounding, snapping, colour parse/format, name cleaning, deep copy, and the secret-safe shared chat printer. |
| `core/PanelMaster.lua` | `NS.addon`, `NS.bus` | AceAddon registration, the printer reclaim, the bus-target factory, `OnInitialize` / `OnEnable`. |
| `core/Database.lua` | `NS:InitDB`, `NS:RunMigrations` | AceDB open, the migration seam, the `[Init]` summary. |
| `defaults/Profile.lua` | `NS.defaults.profile` | Per-character defaults: the (empty) panel registry, `nextID`, and the settings block. |
| `defaults/Global.lua` | `NS.defaults.global` | The `schemaVersion` stamp — the one account-wide value. |
| `modules/Registry.lua` | `NS.Registry` | **Owns `db.profile.panels`.** Create, delete, rename, reset, field edits, sanitizing, slug-uniqueness, off-screen recovery. Sole sender of both panel messages. |
| `modules/Canvas.lua` | `NS.Canvas` | Turns records into frames. The pure `BuildSpec`, the name-keyed frame pool, the offset border child frame, the four accent-bar textures, the shared mouseover ticker, targeted and full repaints. |
| `modules/Unlock.lua` | `NS.Unlock` | Unlock mode (outline, label, drag, snap), global and per-panel, and preview mode. |
| `modules/DebugLog.lua` | `NS.DebugLog`, `NS.Debug` | The on-screen debug console and the gated logging sink. |
| `settings/Schema.lua` | `NS.Schema`, `NS.COMMANDS` | The settings schema (one row per setting) and the command table. Sole sender of `SettingsChanged`. |
| `settings/Slash.lua` | `NS.Slash` | `/pm` dispatch, the generated help index, and every CLI verb. |
| `settings/Panel.lua` | `NS.Panel` | The Blizzard Settings canvas: landing page, General, Panels. Owns the open-dropdown tracking that closes a list on scroll. |

## Data model

Saved to `PanelMasterDB`. **Per-character**, deliberately: a panel layout belongs to the UI a given
character runs, and AceDB's profile machinery is what lets a user copy one to an alt when they do
want it shared. A forced account-wide profile would take that choice away.

```
PanelMasterDB
  global.schemaVersion    -- the build's DB shape; migrations run once per SV file
  profile.panels          -- array of panel records, creation order
  profile.nextID          -- monotonic id source; ids are never reused
  profile.settings        -- the schema-backed settings
```

### The panel record

```lua
{ id, name, enabled, width, height, point, relPoint, x, y, strata, level, alpha,
  bgTexture,     bgColor,    bgClassColor,
  borderTexture, borderSize, borderOffset, borderColor, borderClassColor,
  mouseover, mouseoverAlpha,
  accentEnabled, accentEdges, accentTexture, accentThickness, accentOffset,
                 accentColor, accentClassColor,
  accentBorderTexture, accentBorderSize, accentBorderOffset,
                       accentBorderColor, accentBorderClassColor }
```

`core/Constants.lua`'s `PANEL_TEMPLATE` is the single definition of that shape — the shipped default
AND the source every missing field is repaired from. Four sibling maps derive everything else from
it, so adding a field is one template entry plus one row in whichever of these applies:

| Map | Drives |
|---|---|
| `PANEL_FIELD_TYPE` | CLI coercion and validation |
| `PANEL_FIELD_ORDER` | the `/pm panel <name>` dump order |
| `PANEL_FIELD_MEDIA` | which LibSharedMedia type a media field selects from |
| `COLOR_FIELDS` | which boolean class-colours which colour |

`COLOR_FIELDS` is the generic seam the class-colour feature is built on: every colour read goes
through `Util.ResolveColor`, which consults it. A class colour replaces only the **RGB**; the stored
**alpha** is kept, because "class coloured" is a statement about hue, not about how solid the result
is. Tests pin that a picked colour and a class colour produce an otherwise identical backdrop — same
edge texture, same edge size, same alpha, same anchoring — since a drift there would make a
class-coloured border genuinely render fainter than a picked one.

Because the alpha is still the user's, the colour picker stays **enabled** while class colour is on:
it is the only control that sets opacity, so greying it out contradicted its own tooltip and left a
washed-out class colour unfixable. Its label gains an `(opacity)` suffix to say which half is live. A colour added later gets class-colour support in
the renderer, the CLI and the settings page from that one row — nothing re-decides "does this colour
support class colour?" at a call site. The accent bar proved this out: adding a third class-colourable
colour was one `COLOR_FIELDS` row and no new class-colour logic anywhere.

**Panel records are an `architecture-§5` storage carve-out.** They are not Schema rows: a schema row
is a fixed setting with one widget, and a panel is a variable-length user-created object. They are
mutated only through `NS.Registry`, which is the equivalent single write seam.

### Sanitizing

`Registry.Sanitize` runs on the way **in**, on every write, not on the way out. The stored file is
therefore always already valid: a record missing a field added in a later build is repaired the
first time it is touched, and a hand-edited SavedVariables file cannot feed a string width into
`SetWidth`.

One deliberate exception: **offsets are not clamped to the screen.** A legitimate multi-monitor
layout carries offsets far outside the current `UIParent`, and clamping on every write would quietly
destroy it the first time the user logged in at a lower resolution. Recovering a genuinely
unreachable panel is `Registry:Recover` — `/pm recover` and the settings button — and it is opt-in.

## Message bus (`architecture-§4`)

Three messages, one sender each, consumers registering on their **own** AceEvent target via
`NS.NewBusTarget()`. CallbackHandler keys callbacks by `(message, target)`, so two consumers sharing
a target would silently clobber each other.

| Message | Sender | Meaning | Consumers |
|---|---|---|---|
| `Ka0s_PanelMaster_PanelsChanged` | `modules/Registry.lua` | The **set** changed (add / delete / rename) — rebuild everything. | `Canvas`, the Panels settings page |
| `Ka0s_PanelMaster_PanelChanged` | `modules/Registry.lua` | **One** panel's fields changed — repaint just it. | `Canvas` |
| `Ka0s_PanelMaster_SettingsChanged` | `settings/Schema.lua` | An addon-level setting changed. | `Canvas` |

The split between the two panel messages is what lets a drag repaint one frame instead of all of
them. A test asserts that no other file sends any of the three.

`Canvas:Enable()` — which installs those subscriptions — is called from **`OnEnable`**. This is not
incidental: an early build omitted it, so every message broadcast into a bus with no listener and
nothing was live. The only repaints left were the two paths that call `Canvas:RenderAll()` directly
(lock/unlock and test mode), which is why panels appeared frozen until test mode was toggled. The
test harness hid it by calling `Canvas:Enable()` itself; it now drives the real `OnInitialize` /
`OnEnable`, so a dropped step fails the suite.

## Rendering

`Canvas.BuildSpec(record, settings)` is **pure**: record + settings → exactly what the frame should
look like, with every value already validated and clamped. All of "what does this panel render as"
is therefore unit-testable headlessly, and `applySpec` is a thin, uninteresting application of the
result. `spec.shown` folds the master switch and the panel's own `enabled` into one answer so no
call site has to remember both.

A panel is drawn as a background **texture** (an LSM `background` name, tinted with the resolved
colour) plus a `BackdropTemplate` **edge** (an LSM `border` name at the user's thickness). The
backdrop's `bgFile` is deliberately unused — it insets under the edge, and a panel wants its fill to
run to the frame's actual bounds.

The border lives on its **own child frame** (`f.borderFrame`), not on the panel frame itself. A
backdrop is always drawn at its own frame's bounds, so moving the border in or out relative to the
panel — `borderOffset` — is only possible by moving the frame that carries it. Being a child, it
inherits the panel's strata, level and alpha automatically, so the border can never end up on a
different layer from the panel it belongs to.

`SetBackdropBorderColor` **must** follow `SetBackdrop`: applying a backdrop resets its border colour
to white, so colouring first is silently undone. A test asserts the recorded colour survives.

### Frame names and the pool

Every panel frame is created under a deterministic global name, `PanelMaster_Panel_<slug>`, derived
from the panel's own name by `Util.Slugify`. That is a **public contract**: another addon or a
WeakAura anchors to it by name with no API call, and can work the name out from the panel name alone.

Two consequences follow, and both are load-bearing:

- **Slugs must be unique, not just names.** "Chat BG" and "Chat-BG" are two legal panel names that
  slugify to one frame name, and two frames cannot share a global name. `Registry` refuses the
  second on both create and rename.
- **The pool is keyed by frame name, not a flat stack.** A frame's name is fixed at `CreateFrame`
  time and can never change, so a released frame can only be reused by a panel wanting that same
  name. Delete a panel and re-create it with the same name and you get the same frame back.

Frames are still pooled rather than leaked (`hard rule #14`) — a user with thirty panels toggling
the master switch twice would otherwise leak sixty frames permanently — but the bound is "one frame
per distinct panel name used this session" rather than "one per live panel". Renaming a panel ten
times does leave ten hidden, unparented frames behind. That is the price of the naming contract, and
it is bounded by how often a human renames things.

The alternative considered and rejected: anonymous pooled frames plus `_G` aliases. It keeps a flat
pool, but hands out frames whose `GetName()` is `nil`, which breaks every consumer expecting a real
named frame.

### Mouseover fade

One shared `OnUpdate` at 10Hz drives every mouseover panel, rather than a script per panel.

It **polls** `MouseIsOver` rather than using `OnEnter`/`OnLeave`, because those require the frame to
take mouse input — and a panel that takes the mouse stops being click-through, which is the one
guarantee a backdrop must never break. Polling reads the cursor without claiming it.

While a panel is unlocked (globally or on its own) the fade is suspended and it is held at full
alpha: a panel resting at 0 alpha would be impossible to find and drag.

### Accent bars

A thin strip along one or more of a panel's edges, in the style of BenikUI's panels. Four textures
are created up front on the panel frame — one per edge — and shown or hidden per render; four
textures is cheaper than creating and destroying them as the edge set changes, and it keeps the
render path allocation-free.

They live on their **own child frame** (`accentFrame`), separate from the border's. That is purely
z-order: a child frame always draws above its parent's textures whatever draw layer those use, so
with the border on a child frame and the bars directly on the panel, the border covered the bars
regardless. `applySpec` therefore assigns explicit levels bottom-up — panel fill, then
`borderFrame` at `+1`, then `accentFrame` at `+2` — because left alone both children would default
to `parent + 1` and their order would come down to creation sequence. The base is read back with
`GetFrameLevel()` rather than reusing `spec.level`, since the client clamps a frame's level and the
value that landed may not be the one asked for.

Being a child of the panel is still what makes the bars inherit its strata and alpha: an accent bar
cannot end up on a different layer from the panel it accents, and it fades with the mouseover fade
with no extra bookkeeping.

Each bar is pinned to **both corners** of its edge, which makes "covers the entirety of that edge"
true by construction — the bar tracks the panel's size with no recalculation. `accentOffset` pushes
it outward (the detached look) or, when negative, over the panel's own area.

`accentEdges` is a **set**, not a single value, because any combination is legal. Two consequences:
`Util.EdgeSet` normalizes it on the way in so a hand-edited SavedVariables file cannot smuggle a
fifth "edge" into the render loop; and an **empty** set is preserved rather than defaulted back to
`TOP`, since unticking every edge is a legitimate state that must not be silently undone.

Bar textures come from LibSharedMedia's **statusbar** pool rather than `background` — statusbar
textures are authored to read as thin strips, and it is the pool a user has already curated for their
bars.

Each bar is a **frame**, not a bare texture, because it can carry a border of its own: a backdrop
needs a frame to live on. The fill is a texture filling that frame, and the bar's border gets a
further child frame so it can be offset — the same shape as the panel's border, built **lazily**
since it ships at size 0 and most panels never use it. Without that laziness every panel would carry
four more frames created for nothing.

## Combat

Panels are **non-secure** frames, so the render path is not combat-gated at all: creating, moving,
recolouring and hiding a plain backdrop frame is legal in combat, and gating it would mean a panel
that visibly failed to follow a settings change mid-pull.

Two things are gated, in the two different shapes the standard defines:

- **Unlock defers** (`events-frames-taint-§2`). Unlocking hands the user draggable frames, which is a
  bad thing to do mid-pull. `/pm unlock` in combat queues, prints a grey notice, and is replayed from
  `PLAYER_REGEN_ENABLED`. **Locking is never deferred** — it only makes the UI quieter, so refusing
  it would be the one case where the gate made things worse. An explicit lock also clears a queued
  unlock, or the queue would undo the user's own decision the moment combat ended. Per-panel unlocks
  queue and replay the same way, and a panel deleted mid-combat is dropped from the queue rather
  than resurrecting an unlock entry for a record that has gone.
- **The options panel refuses** (`options-ui-§2`). `Settings.OpenToCategory` is protected, so
  `/pm config` in combat prints a grey notice and returns. It does **not** replay: a panel that pops
  itself open the instant combat drops steals focus during recovery.

## Event wiring

| Event | Handler | Why |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `Canvas:RenderAll()` | Panels are drawn here, not at `OnEnable`: `UIParent`'s size is what recovery measures against and it is not final that early. |
| `PLAYER_REGEN_ENABLED` | `Unlock:ResumePending()` | Replays a combat-deferred unlock. |

## Slash surface

`/pm` (and the `/panelmaster` alias) via AceConsole. Every verb comes from `NS.COMMANDS` in
`settings/Schema.lua`, so the help index, the settings landing page's command list and the README
table are all generated from one table and cannot drift.

Schema-driven verbs: `config version get set list reset resetall debug help`.
Panel verbs: `new delete rename panels panel unlock lock preview recover`.

`/pm panel <name> [field] [value]` inspects and edits a single panel from the command line, using the
same `Registry:Set` seam the settings widgets and the drag handler use.

Output follows `slash-commands-§4/§5`: the cyan `[PM]` tag on every line, green headers, azure
`[group]` headers, gold keys, white values, no trailing colons. `Slash:BuildListLines`,
`BuildPanelLines` and `BuildPanelShowLines` return arrays rather than printing, so the output shape
is asserted in tests without capturing chat.

## Options UI

Blizzard `Settings.RegisterCanvasLayoutCategory` + raw AceGUI (`options-ui`). Three pages:

- **Ka0s Panel Master** (parent) — logo, tagline, the generated slash-command list.
- **General** — the schema rows, in a two-column grid.
- **Panels** — create, edit and delete the panels themselves.

The Panels page shows **one** panel's editor at a time, chosen from a dropdown. Stacking every
panel's editor grew past a screen at three panels and past a scrollbar's usefulness at ten, and
rebuilding all of them on every create or delete is exactly the O(N) teardown `options-ui-§11`
exists to prevent.

Creating a panel is committed by the EditBox's own **Okay** button, the same gesture as the rename
box in the editor below. That is safe because AceGUI's EditBox does **not** commit on focus loss:
`OnEnterPressed` is fired only by the Enter key, the Okay button and a drag-receive, and
`OnEditFocusLost` is never registered at all. (An earlier version added a separate Create button on
the mistaken assumption that tabbing away would create a panel.)

There is deliberately **no heading naming the selected panel** between the dropdown and the editor:
the dropdown already shows which panel is selected, so a heading repeating it was a third band of
chrome between choosing a panel and editing it. The panel selector carries no label either, which
makes it 14px shorter than a labelled control — so a compensating spacer (`LABEL_ROW_H`) sits above
it, or the `Edit` heading would look tighter than every other heading on the page.

`Reset` and `Delete` sit at the **top** of the editor beside `Enabled` and `Unlock`, because that is
where you look once you have decided you are done with a panel. A Delete parked at the foot of a long
scrolling form is one the user only reaches after scrolling past everything they might have wanted to
change instead. `Registry:Reset` restores the whole record from the template plus the profile's
New-Panel-Defaults — the same path `Registry:New` takes, so "reset" and "make a new one" cannot
drift — keeping only `id` and `name`, so the frame name survives and external anchors stay attached.

The editor emits a sequence of full-width **rows** into a `List`-layout group rather than pouring
every widget into one `Flow`. A single Flow reflows controls of differing heights into whatever gaps
it can find, so a checkbox rides up beside a slider's label and two unrelated settings share a line —
which is what made the first version look cluttered. Explicit rows, `Heading`-separated subsections,
and three named gap sizes (`EDITOR_SELECT_GAP` > `EDITOR_SECTION_GAP` > `EDITOR_ROW_GAP`) mean the
spacing itself carries the structure.

### Three widget workarounds

All three are live-client-only and none can be caught by the headless suite, which stubs AceGUI out.

**`AceGUI-3.0` ColorPicker (v28) does not reliably fire `OnValueConfirmed`.** Its `ColorCallback` is
invoked twice — once from `swatchFunc` (`isAlpha` nil) and once from `opacityFunc` (`isAlpha` true) —
and both read the *same* `GetColorRGB`/`GetColorAlpha`. The first call applies the colour and returns
via the `IsVisible()` branch; the second hits the function's own "no change, skip update" guard and
returns **before** reaching the `OnValueConfirmed` fire. So changing a colour without touching the
opacity slider — the overwhelmingly common case — fires `OnValueConfirmed` never. The widget's own
swatch still updates, because it calls `SetColor` on itself first, which is why the symptom was "the
swatch is the colour I picked but the panel is unchanged". Both colour pickers therefore bind
**`OnValueChanged` as well**, which fires while the picker is open and gives a live preview besides.

**`AceGUI-3.0-SharedMediaWidgets` fire `OnValueChanged` without calling `SetValue` first**, because
upstream assumes AceConfigDialog re-renders the whole panel afterwards. This is a canvas panel that
does not, so each callback pushes the value back explicitly or the dropdown keeps displaying the old
name even though the write landed. `core/LSMPatch.lua` is a further fixup for the same library: it
collapses the `LSM30_Border` widget's 42px preview tile, which otherwise leaves a gap beside the
closed dropdown.

**An open dropdown does not follow, or close with, a scrolling page.** AceGUI parents a dropdown's
open list to `UIParent` so it can overflow the panel, which means scrolling slides the control away
while its list stays floating where it was — frequently outside the settings window entirely. Nothing
in AceGUI closes it, so the page tracks every dropdown it builds (`trackDropdown`) and closes the
open one on any **user-driven** scroll.

Closing dispatches on the widget's **`type`**, never on which fields it happens to carry. A stock
AceGUI `Dropdown` also has a `.dropdown` field — its Blizzard `UIDropDownMenuTemplate` frame — so an
earlier field-presence check handed that frame to the SharedMedia library's pool-return, which
iterates a `contentRepo` a Blizzard frame does not have. The error propagated out of `MoveScroll` and
killed mouse-wheel scrolling on the whole page. A unit test pins the dispatch against hand-built
widget stand-ins, since the headless harness builds no real widgets.

The two scroll hooks: the `MoveScroll` override (the wheel path) and the
scrollbar's `OnMouseDown` (the drag path). `OnMouseDown` rather than the slider's `OnValueChanged`,
because that also fires from `FixScroll`'s own `SetValue` during layout — and opening a dropdown
triggers a relayout, so closing there would shut it the instant it opened. The registry is emptied at
the top of each rebuild, since AceGUI offers no per-widget "you were released" callback.

The **category is registered eagerly** at `OnInitialize` so the entry is always in the options list;
each **body is built lazily** on first `OnShow`, because AceGUI lays out against a width that is 0
until then. The header **Defaults button is also built in the first `OnShow`** (`options-ui-§5`,
anti-pattern #42): AceGUI is shared and UI skins restyle it by hooking `RegisterAsWidget`, so a
widget created during load is a race against every other addon's load order and can be left on
Blizzard's stock red art for the session.

The Panels page is the structural one — its content depends on how many panels exist — so it lives
behind `rebuilders` and repaints only on first paint, on an on-screen change, or on the next
`OnShow` after an off-screen one (`options-ui-§11`), never on every `OnShow`.

Defaults actions differ by page and by destructiveness: **General**'s resets settings only and is
safe behind Blizzard's un-gated footer control; **Panels**' is "delete every panel" (the genuine
stock state of that page) and is therefore confirm-gated behind `KA0S_PANELMASTER_DELETEALL`.

## Debug console

`debug-logging`: a 700×344 `DIALOG`-strata window in the vendored JetBrains Mono at 10pt, with
timestamped colour-coded `<HH:MM:SS> | [Tag] <content>` lines, a right-edge scrollbar and an
`N / MAX lines` counter (`debug-logging-§11`), Clear, Copy, and `UISpecialFrames` for ESC.

Logging state is **session-only** (`NS.State.debug`, never in SavedVariables) and **independent of
the window**: capture runs with the console closed, so a bug can be reproduced first and the log read
afterwards. `/pm debug` toggles the window; `/pm debug on|off` sets the flag through the single
`DebugLog:SetEnabled` seam, which also writes the console bracket and, on enable, the `[Init]`
summary.

`/pm debug dump` is the structured-dump verb (`debug-logging-§4`): it prints the registry's and the
renderer's views of the world side by side, including orphaned frames. A panel in the registry with
no frame — or the reverse — is the shape of every rendering bug this addon can have.

## Taint

There is none to speak of, and that is a design property rather than luck: the addon creates only
non-secure frames of its own, never touches a Blizzard frame, never reparents anything, and never
calls a protected API. The single protected call anywhere near it is `Settings.OpenToCategory`, which
is refused under lockdown.

## Known limitations

- **Panel names with spaces are awkward at the CLI.** `/pm rename` and `/pm panel` take the name as
  the first word, so a panel called "Chat BG" can be created and renamed *to*, but not addressed by
  its full name from the command line. Inventing a quoting syntax for a job the settings UI already
  does well was judged the worse trade.
- **Renaming a panel orphans anything anchored to it.** The frame name is derived from the panel
  name, and a frame's name cannot change — so a rename swaps frames and the old global name is left
  pointing at a hidden one. The settings page shows the current frame name so the change is visible;
  there is no migration for external anchors, and there cannot be.
- **Renames accumulate frames.** One per distinct panel name used in a session, never freed (see
  *Frame names and the pool*). Bounded by human behaviour rather than by code.
- **No per-panel strata *level* UI.** `level` is in the record and settable from the CLI, but the
  settings page exposes only the strata dropdown; two panels in the same strata are ordered by
  creation.
- **The mouseover fade is a hard cut, not a smooth fade.** Alpha snaps between the two values at the
  10Hz poll. An animated transition is a natural refinement.
- **Class colour is the player's own class only.** There is no "colour by target's class" or
  per-panel class override; the flag reads `UnitClass("player")`.
- **`/pm recover` is manual.** It never runs at login, because a panel deliberately parked mostly
  off-screen is a legitimate layout and a login-time sweep would silently rearrange it.
