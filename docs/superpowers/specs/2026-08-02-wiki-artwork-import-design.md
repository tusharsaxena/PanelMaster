# Warcraft Wiki artwork import pipeline — design

**Date:** 2026-08-02
**Status:** implemented on `feat/wiki-artwork-pipeline`. See *As built* at the end for what changed.

Turns a directory of Warcraft Wiki artwork into 104 bundled catalog assets, repeatably. The
existing `tools/artwork/import.py` converts *generated* plates one at a time; this pipeline
converts *downloaded* art in bulk, and the two problems are different enough to want different
entry points.

## Why this is a separate tool

`import.py` exists to key alpha out of a plate that has none — an image model hands back white on
black, or color on magenta, and the script derives transparency from it. Every assumption it makes
follows from that.

The wiki sources invert all of them. 104 of 107 arrive with a **real alpha channel already**, so
the job is to *preserve* transparency rather than manufacture it. Running `to_tintable` or
`chroma_key` over them would discard the alpha they came with and re-derive a worse one from
luminance. The correct handling is nearly the opposite of what `import.py` does, which is why this
is a sibling script and not a flag.

## Source survey

Measured over `/mnt/d/Profile/Users/Tushar/Downloads/warcraft wiki`, 107 files.

| Property | Finding |
|---|---|
| Alpha | 104 of 107 already transparent; 3 opaque JPEGs need keying |
| Formats | 68 PNG, 36 WebP, 3 JPEG |
| Size range | 75×90 (`Race-icon-vrykul.webp`) to 2880×1312 (`2880px-Legionlogo.png`) |
| Saturation | **All 107 are full color.** Zero monochrome/tintable candidates. |
| Duplicates | 3 byte-identical pairs (verified by MD5) |

Upscale factor needed to reach a 1024 box:

| Band | Count | Handling |
|---|---|---|
| < 1.0× (downscale) | 19 | Lanczos, no AI |
| 1.0–1.5× | 7 | Lanczos |
| 1.5–2.5× | 24 | Real-ESRGAN |
| 2.5–5× | 41 | Real-ESRGAN |
| ≥ 5× | 16 | Real-ESRGAN, **result will still be soft** |

### Transparent-pixel RGB is inconsistent across sources

The single most important finding. Transparent pixels carry different RGB depending on the
source: `(0,0,0,0)` on most, `(255,255,255,0)` on the `MajorFactionsIcons` set and much of
`class/`, and `(217,182,103,0)` on `race/Human_Crest.png`.

This is invisible in a normal viewer and destructive in two places:

1. **Upscaling** blends neighbouring pixels. A white-under-alpha source bleeds a white halo into
   every emblem edge; a black-under-alpha source bleeds a dark one.
2. **Three of the addon's blend modes read RGB under zero alpha** — Additive adds it, Alpha-key
   thresholds and draws it opaque, Opaque ignores alpha entirely. This is the exact failure
   `import.py`'s `normalize_transparent` docstring records against `alliance-crest-color`.

Both are handled, at different stages: *solidify* before upscaling, *normalize* after fitting.

### Duplicates

| Pair | MD5 | Resolution |
|---|---|---|
| `2560px-Dragonflight_logo.png` / `… (1).png` | `fa2f38e8…` | drop the `(1)` |
| `FlamesRadiance-MajorFactionsIcons.png` / `… (1).png` | `1810b70a…` | drop the `(1)` |
| `class/Dracthyr_Crest.webp` / `race/Dracthyr_Crest.webp` | `47ae684c…` | **keep both** |

Dracthyr is kept twice deliberately. `class/` contains no Evoker crest, so that copy is the Evoker
stand-in; the two outputs are semantically distinct catalog entries that happen to share a source
image. They become `classes/evoker.tga` and `races/dracthyr.tga`.

One **near**-duplicate is also dropped: `Race-icon-arakkoa.webp` (75×90) and
`Race-icon-arakkoabig.png` (188×276) are the same emblem at two thumbnail sizes. The larger is
kept as `races/arakkoa`; the 75 px cut is discarded rather than upscaled 11×, since it carries no
detail the 188 px version lacks. This is the general rule wherever the wiki served two cuts of one
image.

**104 unique assets ship.**

## Output contract

| Property | Value |
|---|---|
| Path | `media/artwork/<category>/<subject>.tga` |
| Directories | `general`, `races`, `classes`, `expansions`, `factions` — lowercase |
| Catalog `category` | `General`, `Races`, `Classes`, `Expansions`, `Factions` — the exact capitalized values in `C.ARTWORK_CATEGORIES`, which `C.ARTWORK_CATEGORY_SET` validates against |
| Dimensions | 1024 × 1024, letterboxed, aspect preserved, ≥ 4 px transparent margin |
| Encoding | 32-bit RLE TGA |
| `tintable` | `false` for all 104 |
| Sources | `media/artwork/raw/<category>/<subject>.<ext>` |
| Pack size | ~179 MB shipped, ~66 MB of raw sources (git only) |

`raw` is reserved and cannot be a category name — `media/artwork/raw/` already exists and is
excluded from packaging by `.pkgmeta` while staying in git, so a corrected asset can be re-derived
without re-downloading. Nesting the sources by category keeps the existing convention that a raw
file is named for the catalog id it produces.

### No addon code changes are required

`modules/Artwork.lua:128` derives the texture path by bare concatenation:

```lua
return C.ARTWORK_PATH_PREFIX .. row.file .. ".tga"
```

A `file` stem of `"classes\\warrior"` therefore resolves to
`Interface\AddOns\PanelMaster\media\artwork\classes\warrior.tga` with no change to the resolver,
`C.ARTWORK_PATH_PREFIX`, or the validation in `tests/test_artwork.lua`. The existing
path-existence test at `tests/test_artwork.lua:159` already normalizes separators and will check
all 104 new rows for free.

Backslash is used in the stem rather than forward slash so the assembled path has one separator
convention throughout.

## Pipeline stages

Manifest-driven. Catalog ids are written into saved variables and can never be renamed, so they
are reviewed as data before any file is written.

1. **Manifest** — `tools/artwork/manifest.tsv`, committed and hand-editable. One row per source:
   `source_path`, `category`, `subject`, `label`, `credit`. A `--scaffold` pass generates it once
   by applying the naming rules below; from then on the file is authoritative and the pipeline
   never re-derives a name. This is what makes the run repeatable and the ids stable.

2. **Ingest** — Pillow opens PNG, WebP and JPEG uniformly and converts to RGBA.

3. **Solidify alpha** — edge-extend the RGB of opaque pixels outward into the transparent region,
   so color under zero alpha is a continuation of the art rather than an arbitrary constant.
   Runs *before* upscaling, because that is the step whose filter kernel would otherwise sample
   it. Without this, the inconsistent transparent RGB documented above becomes a visible halo.

4. **Key the three opaque JPEGs** — `Mogu_crest.jpg`, `800px-DrustRaceIcon.jpg`,
   `Icon_of_the_Damned.jpg`. Corner-seeded flood fill against a near-black background with a
   threshold loose enough to absorb JPEG ringing. These three are the only outputs whose
   correctness is genuinely uncertain and they get individual visual review.

5. **Upscale** — `realesrgan-ncnn-vulkan`, ×4 per pass, repeated where more is needed, RGB and
   alpha carried together. Sources already at or above the target skip to Lanczos. Every result
   lands on the exact target box by a final Lanczos step, so the AI never determines final
   dimensions.

6. **Fit** — letterbox onto a 1024 × 1024 transparent canvas via the existing `fit_square`, with
   the `--pad` margin guarantee. Composition is preserved rather than cropped to a content bbox,
   because these emblems are drawn symmetrically about the frame center and re-centering on a
   lopsided bbox visibly tilts them.

7. **Normalize transparent** — force every zero-alpha pixel to `(0,0,0,0)`. Must run **last**,
   after every resize and paste, since LANCZOS premultiplies and a paste carries its canvas color
   in — normalizing earlier just gets undone.

8. **Emit** — RLE TGA to `media/artwork/<category>/<subject>.tga`.

9. **Generate catalog** — emit 104 Lua rows for `modules/Artwork.lua`.

10. **Report** — per asset: source dimensions, scale factor, engine used, alpha extrema, content
    bbox, margin, output bytes. Plus a contact-sheet PNG of all 104 results for review in one pass.

## Naming rules

Applied by `--scaffold` to produce the manifest, then frozen.

- Strip MediaWiki resolution prefixes: `1024px-`, `2560px-`, `250px-`, `2880px-`.
- Strip trailing ` (1)` duplicate markers.
- Strip descriptive suffixes: `_Crest`, `-Icon`, `_Icon`, `_logo`, `-MajorFactionsIcons`,
  `_Race_Icon`, `Race-icon-`.
- Lowercase; apostrophes dropped (`Mag'har` → `maghar`, `Twilight's_Hammer` → `twilights-hammer`);
  spaces and underscores to hyphens.
- CamelCase split on case boundaries (`ValdrakkenAccord` → `valdrakken-accord`).

### Category mapping

| Source | Category |
|---|---|
| `class/` | `classes` |
| `race/` | `races` |
| `expansion/` | `expansions` |
| `faction/major/`, `faction/expansion/1*/` | `factions` |
| `faction/expansion/00-archeology/` | `races` — these depict races, not factions |
| `other/` clan crests | `factions` |
| `other/Icon_of_Defeat`, `other/Icon_of_the_Damned` | `general` |
| `race/Icon_of_Blood` | `general` |

Two collisions arise from routing the archaeology icons to `races` and are resolved explicitly:

| Sources | Ids |
|---|---|
| `race/Nightborne_Crest.webp`, `…/Nightborne_Race_Icon.webp` | `races/nightborne`, `races/nightborne-legion` |
| `race/Highmountain_Tauren_Crest.webp`, `…/Highmountain_tauren_Legion_Icon.png` | `races/highmountain-tauren`, `races/highmountain-tauren-legion` |

## Components

| File | Status | Purpose |
|---|---|---|
| `tools/artwork/plate.py` | new | Shared primitives extracted from `import.py`: `TRANSPARENT`, `normalize_transparent`, `fit_square`, `_luma`, `BLACK_FLOOR`, `CONTENT_FLOOR`, `MIN_MARGIN` |
| `tools/artwork/wiki_import.py` | new | Batch driver. Flags: `--scaffold`, `--only <glob>`, `--force`, `--dry-run`, `--contact-sheet` |
| `tools/artwork/manifest.tsv` | new | The 104-row mapping, committed |
| `tools/artwork/bin/realesrgan-ncnn-vulkan` | new | Vendored binary + models, ~30 MB |
| `tools/artwork/import.py` | edited | Consumes `plate.py`; behavior unchanged |
| `modules/Artwork.lua` | edited | 104 generated catalog rows appended |
| `docs/artwork-spec.md` | edited | Rewritten for the directory convention |
| `docs/pending/LEDGER.md` | edited | Three accepted deviations recorded |

`plate.py` is extracted rather than duplicated because the transparent-pixel invariant is subtle,
already cost one debugging cycle (recorded in `normalize_transparent`'s docstring), and would
otherwise be independently reimplemented in two scripts free to drift apart.

The binary is committed rather than fetched so the toolchain survives an upstream release
disappearing. `.pkgmeta` already excludes `tools`, so it never reaches players — the cost is git
repository size and Linux-x86-64 specificity, not download size.

## Known limitations

**The 16 sources at ≥ 5× will not look like native 1024 px art.** Real-ESRGAN sharpens and cleans
edges; it does not invent heraldic detail that was never sampled. The `75px-` and `250px-`
filename prefixes indicate these are MediaWiki *thumbnails*, and full-resolution originals almost
certainly exist upstream. Re-sourcing them is strictly better than any upscaler, and because the
pipeline is manifest-driven it is a source-file swap and a re-run — no id changes, no catalog
churn.

**Vulkan is software-only in this environment.** `/usr/share/vulkan/icd.d/` contains no NVIDIA ICD,
only `lvp_icd.json` (lavapipe). Real-ESRGAN will run on CPU. Acceptable for a one-shot batch —
expect roughly 1–3 hours unattended — but installing the NVIDIA WSL Vulkan ICD is worthwhile
before any repeat run.

**The three keyed JPEGs are the weakest outputs.** JPEG ringing around a near-black background
does not threshold cleanly, and no amount of parameter tuning fully removes it. If the result is
unacceptable, re-sourcing a PNG is the fix.

## Accepted deviations from the Ka0s WoW Addon Standard

All three were raised before the decision and confirmed. Recorded in `docs/pending/LEDGER.md`.

1. **Licensing.** `docs/artwork-spec.md` states *"Do not submit ripped or traced Blizzard art… it
   cannot ship."* These are Blizzard-owned Warcraft Wiki assets and they ship anyway. The `credit`
   field records provenance honestly rather than claiming a license the art does not have.

2. **File size.** The spec caps assets at ~1.5 MB. At 1024 × 1024 RLE the measured average is
   1.72 MB, and the pack totals ~179 MB. Chosen over the 48.5 MB 512 × 512 option for fidelity.
   Note this also costs 4 MB of VRAM per distinct texture in use, since WoW decompresses RLE TGA
   to 32 bpp — RLE saves disk, not video memory.

3. **Naming.** The mandatory `-bw`/`-color` suffix is dropped in favour of
   `<category>/<subject>.tga`. Tint behavior is no longer visible in a file listing; the catalog
   row's `tintable` field is the sole source of truth. `docs/artwork-spec.md` is rewritten to
   match.

## Verification

| Check | What it proves |
|---|---|
| `lua tests/run.lua` | `tests/test_artwork.lua:159` asserts every catalog row's derived path exists on disk — all 104 rows validated automatically. Row shape, category membership and `w`/`h` are covered by the existing suite. |
| `luacheck .` | 0/0, unchanged |
| Contact sheet | All 104 outputs reviewed in one pass for halos, clipping and failed keys |
| Per-asset report | Alpha extrema and content bbox catch a silently-empty or margin-less conversion |
| Re-run idempotence | A second run with an unchanged manifest produces byte-identical outputs |

The green gate is unchanged: `lua tests/run.lua` and `luacheck .` before commit.


---

## As built

The design above is what was agreed. This records where the implementation departed from it, and
why — measured rather than assumed.

### Corrected estimates

| Claim in the design | Measured |
|---|---|
| "1-3 hours unattended" for the batch | **~33 minutes.** 154k output px/sec on llvmpipe, 83 assets needing the upscaler. |
| 105 assets | **104.** `Race-icon-arakkoa.webp` (75x90) is a thumbnail of `Race-icon-arakkoabig.png` (188x276) and loses the id to the larger cut. |
| "Real-ESRGAN via the vendored binary" | Confirmed working on **software Vulkan** (llvmpipe), and it **preserves the alpha channel** — both were assumptions worth testing before building around them. |

### Added, not in the design

- **`erase` manifest column.** Discovered during the sample run: `Icon_of_the_Damned.jpg` carries a
  burned-in "(c) 2006 Blizzard Entertainment" line and an artist signature. Those are pixels, not
  metadata. Boxes are applied to the source before keying so the blanked region lands as genuine
  transparency, and a box outside the source is an error rather than a silent no-op.
- **Auto-pad.** A letterboxed wide logo always lands with zero margin on its long axis, so
  `expansions/classic` and `races/human` both tripped the margin warning. Padding by exactly the
  shortfall beats a blanket `--pad` that shrinks art already carrying a 68px margin, and beats
  asking the author to notice a warning and re-run per file.
- **Fingerprint-based skip (`.stamps.tsv`).** The design implied an mtime check. Review proved that
  wrong: an edited `erase` box or a changed `--size` leaves the source untouched, so mtime answers
  "up to date", the stale TGA ships, and the run reports success. The fingerprint covers source
  bytes, `--size`, `--pad`, `--no-ai` and `erase` — and deliberately excludes `label`/`credit`,
  which cannot move a pixel.
- **Scaffold safety.** `--scaffold` at a mistyped path used to overwrite the manifest with a bare
  header and exit 0, destroying every hand-authored erase box. It now validates the directory,
  refuses when hand-authored rows would be orphaned, and writes atomically.
- **Manifest validation.** Duplicate ids and malformed subjects are rejected up front; previously a
  duplicate slot silently converted both rows to one file and reported success.
- **`AI_MIN_SCALE = 1.25`.** Below that the upscaler would run a full x4 pass and throw nearly all
  of it away — ~100 seconds to sharpen an image already at target resolution.

### Decided against

- **Model selection by required scale** (x2/x3/x4 from the `animevideov3` set) measured 1.7x faster
  — 19 min against 33. Rejected: these assets sit adjacent in a dropdown, and three models sharpen
  with visibly different character. One model, one look.
- **`plate.py` extraction was kept.** Verified byte-identical output from `import.py` across all
  three of its conversion paths, before and after.

### Verification performed

- `import.py` output byte-identical to the pre-refactor script on all three paths.
- 8-asset sample exercising every branch: white-under-alpha, the `(217,182,103,0)` source, all three
  opaque JPEGs, a two-pass 9x chain, an extreme-aspect downscale.
- All 104 emitted Lua rows parsed with `lua`, asserting unique ids, unique files, valid categories,
  `w`/`h`, `tintable`, `credit`, and the derived texture path.
- 18-agent adversarial review: 12 findings verified, 6 confirmed and fixed, 6 refuted — including
  one whose evidence cited source files that do not exist.
- Each of the 6 confirmed fixes re-tested against its original reproduction.
- `lua tests/run.lua` 607/607 and `luacheck .` 0/0.

### Not done, deliberately

The full 104-asset batch has **not** been run and no catalog rows have been added to
`modules/Artwork.lua`. Adding 104 rows without their TGAs would fail `tests/test_artwork.lua:159`,
which asserts every row's derived path exists. The pipeline emits the rows on demand
(`--emit-catalog`); they get pasted in after the batch runs.
