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
| `core/Constants.lua` | `NS.Constants` | Strata, anchor-point, edge and artwork enums (with their derived membership sets and option lists), geometry and scale bounds, the frame ladder, the panel record template, the field type/order/media/enum/color maps, preview specs, media paths. |
| `core/Namespace.lua` | `NS.name/version/PREFIX/SCHEMA_VERSION` | Metadata bootstrap. The cyan `[PM]` chat tag lives here. |
| `core/State.lua` | `NS.State` | Session-only runtime state: `debug`, `unlocked`, `unlockedPanels`, `preview`, `previewIDs`. Never persisted. |
| `core/Util.lua` | `NS.Util`, `NS.Print` | Path splitting, clamping, rounding, snapping, boolean and color parse/format, name cleaning, deep copy, and the secret-safe shared chat printer. |
| `core/PanelMaster.lua` | `NS.addon`, `NS.bus` | AceAddon registration, the printer reclaim, the bus-target factory, `OnInitialize` / `OnEnable`. |
| `core/Database.lua` | `NS:InitDB`, `NS:RunMigrations`, `NS:SweepPreviewPanels` | AceDB open on the shared "Default" profile, the migration seam, the preview-orphan sweep, the profile-change callbacks, the `[Init]` summary. |
| `defaults/Profile.lua` | `NS.defaults.profile` | Per-character defaults: the (empty) panel registry, `nextID`, and the settings block. |
| `defaults/Global.lua` | `NS.defaults.global` | The `schemaVersion` stamp — the one account-wide value. |
| `locales/enUS.lua` | `NS.L` | The canonical locale table and its key-is-the-string fallback. Carries no keys in 0.1.0 — see **Localization**. |
| `locales/PostLoad.lua` | — | Derived-key aliases, loaded after every locale file so it reads whatever the active locale resolved. Empty in 0.1.0. |
| `modules/Registry.lua` | `NS.Registry` | **Owns `db.profile.panels`.** Create, delete, rename, reset, copy-from, field edits, sanitizing, slug-uniqueness, off-screen recovery, profile reload. Sole sender of both panel messages. |
| `modules/Artwork.lua` | `NS.Artwork` | The bundled-art catalog and the pure `BuildArtSpec` geometry — fill math, UV crop/flip/rotation composition, tint resolution. Touches no frames and calls no WoW API. Loads **before** `Canvas`, which reads it. |
| `modules/Canvas.lua` | `NS.Canvas` | Turns records into frames. The pure `BuildSpec`, the name-keyed frame pool, the background, border, accent and artwork child frames (the last clipping and re-leveled per render), the four accent bars and their lazy borders, the shared mouseover ticker, targeted and full repaints. |
| `modules/Unlock.lua` | `NS.Unlock` | Unlock mode (outline, label, drag, snap), global and per-panel, and preview mode. |
| `modules/DebugLog.lua` | `NS.DebugLog`, `NS.Debug`, `NS.DebugBuild` | The on-screen debug console and the gated logging sink. `NS.Debug` carries the addon's **only** debug gate (`debug-logging-§4`); `NS.DebugBuild` is the same sink for a site whose arguments cost something to produce, deferring that work past the same gate rather than growing a second one. Its builder must be a plain function reference with its arguments passed unbound — a closure would be allocated at the call site, before the gate, which is the cost being avoided. |
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
                       accentBorderColor, accentBorderClassColor,
  artTexture, artCustomPath, artColor, artClassColor, artAlpha,
  artFill, artPoint, artX, artY, artScale,
  artRotation, artFlipH, artFlipV, artLayer }
```

`core/Constants.lua`'s `PANEL_TEMPLATE` is the single definition of that shape — the shipped default
AND the source every missing field is repaired from. Four sibling maps derive everything else from
it, so adding a field is one template entry plus one row in whichever of these applies:

| Map | Drives |
|---|---|
| `PANEL_FIELD_TYPE` | CLI coercion and validation |
| `PANEL_FIELD_ORDER` | the `/pm panel <name>` dump order |
| `PANEL_FIELD_MEDIA` | which LibSharedMedia type a media field selects from |
| `PANEL_FIELD_ENUM` | which closed value list an `enum` field is validated against |
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

### The artwork fields

Fifteen `art*` fields carry the per-panel art layer, prefixed to match the existing `accent*`
convention and added to the template, `PANEL_FIELD_TYPE` and `PANEL_FIELD_ORDER` like any other
field — which is precisely why `Registry.Sanitize`, `R:Reset`, `R:CopyFrom`, profile switching and
the whole `/pm panel` surface pick them up with no per-field work.

| Field | Default | Kind | Meaning |
|---|---|---|---|
| `artTexture` | `"None"` | `artwork` | Catalog id, or the two reserved values `None` / `Custom` |
| `artCustomPath` | `""` | `string` | Texture path, read only when `artTexture == "Custom"` |
| `artColor` | `{1,1,1,1}` | `color` | Tint |
| `artClassColor` | `false` | `boolean` | Class-color override for `artColor` |
| `artAlpha` | `1.0` | `number` | Art opacity, multiplied onto the resolved tint's alpha |
| `artFill` | `"FIT"` | `enum` | `STATIC` / `STRETCH` / `FILL` / `FIT` / `TILE` |
| `artPoint` | `"CENTER"` | `point` | Anchor within the art frame |
| `artX` / `artY` | `0` | `number` | Offset from that anchor |
| `artScale` | `1.0` | `number` | Size multiplier, clamped to `C.MIN_ART_SCALE`…`C.MAX_ART_SCALE` (0.1–4) |
| `artRotation` | `0` | `enum` | `0` / `90` / `180` / `270`, stored as **numbers** |
| `artFlipH` / `artFlipV` | `false` | `boolean` | Mirror horizontally / vertically |
| `artLayer` | `"ABOVE_BG"` | `enum` | `BELOW_BG` / `ABOVE_BG` / `ABOVE_ALL` |

`artColor` is one more `COLOR_FIELDS` row (`artColor → artClassColor`) and no new class-color code
anywhere — the third time that seam has paid for itself.

`artTexture` defaults to `"None"`, so a record that predates this change renders exactly as before —
`BuildArtSpec` returns `nil` for it before touching anything else.

The five closed lists are **not** five branches in `Registry:Set`. One generic `"enum"` kind reads
`C.PANEL_FIELD_ENUM`, so a sixth enum field later costs one row and no code; `artTexture` has its own
`"artwork"` kind validated case-insensitively against `Artwork.List()`, mirroring how `"media"`
already validates against the live LibSharedMedia list and refuses a typo with the real list.

Two deliberate asymmetries in `Sanitize`:

- **`artTexture` is not validated against the catalog on write**, exactly as the LSM media names
  are not. An id that resolves to nothing now can be valid a moment later (an art pack appending to
  `Artwork.Catalog` loads after this addon), and `BuildArtSpec` already degrades an unresolvable
  id to "draw nothing". Rewriting it to `"None"` on first touch would destroy the user's choice
  permanently to fix a problem that fixes itself. `R:Set` still refuses a typo up front, which is
  when there is somebody to tell.
- **`artX` / `artY` are unbounded**, like the panel's own offsets: the offset is measured against a
  panel size `Sanitize` does not know, so an invented bound would clamp a good placement on a large
  panel the first time the record was touched.

An **empty** `artCustomPath` is a legitimate state — Custom is picked and the path is not typed yet
— so only a non-string falls back to the template, the same distinction the accent edge set makes.
The four enum values do snap back to their template default when what is stored is not a member,
because an unknown `artFill` would otherwise produce a nil size that lands in `SetSize` and aborts
the rest of that panel's paint.

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

That fill texture lives on its **own child frame** (`f.bgFrame`, `SetAllPoints`), not on the panel
frame itself. The reason is artwork: a child frame always draws above its parent's textures whatever
draw layer those use, so with the fill on the panel there is **no** frame level a child could take
to get underneath it, and `artLayer = "BELOW_BG"` would be unreachable. The texture keeps the field
name `f.bg`, so every call site and test that paints it is unchanged; only what it hangs off moved.

The border lives on its **own child frame** (`f.borderFrame`), not on the panel frame itself. A
backdrop is always drawn at its own frame's bounds, so moving the border in or out relative to the
panel — `borderOffset` — is only possible by moving the frame that carries it. Being a child, it
inherits the panel's strata, level and alpha automatically, so the border can never end up on a
different layer from the panel it belongs to.

`SetBackdropBorderColor` **must** follow `SetBackdrop`: applying a backdrop resets its border color
to white, so coloring first is silently undone. A test asserts the recorded color survives.

### The frame ladder

Everything a panel draws sits on a child frame with an explicitly assigned level, seven slots deep,
stated once in `core/Constants.lua` (`C.ART_FRAME_LEVEL`, `C.BG_FRAME_LEVEL`,
`C.BORDER_FRAME_LEVEL`, `C.ACCENT_FRAME_LEVEL`, `C.UNLOCK_FRAME_LEVEL`) and applied in `applySpec`
— except the last, which `modules/Unlock.lua` builds lazily and sets itself:

```
f                       base          the panel frame
  f.artFrame  BELOW_BG  base + 1
  f.bgFrame             base + 2      background fill
  f.artFrame  ABOVE_BG  base + 3      ← artLayer default
  f.borderFrame         base + 4
  f.accentFrame         base + 5
  f.artFrame  ABOVE_ALL base + 6
  f.overlay.frame       base + 7      unlock outline and name label
```

The unlock overlay is on the ladder at all because of this change. It used to be textures on the
panel frame itself, kept above the panel's art by *draw layer*; that works only while the art is
also a region of `f`. Once the fill became a child frame, frame level took precedence over draw
layer and the fill drew straight over the outline — so on every unlock and every preview, the gold
outline and the panel name vanished under the panel's own 85%-opaque background. It now has its own
frame above every other rung, which is what its job requires: nothing may cover the thing that makes
an invisible panel findable.

### Panel levels are strided

A panel's own frame level is `level × C.PANEL_LEVEL_STRIDE`, not `level`. A panel occupies eight
rungs, so consecutive raw levels would *interleave* — one panel's accent bar landing on the same
frame level as the next panel's background fill, with the winner decided by frame creation order,
which the name-keyed pool does not keep in panel order. The `level` setting means "higher draws in
front"; the stride is what makes that true for every distinct value rather than only for values far
enough apart to clear the footprint.

The levels are **spread out** rather than consecutive because the artwork has to *interleave* with
the other three: three of the six slots are the same single `f.artFrame`, whose level is reassigned
per render from `C.ART_FRAME_LEVEL[art.layer]`. Frame levels are mutable at any time, so one frame
covers all three choices — three art frames per panel would be two created to sit hidden forever.
This is also the only arrangement in which "behind the background" and "above the accent bar" are
both expressible.

Left alone, every child frame merely defaults to `parent + 1`, which would pile the fill, the border
and the accent onto one level and leave their order to creation sequence. `base` is read back with
`GetFrameLevel()` rather than reusing `spec.level`, since the client clamps a frame's level and the
value that landed may not be the one asked for.

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
regardless. Their explicit levels — `borderFrame` at `+4`, `accentFrame` at `+5` — come from the
ladder above, which is where the reasoning for the whole stack lives.

Being a child of the panel is still what makes the bars inherit its strata and alpha: an accent bar
cannot end up on a different layer from the panel it accents, and it fades with the mouseover fade
with no extra bookkeeping.

Each bar is pinned to **both corners** of its edge, which makes "covers the entirety of that edge"
true by construction — the bar tracks the panel's size with no recalculation. `accentOffset` pushes
it outward (the detached look) or, when negative, over the panel's own area.

The **left and right bars turn their texture a quarter turn** (`C.ACCENT_TEXCOORD_ROT90`). A
LibSharedMedia statusbar texture is authored as a horizontal bar — its height carries the bevel, its
width is the fill direction — so stretched into a tall thin strip unrotated, the bevel runs along the
bar's length instead of across its thickness and reads as a smear. The rotation uses the
**eight-argument** `SetTexCoord`, which maps a texture coordinate to each screen corner and is the
only form that can transpose the axes; the four-argument form crops and flips but cannot rotate. It
is re-applied on every repaint rather than once at creation, because `SetTexture` resets a texture's
coords and a pooled frame would otherwise inherit the previous panel's orientation. Left and right
take the *same* rotation, matching top and bottom, which are also drawn identically rather than
mirrored.

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

### Artwork

`modules/Artwork.lua` owns two things and touches no frames: `Artwork.Catalog`, the list of
bundled art, and `Artwork.BuildArtSpec(rec, panelW, panelH)`, the record-to-geometry math.
`Canvas.BuildSpec` calls it with the panel's **clamped** render size and hangs the result on
`spec.art`, `nil` meaning "this panel draws no artwork" — the default, and the cheapest answer.
`applyArtwork` then applies that spec and decides nothing.

The math lives outside the renderer for the same reason `BuildSpec` is pure. Fill math is the part
of artwork most likely to be wrong and hardest to eyeball in-game — a `FILL` crop off by half a
pixel of texture space looks fine until the panel is resized — so all five fill types can be checked
against resize in the headless harness instead of by launching the client and squinting.

A catalog row is `{ id, category, label, file, w, h, tintable, credit }`:

- `id` is the **stored** value and part of the saved-variables contract. It is never renamed —
  renaming one degrades every panel using it to "no artwork" on the next load, silently.
- `file` is a bare stem; the path is rebuilt from `C.ARTWORK_PATH_PREFIX` at render time, so the art
  survives the addon folder being moved or renamed. Same reasoning as storing LSM *names*, not paths.
- `w` / `h` are the **authored** pixel size, declared rather than measured: `Texture:GetWidth()`
  returns 0 until the file has loaded, which is not guaranteed on the first render pass, and
  `STATIC`, `FIT` and `TILE` cannot compute anything without a native size. Declaring it is also
  what keeps this module frame-free.
- `tintable = false` marks finished full-color art; `BuildArtSpec` forces its RGB to white (keeping
  the computed alpha), because tinting finished art can only darken it toward the tint.
- `credit` is the attribution record redistribution requires.

Two reserved ids sit outside the catalog: `"None"` (the default, draws nothing) and `"Custom"`
(draw `artCustomPath`). Custom counts as tintable — tinting your own art white is a no-op — and
assumes a nominal `Artwork.CUSTOM_NATIVE_SIZE` of 256, since learning a user file's real pixel size
would need a frame and a load round-trip. `Artwork.Entry` is a linear scan rather than a prebuilt
index precisely so a runtime append to `Artwork.Catalog` works; `Artwork.List` is the ordered
dropdown source (`None` first, catalog sorted by category order then label, `Custom` last, with
`"Category: Label"` prefixes because the widget is a flat list).

Every division in the fill math is guarded — a nil, zero or negative `W`, `H`, `w` or `h` returns
`nil` rather than reaching a division, because WoW accepts inf/nan texture coordinates silently and
renders them as a garbage smear. `STRETCH` deliberately ignores `artScale`: stretching *is* "match
the panel exactly". Position is honoured for `STATIC` and `FIT` only; the other three cover the
panel exactly, so the spec forces `CENTER, 0, 0` rather than letting an offset shove panel-filling
art out through the clip.

Crop, flip and rotation compose on the same four UV corners in that fixed order — flip then rotate
is not the same transform as rotate then flip, and stating the order is what makes the two
checkboxes and the dropdown mean something stable together — and are emitted as the eight-argument
`SetTexCoord` list in its own `UL, LL, UR, LR` order. Quarter turns only: an exact axis transpose
needs no resampling and never samples outside the crop, whereas rotating a *cropped* quad by an
arbitrary angle samples beyond it and, under CLAMP, drags the edge pixels across the corners.
Applying the transpose once to the identity quad reproduces `C.ACCENT_TEXCOORD_ROT90` exactly — the
accent bars' rotation and the artwork's are one rotation. `Texture:SetRotation` was rejected: it is
implemented in terms of texture coordinates internally and therefore fights `SetTexCoord`, which
every fill type but `STRETCH` needs.

`f.artFrame` gets `SetClipsChildren(true)`, guarded on the method existing the way `SetBackdrop`
already is so the headless harness degrades rather than errors. That clip is what makes "artwork
renders inside the panel's bounds" true for offset and scaled art. It is on the **art** frame
specifically, never on the panel, because the accent bars deliberately hang outside the panel's
bounds and a clip one level up would eat them.

`release()` clears the art texture and hides the art frame, so a pooled frame reused by another
panel cannot inherit the previous panel's artwork.

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

## Localization

`locales/enUS.lua` publishes `NS.L` with a metatable whose `__index` returns the key itself, so an
unwrapped or untranslated string renders as its English source rather than erroring or showing a raw
token (`localization-§1`). Keys **are** the English source strings (`localization-§2`), which is why
the US-English sweep mattered: a locale key is the one place a spelling is not merely cosmetic, and
renaming one later means moving every key and every call site in a single change.

`locales/PostLoad.lua` loads after every locale file and holds derived-key aliases — strings whose
translation always matches another key's — so a translator never does the same work twice.

**Both files are deliberately empty of keys in 0.1.0.** No user-facing string routes through `NS.L`
yet; every label, tooltip and message is hardcoded English. That is a scope decision for the first
release rather than an oversight, and it is precisely what made the US-English sweep cheap to do —
there were no keys to move alongside the strings. The seam is kept so a later pass can wrap strings
(`NS.L["Enable panels"]`) without touching call sites. There is no `local L` alias until the first
string is wrapped, so the file stays luacheck-clean.

Two things must **never** be routed through `NS.L`:

| Not localized | Why |
|---|---|
| Panel names | User-supplied data, not UI strings. A user's "Chat" is their text, and translating it would rename their panel — and with it the `PanelMaster_Panel_<slug>` frame name other addons anchor to. |
| Stored `point` / `strata` tokens | Matched on stable identifiers, never on a localized display string (`localization-§4`). A dropdown may show a translated label, but the value written to SavedVariables stays `TOPLEFT` / `LOW`. |

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

Bundled artwork lives under `media/artwork/`, one 512×512 32-bit TGA per catalog row, addressed at
runtime through `C.ARTWORK_PATH_PREFIX` plus the row's `file` stem. The same silent failure mode
applies, which is why a row's path is worth asserting against the filesystem the way the logo's is.
`tools/artwork/import.py` is what produces those files. It converts art authored *outside* the repo
with Pillow — luminance-to-alpha for a white-on-black plate, or a magenta chroma key for full-color
art, which is the only one of the two that can separate dark art from a dark background. It also erases a generator's watermark,
letterboxes a non-square plate rather than distorting it, and normalizes the RGB of fully
transparent pixels, which is invisible under normal blending but is read by other blend modes and
was otherwise left to whichever code path a plate happened to take.

The source plate each asset was converted from is kept under `media/artwork/raw/`, named for the
catalog id it produces, so a piece can be re-derived at a different size or with a corrected margin
without going back to whoever made it. It is committed to git but excluded from the package by
`.pkgmeta` — the same reasoning as the logo's master renders, since the client cannot load a `.png`
at all. Both the asset requirements and the contribution rules are in
[artwork-spec.md](artwork-spec.md) and the README; `tools/` is an **accepted, documented deviation**
from the Ka0s WoW Addon Standard (approved 2026-07-31 — the standard defines no build-tooling
location, and this is the first non-Lua source in the tree).

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
  settings page exposes only the strata dropdown. Two panels sharing a strata *and* a level are
  ordered by frame creation, which the name-keyed pool does not keep in panel order; distinct
  levels order cleanly (see *Panel levels are strided*).
- **The mouseover fade is a hard cut, not a smooth fade.** Alpha snaps between the two values at the
  10Hz poll. An animated transition is a natural refinement.
- **Class color is the player's own class only.** There is no "color by target's class" or
  per-panel class override; the flag reads `UnitClass("player")`.
- **`/pm recover` is manual.** It never runs at login, because a panel deliberately parked mostly
  off-screen is a legitimate layout and a login-time sweep would silently rearrange it.
