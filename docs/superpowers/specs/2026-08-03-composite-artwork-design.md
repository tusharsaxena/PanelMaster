# Composite artwork rendering — design

**Date:** 2026-08-03
**Issue:** #12 (the half the previous commit deferred)
**Status:** approved, implementing

Closes the caveat left by `9f4b94b`: a composed Sunn theme currently renders its **left section
stretched across the whole panel**, because `modules/Canvas.lua` creates exactly one `f.art`
texture per panel. This is the renderer that draws all N sections.

---

## 1. What was wrong in the handoff

The previous session recorded `overlap` as "the fraction by which adjacent sections overlap,
0–30% in the packs I inspected". That is not what it is, and the design was re-derived after
reading the installed SunnArt 4.01 at
`/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/SunnArt`.

From `CustomTheme.lua:28-33`:

> The overlap value is a percentage of the total height of the artwork. […] If your artwork is 256
> pixels high and the top 75 pixels of this artwork contain transparent pixels, set the
> SunnCustomOverlap value of your theme to 75 divided by 256 times 100 (75/256*100) = 29.297

It is **a transparent band at the top of the artwork, measured as a percentage of its height**.
`SunnArt_Core.lua:252` turns it into `olr = 100 / (100 - overlap)`, oversizes the strip by that
ratio (`h = w * scale / 2 * olr`) and offsets the anchor by `h - h/olr`, so the dead band hangs
*outside* the panel and over the game world. It says nothing about adjacent sections.

Three consequences, all of which change what is already committed:

**Sections are flush.** `SunnArt_Core.lua:322` anchors section *n* to section *n-1*'s `TOPRIGHT`.
So the atlas is the plain `band_i = [(i-1)/N, i/N]` and the composed row's native **width** stays
`SECTION_W * N` — the shipped value is correct and does not move.

**The 512×256 assumption has better evidence than the file census.** `SunnArt_Core.lua:259` is
`h = w * self.db.profile.bar[i].scale / 2` — SunnArt hard-codes 2:1 for every section of every
theme, for all four bars. That is stronger than the 30 files counted last time, and replaces the
reasoning in the ARTWORK-SUNN-01 ledger row.

**`overlap` is worth consuming, on the vertical axis.** A PanelMaster panel has no viewport to
hang the band over; it simply renders as nothing. Ignoring it would make a theme declaring 29.297%
autosize a panel 29% taller than its visible art, and letterbox it under FIT — which reads as a
bug. So the band is cropped: see §3.

---

## 2. Two more findings in shipped code

**A precedence inversion.** `SunnArt:ImportThemes` (`SunnArt_Core.lua:132-152`) merges
`panels`/`overlap` in the *opposite* order to the theme-name merge: `db.global.panels` first, then
`SunnArtPack.panels` overwriting it. Our `sources()` pairs each count table with its name table,
so `db.global` wins — the reverse. Section counts and overlaps therefore get their own merge
order, independent of the name order. See §4.

**`SunnCustomPanels` / `SunnCustomOverlap` are dead in SunnArt.** `CustomTheme.lua:2-3` declares
them and invites the player to fill them in; `ImportThemes` never reads either. A player who sets
`SunnCustomPanels["SunnArt\\MyArtWork"] = 5` is silently given 3 sections. We do read them, which
is better behaviour than the addon we adapt, and they are ordered **last** — the player's own hand
edit is the only source a human typed, so it wins. Recorded as a deliberate divergence, not a bug
to match.

---

## 3. The virtual atlas

A composed theme is treated as **one virtual image**. Every existing decision — fill, scale,
anchor, crop, flip, rotation, tint, desaturate, blend — keeps meaning exactly what it means for a
single texture, because `BuildArtSpec` runs unchanged against that virtual image's size. A final
slicing step then cuts its one rectangle into N.

The alternative — defining what each control means "for a composite" — was rejected: it invents a
second set of semantics to document, learn and keep in agreement with the first.

### Content window

Overlap narrows the *content* window on the file's v axis. With `ov` the overlap as a fraction:

```
content native size:   w = SECTION_W * N          h = SECTION_H * (1 - ov)
content v -> file v:   file_v = ov + content_v * (1 - ov)
```

`ov = 0` is the identity, so the no-overlap case is not a branch. Because this is expressed as a
row-level `contentV0`, the **per-section rows get the same crop through the existing
single-texture path** — no composite special case, and `Artwork.NativeSize` needs no change at all
since it already returns `row.w`/`row.h`.

**TILE ignores the crop.** A `REPEAT` wrap repeats a whole file, not a sub-range, so the band
cannot be excluded from a tiled repeat. `contentV0` is forced to 0 when tiling, and the comment
says so rather than pretending otherwise.

### Section bands

```
band_i = [ (i-1)/N , i/N ]                       in bar-u space
file_u = (bar_u - band_i.lo) * N                 within section i
```

### Slicing

For each bar copy `m` (one copy for every fill but TILE) and each section `i`:

1. `span = [m + band_i.lo, m + band_i.hi] ∩ [u0, u1]`. Empty → the section is not drawn. This is
   what makes a FILL crop that pushes section 1 off the panel simply omit it.
2. The span's fraction along the drawn rectangle: `f0 = (span.lo - u0) / (u1 - u0)`, likewise `f1`.
3. `transformRect(f0, 0, f1, 1, flipH, flipV, rotation)` → screen-space fractions of the drawn
   rectangle. This composes flip-then-turns in the **same order** as `composeUV`, and its turn
   permutation is derived from `composeUV`'s own corner shuffle: after one turn, screen-x samples
   *reversed v* and screen-y samples *u*. So a rotated bar stacks its sections vertically and
   `flipH` reverses their order — both fall out, neither is a special case.
4. The quad's own rectangle and anchor, at the same `art.point`:

   | anchor side | offset |
   |---|---|
   | `LEFT`   | `x + sx0 * width` |
   | `RIGHT`  | `x - (1 - sx1) * width` |
   | centred  | `x + ((sx0 + sx1) / 2 - 0.5) * width` |
   | `TOP`    | `y - sy0 * height` |
   | `BOTTOM` | `y + (1 - sy1) * height` |
   | centred  | `y - ((sy0 + sy1) / 2 - 0.5) * height` |

5. `uv = composeUV(file_u0, file_v0, file_u1, file_v1, flipH, flipV, rotation)`.

### TILE

Vertical repeat stays a `REPEAT` wrap — it is within one file. Only the horizontal axis splits:
`ceil(u1)` bar copies × N sections, each quad `CLAMP` horizontally and `REPEAT` vertically.

`Artwork.MAX_ART_QUADS = 24`. Over budget, the bar-copy count is reduced to `floor(MAX / N)` and
the tile grown to match, so the panel stays **covered** rather than going partly bare, and
`art.tileClamped` records it for the harness. A 5-section bar at scale 0.1 would otherwise ask for
500 textures on one panel.

### Spec shape

`art.quads` is always present, with one element for every non-composite. The flat
`width/height/point/x/y/uv` fields stay, now documented as **the whole-bar rect** — what the art
occupies as one image, before slicing. For a composite that is not any single quad, so it is a
summary rather than a duplicate; for `n = 1` it coincides with `quads[1]`, which becomes an
asserted invariant.

Each quad: `{ path, width, height, point, x, y, uv[8], wrapH, wrapV }`.

No draw-layer sublevels. Sections are flush, so no two quads overlap and there is nothing to
order.

---

## 4. Module changes

### `modules/SunnArt.lua`

- Theme **names** keep the existing four-source merge order (`SunnArtPack.theme`,
  `SunnCustomTheme`, `SunnArt.options.args.theme.values`, `SunnArt.db.global.themes`).
- Section **counts and overlaps** get their own merge, later winning:
  `ThemeDB.panels`/`.overlap`, `db.global.panels`/`.overlaps`, `SunnArtPack.panels`/`.overlap`,
  `SunnCustomPanels`/`SunnCustomOverlap`. The middle two reproduce `ImportThemes`; the last is the
  documented divergence from §2.
- Overlap is a **percentage** (SunnArt's own slider is `min = 0, max = 100, step = 0.01`),
  normalised to a fraction and clamped to `[0, 0.9]`. 100 would crop the art out of existence.
- Rows gain `contentV0` (omitted when 0) and their `h` becomes `SECTION_H * (1 - ov)`. Composed
  rows keep `w = SECTION_W * N` and carry `sections`.

### `modules/Artwork.lua`

- `transformRect`, sitting beside `composeUV` and sharing its transform order.
- The content-window remap on v.
- The quad builder at the end of `BuildArtSpec`.
- Fix the orphaned `Artwork.NativeSize` doc comment, which landed inside `BuildArtSpec`'s header
  (`modules/Artwork.lua:736-752`) and splits a sentence in half.

### `modules/Canvas.lua`

- `f.artTextures = { <the existing texture> }` built as today, with `f.art` kept as an alias for
  `[1]`; `ensureArtTexture(f, i)` creates 2..n lazily on `artFrame`.
- `applyArtwork` iterates `art.quads` — one path, no branch — then hides and clears
  `#quads+1 .. n`. Unused textures are never destroyed, so toggling art types does not churn.
- `releaseFrame` clears the whole list.

---

## 5. Testing

All of it is arithmetic on a record, so all of it is headless:

- band arithmetic; the content-window remap at `ov = 0` and `ov > 0`
- the full fill matrix × rotation × flip against a 3-section bar, asserting the quads tile the
  drawn rect with no gap and no double-cover
- a FILL crop that drops section 1 entirely
- a one-section theme producing a spec identical to the equivalent single texture
- `quads[1]` == the flat rect whenever `#quads == 1`
- the TILE cap and `tileClamped`
- `NativeSize` under overlap; autosize consuming it
- the counts/overlap merge order, and `SunnCustomPanels` winning

Plus a smoke test in `docs/smoke-tests.md`, since "does a real pack resolve in-game" is still
unverified from `9f4b94b`.

---

## 6. Docs deferred from `9f4b94b`

README artwork section, `docs/artwork-spec.md`, `docs/ARCHITECTURE.md`, and the LEDGER rows — the
512×256 assumption (now with the `scale / 2` citation), the overlap-crop interpretation, and the
`SunnCustomPanels` divergence.
