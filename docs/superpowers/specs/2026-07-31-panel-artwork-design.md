# Panel Artwork — Design

**Issue:** [#9](https://github.com/tusharsaxena/PanelMaster/issues/9) — Panel artwork: bundled
WoW-themed art, user-supplied art, and per-panel styling options
**Branch:** `feat/panel-artwork`
**Date:** 2026-07-31

## Goal

A panel can carry a texture layer drawn within its bounds, chosen per panel from a bundled
catalog or from a user-supplied path, with its own color, opacity, position, fill, rotation,
flip, draw layer and scale. The default is "no artwork", so existing panels and
profiles are visually unchanged after upgrade.

This first slice lands the **whole subsystem** with **one** catalog entry. Adding artwork later
is then a single catalog row and a `.tga` file — no code changes anywhere else.

## Scope

In scope: the catalog, the record fields, the pure render spec, the renderer changes, the
settings editor section, slash coverage, the procedural art generator, one bundled artwork,
tests, and the README contribution section.

Out of scope: the full multi-category art set (General / Races / Classes / Expansions /
Factions coverage beyond the single seed entry), and localization of the new strings.

## Architecture

### `modules/Artwork.lua` — new module

Loads after `Registry`, before `Canvas` (the renderer reads it). It owns two things:

1. **The catalog** — the list of bundled artwork.
2. **`BuildArtSpec`** — the pure record-to-geometry math.

It touches no frames. This keeps `Canvas` a dumb applier of a pure spec, which is the ethos the
renderer already states in its own header comment.

#### Catalog shape

```lua
Artwork.Catalog = {
  { id = "runic-sigil", category = "General", label = "Runic Sigil",
    file = "runic-sigil", w = 512, h = 512, tintable = true,
    credit = "Ka0s Panel Master (MIT)" },
}
```

- `id` is the **stored** value. It is part of the saved-variables contract and is never renamed.
- `file` is a bare stem. The full path is derived at render time
  (`Interface\AddOns\PanelMaster\media\artwork\<file>.tga`) and is never stored — a stored path
  would strand a record if the addon were moved or renamed, the same reasoning that makes the
  existing media fields store LibSharedMedia *names* rather than paths.
- `w` / `h` are the authored pixel dimensions. They are declared rather than read back from the
  texture object because `Texture:GetWidth()` returns 0 until the file has actually loaded, which
  is not guaranteed on the first render pass — and the `STATIC`, `FIT` and `TILE` fill types all
  need the native size to compute anything at all.
- `tintable` says whether the art is authored as grayscale-on-transparent (tint drives the look)
  or as finished full-color art (tint would only muddy it).
- `credit` carries the licensing attribution the issue requires for redistribution.

Two reserved ids sit outside the catalog:

- `"None"` — the default. No artwork is drawn.
- `"Custom"` — draw `artCustomPath` instead. Treated as `tintable = true` (a user tinting their
  own art to white is a no-op, so the permissive default costs nothing).

Categories are fixed in `C.ARTWORK_CATEGORIES`:
`General`, `Races`, `Classes`, `Expansions`, `Factions`.

### Panel record — 14 new fields

All added to `C.PANEL_TEMPLATE`, `C.PANEL_FIELD_TYPE` and `C.PANEL_FIELD_ORDER`, and all
prefixed `art*` to match the existing `accent*` convention.

| Field | Default | Type | Meaning |
|---|---|---|---|
| `artTexture` | `"None"` | `artwork` | Catalog id, or `None` / `Custom` |
| `artCustomPath` | `""` | `string` | Texture path, used only when `artTexture == "Custom"` |
| `artColor` | `{1,1,1,1}` | `color` | Tint |
| `artClassColor` | `false` | `boolean` | Class-color override for `artColor` |
| `artAlpha` | `1.0` | `number` | Art opacity, multiplied on top of the panel's own alpha |
| `artFill` | `"FIT"` | `enum` | `STATIC` / `STRETCH` / `FILL` / `FIT` / `TILE` |
| `artPoint` | `"CENTER"` | `point` | Where the art sits within the panel |
| `artX` | `0` | `number` | Horizontal offset from that anchor |
| `artY` | `0` | `number` | Vertical offset from that anchor |
| `artScale` | `1.0` | `number` | Size multiplier (0.1–4) |
| `artRotation` | `0` | `enum` | `0` / `90` / `180` / `270` |
| `artFlipH` | `false` | `boolean` | Mirror horizontally |
| `artFlipV` | `false` | `boolean` | Mirror vertically |
| `artLayer` | `"ABOVE_BG"` | `enum` | `BELOW_BG` / `ABOVE_BG` / `ABOVE_ALL` |

Because these are ordinary template fields, `Registry.Sanitize`, `R:Reset`, `R:CopyFrom`,
profile switching and `/pm panel set` all pick them up with no per-field work — which is exactly
what the acceptance criterion about copy/profile operations asks for.

`artColor` gets a row in `C.COLOR_FIELDS` (`artColor → artClassColor`). Class-color support then
costs one table row and no new code, because every color already resolves through
`Util.ResolveColor`.

`artTexture` defaults to `"None"`, so a panel that predates this change renders identically.

#### Enum coercion

Five of the new fields are closed enums. Rather than five near-identical branches in
`Registry:Set`, one generic `"enum"` kind is added, driven by a new map:

```lua
C.PANEL_FIELD_ENUM = {
  artFill = C.ART_FILL, artRotation = C.ART_ROTATION,
  artLayer = C.ART_LAYER,
}
```

Each entry is an ordered array (dropdown order, and the "expected one of: …" error text) plus a
derived `_SET` for membership. `artTexture` gets its own `"artwork"` kind, validated
case-insensitively against the live catalog — mirroring how the `"media"` kind already
validates against the live LibSharedMedia list and refuses a typo with the real list.

### `Artwork.BuildArtSpec(rec, panelW, panelH)` — pure

Returns `nil` when no artwork is selected. Otherwise:

```lua
{
  path,                    -- resolved texture path
  layer,                   -- pass-through enum
  color = {r,g,b,a},       -- tint, already class-color-resolved and alpha-folded
  tile,                    -- true ⇒ SetTexture wraps REPEAT/REPEAT
  width, height,           -- the texture's on-frame size
  point, x, y,             -- anchor within the art frame
  uv = { 8 numbers },      -- crop + flip + rotation, composed
}
```

No frames are touched, so the entire "what does this artwork render as" question is testable
headlessly — the same property `Canvas.BuildSpec` already has, and the reason all five fill types
can be verified against resize without a game client.

#### Fill types

Given panel `W × H`, native `w × h`, and `scale = s`:

| Fill | On-frame size | UV |
|---|---|---|
| `STRETCH` | `W × H` | full 0–1 |
| `FIT` (contain) | `r = min(W/w, H/h) · s` → `w·r × h·r` | full 0–1 |
| `STATIC` | `w·s × h·s` | full 0–1 |
| `FILL` (cover) | `W × H` | centered crop by aspect, tightened by `s` |
| `TILE` | `W × H` | `0 → W/(w·s)` and `0 → H/(h·s)`, wrap `REPEAT` |

`STRETCH` deliberately ignores `scale` — stretching *is* "fill the panel exactly", and a scaled
stretch is either `FILL` or `STATIC` depending on which the user actually meant. The tooltip says
so.

**Position applies to `STATIC` and `FIT` only.** Those are the two modes where the art is smaller
than the panel, so "where does it sit" is a real question. `STRETCH`, `FILL` and `TILE` all cover
the panel exactly, so the spec forces `point = "CENTER", x = 0, y = 0` for them rather than
letting an offset shove panel-filling art out through the clip. The position and scale tooltips
say so — a control that silently does nothing is a bug report.

`FILL`'s crop: let `a = (W/H) / (w/h)`. When `a > 1` the panel is wider than the art, so the
vertical axis is cropped to `1/a` centered; otherwise the horizontal axis is cropped to `a`
centered. `scale` then divides both surviving ranges, so `s > 1` zooms in (a tighter crop) and
`s < 1` zooms out.

#### UV composition

Crop, flip and rotation compose on the same four UV corners, applied in that order, then emitted
in WoW's eight-argument `SetTexCoord` order: `UL, LL, UR, LR`.

Quarter-turn rotation is an exact axis transpose — no resampling, no edge smear, and it is the
only rotation form the eight-argument coord can express faithfully. This is the same technique
`C.ACCENT_TEXCOORD_ROT90` already uses for vertical accent bars, so it is a pattern the repo
already owns. Arbitrary-angle rotation was considered and rejected: rotating a *cropped* quad
samples outside 0–1, which under CLAMP smears the edge pixels across the corners.

`Texture:SetRotation` was also considered and rejected — it is implemented in terms of texture
coordinates internally and therefore fights `SetTexCoord`, which every fill type but `STRETCH`
needs.

### Renderer changes — `modules/Canvas.lua`

`Canvas.BuildSpec` gains `spec.art = NS.Artwork.BuildArtSpec(rec, spec.width, spec.height)`.

One structural change is required. Today the background fill is a texture on the panel frame
itself. A child frame always draws above its parent's textures, whatever draw layer those use —
so with `bg` on the panel, "behind background" is unreachable by any child frame. The fill
therefore moves onto a new `f.bgFrame` child (`SetAllPoints`), keeping the field name `f.bg` for
the texture so call sites and tests are unchanged.

The frame ladder becomes, bottom-up:

```
f                     base
  artFrame  (BELOW_BG)  base + 1
  bgFrame               base + 2
  artFrame  (ABOVE_BG)  base + 3      ← default
  borderFrame           base + 4
  accentFrame           base + 5
  artFrame  (ABOVE_ALL) base + 6
```

There is **one** `f.artFrame`; its frame level is reassigned per render from the three values
above. Frame levels are mutable at any time, so this needs no extra frames — three art frames for
three layer choices would be waste.

`f.artFrame` gets `SetClipsChildren(true)` (guarded on the method existing, the same way
`SetBackdrop` is guarded, so the headless harness degrades rather than erroring). This is what
makes "renders inside the panel's bounds" true for offset and scaled art. Because the clip is on
the art frame specifically, the accent bars — which deliberately hang *outside* the panel — are
completely unaffected.

`release()` clears the art texture and hides the art frame, so a pooled frame reused by another
panel cannot inherit the previous panel's artwork.

Two assertions in `tests/test_accent.lua` currently pin `borderFrame` to `base + 1` and
`accentFrame` to `base + 2`. They are updated to the new ladder. The relative-ordering assertion
next to them (`accent > border`) is the one that carries the real intent, and it still holds.

### Settings editor — `settings/PanelEditor.lua`

A new `Artwork` heading in `buildPanelEditor`, following the existing `editorHeading` /
`editorRow` / `addRefresher` patterns:

- Artwork dropdown — flat and category-prefixed (`"General: Runic Sigil"`), `None` first,
  `Custom path…` last, ordered by category then label. A flat list is honest at one entry; a
  grouped widget can replace it when the catalog is large enough to need one.
- Custom path edit box — enabled only when `Custom` is selected.
- Color + class-color pair — hidden when the selected entry declares `tintable = false`.
- Sliders: opacity, scale, X, Y. Dropdowns: fill, position, rotation, layer.
  Checkboxes: flip horizontal, flip vertical.

### Slash surface

Covered for free by `C.PANEL_FIELD_TYPE` / `C.PANEL_FIELD_ORDER` plus the new `enum` and
`artwork` coercions. `/pm panel <name>` prints the new fields in template order; `/pm panel set`
validates and refuses bad values with the real option list.

### Artwork generation — `tools/artwork/generate.py`

A committed Python + Pillow script that draws the motif in code and writes a 512×512 32-bit
uncompressed TGA to `media/artwork/`. Reproducible, reviewable as a diff, license-clean by
construction (original work, MIT), and re-runnable for the later batch.

The seed entry is `runic-sigil` — a circular runic emblem, authored white-on-transparent so the
per-panel tint drives its color. A centered motif on transparency also exercises every fill type
legibly: aspect cropping, tiling seams and quarter-turns are all visible on it at a glance.

**Documented deviation:** the Ka0s WoW Addon Standard defines no location for build tooling, and
this is the first non-Lua source in the tree. Accepted deliberately (approved 2026-07-31): the
generator's value is that art stays reproducible and license-clean from the repo itself. Recorded
in the README and carried into the audit bundle. `luacheck` is unaffected — it only walks Lua.

### Documentation

`README.md` gains an artwork contribution section covering: where files go under
`media/artwork/`, the accepted format (32-bit uncompressed TGA, power-of-two dimensions), naming
and category conventions, how to add the catalog row, and the licensing/attribution
requirement for submitted art.

## Testing

New `tests/test_artwork.lua`:

- **Fill math** — all five types across wide, tall and square panels crossed with wide, tall and
  square art. This is the acceptance criterion "all five fill types behave correctly as the panel
  is resized", expressed as arithmetic.
- **UV composition** — each quarter-turn, each flip, and the combinations, including composed
  with a `FILL` crop.
- **Tintable gating** — a `tintable = false` entry renders white regardless of `artColor`.
- **Class color** — `artClassColor` overrides RGB and preserves alpha, via `Util.ResolveColor`.
- **Catalog integrity** — every row's derived path points at a file that exists on disk, every
  id is unique, and every category is one of `C.ARTWORK_CATEGORIES`.
- **Upgrade inertness** — a record built from the template renders `spec.art == nil`, proving the
  default is genuinely no-op.
- **Persistence** — a panel with artwork survives `Sanitize`, `CopyFrom` and a profile round-trip
  with every `art*` field intact.

Existing `tests/test_accent.lua` frame-level assertions updated to the new ladder.

Green gate: `lua tests/run.lua` and `luacheck .` both clean.

## Acceptance criteria mapping

| Criterion | Where it is satisfied |
|---|---|
| Bundled artwork renders inside panel bounds | Catalog + `artFrame` with `SetClipsChildren` |
| User-supplied texture | `artTexture = "Custom"` + `artCustomPath` |
| Color, opacity, position, fill settable and live | Record fields → `BuildArtSpec` → per-field repaint via the existing `MSG_PANEL` path |
| All five fill types correct on resize | `BuildArtSpec` fill math + its test matrix |
| Persist across reload; travel with copy/profile | Ordinary template fields, so `Sanitize`/`CopyFrom`/AceDB handle them |
| Default is no artwork | `artTexture = "None"`; upgrade-inertness test |
| README documents contribution | README artwork section |
| Bundled art ships | `media/artwork/runic-sigil.tga`, one seed entry; further categories are a follow-up |
| Green gate | `lua tests/run.lua`, `luacheck .` |

## Deviations from the Ka0s WoW Addon Standard

1. **`tools/artwork/` and a Python source file.** The standard defines no build-tooling location.
   Accepted as a documented deviation (approved 2026-07-31), reason: reproducible, license-clean
   artwork generation from the repo.
2. **New option strings hardcoded in English.** `locales/enUS.lua` already records "0.1.0 ships
   English-only" as an accepted scope decision with the `NS.L` seam kept for a later pass. The new
   strings follow that same existing decision rather than creating a second one.

## Amendments after in-client smoke testing

**Blend mode was designed in and then removed** (2026-07-31, after the smoke run). All five WoW
modes were offered; two of them cannot be correct for artwork defined by its alpha channel.
`DISABLE` ignores alpha, so it can only ever draw a solid rectangle. `MOD` multiplies, which needs
a transparent region to be white to be a no-op, while `ADD` needs it black — one texture cannot
satisfy both, so whichever value is chosen makes the other mode wrong. Rather than ship a
five-item dropdown containing two guaranteed bug reports, the setting was dropped and the mode
fixed at `BLEND` (`C.ART_BLEND_MODE`). The record lost `artBlend`; nothing had shipped, so no
saved variables carried it.

**Transparent-region RGB is now normalized to black** by both artwork tools. It is invisible under
normal blending and was therefore inconsistent — `to_tintable` wrote white, `chroma_key` wrote
black, `fit_square` padded with white, and PIL's LANCZOS resize silently zeroed it by
premultiplying. One shipped asset carried two different values in the same file. Black is the
value `ADD` requires, and even with the blend setting gone the normalization stays: an asset whose
invisible pixels depend on which code path converted it is a latent bug either way.

**Quarter-turn rotation transposes the art's effective dimensions.** The original design applied
rotation only to the UV quad, which distorted `STATIC`, `FIT`, `FILL` and `TILE` at 90 and 270
degrees — a 512x128 piece at `FIT` was squashed 16:1. Square art hides this completely, which is
why the fill matrix now runs wide and tall art against wide and tall panels at every rotation.

**The unlock overlay moved onto its own frame** at `C.UNLOCK_FRAME_LEVEL`, and panel frame levels
are multiplied by `C.PANEL_LEVEL_STRIDE`. Both are consequences of the background fill moving to a
child frame: frame level outranks draw layer, so the fill began covering the unlock outline, and
the panel's frame-level footprint grew from three rungs to eight, making adjacent panel levels
interleave.
