# Panel Master — Artwork Asset Specification

What a texture must satisfy to be dropped into `media/artwork/` and registered in the catalog.
Hand the "Generation brief" section to an image model; check the result against "Hard
requirements" before committing it.

## Hard requirements

| Property | Requirement | Why |
|---|---|---|
| Format | 32-bit TGA, uncompressed or RLE, with alpha | WoW loads `.tga` and `.blp` at runtime. It cannot load `.png` or `.jpg`. |
| Dimensions | Power of two on both axes — 256, 512, 1024 | Non-power-of-two textures fail to load or render corrupt on some drivers. |
| Recommended size | 512 × 512 | Large enough for a full-panel backdrop, small enough that a 30-panel layout stays cheap. |
| Aspect | Square unless the motif demands otherwise | Every fill type works on any aspect, but square art reads predictably in all five. |
| Background | Fully transparent (alpha 0), **not** white or black | The panel's own fill shows through. An opaque background makes the panel's background color, opacity and texture settings pointless. |
| Edge padding | 2–4 px of transparent margin | Prevents the `FILL` crop and the `TILE` wrap from clipping the motif's outermost pixels. |
| Color depth | No dithering, no JPEG-style ringing | Ringing artifacts around the alpha edge are very visible once the art is tinted. |
| File size | Under ~1.5 MB | 512 × 512 × 4 bytes is 1 MB uncompressed; anything much larger means the dimensions are wrong. |

## Two authoring modes

Pick one per asset and declare it in the catalog row via `tintable`.

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

## Generation brief

### Preferred route: generate white-on-black

Most image models cannot emit a real alpha channel. Asked for a transparent background they
paint a gray checkerboard *into the pixels* — which reads as transparent to a human and is
useless to WoW.

For a tintable asset, don't ask. White-on-pure-black converts to alpha exactly: luminance
becomes opacity, and antialiased edges become partial alpha for free. It is not a workaround,
it is the ideal input, and it works with every model.

> A single centered emblem for a fantasy game UI panel, in the visual language of World of
> Warcraft's interface art: **[SUBJECT]**.
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

### Alternative: ask for transparency directly

Only worth it on a service that genuinely supports an alpha channel. Substituting the subject:

> A single centered emblem for a fantasy game UI panel, in the visual language of World of
> Warcraft's interface art: **[SUBJECT — e.g. "an Alliance lion crest", "a Night Elf crescent
> and antler motif", "a Wrath of the Lich King runeblade and frost sigil"]**.
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

Drop the PNG anywhere and run:

```bash
python3 -c "
from PIL import Image
im = Image.open('IN.png').convert('RGBA').resize((512,512), Image.LANCZOS)
im.save('media/artwork/OUT.tga')
"
```

Pillow writes 32-bit uncompressed TGA for an RGBA image, which is exactly what WoW wants.

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

File name: lowercase kebab-case, no spaces, matching the catalog `id`, and **always carrying a
`-bw` or `-color` suffix**:

```
media/artwork/alliance-crest-bw.tga        tintable = true
media/artwork/alliance-crest-color.tga     tintable = false
media/artwork/raw/alliance-crest-bw.png    the source plate, not shipped
```

The suffix is mandatory even when only one half of the pair exists. A bare
`alliance-crest.tga` gives no way to tell from a file listing whether it takes the panel's tint,
and the two behave differently enough that guessing is not acceptable — one follows your color
setting, the other ignores it entirely.

Each half is an **independent catalog row**, not a variant of one entry. They are genuinely
different assets with different `tintable` answers, and a single row would have to carry two
files and two truths:

```lua
{ id       = "alliance-crest-bw",  -- stored value; never rename it once shipped
  category = "Factions",           -- General | Races | Classes | Expansions | Factions
  label    = "Alliance Crest (B&W)",
  file     = "alliance-crest-bw",  -- stem under media/artwork/
  w        = 512, h = 512,         -- authored pixel size, declared not measured
  tintable = true,
  credit   = "Your Name (CC0)" },  -- required; see Licensing
```

`id` is written into saved variables, so renaming one silently breaks every panel using it.

## Licensing

Submitted artwork must be redistributable under a license compatible with this addon's MIT
release. CC0, MIT, and public domain are fine. **Do not submit ripped or traced Blizzard art,
or anything under a non-commercial or no-derivatives license** — it cannot ship.

Every catalog row carries a `credit` string naming the author and the license. That field is
the attribution record; a submission without one cannot be accepted.
