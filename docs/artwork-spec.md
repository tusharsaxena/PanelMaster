# Panel Master — Artwork

How artwork gets into this addon, end to end. Three scripts do the whole job:

| | |
|---|---|
| `tools/artwork/artwork_cleaner.py` | turns any image into the TGA the WoW client can load |
| `tools/artwork/update_catalog.py` | reads `media/artwork/` and rewrites the addon's catalog |
| `tools/artwork/make_poster.py` | draws every bundled piece into one contact sheet for the README |

There is **no manifest and no naming step**. The folder tree and the file names *are* the
configuration: what you call a file becomes its label, what folder you put it in becomes its
category. Name things the way you want them to appear.

**Scope:** this page is about art that *ships with the addon*. Themes from user-installed
[Sunn - Viewport Art](https://www.curseforge.com/wow/addons/sunn-viewport-art) packs also appear in
the artwork dropdown, and none of the below applies to them — nothing is converted, committed,
added to the catalog or licensed by us, because nothing is redistributed. `modules/SunnArt.lua`
reads what is already on the player's disk and synthesizes catalog rows at runtime. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) ▸ *Composites, and the Sunn adapter*.

---

## Quick start

**Requirements:** Python 3 with Pillow. `artwork_cleaner.py` also needs numpy;
`update_catalog.py` and `make_poster.py` do not.

```bash
pip install --user Pillow numpy
```

The upscaler is already vendored at `tools/artwork/bin/` — nothing to download.

### I have one image

```bash
python3 tools/artwork/artwork_cleaner.py --single ~/art/Emblem.png
```

Writes `~/art/Emblem-panelmaster.tga` beside the source. Nothing else is touched — this mode is
for checking a single piece before committing to a batch.

### I have a folder of images

```bash
python3 tools/artwork/artwork_cleaner.py --batch ~/art media/artwork
```

Every image under `~/art` is converted into `media/artwork`, **reproducing the folder structure
exactly** and keeping each file's name. `~/art/race/Tauren.png` becomes
`media/artwork/race/Tauren.tga`. Only the extension changes.

Then make the addon aware of them:

```bash
python3 tools/artwork/update_catalog.py
lua tests/run.lua
python3 tools/artwork/make_poster.py
```

That is the whole loop. `update_catalog.py` rewrites the catalog in `modules/Artwork.lua` from
whatever is on disk, and the test suite confirms every row points at a file that exists.

The poster is the odd one out and is listed last on purpose: nothing in the addon reads it, so
skipping it breaks nothing and fails nothing — it just leaves the README showing a set that no
longer exists. `make_poster.py --check` is what turns that back into a detectable state; see
[`testing.md`](testing.md) ▸ *The artwork gate*.

---

## What the folder tree decides

Everything. Given `media/artwork/faction/expansion/12-midnight/harati.tga`:

| Field | Value | Derived from |
|---|---|---|
| `file` | `faction\expansion\12-midnight\harati` | the path, minus the extension |
| `id` | `faction-expansion-12-midnight-harati` | the path, kebab-cased |
| `category` | `Faction -> Expansion -> 12 Midnight` | the folders, title-cased |
| `label` | `Harati` | the file name, title-cased |
| `w`, `h` | `1024`, `1024` | measured from the file |

So:

- **To rename a piece in the UI**, rename the file.
- **To move it to another group**, move the file.
- **To reorder groups**, rename the folders — they sort alphabetically, which is why numeric
  prefixes like `12-midnight` are useful. A leading number is understood as a sort key rather than
  a word, so `02-the-burning-crusade` reads as "02 The Burning Crusade".

Categories nest as deep as your folders do, and a child sorts adjacent to its parent because its
category string starts with the parent's.

`media/artwork/raw/` is **reserved**. It is excluded from packaging by `.pkgmeta`, so it is where
unshipped source images live if you want them in the repo; it never produces catalog rows.

### Naming rules

- Lowercase kebab-case is the convention (`night-elf.tga`), because the id derives from it.
- Apostrophes are dropped rather than hyphenated: `Mag'har` becomes `maghar`.
- `ALLCAPS` words survive as acronyms; `of`, `the`, `and`, `for` stay lowercase mid-label.
- Two files whose paths reduce to the same id is an **error**, reported by name — ids must be
  unique because they are the stored value.

---

## The `id` is permanent

A panel stores the artwork's `id` in saved variables. Renaming or moving a file changes its id, and
**every panel using it silently falls back to drawing nothing** on the next load. The addon
degrades rather than erroring — `modules/Artwork.lua` resolves an unknown id to no path — so
nothing tells you it happened.

Get the names right before art ships. Afterwards, treat a rename or a move as a breaking change.

---

## What the cleaner does to an image

In order, and the order matters:

| Stage | What | Why here |
|---|---|---|
| **erase** | blanks regions of the *source* (`--erase`, `--single` only) | Runs before anything else, so the blanked area travels the same path as the rest of the image and lands as genuine transparency. For burned-in watermarks and signatures — those are pixels, not metadata, so painting over them is the only removal there is. |
| **key** | derives alpha if the source has **none** | Floods inward from the border against a near-black field. Connectivity is what makes it safe: a plain brightness threshold would also punch holes through dark regions *inside* the art. Alpha ramps between luminance 16 and 48, which absorbs JPEG ringing. |
| **solidify** | pushes opaque color outward under the transparent pixels | The stage whose absence is invisible until too late. Sources disagree about what RGB sits under a transparent pixel — `(0,0,0,0)`, `(255,255,255,0)`, sometimes something arbitrary. Nothing renders it, so nothing complains. But an upscaler's kernel samples those pixels, so a white-under-alpha source grows a **white halo** along every edge. |
| **upscale** | Real-ESRGAN x4 per pass, chained | Skipped below 1.25x, where the model would blow the image up 4x and throw nearly all of it away to sharpen something already at target size. One model for everything, so art sitting side by side in one dropdown sharpens with consistent character. |
| **fit** | letterbox onto a square power-of-two canvas | Never crops. Aspect is preserved, and the padding supplies the transparent margin the `FILL` and `TILE` fills need. |
| **pad** | shrinks slightly if the art would touch the frame | Automatic, by exactly the shortfall. A wide image always lands with zero margin on its long axis. |
| **normalize** | forces every transparent pixel to `(0,0,0,0)` | Must be last. LANCZOS premultiplies and a paste carries its canvas color in, so normalizing earlier is simply undone by the next step. |

### Reading the report

Each converted file prints one line:

```
race/tauren.tga    realesrgan-x4  need  2.93x  alpha 0-255  margin 28   1540KB
```

- **`need`** — how much upscaling was required. Above roughly 5x the result will be soft no matter
  what; the model sharpens, it does not invent detail that was never sampled. Find a bigger source.
- **`margin`** — transparent pixels between the art and the frame edge. `auto-padded Npx` means it
  came up short and was corrected.
- **`keyed`** — the source had no alpha, so transparency was *inferred*. Worth eyeballing.
- Warnings appear for an empty plate, or one with nothing near-opaque.

---

## Choosing source images

The cleaner is only as good as what it is given.

| | |
|---|---|
| **Best** | PNG or WebP with a real alpha channel, at least 1024 px on the short edge |
| **Fine** | Anything with alpha at 400 px or more — upscaling 2-3x is what the model is good at |
| **Poor** | Under 200 px, or a JPEG on a solid background — expect softness and check the edges |
| **Avoid** | A watermark you cannot locate, or art on a busy background |

A file named like `250px-Something.png` is usually a *thumbnail*. The original is almost certainly
larger, and re-downloading it beats any upscaler.

Square-ish art works best. A very wide image is letterboxed into the square canvas, so most of the
texture ends up transparent — correct, but wasteful.

---

## Tinting, and why Desaturate exists

Every piece takes the per-panel **Artwork color**, whose default is white — and multiplying by
white is a no-op, so nothing is tinted until you choose a color. There is no per-asset opt-out;
the catalog carries no `tintable` field.

That is worth stating because tinting full-color art naively does not work. The tint is a
multiply, so a blue tint on a gold-and-crimson crest drags every hue toward blue and returns muddy
brown — not blue.

**Desaturate** is the answer. It drains the art to grayscale in hardware *before* the tint applies,
so the tint multiplies against neutral gray and comes back as a clean, saturated version of the
color you picked. Desaturate + Artwork color turns any of the bundled full-color pieces into a
tintable plate at runtime, per panel, with no re-authoring.

Art authored **white-on-transparent** — every visible pixel RGB `(255,255,255)` with the whole
shape carried by the alpha channel — takes a tint cleanly without Desaturate, because it is already
neutral. That is still the best way to author art meant primarily to be tinted. Put the shading in
the alpha channel, never in the brightness: a pixel at half strength is white at alpha 128, not
gray at alpha 255, because gray multiplied by a tint returns a dark, desaturated tint.

**Blend mode** is separate from all of this. *Normal* paints over the panel obeying transparency;
*Glow* (the API's `ADD`) adds the artwork's light to what is behind, so it can only brighten. Glow
is correct by construction here because the cleaner normalizes every transparent pixel to
`(0,0,0,0)` — black adds nothing. The other three WoW blend modes are not offered: `MOD` needs
transparency to be white, `DISABLE` ignores the alpha channel entirely, and `ALPHAKEY` hard-edges
the art and defeats the opacity slider.

## Reference

### `artwork_cleaner.py`

```
--single FILE          convert one image; writes FILE-panelmaster.tga beside it
--batch SRC DST        convert every image under SRC into DST, mirroring the tree
--size N               output edge length, power of two (default 1024)
--pad PX               force this much transparent margin (default: auto, only when short)
--erase L,T,R,B        blank source regions first; several separated by ';'  (--single only)
--no-ai                Lanczos only, skip the upscaler — fast, useful for framing checks
--force                reconvert even if up to date
--dry-run              list what --batch would do, and write nothing
--quiet, -q            suppress per-stage progress; print only the result lines
```

**It narrates what it is doing.** The upscaler runs on the CPU here, so a single pass over a few
megapixels is tens of seconds with no output of its own — which looks exactly like a hang. Every
stage prints as it starts, with its timing, and a batch prints an `[n/N]` header per file:

```
alliance-symbol.png
    plan       184x255, need 4.02x -> 1 upscaler pass, then fit to 1024x1024
    solidify   edge-extending color under transparent pixels ... 0.0s
    upscale    pass 1/1  184x255 -> 736x1020  4.4s
    fit        736x1020 -> 1024x1024 ... 0.0s
    normalize  forcing transparent pixels to (0,0,0,0) ... 0.0s
```

Progress goes to **stderr** and results to **stdout**, so `> log.txt` captures the results without
the progress noise.

**Upscaling stops a few percent short when that saves a whole pass.** The model only works in jumps
of x4, so an image needing 4.02x would otherwise chain a second full pass to 16x — for a 184x255
source that is a 2944x4080 intermediate, twelve million pixels and about a minute, nearly all of it
discarded on the way back down to 1024. One pass already reaches 736x1020, four pixels short, and
letting Lanczos stretch that last 0.4% is invisible. The shortfall is capped at 5%.

Reads PNG, WebP, JPEG, GIF, BMP and TGA. Non-image files in a `--batch` tree are ignored, so a
README or a stray `.txt` beside the art is not an error.

A batch re-run **skips files that are already up to date**, judged on a fingerprint of everything
that determines the output: the source bytes, `--size`, `--pad`, `--no-ai`. Change any of them and
the file reconverts; change nothing and it is skipped *by name*, so you can always see what was
left alone.

**Removing a watermark.** Find its pixel box in the *source* image, then:

```bash
python3 tools/artwork/artwork_cleaner.py --single art/Crest.jpg --erase 0,522,262,550
```

`L,T,R,B` in source pixels from the top-left. A box outside the image is an error rather than a
silent no-op — a mistake here should be loud, not ship the watermark.

### `update_catalog.py`

```
(no arguments)         rewrite the catalog block in modules/Artwork.lua
--check                exit 1 if the catalog is out of date; write nothing
--print                print the generated rows and exit
```

It rewrites only the region between the `BEGIN GENERATED CATALOG` and `END GENERATED CATALOG`
markers in `modules/Artwork.lua`. Everything outside those markers is hand-owned and untouched.

**Do not hand-edit rows inside the markers.** They are regenerated wholesale from disk, so an edit
survives exactly until the next run. Rename the file instead.

It reports problems it finds — a non-power-of-two texture, a duplicate id, an unreadable file — and
refuses to write on the ones that would produce a broken catalog.

### `make_poster.py`

```
(no arguments)         render every bundled piece into media/poster/artwork-poster.png
--check                exit 1 if the committed poster is missing or out of date; write nothing
--out PATH             write somewhere else
```

It writes two files: the PNG, and `artwork-poster.txt` beside it — a provenance record carrying the
poster's pixel fingerprint, the addon version, the sha256 of each bundled font and the
Pillow/FreeType/zlib versions that built it. Both are committed. The record is what lets `--check`
name the component that moved when a mismatch turns up, instead of leaving a reviewer to argue about
a binary diff.

The poster is stamped with the addon's `## Version:` from the TOC, which makes **a version bump
stale the poster**: regenerate after `/wow-addon:bump-version`. A build *date* was rejected for the
obvious reason — it would change on every run, and a file that differs from the committed one every
time it is generated cannot be checked for staleness at all.

**It does not walk `media/artwork/` itself.** It imports `update_catalog.py` and calls that script's
scan, so the poster and the catalog are two renderings of one list — the `raw/` exclusion and the id
and label derivation come from `scan()`, and the order from the `SORT_KEY` both scripts sort by. The
fatal-problem policy is shared the same way, through `is_fatal()`, so the two cannot succeed on
different inputs either. Two walks would be two chances to disagree, and the
disagreement would be invisible: a poster showing art the addon does not have still looks fine.

**The fonts are bundled at `tools/artwork/fonts/` and there is no fallback.** A missing one exits
with the path it wanted rather than reaching for a system font, because the whole point is that the
same tree renders the same picture anywhere. The same reasoning pins the text layout engine to
`BASIC` and places every string on a whole pixel — a fractional text x is the one thing two Pillow
builds were observed to rasterize differently.

**The poster's identity is its pixels, not its bytes.** `--check` compares a sha256 of the decoded
image, not of the file, and the distinction is the difference between a guarantee and a wish: the
pixels are this script's output and every input to them is pinned, but the bytes are deflate's, and
a zlib-ng build can compress identical pixels into a different PNG through no fault of anything
here. A plain run also **rewrites nothing when the pixels already match**, so a contributor on a
different toolchain cannot churn two megabytes of visually identical binary into the history.

That leaves one input a script cannot pin: a FreeType whose glyph rasterization changes would move
the pixels themselves. It is recorded rather than pinned — hence `artwork-poster.txt`, and hence
`--check` printing which of Pillow, FreeType or zlib differs from the build that made the committed
image.

Everything visible on the sheet is derived: the gold headings are catalog `category` strings, the
caption under each tile is its `label`, ellipsized rather than wrapped when it overruns, and the
footer carries the TOC version and `len(rows)`. There is nothing to hand-edit — regenerate instead.

---

## Asset requirements

What a texture must satisfy to load and render correctly. `artwork_cleaner.py` produces all of
this; the table matters if you are hand-authoring or importing by another route.

| Property | Requirement | Why |
|---|---|---|
| Format | 32-bit TGA, uncompressed or RLE, with alpha | WoW loads `.tga` and `.blp`. It cannot load `.png` or `.jpg` at all. |
| Dimensions | Power of two on both axes | Non-power-of-two textures fail to load or render corrupt on some drivers, and the `TILE` fill cannot wrap them. |
| Aspect | Square canvas — letterbox, never crop | The catalog declares `w`/`h`, and cropping to a content bbox tilts art drawn symmetrically about its center. |
| Background | Fully transparent, **not** white or black | The panel's own fill shows through. An opaque background makes the panel's background color and opacity settings pointless. |
| RGB under alpha 0 | Must be `(0,0,0,0)` | Three of the five blend modes read RGB where alpha is zero. A source whose transparent pixels are white paints a white ghost. |
| Edge padding | At least 4 px of transparent margin | Stops the `FILL` crop and the `TILE` wrap shaving the outermost pixels. |
| Size | ~1.7 MB typical at 1024 as RLE | RLE is a **disk** saving only. WoW expands to 32 bpp in VRAM, so a 1024 texture costs 4 MB of video memory whether compressed or not, against 1 MB at 512. That is the number to weigh. |

---

## Licensing

Artwork **contributed to this addon** must be redistributable under a license compatible with its
MIT release. CC0, MIT and public domain are fine. Do not contribute anything under a
non-commercial or no-derivatives license, and do not contribute traced Blizzard art as your own
work.

The currently bundled set is a knowing exception recorded in `docs/pending/LEDGER.md`
(`ARTWORK-01`): it is Blizzard-owned art shipped under fan-work terms rather than under a license
this project can grant onward. Attribution for it lives in `README.md`. Do not treat it as
precedent for a contribution.

If you are making art **for your own use**, none of this applies. Convert whatever you like and
point a panel at it with the editor's **Custom path** option, which takes any texture path without
touching the catalog at all.

---

## Where the tooling lives, and why that is a deviation

**This is an accepted, documented deviation from the [Ka0s WoW Addon
Standard](https://github.com/tusharsaxena/WowAddonStandards).** The standard defines no location for
build tooling, and `tools/artwork/` is the first non-Lua source in the tree. Accepted on 2026-07-31:
keeping the conversion in the repo is what makes an asset re-derivable and its licensing auditable.
`luacheck` is unaffected — it only walks Lua, and `.pkgmeta` ignores `tools` outright, so none of it
reaches a player.

This note lived in `README.md` until 2026-08-05, when the README was rewritten for players rather
than contributors. The related asset decisions — the vendored upscaler, the bundled poster fonts and
the ungated poster — are `ARTWORK-04`, `ARTWORK-06` and `ARTWORK-05` in `docs/pending/LEDGER.md`.
