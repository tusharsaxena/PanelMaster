# Architecture — Ka0s Panel Master

How the addon is put together: the module map, the data model, the message bus, the slash surface,
the event wiring, and the decisions worth knowing before changing anything.

Built to the [Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards). Read the
root [CLAUDE.md](../CLAUDE.md) first.

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
| `core/Util.lua` | `NS.Util` | Path splitting, clamping, rounding, snapping, boolean and color parse/format, name cleaning, deep copy. The secret-safe shared chat printer left this file for `core/CoreSetup.lua`. |
| `core/CoreSetup.lua` | `NS.Core`, `NS.Print`, `NS.Util.print`, `NS.SafeToString`, `NS.IsConcatSafe`, **`NS.LIBKA0S_MISSING`** | The `LibKa0s-Core-1.0` seam: the secret-safe stringifier and the prefixed chat printer, republished under the names this addon has always used. Also publishes **`NS.LIBKA0S_MISSING`**, the one cause clause every other LibKa0s seam appends its own consequence to — a cross-file contract three other files depend on, not an implementation detail of this one, and set OUTSIDE the missing-library branch because they read it on both paths. Core's window-chrome half is declined: the only standalone window here is the debug console, which the DebugLog major draws. |
| `core/DebugLogSetup.lua` | `NS.DebugLog`, `NS.Debug`, `NS.DebugBuild` | The `LibKa0s-DebugLog-1.0` seam, replacing the 429-line `modules/DebugLog.lua`. The console window, both formatters, the buffer and the enable seam are the library's; what stays this addon's is `NS.DebugBuild` (the same gated sink for a site whose arguments cost something to produce — its builder must be a plain function reference with its arguments passed unbound, since a closure would be allocated at the call site, before the gate, which is the cost being avoided) and `D:Diagnose()` (the structured dump verb, which reports what *this* addon believes is on screen). `NS.Debug` carries the addon's **only** debug gate (`debug-logging-§4`). |
| `core/PanelMaster.lua` | `NS.addon`, `NS.bus` | AceAddon registration, the printer reclaim, the bus-target factory, `OnInitialize` / `OnEnable`. |
| `core/Database.lua` | `NS:InitDB`, `NS:RunMigrations`, `NS:SweepPreviewPanels` | AceDB open on the shared "Default" profile, the migration seam, the preview-orphan sweep, the profile-change callbacks, the `[Init]` summary. |
| `defaults/Profile.lua` | `NS.defaults.profile` | Per-character defaults: the (empty) panel registry, `nextID`, and the settings block. |
| `defaults/Global.lua` | `NS.defaults.global` | The `schemaVersion` stamp — the one account-wide value. |
| `locales/enUS.lua` | `NS.L` | The canonical locale table and its key-is-the-string fallback. Carries no keys in 0.1.0 — see **Localization**. |
| `locales/PostLoad.lua` | — | Derived-key aliases, loaded after every locale file so it reads whatever the active locale resolved. Empty in 0.1.0. |
| `modules/Registry.lua` | `NS.Registry` | **Owns `db.profile.panels`.** Create, delete, rename, reset, copy-from, field edits, sanitizing, name and frame-name uniqueness (the latter on create only — see *Frame names and the pool*), off-screen recovery, profile reload. Sole sender of both panel messages. |
| `modules/Artwork.lua` | `NS.Artwork` | The bundled-art catalog and the pure `BuildArtSpec` geometry — fill math, UV crop/flip/rotation composition, tint resolution. Touches no frames and calls no WoW API. Loads **before** `Canvas`, which reads it. |
| `modules/SunnArtPacks.lua` | `NS.SunnArtPacks` | The known-pack manifest: what the official Sunn packs contain, keyed by theme path, with **measured** section dimensions. Pure data, generated by `tools/sunn/build_manifest.py`. Loads **before** `SunnArt`, which reads it. |
| `modules/SunnArt.lua` | `NS.SunnArt` | The adapter for user-installed **Sunn - Viewport Art** packs. Reads another addon's globals, synthesizes one composed whole-bar catalog row per theme and appends them to `Artwork.Catalog` at `OnEnable`. Discovery only — it draws nothing and ships no pack bytes. |
| `modules/Canvas.lua` | `NS.Canvas` | Turns records into frames. The pure `BuildSpec`, the name-keyed frame pool, the background, border, accent and artwork child frames (the last clipping and re-leveled per render), the four accent bars and their lazy borders, the shared mouseover ticker, targeted and full repaints. |
| `modules/Unlock.lua` | `NS.Unlock` | Unlock mode (outline, label, drag, snap), global and per-panel, and preview mode. |
| `settings/Schema.lua` | `NS.Schema` | The settings schema (one row per setting). Sole sender of `SettingsChanged`. |
| `settings/Slash.lua` | `NS.Slash`, `NS.COMMANDS` | The `LibKa0s-Slash-1.0` seam plus everything the library does not own. The dispatcher, the generated help index, the landing-page row formatter, the schema CLI (`list`/`get`/`set`/`reset`/`resetall`/`version`) and the type-aware value parser are the library's. **`NS.COMMANDS` stays this addon's** — positional `{ name, description, handler }` triples, passed in rather than owned, because the settings landing page renders the same rows and a library that owned the table would force the options major to resolve the slash major to read it. Every PANEL verb stays too: they act on registry records, not schema rows. Two descriptor adapters: `groupKey` (this schema groups by `row.group`, the library defaults to `row.page`) and `parse` (the library matches an enum case-sensitively; `/pm set settings.defaultStrata low` has always worked here). |
| `settings/PanelEditor.lua` | `NS.PanelEditor` | The Panels page's body: the create box, the panel selector, one panel's editor, the page's mutation actions and its two bus triggers. Peeled out of `settings/Panel.lua` (`layout-§1`) and drawn with that file's helpers, which it reads from `NS.Panel.__ui`. |
| `settings/OptionsSetup.lua` | `NS.Helpers`, `NS.SetBuildMain` | The `LibKa0s-Options-1.0` seam. `NS.Helpers` **is** the library instance rather than a wrapper (options-ui-§1), which is what lets `settings/Panel.lua` decorate it in place. Holds the descriptor: the write seam (`NS.Schema:Set`, already the two-argument shape the library calls with), `rowsForPage`, the boot validation, the AceGUI stash and the drag throttle. `buildMain` reaches the landing page through a forward declaration `settings/Panel.lua` fills in, because that file loads after this one. |
| `settings/Panel.lua` | `NS.Panel` | What LibKa0s-Options-1.0 does **not** own: the open-dropdown registry that closes a list on scroll, the paired-button width, the landing page's body, the Profiles page, and the four page builders. The canvas factory, the header and breadcrumb, the lazy Defaults button, the scroll frame, the scrollbar patch, section headings, spacers, tooltips, the five widget makers and the two-column flow engine are all the library's now. Two library members are wrapped **on the instance** — `RenderField` and `EnsureScroll` — because the flow engine resolves both from the instance table at call time, so a host-side helper beside them is bypassed by every page it draws. Drives the editor through `E:WireBus` / `E:BuildPage` / `E:Rebuild`. |

## The LibKa0s seams, and the load order they pin

Four of the five `LibKa0s` majors are adopted (`Core`, `DebugLog`, `Slash`, `Options`); `Perf` is
declined on structural grounds — see `LIBKA0S-31` in [`pending/LEDGER.md`](pending/LEDGER.md). The
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
| `settings/Slash.lua` | `", so the slash help index and the settings CLI (list/get/set/reset) are unavailable."` |
| `settings/OptionsSetup.lua` | `", so the settings panel is unavailable."` |

A degraded install therefore says the same thing about **why** at every site and a different thing
about **what** at each one. The wording is the whole Ka0s collection's and is not this addon's to
reword — `tests/test_libka0s.lua` pins the clause on both paths.

The TOC order is not arbitrary. Each seam's own header states its constraints; the ones that bind:

- `libs\LibKa0s\LibKa0s.xml` sits **after** LibStub and Ace3. `Core` resolves LibStub; the other
  four resolve `LibKa0s-Core-1.0` and `return` **before** `LibStub:NewLibrary` when it is absent or
  too old, so the major is simply never registered.
- `core/CoreSetup.lua` after `core/Namespace.lua` (which defines `NS.PREFIX`, passed to the printer
  descriptor verbatim) and after `core/Util.lua` (which owns `NS.Util`), and **before**
  `core/PanelMaster.lua`, whose AceConsole embed clobbers `NS.Print` and reclaims it from
  `NS.Util.print`. Publishing on both keys is what keeps that reclaim load-bearing and correct.
  It must also precede the six files taking the printer as a `local print = NS.Print` **file-scope
  upvalue** — `modules/Unlock.lua`, `settings/Schema.lua`, `settings/Slash.lua`,
  `settings/PanelEditor.lua`, `settings/Panel.lua` — or the swap silently no-ops while appearing to
  work.
- `core/DebugLogSetup.lua` after `core/Constants.lua` (`C.FONT_MONO`) and `core/CoreSetup.lua`.
  Everything else its descriptor touches is reached through a **closure**, which is what let the
  console move out of `modules/` into `core/` without inverting a dependency.
- `settings/OptionsSetup.lua` after `settings/Schema.lua` and `settings/Slash.lua`, and **before**
  `settings/Panel.lua`, which captures the instance at file scope. `settings/PanelEditor.lua` binds
  its helpers lazily inside its own rebuild, so it pins nothing.

`tests/test_harness.lua` derives the suite's load list from the TOC rather than keeping a second
copy, so a file added to one and not the other cannot go untested.

## Data model

Saved to `PanelMasterDB`, in AceDB profiles, with every character starting on the **shared
"Default" profile** (`AceDB:New(..., true)`).

Shared rather than character-keyed because a panel layout is a description of a UI and most people
run one UI: under a per-character default, anyone wanting a common layout has to rebuild or copy it
on every alt, whereas under this one anyone wanting a private layout makes one on the Profiles page
in two clicks. The asymmetry favors the shared default.

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
{ id, name, frameName, enabled, width, height, point, relPoint, x, y, strata, level, scale, alpha,
  bgTexture,     bgColor,    bgClassColor,
  borderTexture, borderSize, borderOffset, borderColor, borderClassColor,
  mouseover, mouseoverAlpha,
  accentEnabled, accentEdges, accentTexture, accentThickness, accentOffset,
                 accentColor, accentClassColor,
  accentBorderTexture, accentBorderSize, accentBorderOffset,
                       accentBorderColor, accentBorderClassColor,
  artTexture, artCustomPath, artColor, artClassColor, artDesaturate, artBlend, artAlpha,
  artFill, artPoint, artX, artY, artScale,
  artRotation, artFlipH, artFlipV, artLayer }
```

`id`, `name` and `frameName` are the record's **identity** — what the panel *is* rather than how it
looks — and the three seams that rewrite a record wholesale all preserve them: `R:Reset` restores
them after the template rewrite, `COPY_EXCLUDED` keeps `CopyFrom` off them, and `R:Rename` writes
only `name`. `frameName` and the preview marker are deliberately absent from `PANEL_TEMPLATE` and
from `PANEL_FIELD_TYPE`, so neither is a settable field.

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

Sixteen `art*` fields carry the per-panel art layer, prefixed to match the existing `accent*`
convention and added to the template, `PANEL_FIELD_TYPE` and `PANEL_FIELD_ORDER` like any other
field — which is precisely why `Registry.Sanitize`, `R:Reset`, `R:CopyFrom`, profile switching and
the whole `/pm panel` surface pick them up with no per-field work.

| Field | Default | Kind | Meaning |
|---|---|---|---|
| `artTexture` | `"None"` | `artwork` | Catalog id, or the two reserved values `None` / `Custom` |
| `artCustomPath` | `""` | `string` | Texture path, read only when `artTexture == "Custom"` |
| `artColor` | `{1,1,1,1}` | `color` | Tint |
| `artClassColor` | `false` | `boolean` | Class-color override for `artColor` |
| `artDesaturate` | `false` | `boolean` | Collapse the art to grayscale **before** the tint multiplies against it |
| `artBlend` | `"BLEND"` | `enum` | `BLEND` / `ADD` — the texture's blend mode; `ADD` is the "Glow" look |
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

The six closed lists are **not** six branches in `Registry:Set`. One generic `"enum"` kind reads
`C.PANEL_FIELD_ENUM` — four rows now, `artFill`, `artRotation`, `artLayer` and `artBlend` — so a
further enum field later costs one row and no code; `artPoint` rides the shared `"point"` kind that
the panel's own anchor already uses; and `artTexture` has its own `"artwork"` kind validated
case-insensitively against `Artwork.List()`, mirroring how `"media"` already validates against the
live LibSharedMedia list and refuses a typo with the real list.

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
Four of the closed lists — `artFill`, `artRotation`, `artLayer` and `artPoint` — do snap back to
their template default when what is stored is not a member, because an unknown `artFill` would
otherwise produce a nil size that lands in `SetSize` and aborts the rest of that panel's paint.
`artBlend` is the one that does **not** get snapped in `Sanitize`: it is defended a step later, in
`BuildArtSpec`, which falls back to the template value for anything outside `C.ART_BLEND_SET`. An
unknown blend mode cannot produce a nil geometry the way the other four can — the worst it reaches is
`SetBlendMode`, which the spec never lets it reach.

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
someone else's orphans. It is idempotent, and the marker is additive, so it needed no schema bump of
its own.

The marker is deliberately **not** in `PANEL_FIELD_TYPE`, `PANEL_FIELD_ORDER` or `PANEL_TEMPLATE` —
the CLI cannot set it, `/pm panel <name>` does not print it, and a normally-created panel never has
it — and it is in the registry's `COPY_EXCLUDED`, so `CopyFrom` cannot smear it onto a real panel.

`R:Reset` **refuses** a marked record outright, with a reason the caller prints. It rewrites the
record from `C.PANEL_TEMPLATE`, which carries no marker, so a reset used to strip it and promote a
throwaway placeholder into a permanent panel the user then had to delete by hand — the one remaining
path by which preview could leave litter in a saved layout. Refusing rather than re-stamping:
resetting a placeholder to the shipped template is not a meaningful thing to want, and a tagged
notice explains why more usefully than silently doing nothing. With that closed, the marker survives
every registry write seam, which is what makes "preview off removes exactly what preview added" true
unconditionally.

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

`scale` is the panel's own frame scale, applied by `applySpec` **before** the size and the anchor —
that order is load-bearing, because a frame's scale is the unit both `SetSize` and `SetPoint`'s
offsets are expressed in, so setting it afterwards leaves the panel sized and placed in the previous
scale's units until some unrelated write repaints it. It is deliberately not folded into
`width`/`height`: the stored size is what the user typed and what the editor's sliders show. Bounded
by `C.MIN_PANEL_SCALE`/`C.MAX_PANEL_SCALE` (0.25–4.0) rather than by the artwork's own scale range
(0.1–4.0), because `artScale` resizes a texture inside a panel whose clickable area is unchanged
while this resizes the frame itself — a floor of 0.1 would walk straight around the `C.MIN_SIZE`
floor that exists to keep a panel findable and grabbable. One consequence worth knowing: because
`SetPoint` offsets are in the frame's own scaled units, changing the scale also moves the panel
relative to its anchor.

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

Every panel frame is created under a global name, `PanelMaster_Panel_<slug>`, derived from the
panel's name by `Util.Slugify` **at create time and then stored on the record** as `rec.frameName`.
That is a **public contract**: another addon or a WeakAura anchors to it by name with no API call.

The frame name is **identity, like the id** — `Registry.FrameName` reads the stored field and never
recomputes it. `R:Reset` preserves it alongside `id` and `name`; `COPY_EXCLUDED` keeps `CopyFrom`
from smearing one panel's global onto another; and `R:Rename` does not touch it at all.

Three consequences follow, and all are load-bearing:

- **A rename is a relabel.** The panel keeps the frame it already had, so nothing anchored to it
  moves and no frame is abandoned. This is the fix for the pair of bugs (#6, #7) that the derived
  frame name caused: a frame's name is immutable after `CreateFrame`, so recomputing it meant a
  rename had to retire the old frame and stand up a new one — silently orphaning every external
  anchor, with no migration possible, and leaking one frame per distinct name typed.
- **Frame names must be unique on create, and only on create.** "Chat BG" and "Chat-BG" are two
  legal panel names wanting one frame name, and two frames cannot share a global. `Registry` refuses
  the second at create. It does **not** check on rename, because a rename claims no new global. A
  name that looks free can still be refused: a panel created as "Alpha" and later renamed still
  holds `PanelMaster_Panel_Alpha`, and the refusal names it.
- **The pool is keyed by frame name, not a flat stack.** A released frame can only be reused by a
  panel wanting that same name. Delete a panel and re-create it with the same name and you get the
  same frame back.

Frames are pooled rather than leaked (`hard rule #14`) — a user with thirty panels toggling the
master switch twice would otherwise leak sixty frames permanently — and the bound is now "one frame
per distinct frame name used this session", which renaming no longer grows.

The trade this buys, stated plainly: after a rename the frame name no longer matches the panel's
name and stops being derivable from it. Predictability at create was judged the lesser half of the
contract — you look the name up once, when you wire something to the panel, and the settings page's
name-box tooltip is where. Anchors that silently stop tracking, days later, are the worse failure.

The alternative considered and rejected: anonymous pooled frames plus `_G` aliases. It keeps a flat
pool, but hands out frames whose `GetName()` is `nil`, which breaks every consumer expecting a real
named frame.

`NS.SCHEMA_VERSION` is **2** for this: the v1 → v2 migration stamps `frameName` onto every panel by
deriving it from the name, which reproduces exactly the global that build already gave the frame, so
the upgrade moves nobody's anchors. `R.Sanitize` fills the field the same way for a record arriving
by another route (an imported profile, a test), which is what covers profiles other than the one
active when the migration ran.

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

A catalog row is `{ id, category, label, file, w, h }`, and **every row is
generated** by `tools/artwork/update_catalog.py` from what is actually in `media/artwork/`. That
script's scan is also imported and reused by `tools/artwork/make_poster.py`, so the catalog and the
README's contact sheet are two renderings of one list and cannot disagree about what shipped:

- `id` is the **stored** value and part of the saved-variables contract. It is never renamed —
  renaming one degrades every panel using it to "no artwork" on the next load, silently.
- `file` is a bare stem; the path is rebuilt from `C.ARTWORK_PATH_PREFIX` at render time, so the art
  survives the addon folder being moved or renamed. Same reasoning as storing LSM *names*, not paths.
- `category` is **derived from the folder** the art sits in, so
  `media/artwork/faction/expansion/12-midnight/harati.tga` becomes
  `"Faction -> Expansion -> 12 Midnight"`. There is no fixed category list: a declared one could
  only be a second opinion about the same thing, and would need editing every time a folder appears.
- `w` / `h` are the pixel size measured at generation time and then **declared** in the row rather
  than read at runtime: `Texture:GetWidth()` returns 0 until the file has loaded, which is not
  guaranteed on the first render pass, and `STATIC`, `FIT` and `TILE` cannot compute anything
  without a native size. Declaring it is also what keeps this module frame-free.
- There is no `tintable` field. Every piece takes the per-panel tint, whose default is white and
  therefore a no-op. Tinting finished full-color art does muddy it — multiplication can only drag
  every hue toward the tint — which is what `artDesaturate` is for: it drains the art to grayscale
  in hardware first, so the tint multiplies against neutral gray and returns a clean, saturated
  version of the chosen color.

`applyArtwork` writes both of the tone controls onto every quad's texture, in the order the effect
requires: `SetDesaturated` **before** `SetVertexColor`, since the two compose and grayscale-then-tint
is the whole point; then `SetBlendMode(art.blend)`. Both are written unconditionally rather than only
when they differ from the default, because these textures are **pooled** — a value one panel set
would otherwise leak into the next panel that reused the object. `SetDesaturated` is guarded on
existing, an absence rather than a rename, so it does not go through `Compat`.

Two reserved ids sit outside the catalog: `"None"` (the default, draws nothing) and `"Custom"`
(draw `artCustomPath`). Custom assumes a nominal `Artwork.CUSTOM_NATIVE_SIZE` of 256, since learning a user file's real pixel size
would need a frame and a load round-trip. `Artwork.Entry` is a linear scan rather than a prebuilt
index precisely so a runtime append to `Artwork.Catalog` works; `Artwork.List` is the ordered
dropdown source (`None` first, catalog sorted by category then label, both alphabetically, `Custom` last, with
`"Category: Label"` prefixes because the widget is a flat list).

Every division in the fill math is guarded — a nil, zero or negative `W`, `H`, `w` or `h` returns
`nil` rather than reaching a division, because WoW accepts inf/nan texture coordinates silently and
renders them as a garbage smear. `STRETCH` deliberately ignores `artScale`: stretching *is* "match
the panel exactly". Position is honored for `STATIC` and `FIT` only; the other three cover the
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

`release()` clears **every** art texture and hides the art frame, so a pooled frame reused by another
panel cannot inherit the previous panel's artwork.

**Fitting a panel to its art is an action, not a stored mode.** `Registry:FitToArtwork(key)` sets
**both axes** to the art's PRESENTED size — `Artwork.NativeSize`'s answer (the whole piece, which
for a composed row is the virtual bar rather than one section), transposed when `artRotation` is 90
or 270, then multiplied by `artScale`. Both are read through the same enum and clamp seams the fill
math uses, so a record holding junk fits to the size it will actually be drawn at. It sanitizes
afterwards so the result meets the
same MIN/MAX clamp as any stored size, fires `MSG_PANEL`, and returns `false` plus a printable
reason when there is nothing to fit to.

Adopting the native size outright was rejected while fitting was an always-on flag, on the grounds
that it would throw a 1024px wall across the screen for one piece and a letterbox for another. As a
button the trade inverts: nothing happens unless it is pressed, so the honest answer to "fit this
panel to its artwork" is the artwork's actual size, and a panel that comes out too big is resized by
the same hand that asked.

The target is the size **`STATIC`** draws at. `FIT` is the one fill that still will not fill the
panel afterwards, and that is `FIT`'s own definition rather than a miss: it contains the art in the
panel and *then* applies `artScale`, so fitting to its output would be a fixed point only at scale 1
and a shrinking spiral below it — press twice at 0.5 and the panel is a quarter the size. Its two callers are the editor's
**Fit to artwork** button and `/pm panel <name> fitart`, which sits in the field slot the way
`deleteall` sits in the name slot.

It was a boolean record field once (`artAutosize`, with a `C.ART_AUTOSIZE_FIELDS` set naming the
writes that re-derived). That shape had two problems a button does not: it silently overwrote a
height the user had typed, and it needed `height` explicitly carved out of the re-derive set or
typing one undid itself on every keystroke. Neither the field nor the trigger set exists any more,
so `height` is an ordinary field with nothing reaching behind the user to change it.

### Composites, and the Sunn adapter

`modules/SunnArt.lua` discovers user-installed **Sunn - Viewport Art** packs and appends catalog rows
for them. It ships no pack bytes and draws nothing: it reads another addon's globals and synthesizes
rows, which the ordinary `Artwork` and `Canvas` seams then resolve and draw. Injection runs at
`OnEnable` rather than at file scope, because a pack is a separate addon whose Lua has not
necessarily run when this module loads, and it is idempotent — a second call replaces its own rows
rather than duplicating them, identified by the `sunn-` id prefix so nothing but our additions is
ever removed.

**One row per theme** — the whole bar, under the theme's own name. A **composed row** carries
`sections`, the ordered list of absolute section paths, and is the only row in the addon that is not
one texture; a one-section theme is a composite of one and carries no `sections`, so it takes the
ordinary single-texture route. Every Sunn row also carries an absolute `path`, which wins over the
bundled derivation: `C.ARTWORK_PATH_PREFIX` is rooted at *this* addon and cannot reach another's
folder by construction.

Per-section rows (`Blackrock (left)`, and a `-1`/`-2`/`-3` id each) were dropped. They turned the
twelve official packs' 88 themes into 270 dropdown entries, four fifths of them fragments of
something listed three lines above; a single strip is still reachable through **Custom path**, which
is what that control is for. The `-bar` suffix on a multi-section id survives the removal even
though nothing needs disambiguating any more — ids are the saved-variables contract, and a rename is
a breaking change whether or not the reason for the name still holds.

A composite is rendered as a **virtual atlas**: the bar is treated as one image of the whole bar's
size, `BuildArtSpec` runs against it completely unchanged, and only then is its single rectangle cut
into N. That is the whole design, and it is what keeps fill, scale, anchor, crop, flip, rotation,
tint, desaturate and blend meaning exactly what they mean for a single texture — the alternative
was a second set of semantics to define, document and keep in agreement with the first.

- Section *i* owns the band `[(i-1)/N, i/N]` of the virtual image, and each band is intersected with
  the crop the fill already chose. A `FILL` that pushes the left section off the panel therefore
  simply does not emit it, rather than needing a rule about it. The intersection is tested against a
  fraction of the span rather than `hi > lo`, because a crop landing exactly on a band edge is the
  common case (`FILL` centers its window) and in floating point the vanishing sections otherwise
  survive by an ulp as sub-pixel slivers, which draw as a bright seam.
- Placement is `transformRect`, the screen-space counterpart of `composeUV`. Both take fractions of
  the unturned art and compose flip-then-turns in the **same order**, and the turn permutation is
  read off `composeUV`'s own corner shuffle rather than derived independently: one turn there makes
  the screen's horizontal axis run along *reversed v* and its vertical along *u*. A rotated bar
  therefore stacks its sections vertically and a horizontal flip reverses their order, neither
  special-cased anywhere.
- Quads are anchored at the **same** `art.point` as the whole rect, offset from whichever edge that
  point names. Re-anchoring each to `CENTER` would have been shorter and drifts the bar apart on
  resize whenever the rect is anchored by an edge.
- `TILE` splits only the horizontal axis — the vertical repeat stays a `REPEAT` wrap, since that one
  is inside a single file — so a tiled bar is `copies × sections` quads, each `CLAMP` horizontally
  and `REPEAT` vertically. `Artwork.MAX_ART_QUADS` (24) caps the total; over budget the copy count
  drops and each tile grows, so the panel stays **covered** rather than going partly bare, and
  `art.tileClamped` records it for the harness.

Sunn's per-theme `overlap` is **not** an overlap between sections — sections are flush
(`SunnArt_Core.lua:322` anchors each to the previous one's `TOPRIGHT`). It is the transparent band at
the top of the artwork, and it is consumed as a **content window**: a row declares `h` net of the
band and `contentV0` as where its content starts in the file, and `BuildArtSpec` maps content space
onto file space at the last moment. Because that is a row-level property, the per-section rows get
the same crop through the ordinary single-texture path, and `Artwork.NativeSize` needs no change at
all — which is what makes autosize shape a panel around visible art rather than padding. `TILE`
forces the crop to zero, because a `REPEAT` wrap repeats a whole file and not a sub-range of one.
See `ARTWORK-07`, `ARTWORK-08` and `ARTWORK-09` in [`pending/LEDGER.md`](pending/LEDGER.md) for the
declared section size, the crop interpretation and the two merge orders.

**The known-pack fallback.** Discovery from a pack's own registration needs that pack's Lua to have
run, and every official pack TOC carries `## Dependencies: SunnArt` — enforced by the client before
any Lua executes. So a disabled or unloadable SunnArt means nothing registers and the feature goes
silent, even though the textures are ordinary files that WoW draws regardless. Since Sunn has not
shipped since 2024-08, that is the expected end state rather than a hypothesis.
`modules/SunnArtPacks.lua` is the list that survives it: 88 themes across 12 packs, generated by
`tools/sunn/build_manifest.py` from an installation that has them. Two rules keep it from becoming a
competing source of truth — **live registration wins per theme** (the `seen` set is the whole test,
so precedence is structural rather than an ordering rule that can be got backwards), and a theme is
offered only when its pack's **folder is actually installed**, read via `Compat.AddOnFolders`, which
lists folders on disk including disabled ones.

**The folder gate applies to live discovery too**, which is not obvious — a theme that registered
must have had its Lua run, so surely its folder is there. Two of the four sources break that.
`SunnArt.db.global.themes` is saved variables, so a theme the player built in SunnArt's Advanced
options outlives the pack being deleted; and `SunnCustomTheme` is a hand-edited file that can name
anything at all. Both produce a dropdown entry that draws nothing, which reads as this addon being
broken rather than the art being absent. WoW exposes no way to ask whether a texture *file* exists,
so the pack folder is the only evidence available — and for a manifest theme it is a real check,
since the generator verified the files when it measured them. `S.Installed()` is therefore defined
as `#S.Themes() > 0` rather than as its own inspection of the globals, so it cannot answer yes to a
question the dropdown then answers no to.

A nil roster means "cannot tell" and offers the theme anyway, because withholding every theme would
disable a working feature where offering a missing one merely draws nothing.

The manifest also carries the one fact registration never does: **measured** section dimensions.
SunnArt hard-codes 2:1 and 250 of the 270 section files are indeed 512×256 — but five official themes
are square and three are 1024 wide, and SunnArt draws those squashed because its own arithmetic
cannot express them. `sectionSize` therefore prefers the manifest for every theme it knows, however
that theme was discovered; `S.SECTION_W`/`S.SECTION_H` remain only as the fallback for a theme
nobody has measured. See `ARTWORK-07` and `ARTWORK-10`.

Every spec therefore carries `art.quads`, and a single texture is a **one-element list** — so
`applyArtwork` has one path and no branch that can rot. The flat `width`/`height`/`point`/`x`/`y`/`uv`
fields remain as the whole-bar rect: for a composite that is not any single quad but the rectangle
they collectively fill, and for everything else it is `quads[1]` exactly, which the suite asserts.
`f.artTextures` holds the textures, index 1 built eagerly as the lone texture always was and the
rest created lazily by `ensureArtTexture`; unused ones are cleared and hidden but never destroyed,
so a panel toggling between art types does not churn objects.

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
| Panel names | User-supplied data, not UI strings. A user's "Chat" is their text, and translating it would rename their panel — silently, behind their back, in every list and dropdown. (It would no longer move the `PanelMaster_Panel_<slug>` frame name, which is stamped at create, so external anchors would survive — but a panel that relabels itself when the client language changes is its own problem.) |
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

Bundled artwork lives under `media/artwork/`, one 1024×1024 32-bit TGA per catalog row — 101 of them
as it ships, with the catalog's declared `w`/`h` matching to the pixel — addressed at runtime through
`C.ARTWORK_PATH_PREFIX` plus the row's `file` stem. The same silent failure mode applies, which is
why a row's path is worth asserting against the filesystem the way the logo's is.
`tools/artwork/artwork_cleaner.py` is what produces those files. It converts art authored *outside* the repo
with Pillow — luminance-to-alpha for a white-on-black plate, or a magenta chroma key for full-color
art, which is the only one of the two that can separate dark art from a dark background. It also erases a generator's watermark,
letterboxes a non-square plate rather than distorting it, and normalizes the RGB of fully
transparent pixels, which is invisible under normal blending but is read by other blend modes and
was otherwise left to whichever code path a plate happened to take.

The source plate each asset was converted from is kept under `media/artwork/raw/`, named for the
catalog id it produces, so a piece can be re-derived at a different size or with a corrected margin
without going back to whoever made it. It is committed to git but excluded from the package by
`.pkgmeta` — the same reasoning as the logo's master renders, since the client cannot load a `.png`
at all.

`media/poster/artwork-poster.png` is another non-runtime media asset, and the only **generated** one:
a single contact sheet of every catalog row, drawn by `tools/artwork/make_poster.py` and embedded in
the README so the artwork set is visible without a clone. `.pkgmeta` excludes it on the same
reasoning again. Two properties are load-bearing rather than incidental. It is built
from `update_catalog.py`'s scan rather than its own walk, so it cannot show a set the addon does not
have; and it renders from fonts vendored at `tools/artwork/fonts/` with no system fallback, so the
same tree renders the same picture on any machine. Its identity is that picture — `--check` compares
a fingerprint of the decoded pixels, not of the file, because PNG bytes are deflate's output and can
differ between zlib builds for pixels that are identical. `media/poster/artwork-poster.txt` records
the fingerprint and the toolchain that produced it, so a mismatch can be attributed rather than
guessed at. Nothing in the addon reads any of it, which is exactly why staleness is undetectable by
either green-gate command — hence the `--check` mode and `docs/testing.md` ▸ *The artwork gate*.

Both the asset requirements and the contribution rules are in
[artwork-spec.md](artwork-spec.md) and the README; `tools/` is an **accepted, documented deviation**
from the Ka0s WoW Addon Standard (approved 2026-07-31 — the standard defines no build-tooling
location, and this is the first non-Lua source in the tree).

## Known limitations

- **Panel names with spaces are awkward at the CLI.** `/pm rename` and `/pm panel` take the name as
  the first word, so a panel called "Chat BG" can be created and renamed *to*, but not addressed by
  its full name from the command line. Inventing a quoting syntax for a job the settings UI already
  does well was judged the worse trade.
- **A renamed panel's frame name no longer matches its name.** The frame name is stamped at create
  and is identity from then on, so a rename cannot break an anchor — but it also cannot be worked
  out from the panel's current name. The name box's tooltip shows it. This is the deliberate half of
  the trade described in *Frame names and the pool*, not an oversight.
- **A panel name can be refused because a renamed panel still holds its frame name.** Creating
  "Alpha" fails while a panel created as "Alpha" and since renamed still carries
  `PanelMaster_Panel_Alpha`. The refusal names the holder. Refusing is correct — two frames cannot
  share a global — but the reason is not obvious from the panel list.
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
