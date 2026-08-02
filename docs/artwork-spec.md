# Panel Master — Artwork Asset Specification

What a texture must satisfy to be dropped into `media/artwork/` and registered in the catalog.
Hand the "Generation brief" section to an image model; check the result against "Hard
requirements" before committing it.

## Hard requirements

| Property | Requirement | Why |
|---|---|---|
| Format | 32-bit TGA, uncompressed or RLE, with alpha | WoW loads `.tga` and `.blp` at runtime. It cannot load `.png` or `.jpg`. |
| Dimensions | Power of two on both axes — 512 or 1024 | Non-power-of-two textures fail to load or render corrupt on some drivers, and the `TILE` fill cannot wrap them at all. |
| Recommended size | 1024 x 1024 for imported or painted art; 512 x 512 is enough for a generated line-art plate | A full-panel backdrop is drawn at panel size, and 512 visibly softens on a large panel. Flat line art carries no detail that 512 loses. |
| Aspect | Square canvas, always — letterbox a non-square motif, never crop it | Every fill type works on any aspect, but the catalog declares `w`/`h`. Cropping to a content bbox tilts emblems drawn symmetrically about the frame center. |
| Background | Fully transparent (alpha 0), **not** white or black | The panel's own fill shows through. An opaque background makes the panel's background color, opacity and texture settings pointless. |
| RGB under alpha 0 | Must be `(0,0,0,0)`, not merely "invisible" | Additive, Alpha-key and Opaque blend modes all read RGB where alpha is zero. A source whose transparent pixels are white paints a white ghost in three of five modes. Every tool here normalizes this **last**, after the final resize. |
| Edge padding | >= 4 px of transparent margin (`MIN_MARGIN` in `tools/artwork/plate.py`) | Prevents the `FILL` crop and the `TILE` wrap from shaving the motif's outermost pixels. |
| Color depth | No dithering, no JPEG-style ringing | Ringing artifacts around the alpha edge are very visible once the art is tinted. |
| File size | 512 -> ~1 MB. 1024 -> ~4 MB uncompressed, ~1.7 MB typical as RLE | RLE is a **disk** saving only. WoW expands to 32 bpp in VRAM, so a 1024 texture costs 4 MB of video memory whether or not it is compressed, against 1 MB at 512. That is the number to weigh, not the file size. |

The bundled wiki-imported set is 1024 and exceeds the old ~1.5 MB per-file guidance; that is a
recorded, accepted deviation (`docs/pending/LEDGER.md`), taken for fidelity on large panels. It is
not a license to ship a 2048 plate.

## Two authoring modes

Pick one per asset and declare it in the catalog row via `tintable`. That field is the **sole**
source of truth — it is not encoded in the filename, and nothing infers it from the pixels. See
"Naming and registration".

### Tintable — `tintable = true` (preferred)

Authored **white-on-transparent**: pure luminance, no hue at all. The per-panel Color setting
drives it at runtime, so a single file serves every color scheme, and it inherits class-color
support for free.

- Every visible pixel is `RGB = (255, 255, 255)`. Shape and depth are carried **entirely by the
  alpha channel**, never by brightness.
- A pixel that should read as 50% strength is `RGB (255,255,255), A 128` — *not* `RGB (128,128,128),
  A 255`. Gray RGB multiplied by a tint color yields a muddy, desaturated result.
- Verify before committing: flatten onto black. It should look like a clean white line-art plate.

### Full color — `tintable = false`

Authored as finished art with its own palette. The Color control is hidden in the editor and the
tint is forced to white so it cannot muddy the art. Use this only when the piece genuinely depends
on multiple hues — a faction crest with heraldic colors, for instance.

## Three authoring routes

| Route | Source | Alpha comes from | Tool |
|---|---|---|---|
| White-on-black | an image model | luminance, derived | `import.py` |
| Magenta chroma | an image model | a chroma key, derived | `import.py --chroma` |
| Import existing art | a downloaded file that already has an alpha channel | the source, **preserved** | `wiki_import.py` |

The first two exist because most image models cannot emit a real alpha channel, so it has to be
manufactured. The third is the opposite problem and therefore a separate script, not a flag:
running `to_tintable` or `chroma_key` over art that arrived with good alpha would throw that alpha
away and re-derive a worse one from brightness.

## Generation brief

### Preferred route: generate white-on-black

Most image models cannot emit a real alpha channel. Asked for a transparent background they
paint a gray checkerboard *into the pixels* — which reads as transparent to a human and is
useless to WoW.

For a tintable asset, don't ask. White-on-pure-black converts to alpha exactly: luminance
becomes opacity, and antialiased edges become partial alpha for free. It is not a workaround,
it is the ideal input, and it works with every model.

> Generate a new image from scratch; don't edit any pre-existing image.
>
> A single centered emblem for a fantasy game UI panel, in the visual language of World of
> Warcraft's interface art: **[SUBJECT]**.
>
> Use the attached image as a reference (DO NOT COPY).
>
> Style: clean ornamental line art with engraved metalwork detail. Strictly symmetrical. Bold,
> readable silhouette that still reads clearly when scaled down to 120 pixels. Decorative
> heraldry and filigree — not an illustration. No scene, no landscape, no characters, no text,
> no lettering, no numbers, no watermark, no signature.
>
> Composition: the emblem is centered with clear empty margin on all four sides. It must not
> touch or cross the edges of the frame. Nothing is cropped.
>
> Color: **PURE WHITE artwork on a PURE BLACK background (#000000).** Absolutely no other
> color anywhere in the image. Pure monochrome. Depth and shading are carried only by how
> bright the white is — thinner detail is dimmer, never a different hue. No glow, no bloom, no
> vignette, no gradient in the background, no border frame around the image, no gray background
> panel.
>
> Output: exactly 512 x 512 pixels, perfectly square.

Convert with the luminance-to-alpha script under "Converting to TGA" below.

Free services worth trying, best fit first: **Recraft** (icon- and vector-native, exports SVG,
which renders to a clean plate at any size), **Ideogram** (crispest free model for graphic-design
shapes and symmetry), **Bing Image Creator / Microsoft Designer** (DALL·E 3, most accessible,
follows long prose prompts well). All are weak at *strict* symmetry and fond of adding glow —
generate several variants and pick rather than iterating on one.

### Full color route: generate on magenta

For a `tintable = false` asset, black is the wrong backdrop. Keying color art off black cannot
separate dark ART from dark BACKGROUND, so every shadow, sable field and deep blue in the piece
goes translucent.

Magenta has no such blind spot. No heraldic palette — gold, steel, crimson, azure, sable — comes
near `#FF00FF`, so nothing keys out by accident, and a near-black navy stays fully opaque.

Generate the **same subject** you used for the B&W plate, so the pair reads as one motif:

> Generate a new image from scratch; don't edit any pre-existing image.
>
> A single centered emblem for a fantasy game UI panel, in the visual language of World of
> Warcraft's interface art: **[SUBJECT]**.
>
> Style: ornamental heraldry with engraved metalwork detail, richly colored and shaded like a
> painted crest. Strictly symmetrical. Bold, readable silhouette that still reads clearly when
> scaled down to 120 pixels. No scene, no landscape, no text, no lettering, no numbers, no
> watermark, no signature.
>
> Composition: the emblem is centered with clear empty margin on all four sides. It must not
> touch or cross the edges of the frame. Nothing is cropped.
>
> Color: the emblem is **full color** — aged gold, burnished steel, deep crimson and royal blue,
> with real shading and depth. It sits on a **solid pure magenta background, hex #FF00FF**, a
> flat uniform chroma-key field. **The magenta must appear NOWHERE in the emblem itself** — no
> magenta, no purple, no violet, no hot pink, no lavender anywhere in the artwork. The background
> is one flat unshaded magenta with no gradient, no vignette, no glow, no bloom, no shadow cast
> onto it, and no border frame around the image.
>
> Output: exactly 512 x 512 pixels, perfectly square.

Convert with `--chroma`:

```bash
python3 tools/artwork/import.py IN.png alliance-crest-color --chroma
```

Two things to check on the result. If the emblem has magenta-adjacent hues in it despite the
instruction, those areas key themselves partly away — regenerate rather than patch. And if the
model shaded the background or added a glow, the key leaves a halo; regenerate that too.

### Import route: art that already has alpha

For art you did not generate — a wiki cutout, a PNG from a designer, anything that arrives with a
real alpha channel. Batch, manifest-driven, and it never touches the alpha it was given.

```bash
python3 tools/artwork/wiki_import.py --scaffold ~/Downloads/artwork  # propose the manifest
python3 tools/artwork/wiki_import.py --dry-run                       # plan, write nothing
python3 tools/artwork/wiki_import.py --only 'classes/*'              # convert a subset
python3 tools/artwork/wiki_import.py                                 # convert everything
python3 tools/artwork/wiki_import.py --emit-catalog                  # print the Lua rows
```

`--scaffold` walks a directory and writes `tools/artwork/manifest.tsv`: one row per source, six
tab-separated columns — `source`, `category`, `subject`, `label`, `credit`, `erase`. It guesses
`category` from what the art *depicts* rather than which folder it sat in, derives `subject` from
the filename, drops byte-identical duplicates, and where two sources claim one id keeps the larger.
Every drop is printed. Nothing is silent, because a silent wrong guess becomes a shipped id.

**Then read the `subject` column before converting.** `id` is written into saved variables, so a
name is permanent the moment it ships; the manifest is the last place it is cheap to fix. From then
on the manifest is authoritative — conversion never re-derives a name — which is what makes the run
repeatable and lets a bad source be swapped and re-run with no catalog churn. Re-scaffolding is
safe: hand-edited `label`, `credit` and `erase` values are carried over, and a scaffold that would
orphan them refuses to overwrite unless you pass `--force-scaffold`.

The stages that matter, in order:

| Stage | Why it is where it is |
|---|---|
| **Erase** (the `erase` column) | Applied to the *source*, before anything else, so the blanked region travels the same path as the rest of the image and lands as genuine transparency. |
| **Key** (opaque sources only) | Runs only when the source has no alpha at all. Flood-fills inward from the border against a near-black field, so a dark region *enclosed* by the emblem stays opaque. Alpha ramps between luminance 16 and 48 to absorb JPEG ringing. These are the weakest inputs in any batch — eyeball them. |
| **Solidify**, before upscaling | Edge-extends opaque RGB outward into the transparent region. Sources disagree wildly about what RGB sits under alpha 0, and an upscaler's kernel samples those pixels: a white-under-alpha source grows a white halo along every edge. Run after upscaling it would be too late — the halo is already baked in. |
| **Upscale** | Real-ESRGAN at x4 per pass, chained, from the binary vendored at `tools/artwork/bin/`. Skipped below 1.25x, where Lanczos invents nothing the eye can find and a full x4 pass would be thrown away. One model for the whole catalog: these assets sit next to each other in a dropdown, and models sharpen with visibly different character. |
| **Fit**, then auto-pad | Letterboxed onto the square canvas — never cropped. If the result lands under the 4 px margin (a wide logo always does on its long axis), it is shrunk by exactly the shortfall and the amount is reported. |
| **Normalize transparent**, last | Forces every zero-alpha pixel to `(0,0,0,0)`. Must be last: LANCZOS premultiplies and a paste carries its canvas color in, so normalizing any earlier is simply undone by the next step. |

The `erase` column takes source-pixel boxes, `L,T,R,B`, semicolons between several. It exists for
burned-in copyright lines and artist signatures: those are pixels in the JPEG, not metadata, so
painting over them is the only removal there is. A box outside the source is an error rather than a
silent no-op. The fill matches what the source treats as background — black for an opaque plate
about to be keyed, real transparency for a plate that already has alpha — because painting black
into the latter would leave an opaque black rectangle nothing downstream keys away.

An output is rebuilt when anything that determines its pixels changes: the source bytes, `--size`,
`--pad`, `--no-ai`, or its own `erase` box. `label` and `credit` deliberately do not count, since
they cannot move a pixel and folding them in would force a needless multi-hour reconvert.

Review the batch with `--contact-sheet sheet.png`, which grids every plate on mid gray so dark and
light art are both visible. The per-asset report line flags an empty plate, a plate with nothing
near-opaque, and a margin still short after auto-padding.

### Alternative: ask for transparency directly

Only worth it on a service that genuinely supports an alpha channel. Substituting the subject:

> A single centered emblem for a fantasy game UI panel, in the visual language of World of
> Warcraft's interface art: **[SUBJECT]**.
>
> Use the attached image as a reference (DO NOT COPY).
>
> Style: clean ornamental line art with engraved metalwork detail. Symmetrical. Bold, readable
> silhouette that survives being scaled down to 120 pixels. Decorative filigree, not
> illustration — no scene, no landscape, no characters, no text, no lettering, no watermark.
>
> Composition: the emblem is centered with clear empty margin on all four sides. It does not touch
> the edges of the frame. Nothing is cropped.
>
> Color: **pure white artwork on a fully transparent background.** No gray. No color. No
> gradients in hue — depth is carried only by opacity. No drop shadow, no glow, no outer stroke,
> no background panel, no border frame around the image.
>
> Output: 512 × 512 pixels, square, PNG with a real alpha channel.

For a `tintable = false` asset, replace the Color paragraph with the palette you want and keep
everything else.

Ask for PNG — models produce it reliably and TGA rarely. Conversion is the next step.

## Converting to TGA

For a one-off, by hand:

```bash
python3 -c "
from PIL import Image
im = Image.open('IN.png').convert('RGBA').resize((1024,1024), Image.LANCZOS)
im.save('media/artwork/factions/alliance-crest.tga')
"
```

Pillow writes 32-bit uncompressed TGA for an RGBA image, which is exactly what WoW wants. Pass
`compression="tga_rle"` to save disk; it changes nothing in VRAM. `import.py` writes uncompressed,
`wiki_import.py` writes RLE. Both create the category directory as needed.

**Luminance to alpha** — the converter for the preferred white-on-black route. Every pixel
becomes white, and the brightness it had becomes its opacity:

```bash
python3 -c "
from PIL import Image
im = Image.open('IN.png').convert('RGB').resize((512,512), Image.LANCZOS)
px = im.load()
out = Image.new('RGBA', im.size)
op = out.load()
for y in range(im.height):
    for x in range(im.width):
        r,g,b = px[x,y]
        op[x,y] = (255, 255, 255, (r*299 + g*587 + b*114)//1000)
out.save('media/artwork/OUT.tga')
"
```

**Already transparent, but colored or gray** — whiten every pixel and fold its brightness into
the alpha it already has:

```bash
python3 -c "
from PIL import Image
im = Image.open('IN.png').convert('RGBA')
px = im.load()
for y in range(im.height):
    for x in range(im.width):
        r,g,b,a = px[x,y]
        lum = (r*299 + g*587 + b*114) // 1000
        px[x,y] = (255, 255, 255, a * lum // 255)
im.save('media/artwork/OUT.tga')
"
```

## Naming and registration

Art mirrors the layout of the source tree it was imported from, named for the catalog subject:

```
media/artwork/class/warrior.tga                          shipped
media/artwork/faction/expansion/12-midnight/harati.tga   shipped
media/artwork/raw/class/warrior.png                      the source, excluded from the zip
```

**Directory and category are deliberately unrelated.** The directory answers "where did this come
from", and mirrors the download folder so `media/artwork/` and the source can be diffed and read as
the same thing. The catalog row's `category` answers "which dropdown group does this appear under",
and is one of the five in `C.ARTWORK_CATEGORY_SET`. A piece filed at
`faction/expansion/12-midnight/` is a `Factions` row; neither name is wrong, they answer different
questions. Nothing derives one from the other.

`raw` is reserved and can never be a top-level source folder — `media/artwork/raw/` holds unshipped
sources and is excluded from packaging by `.pkgmeta`, so a bad asset can be re-derived without
re-downloading. Subject stems are lowercase kebab-case, apostrophes dropped rather than hyphenated
(`Mag'har` -> `maghar`).

**There is no `-bw`/`-color` suffix.** It used to be mandatory; it is gone, which is a recorded
accepted deviation (`docs/pending/LEDGER.md`). The suffix bought one thing — being able to tell
tint behavior from a file listing — and cost a filename that disagrees with the catalog whenever
someone flips `tintable` without renaming the file, which is precisely the failure it was meant to
prevent. **The catalog row's `tintable` field is now the only source of truth.** Nothing infers it
from the filename, from the directory, or from the pixels. If you want to know whether an asset
takes the panel's tint, read the row.

A tintable and a full-color treatment of the same motif are still **independent catalog rows** with
distinct ids and distinct files — they are genuinely different assets with different `tintable`
answers, and one row cannot carry two files and two truths. Distinguish them in the subject itself
(`alliance-crest`, `alliance-crest-plate`), not with a suffix that means something to the tooling.

```lua
{ id       = "factions-alliance-crest",  -- stored value; never rename it once shipped
  category = "Factions",                 -- General | Races | Classes | Expansions | Factions
  label    = "Alliance Crest",
  file     = "faction\\major\\alliance-crest", -- mirrors the source tree, no extension
  w        = 1024, h = 1024,              -- authored pixel size, declared not measured
  tintable = false,
  credit   = "Your Name (CC0)" },         -- required; see Licensing
```

`file` carries **backslashes**. `modules/Artwork.lua` builds the texture path by bare
concatenation — `C.ARTWORK_PATH_PREFIX .. row.file .. ".tga"` — so a backslash keeps one separator
convention across the whole assembled path, and the directory move needs no resolver change at all.
`tests/test_artwork.lua` normalizes separators and asserts the derived path exists on disk, so a
row pointing at a missing file fails the green gate rather than shipping.

`id` is written into saved variables. Renaming one silently breaks every panel using it.
`wiki_import.py --emit-catalog` prints rows in exactly this shape from the manifest.

## Licensing

Artwork **submitted to this addon** must be redistributable under a license compatible with its MIT
release. CC0, MIT and public domain are fine. Do not submit anything under a non-commercial or
no-derivatives license, and do not submit traced Blizzard art as your own work.

The bundled wiki-imported set is a knowing exception, recorded as an accepted deviation in
`docs/pending/LEDGER.md`: it is Blizzard-owned Warcraft Wiki art, shipped under Blizzard's fan-work
terms rather than under a license we can grant onward. Its `credit` strings say so plainly —
`"Warcraft Wiki (Blizzard Entertainment)"` — because the honest answer to "what license is this?"
is not one, and claiming otherwise would be worse than admitting it. Do not treat it as precedent
for a contribution.

Every catalog row carries a `credit` string naming the author and the license. That field is the
attribution record; a submission without one cannot be accepted.
