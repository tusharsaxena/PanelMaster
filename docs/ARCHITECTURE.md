# Architecture — Ka0s Panel Master

How the addon is put together: the module map, the data model, the message bus, the slash surface,
the event wiring, and the decisions worth knowing before changing anything.

Built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards). Read the
root [CLAUDE.md](../CLAUDE.md) and [agent-context.md](agent-context.md) first.

## What it is

A backdrop-panel creator, in the lineage of kgPanels and ElvUI's panels. The user creates named
rectangles with a color, a border, a size, a position and a layer, and the addon draws them behind
the rest of the UI. That is the whole product.

**It does not host anything.** A panel is not a container: nothing is reparented into it, no other
addon's frames are moved, and no Blizzard frame is touched. It is scenery — a visual grouping cue
behind frames that stay exactly where their own addons put them. This constraint is why the addon
needs no secure frames, no combat gating on its render path, and no taint story.

## Module map

Load order is fixed by the TOC (`layout`); `core/Compat.lua` is first, `settings/` last.

| File | Publishes | Role |
|---|---|---|
| `core/Compat.lua` | `NS.Compat` | The only caller of deprecated / varying APIs. Addon metadata, screen size, UI scale, LibSharedMedia registration and lookup, class color, cursor test. |
| `core/LSMPatch.lua` | — | Upstream fixup for the vendored `LSM30_Border` widget's misaligned preview tile. Lives in `core/`, not `libs/`, so a lib refresh cannot blow it away. |
| `core/Constants.lua` | `NS.Constants` | Strata, anchor-point and edge enums, geometry bounds, the panel record template, the field type/order/media/color maps, preview specs, media paths. |
| `core/Namespace.lua` | `NS.name/version/PREFIX/SCHEMA_VERSION` | Metadata bootstrap. The cyan `[PM]` chat tag lives here. |
| `core/State.lua` | `NS.State` | Session-only runtime state: `debug`, `unlocked`, `unlockedPanels`, `preview`, `previewIDs`. Never persisted. |
| `core/Util.lua` | `NS.Util`, `NS.Print` | Path splitting, clamping, rounding, snapping, boolean and color parse/format, name cleaning, deep copy, and the secret-safe shared chat printer. |
| `core/PanelMaster.lua` | `NS.addon`, `NS.bus` | AceAddon registration, the printer reclaim, the bus-target factory, `OnInitialize` / `OnEnable`. |
| `core/Database.lua` | `NS:InitDB`, `NS:RunMigrations`, `NS:SweepPreviewPanels` | AceDB open on the shared "Default" profile, the migration seam, the preview-orphan sweep, the profile-change callbacks, the `[Init]` summary. |
| `defaults/Profile.lua` | `NS.defaults.profile` | Per-character defaults: the (empty) panel registry, `nextID`, and the settings block. |
| `defaults/Global.lua` | `NS.defaults.global` | The `schemaVersion` stamp — the one account-wide value. |
| `modules/Registry.lua` | `NS.Registry` | **Owns `db.profile.panels`.** Create, delete, rename, reset, copy-from, field edits, sanitizing, slug-uniqueness, off-screen recovery, profile reload. Sole sender of both panel messages. |
| `modules/Canvas.lua` | `NS.Canvas` | Turns records into frames. The pure `BuildSpec`, the name-keyed frame pool, the offset border child frame, the four accent-bar frames and their lazy borders, the shared mouseover ticker, targeted and full repaints. |
| `modules/Unlock.lua` | `NS.Unlock` | Unlock mode (outline, label, drag, snap), global and per-panel, and preview mode. |
| `modules/DebugLog.lua` | `NS.DebugLog`, `NS.Debug` | The on-screen debug console and the gated logging sink. |
| `settings/Schema.lua` | `NS.Schema` | The settings schema (one row per setting). Sole sender of `SettingsChanged`. |
| `settings/Slash.lua` | `NS.Slash`, `NS.COMMANDS` | `/pm` dispatch, the generated help index, every CLI verb, and the command table they all read (at the bottom of the file, below the verbs it calls). |
| `settings/PanelEditor.lua` | `NS.PanelEditor` | The Panels page's body: the create box, the panel selector, one panel's editor, the page's mutation actions and its two bus triggers. Peeled out of `settings/Panel.lua` (`layout-§1`) and drawn with that file's helpers, which it reads from `NS.Panel.__ui`. |
| `settings/Panel.lua` | `NS.Panel` | The Blizzard Settings canvas: header, scroll frame, tooltips, the schema renderer, landing page, General, and registration of all four categories. Owns the open-dropdown tracking that closes a list on scroll, and drives the editor through `E:WireBus` / `E:BuildPage` / `E:Rebuild`. |

## Data model

Saved to `PanelMasterDB`, in AceDB profiles, with every character starting on the **shared
"Default" profile** (`AceDB:New(..., true)`).

Shared rather than character-keyed because a panel layout is a description of a UI and most people
run one UI: under a per-character default, anyone wanting a common layout has to rebuild or copy it
on every alt, whereas under this one anyone wanting a private layout makes one on the Profiles page
in two clicks. The asymmetry favours the shared default.

Note AceDB's precedence — `sv.profileKeys[charKey] or defaultProfile or charKey` — so a character
that has already been assigned a profile keeps it. This governs where *new* characters land.

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
| `COLOR_FIELDS` | which boolean class-colors which color |

`COLOR_FIELDS` is the generic seam the class-color feature is built on: every color read goes
through `Util.ResolveColor`, which consults it. A class color replaces only the **RGB**; the stored
**alpha** is kept, because "class colored" is a statement about hue, not about how solid the result
is. Tests pin that a picked color and a class color produce an otherwise identical backdrop — same
edge texture, same edge size, same alpha, same anchoring — since a drift there would make a
class-colored border genuinely render fainter than a picked one.

Because the alpha is still the user's, the color picker stays **enabled** while class color is on:
it is the only control that sets opacity, so graying it out contradicted its own tooltip and left a
washed-out class color unfixable. Its label gains an `(opacity)` suffix to say which half is live. A color added later gets class-color support in
the renderer, the CLI and the settings page from that one row — nothing re-decides "does this color
support class color?" at a call site. The accent bar proved this out: adding a third class-colorable
color was one `COLOR_FIELDS` row and no new class-color logic anywhere.

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

`Registry:Recover` derives the legal offset range from the record's **anchor**, not from a fixed
half-screen: the offset is measured from `relPoint`, so a `LEFT`-anchored panel legally runs `0…w`, a
`RIGHT`-anchored one `-w…0`, and only a `CENTER`-anchored one `-w/2…+w/2` (the vertical axis the same
way, keyed on `TOP`/`BOTTOM`). Applying the CENTER range to all nine points is what used to drag a
perfectly visible `TOPLEFT` panel inward.

### Preview mode

Preview writes its placeholders into the registry as **real records**, which is what makes the
preview exercise the real render path rather than a mock that can drift from it. Two things track
them, and both are needed:

| Half | Lives in | Survives a `/reload`? |
|---|---|---|
| `NS.State.previewIDs` | session state | no — the fast in-session path |
| `rec[C.PREVIEW_FIELD]` (`preview = true`) | the record itself | yes — the recovery path |

`NS:SweepPreviewPanels()` walks `db.profile.panels` backwards, removes every marked record and
returns the count. It runs from `NS:InitDB` — after `NS:RunMigrations`, before
`NS:RegisterProfileCallbacks`, therefore before `Canvas:Enable` and the first `RenderAll`, so an
orphan is never drawn — and again on the profile-reload path, since a copied profile can carry
someone else's orphans. It is idempotent, and the marker is additive, so `NS.SCHEMA_VERSION` stays
at 1.

The marker is deliberately **not** in `PANEL_FIELD_TYPE`, `PANEL_FIELD_ORDER` or `PANEL_TEMPLATE` —
the CLI cannot set it, `/pm panel <name>` does not print it, and a normally-created panel never has
it — and it is in the registry's `COPY_EXCLUDED`, so `CopyFrom` cannot smear it onto a real panel.
Known trade-off: a preview panel the user runs `/pm panel <name> reset` on loses the marker and
becomes a real panel.

Both transitions go through `U:SetUnlocked`, never a direct write to `NS.State.unlocked`, so leaving
preview clears the per-panel unlock and pending sets the same way any other lock does. The order is
**registry first, lock second**: `SetUnlocked` repaints, so the placeholders have to exist before it
runs. Preview's implied unlock passes `SetUnlocked`'s private `immediate` flag, which skips the
combat gate: the placeholders are non-secure frames preview has just created itself, so no secure
write is involved, and deferring only that half would leave the user mid-pull with three anonymous,
mouse-transparent rectangles under a message that never mentions preview.

## Message bus (`architecture-§4`)

Three messages, one sender each, consumers registering on their **own** AceEvent target via
`NS.NewBusTarget()`. CallbackHandler keys callbacks by `(message, target)`, so two consumers sharing
a target would silently clobber each other.

| Message | Sender | Meaning | Consumers |
|---|---|---|---|
| `Ka0s_PanelMaster_PanelsChanged` | `modules/Registry.lua` | The **set** changed (add / delete / rename) — rebuild everything. | `Canvas`, the Panels settings page |
| `Ka0s_PanelMaster_PanelChanged` | `modules/Registry.lua` | **One** panel's fields changed — repaint just it. | `Canvas` |
| `Ka0s_PanelMaster_SettingsChanged` | `settings/Schema.lua` | An addon-level setting changed **in a way a panel can show**. | `Canvas` |

Not every row broadcasts: `settings.snapToGrid` and `settings.gridSize` carry no `onChange`, because
`Unlock.SnapPosition` reads them live at drag-stop and nothing renders from them. Announcing would
repaint every panel on each tick of the Grid size slider for no visible difference.

The split between the two panel messages is what lets a drag repaint one frame instead of all of
them. A test asserts that no other file sends any of the three.

A caller that changes the set N times at once uses the **batch seams** rather than N single calls:
`Registry:NewBatch(specs)` and `Registry:DeleteBatch(keys)` mutate N records and broadcast
`PanelsChanged` **once** — the shape `Registry:DeleteAll` already had. Preview mode is the caller
that needs them: standing up three placeholders used to rebuild every consumer three times.

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
color) plus a `BackdropTemplate` **edge** (an LSM `border` name at the user's thickness). The
backdrop's `bgFile` is deliberately unused — it insets under the edge, and a panel wants its fill to
run to the frame's actual bounds.

The border lives on its **own child frame** (`f.borderFrame`), not on the panel frame itself. A
backdrop is always drawn at its own frame's bounds, so moving the border in or out relative to the
panel — `borderOffset` — is only possible by moving the frame that carries it. Being a child, it
inherits the panel's strata, level and alpha automatically, so the border can never end up on a
different layer from the panel it belongs to.

`SetBackdropBorderColor` **must** follow `SetBackdrop`: applying a backdrop resets its border color
to white, so coloring first is silently undone. A test asserts the recorded color survives.

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

A thin strip along one or more of a panel's edges, in the style of BenikUI's panels. **On by
default**, with the panel's own border off to match: the shipped look leans on the bar for
definition, and a panel wearing both an outline and a bar reads as busy rather than framed. The bar
ships with a 1px **black** hairline of its own — black rather than the panel border's gray because
its job is to separate the bar from what is behind it, and against a bright background a bare class
color bleeds into the scenery. Four textures
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
recoloring and hiding a plain backdrop frame is legal in combat, and gating it would mean a panel
that visibly failed to follow a settings change mid-pull.

Two things are gated, in the two different shapes the standard defines:

- **Unlock defers** (`events-frames-taint-§2`). Unlocking hands the user draggable frames, which is a
  bad thing to do mid-pull. `/pm unlock` in combat queues, prints a gray notice, and is replayed from
  `PLAYER_REGEN_ENABLED`. **Locking is never deferred** — it only makes the UI quieter, so refusing
  it would be the one case where the gate made things worse. An explicit lock also clears a queued
  unlock, or the queue would undo the user's own decision the moment combat ended. Per-panel unlocks
  queue and replay the same way, and a panel deleted mid-combat is dropped from the queue rather
  than resurrecting an unlock entry for a record that has gone. **Preview is the one documented
  bypass** — see the preview section above.
- **The options panel refuses** (`options-ui-§2`). `Settings.OpenToCategory` is protected, so
  `/pm config` in combat prints a gray notice and returns. It does **not** replay: a panel that pops
  itself open the instant combat drops steals focus during recovery.

## Event wiring

| Event | Handler | Why |
|---|---|---|
| `PLAYER_ENTERING_WORLD` | `Canvas:RenderAll()` | Panels are drawn here, not at `OnEnable`: `UIParent`'s size is what recovery measures against and it is not final that early. |
| `PLAYER_REGEN_ENABLED` | `Unlock:ResumePending()` | Replays a combat-deferred unlock. |
| `PLAYER_LOGIN` | `Panel:Register()` | A second **eager** attempt at settings-category registration, for the load order where `Settings`/AceGUI were not there yet in `OnInitialize`. `Register` is idempotent, so it is a no-op on a normal login. Not a deferral to first `/pm config` (anti-pattern #22). Subscribed from `OnInitialize`, not `OnEnable`: AceAddon runs `OnEnable` from inside its own `PLAYER_LOGIN` handler, and subscribing mid-dispatch misses that firing — the only one a non-LoD addon gets. |

## Slash surface

`/pm` (and the `/panelmaster` alias) via AceConsole. Every verb comes from `NS.COMMANDS` in
`settings/Slash.lua`, so the help index, the settings landing page's command list and the README
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

Blizzard `Settings.RegisterCanvasLayoutCategory` + raw AceGUI (`options-ui`). A parent category and
three subcategories:

- **Ka0s Panel Master** (parent) — logo, tagline, the generated slash-command list.
- **General** — the schema rows, in a two-column grid.
- **Panels** — create, edit and delete the panels themselves.
- **Profiles** — AceDBOptions' own options table, rendered by AceConfigDialog into a container
  parented to our canvas.

Profiles is the **one** place `AceConfigDialog` is used. `anti-patterns` forbids it for content and
carves out Profiles explicitly, and the carve-out earns itself: AceDBOptions returns a complete,
correct table for create / switch / copy / reset / delete plus the per-character, class, realm and
faction scopes, and a hand-rolled AceGUI equivalent would be a large pile of code whose only
distinguishing feature would be its own bugs. It has no Defaults button — the page already carries
its own destructive controls, and a second "reset" meaning something else would be a trap. Both libs
are `OptionalDeps`, so their absence means no Profiles page rather than a broken one.

Switching profile swaps `db.profile` wholesale, so `core/Database.lua` registers AceDB's
`OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` callbacks and delegates to
`Registry:ReloadProfile` — in the registry rather than the database so `PanelsChanged` keeps exactly
one sender. The reload re-runs migrations and re-sanitizes every record, since an incoming profile
may predate the current build. Without it the previous profile's panels would simply stay on screen.

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
makes it 14px shorter than a labeled control — so a compensating spacer (`LABEL_ROW_H`) sits above
it, or the `Edit` heading would look tighter than every other heading on the page.

The editor opens with a **General** section in decision order — which panel is this (name, and the
option to copy another's look), is it on (Enabled / Unlock), am I done with it (Reset / Delete). The
frame name lives in the name box's **tooltip** rather than as a permanent second label: it is
reference information you need once, when wiring something else up to this panel.

`Registry:CopyFrom` copies every field except `id`, `name` and the four geometry fields. Position is
excluded because the point of copying is to make a panel *match* another while staying where it is —
copying position too would land the two exactly on top of each other. Size **is** copied: matching
dimensions is usually what was wanted, and unlike position it cannot make a panel disappear. Values
are deep-copied, or the two panels would share a color array and editing one would change the other.

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
and both read the *same* `GetColorRGB`/`GetColorAlpha`. The first call applies the color and returns
via the `IsVisible()` branch; the second hits the function's own "no change, skip update" guard and
returns **before** reaching the `OnValueConfirmed` fire. So changing a color without touching the
opacity slider — the overwhelmingly common case — fires `OnValueConfirmed` never. The widget's own
swatch still updates, because it calls `SetColor` on itself first, which is why the symptom was "the
swatch is the color I picked but the panel is unchanged". Both color pickers therefore bind
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
open one on any **user-driven** scroll. Tracking lives on the **render context** (`ctx.dropdowns`),
one registry per page: a single file-level list meant the Panels page's rebuild emptied the General
page's tracking too, after which scrolling General left its open list floating.

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

Its body lives in `settings/PanelEditor.lua`, a sibling in the same folder (`layout-§1`): the editor
was by far the largest thing in `settings/Panel.lua` and shares none of the page chrome around it.
`P:Register` wires the bus (`E:WireBus`) at registration and the page's `OnShow` calls `E:BuildPage`
then `E:Rebuild`, so the lazy-build contract is unchanged. The editor draws with the page's own
helpers — the scroll frame, the tooltip attacher, the section heading, the paired-button width and
the open-dropdown registry — published once as the internal `NS.Panel.__ui` and bound on first use,
since the TOC loads the editor *before* the page.

It has exactly **two** triggers, both on the bus, and no widget callback rebuilds the page itself:

| Message | Meaning | Response |
|---|---|---|
| `MSG_PANELS` | the SET of panels changed (create, delete, rename) | one `runRebuilders` |
| `MSG_PANEL` | one field of one panel changed (CLI, drag, `Reset`, `CopyFrom`) | `P:RefreshPanels` — the open editor's per-control `refreshers`, in place; never a rebuild (anti-pattern #39) |

`MSG_PANEL` returns early unless the id is the one the editor is showing. A mutating control sets the
selection *before* it mutates, so the single rebuild lands on the right panel; the create box, whose
id does not exist yet, parks the new panel's **name** in `ctx.pendingSelect` and the bus handler
resolves it. A rebuild clears `ctx.refreshers` first, since every closure in it holds a widget the
rebuild is about to release. The color-picker refresher uses `SetColor`, which fires no callback and
therefore cannot re-enter `Registry:Set`.

Defaults actions differ by page and by destructiveness: **General**'s resets settings only and is
safe behind Blizzard's un-gated footer control; **Panels**' is "delete every panel" (the genuine
stock state of that page) and is therefore confirm-gated behind `KA0S_PANELMASTER_DELETEALL`.

## Debug console

`debug-logging`: a 700×344 `DIALOG`-strata window in the vendored JetBrains Mono at 10pt, with
timestamped color-coded `<HH:MM:SS> | [Tag] <content>` lines, a right-edge scrollbar and an
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

## Shipped media

Four logo assets, one of which the game can actually load:

| File | Size | Ships to players | Purpose |
|---|---|---|---|
| `panelmaster.logo.tga` | 512×512, 24-bit RLE | **yes** | The runtime asset — `C.LOGO_PATH`, drawn on the settings landing page |
| `panelmaster.logo.png` | 1254×1254 | no | Master art; the source the others are rendered from |
| `panelmaster.logo.jpg` | 1024×1024 | no | Project page / CDN |
| `panelmaster.logo.256.jpg` | 256×256 | no | README, thumbnails |

WoW cannot load `.png` or `.jpg` at runtime **at all**, and rescales any texture that is not a power
of two — hence a 512 TGA rather than the 1254 master. `.pkgmeta` excludes the three non-runtime
renders, so a player's download does not carry megabytes of files their client physically cannot use.

The failure mode here is silent: a missing or wrongly-named texture renders **nothing** and raises
**no error**, so it surfaces as a blank settings page that reads like a layout bug. A test therefore
asserts that the file `C.LOGO_PATH` names exists on disk, and the same for the debug console's
vendored font.

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
  *Frame names and the pool*). Bounded by human behavior rather than by code.
- **No per-panel strata *level* UI.** `level` is in the record and settable from the CLI, but the
  settings page exposes only the strata dropdown; two panels in the same strata are ordered by
  creation.
- **The mouseover fade is a hard cut, not a smooth fade.** Alpha snaps between the two values at the
  10Hz poll. An animated transition is a natural refinement.
- **Class color is the player's own class only.** There is no "color by target's class" or
  per-panel class override; the flag reads `UnitClass("player")`.
- **`/pm recover` is manual.** It never runs at login, because a panel deliberately parked mostly
  off-screen is a legitimate layout and a login-time sweep would silently rearrange it.
