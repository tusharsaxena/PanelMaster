#!/usr/bin/env python3
"""Render a single PNG contact sheet of every artwork that ships with the addon.

The poster is a *derived* file, not an authored one. It exists so a reader of the project page can
see the whole artwork set at a glance without cloning, and it must never be able to disagree with
what the addon actually loads. Both guarantees come from one decision: the poster is built from
update_catalog.scan() — the same walk, the same SKIP_DIRS pruning, the same label and category
derivation that writes modules/Artwork.lua. There is no second list of artwork here to drift.

What each part of the page is derived from:

    group heading   the row's `category` -- "Faction -> Expansion -> 12 Midnight"
    tile            the row's TGA, letterboxed onto the tile backing
    label           the row's `label` only, ellipsized if it overruns the tile
    order           update_catalog.SORT_KEY -- the object the catalog itself sorts by
    "vX.Y.Z"        the `## Version:` line of PanelMaster.toc -- see addon_version()
    "N artworks"    len(rows)

Determinism is the headline requirement, and it is stated as a guarantee about PIXELS rather than
about file bytes -- because only one of those two is this script's to make.

Five things are pinned so the pixels cannot drift, each marked at its line below: the fonts are
loaded only from tools/artwork/fonts/ and never from the system, the text layout engine is forced to
BASIC so a machine with libraqm installed lays out identically to one without, all text is placed on
whole pixels so no sub-pixel offset is left for a rasterizer to round its own way, the stamp is the
TOC version and never a build date, and every iteration runs over the sorted row list rather than a
dict or a set.

The file's BYTES are deflate's output, and deflate is not ours: a zlib-ng build can compress
identical pixels into a different PNG. So the poster's identity is its pixel fingerprint, not its
sha256 --- see fingerprint(). --check compares pixels, which means a toolchain difference no longer
reports staleness that isn't there; and a plain run REWRITES NOTHING when the pixels already match,
which is what keeps a 2 MB binary from churning in the history for changes nobody made.

That leaves exactly one unpinnable input: a FreeType whose glyph rasterization changes would move
the pixels themselves. It cannot be pinned from inside a script, so it is recorded instead ---
media/poster/artwork-poster.txt carries the fingerprint, the font hashes and the Pillow/FreeType/zlib
versions of the build that produced the committed image, and --check names the component that
differs when a mismatch shows up. Diagnosis by evidence rather than by argument.

The fonts live under tools/ rather than media/ deliberately. media/ is for assets the *client*
loads; these are read only by this script at build time, are excluded from the package by .pkgmeta's
`tools` ignore, and are kept next to their only consumer so the "fail loudly if absent" contract is
obvious. Do not move them to media/fonts/.

Usage:
    python3 tools/artwork/make_poster.py             # render and write media/poster/
    python3 tools/artwork/make_poster.py --check     # exit 1 if the committed poster is stale
    python3 tools/artwork/make_poster.py --out PATH  # write somewhere else

Requires Pillow.
"""

import argparse
import hashlib
import io
import math
import os
import sys

import PIL
from PIL import Image, ImageDraw, ImageFont, features

HERE = os.path.dirname(os.path.abspath(__file__))

# The catalog scanner is a sibling script, not an installed package, and the documented way to run
# these tools is `python3 tools/artwork/...` from the repo root — where tools/artwork/ is not on the
# path. Import by path so both invocations work. update_catalog has no import-time side effects: no
# I/O, no argparse, and its sys.exit() is behind __main__.
sys.path.insert(0, HERE)
import update_catalog as catalog                                            # noqa: E402 - needs the path above

REPO = catalog.REPO
ART_DIR = catalog.ART_DIR
OUT_PNG = os.path.join(REPO, "media", "poster", "artwork-poster.png")

# The provenance record, written beside the poster and committed with it. See build_record().
OUT_TXT = os.path.splitext(OUT_PNG)[0] + ".txt"

TOC = os.path.join(REPO, "PanelMaster.toc")

# Bundled, and only ever bundled. A system font would render differently on every machine, which
# silently breaks the byte-identical guarantee that --check depends on; a missing file is therefore
# a hard stop, never a fallback.
FONT_DIR = os.path.join(HERE, "fonts")
FONT_REGULAR = os.path.join(FONT_DIR, "DejaVuSans.ttf")
FONT_BOLD = os.path.join(FONT_DIR, "DejaVuSans-Bold.ttf")

# ------------------------------------------------------------------------------------------------
# The approved layout
# ------------------------------------------------------------------------------------------------

# Dark, because the artwork is overwhelmingly dark-edged and light-on-light loses the tile borders.
BG = (18, 18, 22)
TILE_BG = (32, 33, 40)          # what a transparent pixel resolves to — the poster has no alpha
TILE_EDGE = (64, 66, 78)        # the 1px tile border, and every rule on the page
TEXT = (222, 224, 232)
DIM = (150, 153, 165)
GOLD = (255, 209, 102)          # the addon's accent; used for the category headings only

COLS = 8                        # 8 * 150 + 7 * 22 + 2 * 48 = 1450px wide, a comfortable page width
BOX = 150                       # the tile itself; artwork is letterboxed into BOX - 12
GAP = 22
MARGIN = 48
LABEL_BAND = 30                 # reserved under each tile for the one-line label
TOP = 170                       # first heading's baseline area, clear of the header block

INSET = 12                      # breathing room between the artwork and the tile edge
LABEL_PAD = 8                   # tile bottom to label top
LABEL_OVERHANG = 8              # a label may run this far past the tile before it is ellipsized

HEADING_H = 34                  # heading row height, from its top to the first tile's top
GROUP_GAP = 14                  # extra separation between one category block and the next

# Header block. Fixed positions rather than measured text, so a font metrics change cannot move the
# grid and invalidate every previously generated poster.
TITLE = "Panel Master"
SUBTITLE = "Bundled artwork — every texture that ships with the addon"
FOOTER_LEFT = "github.com/tusharsaxena/PanelMaster"
TITLE_XY = (48, 40)
SUBTITLE_XY = (48, 96)
HEADER_RULE_Y = 138

# Footer block, measured down from the bottom of the last label band.
FOOTER_RULE_PAD = 36
FOOTER_TEXT_PAD = 22            # rule to the top of the footer text
FOOTER_TEXT_H = 22              # the 17px line's own box
FOOTER_BOTTOM = 26              # true bottom margin under it

SIZE_TITLE = 46
SIZE_SUBTITLE = 20
SIZE_HEADING = 21
SIZE_LABEL = 15
SIZE_FOOTER = 17

ELLIPSIS = "…"


# ------------------------------------------------------------------------------------------------
# Inputs
# ------------------------------------------------------------------------------------------------

def font(path, size):
    """A bundled font at `size`, or a hard stop naming the file that is missing."""
    if not os.path.isfile(path):
        sys.exit(
            "bundled font missing: %s\n"
            "The poster must not fall back to a system font — that would make the output differ "
            "between machines and break --check.\n"
            "Restore tools/artwork/fonts/ (DejaVuSans.ttf, DejaVuSans-Bold.ttf) from git."
            % path
        )
    # BASIC, not the default. Pillow uses libraqm for text layout when it is installed and its own
    # basic layout when it is not, and the two do not always place glyphs identically. Forcing the
    # engine makes the render independent of how Pillow happened to be built.
    return ImageFont.truetype(path, size, layout_engine=ImageFont.Layout.BASIC)


def addon_version():
    """The addon's version, read from the TOC.

    The poster carries a version rather than a build date, and the difference is not cosmetic. A
    wall-clock date changes on every run, so the poster would differ from the committed one the
    moment anybody regenerated it and --check could never mean anything. The TOC version changes
    exactly when a release happens — deliberately, by a human — which is the only kind of stamp a
    byte-identical artifact can carry.
    """
    with open(TOC, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("## Version:"):
                return line.split(":", 1)[1].strip()
    sys.exit("no '## Version:' line in %s — the poster stamps the addon version" % TOC)


def art_path(row):
    """The absolute path of a catalog row's TGA.

    Rebuilt rather than read off the row: `file` is escaped for a Lua string literal (its separators
    are DOUBLED backslashes), so it is not usable as a filesystem path anywhere but in Artwork.lua.
    """
    return os.path.join(ART_DIR, row["file"].replace("\\\\", "/") + ".tga")


def grouped(rows):
    """[(category, [row, ...]), ...] in the catalog's own order.

    Sorted by catalog.SORT_KEY — the same object update_catalog.render() sorts by, not a copy of it,
    so re-ordering the dropdown re-orders the poster and the two cannot drift. Groups are accumulated
    by walking that sorted list — never by iterating a dict, whose order would be an accident of
    insertion.
    """
    groups, order = {}, []
    for r in sorted(rows, key=catalog.SORT_KEY):
        if r["category"] not in groups:
            groups[r["category"]] = []
            order.append(r["category"])
        groups[r["category"]].append(r)
    return [(c, groups[c]) for c in order]


# ------------------------------------------------------------------------------------------------
# Drawing
# ------------------------------------------------------------------------------------------------

def ellipsize(draw, text, fnt, maxw):
    """`text`, trimmed until it fits `maxw`, with an ellipsis marking what was cut.

    Deliberately one line: wrapping to two would make tiles in the same row have different heights
    or force a taller band on every tile for the sake of a handful of long names.
    """
    # `text and` guards the empty label: it measures as 0 and would take this fast path back out
    # again, leaving the tile blank. A row can only reach that through a degenerate filename, but
    # the ellipsis below is the honest answer for it too.
    if text and draw.textlength(text, font=fnt) <= maxw:
        return text
    s = text
    while s and draw.textlength(s + ELLIPSIS, font=fnt) > maxw:
        s = s[:-1]
    # A label whose first character alone overruns the tile leaves nothing to trim. The bare
    # ellipsis is still honest — it says "there is a name here and it did not fit" — and it keeps
    # the tile from looking unlabeled.
    return (s + ELLIPSIS) if s else ELLIPSIS


def thumb(row):
    """One tile: the artwork letterboxed and centered on the tile backing.

    Composited rather than pasted because the TGAs are RGBA and their transparent regions must
    resolve to the tile color, not to black.
    """
    try:
        with Image.open(art_path(row)) as src:
            im = src.convert("RGBA")
    except Exception as exc:                              # noqa: BLE001 - re-raised as one type
        raise RuntimeError("%s: unreadable (%s)" % (row["file"], exc))

    cell = Image.new("RGBA", (BOX, BOX), TILE_BG + (255,))
    im.thumbnail((BOX - INSET, BOX - INSET), Image.LANCZOS)
    cell.alpha_composite(im, ((BOX - im.width) // 2, (BOX - im.height) // 2))
    return cell


def layout_height(groups):
    """The page height for these groups, computed before anything is drawn.

    Done up front because Pillow cannot grow a canvas: the full height has to be known to allocate
    the image, and the footer has to be placed against the real bottom of the grid.
    """
    y = TOP
    for _, items in groups:
        y += HEADING_H
        y += math.ceil(len(items) / COLS) * (BOX + LABEL_BAND + GAP)
        y += GROUP_GAP
    # The last row's trailing gap and the last group's trailing separation are not page content.
    bottom = y - GAP - GROUP_GAP
    return bottom, bottom + FOOTER_RULE_PAD + FOOTER_TEXT_PAD + FOOTER_TEXT_H + FOOTER_BOTTOM


def render(rows):
    """The whole poster, as an RGB image."""
    groups = grouped(rows)
    grid_bottom, height = layout_height(groups)
    width = MARGIN * 2 + COLS * BOX + (COLS - 1) * GAP

    poster = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(poster)

    f_title = font(FONT_BOLD, SIZE_TITLE)
    f_sub = font(FONT_REGULAR, SIZE_SUBTITLE)
    f_heading = font(FONT_BOLD, SIZE_HEADING)
    f_label = font(FONT_REGULAR, SIZE_LABEL)
    f_footer = font(FONT_REGULAR, SIZE_FOOTER)

    draw.text(TITLE_XY, TITLE, font=f_title, fill=GOLD)
    draw.text(SUBTITLE_XY, SUBTITLE, font=f_sub, fill=DIM)
    draw.line([(MARGIN, HEADER_RULE_Y), (width - MARGIN, HEADER_RULE_Y)], fill=TILE_EDGE, width=1)

    y = TOP
    for cat, items in groups:
        draw.text((MARGIN, y), cat, font=f_heading, fill=GOLD)
        y += HEADING_H
        for i, row in enumerate(items):
            col = i % COLS
            if col == 0 and i:
                y += BOX + LABEL_BAND + GAP
            x = MARGIN + col * (BOX + GAP)

            poster.paste(thumb(row), (x, y))
            draw.rectangle([x, y, x + BOX - 1, y + BOX - 1], outline=TILE_EDGE, width=1)

            label = ellipsize(draw, row["label"], f_label, BOX + LABEL_OVERHANG)
            # round(), not the raw center. Centering gives a fractional x for most labels, and a
            # fractional x is the one input here that different FreeType/Pillow builds disagree
            # about: they bucket the sub-pixel offset differently, so the same label rasterizes to
            # different bytes and --check reports staleness that is not there. Whole pixels are
            # rasterized identically everywhere, and half a pixel of centering is invisible.
            lw = round(draw.textlength(label, font=f_label))
            tx = x + round((BOX - lw) / 2)
            # A label is allowed to overhang its TILE by LABEL_OVERHANG — that is what keeps the
            # ellipsis rare — but never the PAGE. In the outer columns the two are not the same
            # thing: an overhanging label in column 0 starts left of the margin and in the last
            # column ends right of it, and a poster whose text breaks its own margin reads as a
            # rendering bug rather than a design. Clamped, so those labels sit flush instead.
            tx = max(MARGIN, min(tx, width - MARGIN - lw))
            draw.text((tx, y + BOX + LABEL_PAD), label, font=f_label, fill=TEXT)
        # The final row of a group is usually partial; it still consumes a full row of height.
        y += BOX + LABEL_BAND + GAP
        y += GROUP_GAP

    rule_y = grid_bottom + FOOTER_RULE_PAD
    text_y = rule_y + FOOTER_TEXT_PAD
    draw.line([(MARGIN, rule_y), (width - MARGIN, rule_y)], fill=TILE_EDGE, width=1)
    draw.text((MARGIN, text_y), FOOTER_LEFT, font=f_footer, fill=DIM)
    # The version identifies WHICH release's artwork set this is — the poster outlives any one
    # upload, and a reader who finds it on a project page has no other way to tell.
    stamp = "v%s  ·  %d artworks" % (addon_version(), len(rows))
    # Rounded for the same reason as the labels. Today's string happens to measure to a whole number
    # of pixels; a different one would not, and the drift would be silent.
    draw.text((width - MARGIN - round(draw.textlength(stamp, font=f_footer)), text_y),
              stamp, font=f_footer, fill=DIM)
    return poster


# ------------------------------------------------------------------------------------------------
# Encoding
# ------------------------------------------------------------------------------------------------

def encode(poster):
    """The poster as PNG bytes.

    The single place the file is serialized, so a write and a comparison can never disagree about
    what "the poster" means.

    Nothing here varies run to run: PNG has no timestamp chunk unless one is asked for, a freshly
    constructed Image carries no info dict to leak into tEXt, and the compression level is stated
    rather than left to the default so a Pillow upgrade cannot silently re-encode the same pixels
    into different bytes. optimize=False for the same reason — it is a heuristic, and heuristics are
    free to change between versions.
    """
    buf = io.BytesIO()
    poster.save(buf, format="PNG", optimize=False, compress_level=9)
    return buf.getvalue()


def fingerprint(poster):
    """The sha256 of the poster's PIXELS — the thing that is actually supposed to be stable.

    This is what makes the guarantee airtight rather than best-effort, and the distinction is the
    whole point:

      * The PIXELS are this script's output. Every input to them is pinned — bundled fonts, BASIC
        layout, whole-pixel text placement, the catalog's sort order.
      * The BYTES are deflate's output, and deflate is not ours. A zlib-ng build, or a Pillow that
        passes different parameters to it, can compress identical pixels into a different file
        without anything here changing.

    Comparing bytes therefore reports "out of date" for a toolchain difference that changed nothing
    a reader can see. Comparing pixels reports staleness when, and only when, the poster no longer
    depicts what ships. The mode and size are folded in so a same-pixels-different-shape image
    cannot collide.
    """
    return hashlib.sha256(
        ("%s %dx%d\n" % (poster.mode, poster.width, poster.height)).encode("ascii")
        + poster.tobytes()
    ).hexdigest()


def file_fingerprint(path):
    """`fingerprint` of an already-written poster, or None if it cannot be read as an image."""
    try:
        with Image.open(path) as im:
            im.load()
            return fingerprint(im)
    except Exception:                                     # noqa: BLE001 - any failure means "no"
        return None


def toolchain():
    """The versions that rasterized and compressed this poster, for the provenance record.

    Recorded rather than pinned because a script cannot pin its own interpreter's libraries. If the
    pixel fingerprint ever does move without the artwork moving, this is the evidence for which
    component moved — otherwise that diagnosis is guesswork.
    """
    return [
        ("Pillow", PIL.__version__),
        ("FreeType", features.version("freetype2") or "unknown"),
        ("zlib", features.version("zlib") or "unknown"),
    ]


def build_record(poster, rows, digest):
    """The human-readable provenance file written beside the poster.

    Committed alongside it so a reviewer looking at a 2 MB binary in a diff can see what changed
    without opening it, and so a pixel mismatch can be attributed to a toolchain rather than argued
    about. Rewritten only when the poster is (see main), so it stays the record of the build that
    produced the committed image rather than of whoever last ran --check.
    """
    lines = [
        "Panel Master — bundled artwork poster",
        "Generated by tools/artwork/make_poster.py. Do not edit by hand.",
        "",
        "addon version   %s" % addon_version(),
        "artworks        %d" % len(rows),
        "image           %dx%d %s" % (poster.width, poster.height, poster.mode),
        "pixel sha256    %s" % digest,
        "",
        "Fonts (bundled, tools/artwork/fonts/):",
    ]
    for path in (FONT_REGULAR, FONT_BOLD):
        with open(path, "rb") as fh:
            lines.append("  %-24s %s" % (os.path.basename(path),
                                         hashlib.sha256(fh.read()).hexdigest()))
    lines += ["", "Built with:"]
    for name, version in toolchain():
        lines.append("  %-24s %s" % (name, version))
    return "\n".join(lines) + "\n"


def read_record_toolchain(path):
    """The `Built with:` block of an existing record, as [(name, version), ...]."""
    if not os.path.isfile(path):
        return []
    out, seen = [], False
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            if line.startswith("Built with:"):
                seen = True
            elif seen and line.startswith("  "):
                parts = line.split()
                if len(parts) >= 2:
                    out.append((parts[0], parts[1]))
    return out


# ------------------------------------------------------------------------------------------------
# Driver
# ------------------------------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="examples:\n"
               "  python3 tools/artwork/make_poster.py\n"
               "  python3 tools/artwork/make_poster.py --check\n"
               "  python3 tools/artwork/make_poster.py --out /tmp/preview.png\n",
    )
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if the committed poster is out of date; write nothing")
    ap.add_argument("--out", default=OUT_PNG,
                    help="write somewhere other than media/poster/artwork-poster.png")
    args = ap.parse_args(argv)

    rows, problems = catalog.scan()
    if problems:
        print("%d problem(s) in media/artwork/:" % len(problems))
        for p in problems:
            print("  " + p)
        # catalog.is_fatal, not a local copy of its rule: a duplicate id or a file Pillow cannot
        # open stops both scripts, a non-power-of-two texture stops neither. Deciding this here
        # would let the poster and the catalog succeed on different inputs.
        if catalog.is_fatal(problems):
            return 1

    if not rows:
        sys.exit("no .tga files found under %s" % ART_DIR)

    try:
        poster = render(rows)
    except RuntimeError as exc:
        # scan() opened every one of these to measure it, so a failure here means the file changed
        # underfoot or Pillow can read the header but not the pixels. Either way, do not write a
        # poster with a blank tile in it and call it current.
        print("1 problem rendering media/artwork/:")
        print("  " + str(exc))
        return 1

    digest = fingerprint(poster)
    record = os.path.splitext(args.out)[0] + ".txt"
    existing = file_fingerprint(args.out)

    if args.check:
        if existing is None:
            print("poster is MISSING — run tools/artwork/make_poster.py"
                  if not os.path.isfile(args.out) else
                  "poster is UNREADABLE — run tools/artwork/make_poster.py")
            return 1
        if existing != digest:
            print("poster is OUT OF DATE — run tools/artwork/make_poster.py")
            print("  committed pixels %s" % existing)
            print("  this tree renders %s" % digest)
            # A pixel mismatch is meant to mean the artwork moved. If it did not, the evidence for
            # what else did is in the record — and naming the differing component beats leaving a
            # reviewer to guess at a 2 MB binary diff.
            was = dict(read_record_toolchain(record))
            moved = [(n, was.get(n), v) for n, v in toolchain() if n in was and was[n] != v]
            if moved:
                print("  toolchain differs from the one that built it:")
                for name, before, after in moved:
                    print("    %-10s built with %s, you have %s" % (name, before, after))
                print("  If media/artwork/ has not changed, that is the cause — see the docstring.")
            return 1
        print("poster is up to date (%d artworks, v%s)" % (len(rows), addon_version()))
        return 0

    # Nothing to do when the picture is already right. This is the no-churn rule, and it is what
    # makes "identical inputs produce no diff" true in practice rather than only in principle: a
    # contributor on a different zlib would otherwise rewrite 2 MB of byte-different, pixel-identical
    # PNG every time they ran the tool, and the poster's history would fill with changes nobody made.
    if existing == digest:
        print("poster already up to date (%d artworks, v%s)" % (len(rows), addon_version()))
        return 0

    data = encode(poster)

    # dirname("preview.png") is "", which makedirs rejects — and a bare filename is exactly what
    # --out invites you to type from the repo root. Only create a directory if one was named.
    out_dir = os.path.dirname(args.out)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    # Atomic, so an interrupted run cannot leave a half-written PNG that --check would then read as
    # merely "out of date".
    for path, blob in ((args.out, data), (record, build_record(poster, rows, digest).encode("utf-8"))):
        tmp = path + ".tmp"
        with open(tmp, "wb") as fh:
            fh.write(blob)
        os.replace(tmp, path)

    # Repo-relative when it is in the repo; --out can point anywhere, and relpath() to a sibling of
    # the repo root renders as a stack of "../" that is worse than the absolute path.
    shown = os.path.relpath(args.out, REPO)
    if shown.startswith(".."):
        shown = os.path.abspath(args.out)
    print("wrote %d artworks to %s (%dx%d, %.1f KB, v%s)"
          % (len(rows), shown, poster.width, poster.height, len(data) / 1024.0, addon_version()))
    print("  pixel sha256 %s" % digest)

    cats = {}
    for r in rows:
        cats[r["category"]] = cats.get(r["category"], 0) + 1
    for c in sorted(cats):
        print("  %-52s %3d" % (c, cats[c]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
