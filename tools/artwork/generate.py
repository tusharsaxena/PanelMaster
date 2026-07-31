#!/usr/bin/env python3
"""Procedural artwork generator for Ka0s Panel Master.

Draws each bundled panel artwork in code and writes it to ``media/artwork/`` as the
32-bit uncompressed TGA that WoW loads at runtime. Committed rather than run once and
forgotten, so the shipped art stays reproducible, reviewable as a diff, and
license-clean by construction (original work, MIT).

Everything is authored TINTABLE: pure white, with the entire shape carried by the alpha
channel. That is what lets one texture serve every panel color and pick up class color
for free — see docs/artwork-spec.md for why gray RGB would be wrong here.

Usage:
    python3 tools/artwork/generate.py            # write every asset
    python3 tools/artwork/generate.py runic-sigil-bw

Requires Pillow.
"""

import math
import os
import sys

from PIL import Image, ImageDraw

# Authored size. Power of two, as WoW requires.
SIZE = 512

# Everything is drawn at SS times the final size and downsampled at the end. WoW applies
# no antialiasing of its own, and PIL's draw primitives are hard-edged, so supersampling
# is the only thing standing between this and a staircased ring.
SS = 4

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(REPO, "media", "artwork")


def _ring(draw, cx, cy, radius, width, fill=255):
    """An annulus centered on (cx, cy). PIL has no stroked-circle primitive that centers
    the stroke on the path, so the width is applied symmetrically by hand."""
    half = width / 2.0
    draw.ellipse(
        [cx - radius - half, cy - radius - half, cx + radius + half, cy + radius + half],
        fill=fill,
    )
    draw.ellipse(
        [cx - radius + half, cy - radius + half, cx + radius - half, cy + radius - half],
        fill=0,
    )


def _spoke(draw, cx, cy, angle, r0, r1, width, fill=255):
    """A radial tick from radius r0 to r1 along `angle` (degrees, 0 = up)."""
    a = math.radians(angle - 90.0)
    draw.line(
        [
            cx + math.cos(a) * r0, cy + math.sin(a) * r0,
            cx + math.cos(a) * r1, cy + math.sin(a) * r1,
        ],
        fill=fill,
        width=int(width),
    )


def _diamond(draw, cx, cy, angle, radius, half_w, half_h, fill=255):
    """A diamond floating at `angle`/`radius` from center, pointing outward."""
    a = math.radians(angle - 90.0)
    px, py = cx + math.cos(a) * radius, cy + math.sin(a) * radius
    ox, oy = math.cos(a), math.sin(a)          # outward
    tx, ty = -oy, ox                           # tangential
    draw.polygon(
        [
            (px + ox * half_h, py + oy * half_h),
            (px + tx * half_w, py + ty * half_w),
            (px - ox * half_h, py - oy * half_h),
            (px - tx * half_w, py - ty * half_w),
        ],
        fill=fill,
    )


def runic_sigil():
    """A circular runic emblem: twin rings, eight cardinal spokes, a ring of diamonds and
    an angular star at the center.

    Chosen as the seed asset because it exercises every fill type legibly at a glance —
    the concentric rings make an aspect-ratio crop obvious, the cardinal symmetry makes a
    quarter-turn verifiable, and the transparent margin makes a tile seam visible.
    """
    n = SIZE * SS
    a = Image.new("L", (n, n), 0)     # the alpha plate; RGB is forced white at the end
    d = ImageDraw.Draw(a)
    c = n / 2.0

    # Radii as fractions of the half-extent, so the composition scales with SIZE. The
    # outermost element stops at 0.94 to leave the transparent margin that keeps the FILL
    # crop and the TILE wrap from shaving the motif (docs/artwork-spec.md).
    unit = c
    outer_r = unit * 0.86
    inner_r = unit * 0.62
    core_r = unit * 0.34

    _ring(d, c, c, outer_r, unit * 0.030)
    _ring(d, c, c, outer_r * 0.93, unit * 0.010)
    _ring(d, c, c, inner_r, unit * 0.018)
    _ring(d, c, c, core_r, unit * 0.012)

    # Eight spokes bridging the two rings, heavier on the cardinals than the diagonals so
    # the emblem has an obvious "up" and a quarter-turn is visibly a quarter-turn.
    for i in range(8):
        cardinal = (i % 2) == 0
        _spoke(
            d, c, c, i * 45.0,
            inner_r, outer_r * 0.93,
            unit * (0.022 if cardinal else 0.010),
        )

    # Diamonds riding the inner ring, at the diagonals only — offsetting the spokes so the
    # two rhythms interlock rather than stack.
    for i in range(4):
        _diamond(d, c, c, 45.0 + i * 90.0, inner_r, unit * 0.030, unit * 0.055)

    # Cardinal blades: long tapered points reaching from the core out to the inner ring.
    for i in range(4):
        ang = math.radians(i * 90.0 - 90.0)
        ox, oy = math.cos(ang), math.sin(ang)
        tx, ty = -oy, ox
        tip_r, base_r, half_w = inner_r * 0.97, core_r, unit * 0.055
        d.polygon(
            [
                (c + ox * tip_r, c + oy * tip_r),
                (c + ox * base_r + tx * half_w, c + oy * base_r + ty * half_w),
                (c + ox * base_r - tx * half_w, c + oy * base_r - ty * half_w),
            ],
            fill=255,
        )

    # The core: a four-pointed star inside an open disc, so the middle of the emblem is a
    # solid focal point rather than another hole.
    d.ellipse([c - core_r, c - core_r, c + core_r, c + core_r], fill=0)
    _ring(d, c, c, core_r, unit * 0.012)
    for i in range(4):
        ang = math.radians(i * 90.0 - 45.0)
        ox, oy = math.cos(ang), math.sin(ang)
        tx, ty = -oy, ox
        d.polygon(
            [
                (c + ox * core_r * 0.82, c + oy * core_r * 0.82),
                (c + tx * core_r * 0.30, c + ty * core_r * 0.30),
                (c - ox * core_r * 0.10, c - oy * core_r * 0.10),
                (c - tx * core_r * 0.30, c - ty * core_r * 0.30),
            ],
            fill=255,
        )
    d.ellipse(
        [c - core_r * 0.14, c - core_r * 0.14, c + core_r * 0.14, c + core_r * 0.14],
        fill=255,
    )

    return a.resize((SIZE, SIZE), Image.LANCZOS)


ASSETS = {
    # The "-bw" suffix is part of the naming contract: every motif ships as a
    # <motif>-bw / <motif>-color pair, so the suffix is never optional even when only
    # one half of the pair exists yet.
    "runic-sigil-bw": runic_sigil,
}


def write(name):
    alpha = ASSETS[name]()
    # Pure white everywhere; the alpha plate carries the entire shape. A gray RGB would
    # multiply against the panel's tint and come out muddy.
    white = Image.new("RGB", alpha.size, (255, 255, 255))
    out = Image.merge("RGBA", (*white.split(), alpha))
    # Zero the RGB wherever the alpha is zero, matching tools/artwork/import.py. Invisible under
    # normal blending, but Additive ADDS that RGB to whatever is behind — so a fully-transparent
    # white would wash the entire panel out instead of adding nothing. See TRANSPARENT there.
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if px[x, y][3] == 0:
                px[x, y] = (0, 0, 0, 0)
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, name + ".tga")
    out.save(path)   # Pillow writes 32-bit uncompressed TGA for RGBA, which is what WoW wants
    print("wrote %s (%dx%d)" % (path, out.width, out.height))
    return out


def main(argv):
    names = argv[1:] or sorted(ASSETS)
    unknown = [n for n in names if n not in ASSETS]
    if unknown:
        sys.exit("unknown asset(s): %s\nknown: %s" % (", ".join(unknown), ", ".join(sorted(ASSETS))))
    for name in names:
        write(name)


if __name__ == "__main__":
    main(sys.argv)
