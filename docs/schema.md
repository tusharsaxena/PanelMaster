# Schema

What Panel Master persists: the two SavedVariables scopes, the panel record and every field on it,
the artwork fields, and the sanitizing pass that runs before anything is stored. What is *drawn* from
these records is [data-flow.md](data-flow.md); the controls that edit them are
[settings-panel.md](settings-panel.md).

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

`profile.settings` gained three keys in the settings-revamp pass, all of them the stored half of the
Master controls tab (`options-ui-§15`) and all of them shipping at the identity so no existing
profile renders differently:

```
  settings.visibility     -- "always" | "inCombat" | "outOfCombat" | "never"
  settings.scale          -- addon-wide multiplier over each panel's own scale
  settings.alpha          -- addon-wide multiplier over each panel's own opacity
```

#### The panel record

```lua
{ id, name, frameName, enabled, width, height, point, relPoint, x, y, strata, level, scale, alpha,
  bgTexture,     bgColor,    bgClassColor,
  borderTexture, borderSize, borderOffset, borderColor, borderClassColor,
  mouseover, mouseoverAlpha,
  accentEnabled, accentEdges, accentTexture, accentAlpha, accentThickness, accentOffset,
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
| `COLOR_CLASS_SOURCE` | **whose** class each color means — `"player"` or `"unit"` |

`COLOR_FIELDS` is the generic seam the class-color feature is built on: every color read goes
through `Util.ResolveColor`, which consults it. A class color replaces only the **RGB**; the stored
**alpha** is kept, because "class colored" is a statement about hue, not about how solid the result
is. Tests pin that a picked color and a class color produce an otherwise identical backdrop — same
edge texture, same edge size, same alpha, same anchoring — since a drift there would make a
class-colored border genuinely render fainter than a picked one.

**The lookup itself is `LibKa0s-Core-1.0`'s, not this addon's.** `options-ui-§17` allows exactly one
resolver in the collection, and `Core.ResolveColor` / `Core.ClassColor` are it; `Compat.GetClassColor`
read `RAID_CLASS_COLORS` here and is gone. This addon's recorded argument is the one the library
adopted — `RAID_CLASS_COLORS` is the table every other UI on the player's screen is already reading —
so the source did not change, only who owns it, and the library also memoizes the player's answer on
success where this copy never did. What stays host-side is the two things the library cannot know:
which flag pairs with which color (`COLOR_FIELDS`), and whose class each color means
(`COLOR_CLASS_SOURCE`). All five are `"player"`, and the argument is the same for every one: a panel
is chrome — it is a backdrop the player put behind their own UI, it tracks no unit, and it has no
unit token to ask about. The declaration is per field anyway, because that is what an audit reads,
and because the day a panel gains a tracked unit the change is one row.

Because the alpha is still the user's, the color picker stays **enabled** while class color is on —
and `disabledIf` on a color row is now forbidden outright (anti-pattern #74). It is the only control
that sets opacity, so graying it out contradicted its own tooltip and left a washed-out class color
unfixable. Its label gains an `(opacity)` suffix to say which half is live, and its tooltip carries
the collection's own sentence for it (`H.CLASS_COLOR_NOTE`) rather than a paraphrase. The companion
is labeled **`Use class color`**, which is the name the standard gives it. A color added later gets class-color support in
the renderer, the CLI and the settings page from that one row — nothing re-decides "does this color
support class color?" at a call site. The accent bar proved this out: adding a third class-colorable
color was one `COLOR_FIELDS` row and no new class-color logic anywhere.

**Panel records are an `architecture-§5` storage carve-out.** They are not Schema rows: a schema row
is a fixed setting with one widget, and a panel is a variable-length user-created object. They are
mutated only through `NS.Registry`, which is the equivalent single write seam.

#### The artwork fields

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

#### Sanitizing

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
