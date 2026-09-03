# Shipped media

Four logo assets, one of which the game can actually load:

| File | Size | Ships to players | Purpose |
|---|---|---|---|
| `panelmaster.logo.tga` | 512×512, 24-bit RLE | **yes** | The runtime asset — `C.LOGO_PATH`, drawn on the settings landing page |
| `panelmaster.logo.png` | 2000×2000 | no | Master art; the source the `.tga` and the 256 avatar are rendered from |
| `panelmaster.logo.jpg` | 2000×2000 | no | Project page / CDN. Supplied alongside the master at full size, not downscaled from it |
| `panelmaster.logo.256.jpg` | 256×256 | no | README, thumbnails |

WoW cannot load `.png` or `.jpg` at runtime **at all**, and rescales any texture that is not a power
of two — hence a 512 TGA rather than the 2000 master. `.pkgmeta` excludes the three non-runtime
renders, so a player's download does not carry megabytes of files their client physically cannot use.

The failure mode here is silent: a missing or wrongly-named texture renders **nothing** and raises
**no error**, so it surfaces as a blank settings page that reads like a layout bug. A test therefore
asserts that the file `C.LOGO_PATH` names exists on disk, and the same for the debug console's
monospace face — which is no longer this addon's to ship. JetBrains Mono lives in the LibKa0s
payload (`libs/LibKa0s/media/fonts/`) and is reached through `NS.MediaFont`; `media/fonts/` here is
gone, along with the second copy of its license. The shared icon set the console's title bar draws
from arrives the same way. What stays under `media/` is this addon's own product — the artwork
catalog, the logo, the project-page plates — not chrome.

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

`media/artwork/raw/` is the **reserved** home for the source plate an asset was converted from,
named for the catalog id it produces, so a piece can be re-derived at a different size or with a
corrected margin without going back to whoever made it. It is excluded from packaging by `.pkgmeta`
and skipped by the catalog generator (`update_catalog.py`'s `SKIP_DIRS`) — the same reasoning as the
logo's master renders, since the client cannot load a `.png` at all. **No plates are committed
there today**: the folder is absent from the working tree, and the shipped `.tga` set is the only
copy in the repo. See [artwork-spec.md](artwork-spec.md) for what belongs in it.

`media/poster/artwork-poster.png` is another non-runtime media asset, and the only **generated** one:
a single contact sheet of every catalog row, drawn by `tools/artwork/make_poster.py` and embedded in
the README so the artwork set is visible without a clone. `.pkgmeta` excludes it on the same
reasoning again. Two properties are load-bearing rather than incidental. It is built
from `update_catalog.py`'s scan rather than its own walk, so it cannot show a set the addon does not
have; and it renders from fonts vendored at `tools/artwork/fonts/` with no system fallback, so the
same tree renders the same picture on any machine. Its identity is that picture — `--check` compares
a fingerprint of the decoded pixels, not of the file, because PNG bytes are deflate's output and can
differ between zlib builds for pixels that are identical. It has a `artwork-poster.jpg` twin for the
CurseForge 2 MB upload cap — see the screenshots note below; the `--check` fingerprint is the PNG's,
since that is the generated master and the JPEG is a lossy derivative of it.
`media/poster/artwork-poster.txt` records
the fingerprint and the toolchain that produced it, so a mismatch can be attributed rather than
guessed at. Nothing in the addon reads any of it, which is exactly why staleness is undetectable by
either green-gate command — hence the `--check` mode and `docs/testing.md` ▸ *The artwork gate*.

`media/screenshots/` holds the four project-page captures the README's `## Screenshots` section
embeds. Like every non-runtime asset above they are committed but excluded wholesale by `.pkgmeta`,
and the README points at the **CurseForge CDN** copies rather than at these paths: CurseForge serves
the project page from its own CDN, so a repo-relative path renders on GitHub and nowhere else. These
are the sources those uploads were made from.

**PNG is the repo default, and the two JPEGs are not a half-finished conversion.** `.png` is what a
capture and a render are kept as, because it is lossless and re-derivable. **CurseForge caps an
uploaded image at 2 MB**, and exactly two assets exceed it — the 3439×1439 hero capture
(`panelmaster.screenshot.04.png`, 8.1 MB) and the artwork poster (`artwork-poster.png`, 2.1 MB). Each
therefore carries a JPEG twin beside its PNG master, compressed only to clear that limit, and it is
the twin the README links. `01` to `03` are under the cap and stay PNG on both sides, which is why
the set looks mixed: the format follows the file size, not a migration in progress. A new capture
under 2 MB needs no JPEG; one over it gets one, and the PNG stays as the master.

Both the asset requirements and the contribution rules are in
[artwork-spec.md](artwork-spec.md) and the README; `tools/` is an **accepted, documented deviation**
from the Ka0s WoW Addon Standard (approved 2026-07-31 — the standard defines no build-tooling
location, and this is the first non-Lua source in the tree).
