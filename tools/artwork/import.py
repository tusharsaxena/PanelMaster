#!/usr/bin/env python3
"""Import externally-authored artwork into Ka0s Panel Master.

Turns a white-on-black plate — what an image model actually gives you when asked for
monochrome line art — into the tintable 32-bit TGA the addon renders. See
docs/artwork-spec.md for why white-on-black is the preferred route rather than asking a
model for transparency it usually cannot produce.

The conversion is luminance-to-alpha: every pixel becomes pure white and the brightness it
had becomes its opacity. That is exactly right for tintable art. Antialiased edges land as
partial alpha for free, and because the RGB is uniformly white, the panel's tint color
multiplies cleanly instead of muddying against a gray.

Usage:
    python3 tools/artwork/import.py IN.png alliance-crest
    python3 tools/artwork/import.py IN.png alliance-crest --keep-color
    python3 tools/artwork/import.py IN.png alliance-crest --erase 820,820,1024,1024

Requires Pillow.
"""

import argparse
import os
import sys

from PIL import Image

# Shared with wiki_import.py. What a transparent pixel's RGB must be, how art is letterboxed onto
# a power-of-two square, and what counts as content when measuring the margin are answers both
# importers need and neither should re-derive. See plate.py.
from plate import (
    BLACK_FLOOR,
    MIN_MARGIN,
    TRANSPARENT,
    content_bbox,
    fit_square,
    luma as _luma,
    normalize_transparent,
    pad_within,
)

SIZE = 512

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(REPO, "media", "artwork")


def to_tintable(im):
    """White-on-black plate -> white RGB with the shape carried entirely by alpha."""
    im = im.convert("RGB")
    src = im.load()
    out = Image.new("RGBA", im.size)
    dst = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = src[x, y]
            a = _luma(r, g, b)
            dst[x, y] = (255, 255, 255, 0 if a < BLACK_FLOOR else a)
    return out


def keep_color(im):
    """Color art on a black field -> keep the color, derive alpha from luminance.

    For a `tintable = false` catalog row when the art has no near-black tones. Alpha comes
    from brightness because a black background is the only thing separating "background" from
    "art" in a plate carrying no alpha of its own — which is exactly the weakness: a deep navy
    shield field is, to this function, indistinguishable from background, and goes translucent.
    Prefer chroma_key for anything with dark tones in it.
    """
    im = im.convert("RGB")
    src = im.load()
    out = Image.new("RGBA", im.size)
    dst = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = src[x, y]
            a = _luma(r, g, b)
            dst[x, y] = (r, g, b, 0 if a < BLACK_FLOOR else 255)
    return out


# The chroma backdrop asked for in docs/artwork-spec.md. Pure magenta is the standard choice
# because no heraldic palette — gold, steel, crimson, azure, sable — comes near it, so nothing
# in the art keys out by accident.
CHROMA = (255, 0, 255)

# Full magenta scores 255 on the spill measure below; art scores 0. The divisor is what a pixel
# has to score before it is treated as pure backdrop. Held under 255 so a slightly-off magenta
# (an image model will not hand back an exact #FF00FF) still keys out completely.
CHROMA_SPILL_FULL = 200.0


def chroma_key(im):
    """Color art on a magenta field -> full color, with alpha keyed off the backdrop.

    The reason this exists rather than reusing keep_color: luminance keying cannot separate
    dark ART from a dark BACKGROUND, so any piece with shadow, sable heraldry or a deep blue
    field loses it. Distance from a chroma color has no such blind spot — a near-black pixel is
    still enormously far from magenta, so it stays fully opaque.

    Known limitation, and the reason the asset spec tells you to keep magenta OUT of the art: a
    hue that is itself red-and-blue-without-green registers a little spill of its own. A deep
    crimson comes back at alpha 242 rather than 255, with its blue nudged a few levels. Invisible
    on a decorative overlay, but it is a real bias, and a genuinely magenta emblem would key
    itself half away.

    Removing the spill is the other half. An antialiased edge is a BLEND of art and backdrop, so
    it carries magenta that would otherwise fringe every outline purple. Rather than guess at
    that with a channel heuristic, this inverts the blend exactly: the pixel we can see is
    `art*a + chroma*(1-a)`, so the art is `(seen - chroma*(1-a)) / a`. At a = 1 that is the
    identity, and at a partial alpha it recovers the true color instead of a purple average.
    """
    im = im.convert("RGB")
    src = im.load()
    out = Image.new("RGBA", im.size)
    dst = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = src[x, y]
            # The spill measure: how much MORE red and blue this pixel has than green. Magenta is
            # the one color that maxes it (255 and 255 against 0), and it is scale-free, so a dark
            # navy scores 0 exactly as a bright gold does. That is the whole point — an absolute
            # distance from magenta cannot tell dark ART from a blended EDGE, and keying on it
            # turns every shadowed region translucent.
            spill = min(r, b) - g
            if spill <= 0:
                dst[x, y] = (r, g, b, 255)
                continue
            a = 1.0 - min(1.0, spill / CHROMA_SPILL_FULL)
            if a <= 0.0:
                dst[x, y] = (0, 0, 0, 0)
                continue
            # Un-mix: the pixel we can see is `art*a + chroma*(1-a)`, so the art is
            # `(seen - chroma*(1-a)) / a`. Clamped because a near-zero alpha divides a small
            # residue by a small number, and rounding in the source can push it outside 0-255.
            px = tuple(
                max(0, min(255, int(round((seen - c * (1.0 - a)) / a))))
                for seen, c in ((r, CHROMA[0]), (g, CHROMA[1]), (b, CHROMA[2]))
            )
            dst[x, y] = px + (int(round(a * 255)),)
    return out


def erase(im, box, fill):
    """Paint a region back to the BACKDROP color before conversion — used to remove a
    generator's corner watermark.

    Applied to the SOURCE plate rather than the output, so the erased area goes through the
    same key as everything else and lands as genuine transparency.

    `fill` must be whichever backdrop this plate uses, which is why it is a parameter rather
    than a constant: painting black into a magenta plate would not erase the watermark, it
    would replace it with an opaque black rectangle — black is as far from magenta as gold is,
    so the chroma key would keep every pixel of it.
    """
    im = im.copy()
    im.paste(fill, box)
    return im


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("source", help="input image (PNG, JPG, anything Pillow reads)")
    ap.add_argument("name", help="catalog id / output stem, e.g. alliance-crest")
    ap.add_argument("--keep-color", action="store_true",
                    help="preserve the source colors, keying alpha off a BLACK backdrop "
                         "(for a tintable = false catalog row with no dark tones)")
    ap.add_argument("--chroma", action="store_true",
                    help="preserve the source colors, keying alpha off a MAGENTA backdrop; "
                         "the right choice for any color art containing dark tones")
    ap.add_argument("--erase", metavar="L,T,R,B", action="append", default=[],
                    help="black out this region first; repeatable (e.g. a corner watermark)")
    ap.add_argument("--size", type=int, default=SIZE,
                    help="output edge length; must be a power of two (default %d)" % SIZE)
    ap.add_argument("--pad", type=int, default=0, metavar="PX",
                    help="shrink the art within the frame to guarantee this much transparent "
                         "margin, in output pixels")
    args = ap.parse_args(argv)

    if args.size & (args.size - 1):
        sys.exit("--size must be a power of two, got %d (WoW cannot load NPOT textures)" % args.size)

    if args.chroma and args.keep_color:
        sys.exit("--chroma and --keep-color are two different keys; pick one")

    im = Image.open(args.source)
    backdrop = CHROMA if args.chroma else (0, 0, 0)
    for spec in args.erase:
        try:
            box = tuple(int(v) for v in spec.split(","))
            if len(box) != 4:
                raise ValueError
        except ValueError:
            sys.exit("--erase wants four comma-separated integers L,T,R,B; got %r" % spec)
        im = erase(im, box, backdrop)

    out = (chroma_key if args.chroma else keep_color if args.keep_color else to_tintable)(im)
    # Resize AFTER conversion, so the resampling filter averages the alpha channel and the
    # emblem's edges stay soft rather than being hard-keyed at the source resolution.
    out = fit_square(out, args.size)

    # Padding shrinks the whole plate and re-centers it on a transparent frame, rather than
    # cropping to the content bbox and rescaling. Keeping the source's own composition intact
    # matters: these emblems are drawn symmetrically about the frame's center, and re-centering
    # on a bbox that is a few pixels lopsided would visibly tilt them off-axis.
    if args.pad > 0:
        try:
            out = pad_within(out, args.size, args.pad)
        except ValueError as exc:
            sys.exit(str(exc))

    # LAST, after every resize and paste. Each of those can reintroduce a stray RGB under a zero
    # alpha — LANCZOS by premultiplying, a paste by carrying its canvas color in — so normalizing
    # any earlier just gets undone by the next step.
    out = normalize_transparent(out)

    # dirname() rather than OUT_DIR, so a name carrying a category — `factions/alliance-crest` —
    # creates the directory it needs instead of failing on a path that does not exist yet. Art now
    # lives in nested folders under media/artwork/, so that is the ordinary case, not an exotic one.
    path = os.path.join(OUT_DIR, args.name + ".tga")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out.save(path)   # Pillow writes 32-bit uncompressed TGA for RGBA, which is what WoW wants

    alpha = out.getchannel("A")
    lo, hi = alpha.getextrema()
    bbox = content_bbox(out)
    print("wrote %s (%dx%d, alpha %d-%d, content bbox %s)"
          % (path, out.width, out.height, lo, hi, bbox))
    if hi < 200:
        print("  WARNING: nothing in this image is near-opaque. Was the source really "
              "white-on-black?")
    if bbox:
        margin = min(bbox[0], bbox[1], out.width - bbox[2], out.height - bbox[3])
        if margin < MIN_MARGIN:
            print("  WARNING: only %dpx of transparent margin (want >= %d). The FILL crop and "
                  "the TILE wrap will shave the motif; re-run with --pad %d "
                  "(docs/artwork-spec.md)." % (margin, MIN_MARGIN, MIN_MARGIN - margin))


if __name__ == "__main__":
    main()
