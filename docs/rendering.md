# Rendering detail

The drawing decisions behind a rendered panel: the mouseover fade ticker, the four accent bars, the
artwork pipeline, and the Sunn composite adapter. The frame ladder and pool that host all of this are
[data-flow.md](data-flow.md); authoring artwork for the addon is
[artwork-spec.md](artwork-spec.md).

One shared `OnUpdate` at 10Hz drives every mouseover panel, rather than a script per panel.

It **polls** `MouseIsOver` rather than using `OnEnter`/`OnLeave`, because those require the frame to
take mouse input — and a panel that takes the mouse stops being click-through, which is the one
guarantee a backdrop must never break. Polling reads the cursor without claiming it.

While a panel is unlocked (globally or on its own) the fade is suspended and it is held at full
alpha: a panel resting at 0 alpha would be impossible to find and drag.

#### Accent bars

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

#### Artwork

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

#### Composites, and the Sunn adapter

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
