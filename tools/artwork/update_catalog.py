#!/usr/bin/env python3
"""Rewrite the addon's artwork catalog from whatever is in media/artwork/.

The folder tree IS the catalog. Drop converted TGAs into media/artwork/, run this, and every row
the addon needs is regenerated from the paths and the pixels — no manifest, no metadata file, no
hand-maintained list that can drift from what actually shipped.

What each field is derived from:

    file      the path under media/artwork/, backslash-separated, minus the extension
    id        the same path, lowercase kebab-case, slashes becoming hyphens
    category  the folder path, title-cased and joined -- "Faction -> Expansion -> 12 Midnight"
    label     the file name, title-cased -- "Harati"
    w, h      measured from the file
    tintable  measured from the pixels; see is_tintable()

Usage:
    python3 tools/artwork/update_catalog.py            # rewrite modules/Artwork.lua
    python3 tools/artwork/update_catalog.py --check     # exit 1 if it would change anything
    python3 tools/artwork/update_catalog.py --print     # print the rows, write nothing

Requires Pillow and numpy.
"""

import argparse
import os
import re
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
ART_DIR = os.path.join(REPO, "media", "artwork")
CATALOG_LUA = os.path.join(REPO, "modules", "Artwork.lua")

# Holds unshipped source images and is excluded from packaging by .pkgmeta, so it must never
# produce catalog rows.
SKIP_DIRS = {"raw"}

# The separator between folder levels in a category string. Chosen over "/" so the category reads
# as a path through the dropdown's groups rather than as a file path, which it is not.
CATEGORY_SEP = " -> "

# Marks the generated region of modules/Artwork.lua. Everything between these lines is replaced;
# everything outside is left exactly as written, so the module's prose and logic are hand-owned.
BEGIN = "-- BEGIN GENERATED CATALOG (tools/artwork/update_catalog.py) -- do not edit by hand"
END = "-- END GENERATED CATALOG"

# Above this mean saturation, art is treated as full color. Measured over opaque pixels only:
# a transparent margin has no hue to speak of and would drag every average toward zero.
SATURATION_FLOOR = 0.12

# A tintable plate is white-on-transparent, so its opaque pixels should be near 255. This guards
# the case saturation alone cannot see: mid-gray line art is unsaturated but NOT tintable, because
# gray multiplied by a tint color comes back muddy instead of colored.
BRIGHTNESS_FLOOR = 200


def is_tintable(im):
    """Decide whether the panel's Color setting may drive this art.

    A tintable plate carries its shape entirely in the alpha channel and is uniformly white in RGB,
    so multiplying by any tint gives that tint at the right opacity. Full-color art has its own
    palette, and multiplying it can only drag every hue toward one color and muddy it.

    Both conditions are required. Saturation alone would call a mid-gray plate tintable, but gray
    times a tint is a dark, desaturated version of that tint rather than the tint itself — which is
    exactly the "authored the shading into the RGB instead of the alpha" mistake.
    """
    a = np.asarray(im.convert("RGBA"), dtype=np.float32)
    opaque = a[..., 3] > 128
    if not opaque.any():
        return False
    rgb = a[..., :3][opaque]
    mx = rgb.max(axis=1)
    mn = rgb.min(axis=1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0).mean()
    return bool(sat < SATURATION_FLOOR and mx.mean() >= BRIGHTNESS_FLOOR)


def _words(text):
    """`12-midnight` -> ['12', 'Midnight'];  `02-the-burning-crusade` -> ['02','The','Burning','Crusade'].

    A small word ("the", "of") is only lowercased mid-title. A LEADING NUMERIC token does not count
    as the title's start — folders are numbered to force chronological order in the dropdown
    (`02-the-burning-crusade`), and treating that digit group as the first word would render
    "02 the Burning Crusade" with a stranded lowercase article.
    """
    small = {"of", "the", "and", "for", "a", "an", "to", "in", "on"}
    parts = [p for p in re.split(r"[-_\s]+", text) if p]
    out, seen_word = [], False
    for p in parts:
        if p.isdigit() and not seen_word:
            out.append(p)                       # a sort prefix, not the title's first word
            continue
        if p.isupper():                         # an acronym the author capitalized deliberately
            out.append(p)
        elif seen_word and p.lower() in small:
            out.append(p.lower())
        else:
            out.append(p.capitalize())
        seen_word = True
    return out


def titleize(text):
    return " ".join(_words(text))


def slug(text):
    """Lowercase kebab-case, safe as both a filename fragment and a Lua string."""
    text = text.replace("'", "").replace("’", "")
    text = re.sub(r"[^A-Za-z0-9]+", "-", text)
    return re.sub(r"-{2,}", "-", text).strip("-").lower()


def scan(art_dir=ART_DIR):
    """Every shipped TGA under media/artwork/, as a catalog row."""
    rows, problems = [], []
    for dirpath, dirnames, names in os.walk(art_dir):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(names):
            if not name.lower().endswith(".tga"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, art_dir).replace("\\", "/")
            stem = rel[:-4]
            folders = stem.split("/")[:-1]
            leaf = stem.split("/")[-1]

            try:
                with Image.open(full) as im:
                    w, h = im.size
                    tint = is_tintable(im)
            except Exception as exc:                              # noqa: BLE001 - collected, not raised
                problems.append("%s: unreadable (%s)" % (rel, exc))
                continue

            if w & (w - 1) or h & (h - 1):
                # Not fatal to the catalog, but the TILE fill cannot wrap it and some drivers will
                # not load it at all, so it must not pass silently.
                problems.append("%s: %dx%d is not a power of two" % (rel, w, h))

            rows.append({
                "id": slug(stem.replace("/", "-")),
                "category": CATEGORY_SEP.join(titleize(f) for f in folders) or "General",
                "label": titleize(leaf),
                "file": stem.replace("/", "\\\\"),
                "w": w, "h": h,
                "tintable": tint,
            })

    seen = {}
    for r in rows:
        if r["id"] in seen:
            problems.append("duplicate id %s (from %s and %s)" % (r["id"], seen[r["id"]], r["file"]))
        seen[r["id"]] = r["file"]
    return rows, problems


def render(rows):
    """The Lua table body, sorted the way the dropdown groups it."""
    out = []
    for r in sorted(rows, key=lambda r: (r["category"], r["label"], r["id"])):
        out.append(
            '  { id       = "%s",\n'
            '    category = "%s",\n'
            '    label    = "%s",\n'
            '    file     = "%s",\n'
            '    w        = %d, h = %d,\n'
            '    tintable = %s },'
            % (r["id"], r["category"], r["label"], r["file"],
               r["w"], r["h"], "true" if r["tintable"] else "false")
        )
    return "\n".join(out)


def splice(source, body):
    """Replace the generated region of Artwork.lua, leaving everything else untouched."""
    if BEGIN not in source or END not in source:
        sys.exit("markers not found in %s — expected:\n  %s\n  %s" % (CATALOG_LUA, BEGIN, END))
    head = source[:source.index(BEGIN) + len(BEGIN)]
    tail = source[source.index(END):]
    return head + "\n" + body + "\n  " + tail


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if the catalog is out of date; write nothing")
    ap.add_argument("--print", dest="show", action="store_true",
                    help="print the generated rows and exit")
    args = ap.parse_args(argv)

    rows, problems = scan()
    if problems:
        print("%d problem(s) in media/artwork/:" % len(problems))
        for p in problems:
            print("  " + p)
        if any("duplicate id" in p or "unreadable" in p for p in problems):
            return 1

    if not rows:
        sys.exit("no .tga files found under %s" % ART_DIR)

    body = render(rows)
    if args.show:
        print(body)
        return 0

    with open(CATALOG_LUA, encoding="utf-8") as fh:
        source = fh.read()
    updated = splice(source, body)

    if args.check:
        if updated != source:
            print("catalog is OUT OF DATE — run tools/artwork/update_catalog.py")
            return 1
        print("catalog is up to date (%d rows)" % len(rows))
        return 0

    if updated == source:
        print("catalog already up to date (%d rows)" % len(rows))
        return 0

    tmp = CATALOG_LUA + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(updated)
    os.replace(tmp, CATALOG_LUA)

    cats = {}
    for r in rows:
        cats[r["category"]] = cats.get(r["category"], 0) + 1
    tint = sum(1 for r in rows if r["tintable"])
    print("wrote %d rows to %s (%d tintable, %d full color)"
          % (len(rows), os.path.relpath(CATALOG_LUA, REPO), tint, len(rows) - tint))
    for c in sorted(cats):
        print("  %-52s %3d" % (c, cats[c]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
