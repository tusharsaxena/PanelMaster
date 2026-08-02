#!/usr/bin/env python3
"""Image primitives shared by the artwork importers.

Two scripts convert art into the 32-bit TGA the client loads, and they solve opposite halves of
one problem. `import.py` takes a generated plate that has NO alpha and derives it, by luminance or
by chroma key. `wiki_import.py` takes downloaded art that already HAS alpha and preserves it.

What they share is everything downstream of that split: what a transparent pixel's RGB must be,
how art is letterboxed onto a power-of-two square, and what counts as "content" when measuring the
margin. Those answers are subtle, were arrived at by debugging real breakage, and are wrong in
different ways if each script re-derives them. Hence one module rather than two copies free to
drift apart.

Requires Pillow.
"""

from PIL import Image


# Below this 0-255 luminance a pixel is treated as background. Image models rarely return a
# mathematically pure black — a 2/255 haze across the whole frame is normal, invisible on its
# own, and would otherwise show up as a faint full-frame box under the TILE fill type.
BLACK_FLOOR = 6

# What counts as actual artwork when measuring the transparent margin, as opposed to the
# speckle that survives BLACK_FLOOR. Well below the eye's threshold on a dark panel, well above
# the noise.
CONTENT_FLOOR = 24

# The transparent margin docs/artwork-spec.md asks for, in output pixels. Below this the FILL
# crop and the TILE wrap start shaving the motif's outermost detail.
MIN_MARGIN = 4


# What a fully-transparent pixel's RGB is set to. Invisible under normal blending, and therefore
# easy to assume does not matter — but three of the blend modes read it:
#
#   Additive  adds the RGB to whatever is behind. Black adds nothing, which is what "transparent"
#             has to mean. White would wash the entire panel out.
#   Alpha key thresholds alpha and draws what survives fully opaque.
#   Opaque    ignores alpha completely and draws the RGB across the whole square.
#
# Black is the only value that is correct for Additive, which is the mode people actually reach for,
# so it is the one this normalizes to.
TRANSPARENT = (0, 0, 0, 0)


def luma(r, g, b):
    """Rec. 601 luminance, integer. The weighting the eye actually uses."""
    return (r * 299 + g * 587 + b * 114) // 1000


def normalize_transparent(im):
    """Force every fully-transparent pixel to one defined RGB.

    Necessary because the value otherwise depends on which code path a plate happened to take.
    PIL's LANCZOS resize premultiplies internally, so it ZEROES the RGB of transparent pixels —
    meaning to_tintable's white survived on a plate that needed no resize and was silently wiped
    on one that did. fit_square's padding added a third answer. alliance-crest-color ended up
    carrying white letterbox bars and a black keyed interior in the same file, which under Opaque
    drew as a black box inside a white one.

    Must run LAST, after every resize and paste. Each of those can reintroduce a stray RGB under a
    zero alpha, so normalizing any earlier just gets undone by the next step.
    """
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            if px[x, y][3] == 0:
                px[x, y] = TRANSPARENT
    return im


def fit_square(im, size):
    """Scale onto a transparent size x size canvas, preserving aspect.

    Sources do not arrive square. An image model returns a 912x1149 portrait plate when asked for
    a square one; the wiki serves a 2560x1243 logo at its native 2:1. Resizing either straight to
    size x size would squash the art, and nothing downstream could tell: the catalog row declares
    w = h = size, so the fill math would faithfully preserve an aspect that was already wrong.

    Letterboxing instead keeps the motif's proportions and lands it in the square the catalog
    declares. The padding is transparent, so it also supplies the margin the FILL crop and the
    TILE wrap want.
    """
    if im.size == (size, size):
        return im
    scale = min(size / im.width, size / im.height)
    w, h = max(1, int(round(im.width * scale))), max(1, int(round(im.height * scale)))
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    canvas.paste(im.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2))
    return canvas


def pad_within(im, size, pad):
    """Shrink the whole plate and re-center it, guaranteeing `pad` px of transparent margin.

    Deliberately not a crop-to-content-bbox followed by a rescale. These emblems are drawn
    symmetrically about the frame's center, and re-centering on a bbox that is a few pixels
    lopsided — which every antialiased plate's bbox is — would visibly tilt them off-axis.
    Shrinking the existing composition keeps whatever centering the source had.
    """
    inner = size - pad * 2
    if inner < 1:
        raise ValueError("pad %d leaves no room in a %dpx image" % (pad, size))
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    canvas.paste(im.resize((inner, inner), Image.LANCZOS), (pad, pad))
    return canvas


def content_bbox(im):
    """The bounding box of real artwork, ignoring near-invisible speckle.

    Measured at CONTENT_FLOOR rather than at any non-zero alpha: a converted plate carries a
    scatter of near-invisible speckle from an imperfect source background, and a bbox taken at
    alpha > 0 reports the whole frame every time, which makes the margin warning useless.
    """
    return im.getchannel("A").point(lambda v: 255 if v >= CONTENT_FLOOR else 0).getbbox()


def margin_of(im):
    """Smallest transparent margin on any of the four sides, or None if the plate is empty."""
    bbox = content_bbox(im)
    if not bbox:
        return None
    return min(bbox[0], bbox[1], im.width - bbox[2], im.height - bbox[3])
