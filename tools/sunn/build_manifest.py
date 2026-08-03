#!/usr/bin/env python3
"""Build the known-pack manifest for the Sunn - Viewport Art adapter.

Reads an installed WoW AddOns directory, extracts every theme the official Sunn packs register,
verifies each one against the texture files actually on disk, and rewrites the generated block in
`modules/SunnArtPacks.lua`.

WHY THIS EXISTS
---------------
`modules/SunnArt.lua` discovers themes from the packs' own registration, which is the right primary
mechanism and needs no list here. But the packs are hard-dependent on SunnArt (`## Dependencies:
SunnArt` in every pack TOC), so with SunnArt disabled or unloadable NOTHING registers and the whole
feature goes silent -- even though the textures are ordinary files that WoW can draw regardless.
This manifest is the fallback for exactly that case, gated on the pack's folder actually being
installed.

It also carries something registration never provides: the sections' MEASURED pixel dimensions.
Most are 512x256, but not all -- five official themes are square and three are 1024 wide -- so a
single declared aspect is wrong for some of them. See ARTWORK-07 in docs/pending/LEDGER.md.

REPRODUCIBILITY, AND HOW THIS DIFFERS FROM tools/artwork/
--------------------------------------------------------
`update_catalog.py` reads `media/artwork/`, which is in this repo, so it reruns from a clean clone.
This one cannot: its input is somebody's WoW installation with the packs installed. That is why the
output is committed and this script takes an explicit --addons path. Rerun it when a pack is
updated or a new official pack appears; there is no gate that can detect staleness, and the cost of
being stale is bounded -- a stale row is only ever consulted when live registration is absent, and
live registration always wins.

Usage:
    python3 tools/sunn/build_manifest.py --addons "/path/to/_retail_/Interface/AddOns"
    python3 tools/sunn/build_manifest.py --addons ... --check
"""

import argparse
import os
import re
import struct
import sys

BEGIN = "  -- BEGIN GENERATED MANIFEST (tools/sunn/build_manifest.py) -- do not edit by hand"
END = "  -- END GENERATED MANIFEST"

OUT = os.path.join("modules", "SunnArtPacks.lua")

MAX_SECTIONS = 5   # SunnArt's documented ceiling

# The two registration styles, both real and both in use among the official packs:
#
#   SunnArtPack1  ..  SunnArt.options.args.theme.values["SunnArtPack1\\green"] = "Green"
#   SunnArtPack10 ..  SunnArtPack.theme["SunnArtPack10\\wc3_horde-"] = "Warcraft III - Horde"
#
# The second self-initializes its own global and also declares panels and overlap; the first
# declares names only and therefore takes SunnArt's default of 3 sections and no overlap.
RE_OPTIONS = re.compile(
    r'SunnArt\.options\.args\.theme\.values\[\s*"([^"]+)"\s*\]\s*=\s*"([^"]*)"')
RE_PACK = re.compile(
    r'SunnArtPack\.(theme|panels|overlap)\[\s*"([^"]+)"\s*\]\s*=\s*"?([^"\n]+?)"?\s*$', re.M)
RE_DEFAULT_THEME = re.compile(r'\[\s*"([^"]+)"\s*\]\s*=\s*"([^"]*)"')


def read(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def unescape(s):
    r"""A theme key as the Lua VALUE, not as the source spells it.

    The pack files are read as text, so `"SunnArtPack2\\blackrock"` in the source arrives here with
    two literal backslashes. The key is one. Skipping this step re-escapes an already-escaped
    string and emits `\\\\`, which is a path no texture will ever resolve.
    """
    return s.replace("\\\\", "\\")


def tga_size(path):
    """(width, height) from a TGA header, or None. Bytes 12-15, little-endian uint16 each."""
    try:
        with open(path, "rb") as fh:
            head = fh.read(18)
        if len(head) < 16:
            return None
        return struct.unpack("<HH", head[12:16])
    except OSError:
        return None


def collect(addons):
    """{theme file -> dict} for every official pack theme found under `addons`."""
    themes = {}

    for folder in sorted(os.listdir(addons)):
        if not folder.startswith("SunnArtPack"):
            continue
        lua = os.path.join(addons, folder, folder + ".lua")
        if not os.path.isfile(lua):
            continue
        src = read(lua)

        names, panels, overlap = {}, {}, {}
        for m in RE_OPTIONS.finditer(src):
            names[unescape(m.group(1))] = m.group(2)
        for m in RE_PACK.finditer(src):
            {"theme": names, "panels": panels, "overlap": overlap}[m.group(1)][unescape(m.group(2))] = \
                m.group(3)

        for file, name in names.items():
            themes[file] = {
                "folder": folder,
                "name": name,
                "sections": int(float(panels.get(file, 3))),
                "overlap": float(overlap.get(file, 0)),
            }

    # SunnArt's own four built-in themes, which live in its saved-variable DEFAULTS rather than in
    # any pack file. They are the one group that is present whenever SunnArt itself is.
    defaults = os.path.join(addons, "SunnArt", "SunnArt_Defaults.lua")
    if os.path.isfile(defaults):
        block = re.search(r"themes\s*=\s*\{(.*?)\}", read(defaults), re.S)
        if block:
            for m in RE_DEFAULT_THEME.finditer(block.group(1)):
                themes[unescape(m.group(1))] = {
                    "folder": "SunnArt", "name": m.group(2), "sections": 3, "overlap": 0.0,
                }
    return themes


def verify(addons, themes):
    """Measure each theme against the files on disk. Returns (rows, problems)."""
    rows, problems = [], []

    for file in sorted(themes):
        t = themes[file]
        prefix = os.path.join(addons, file.replace("\\", os.sep))
        dims, found = set(), 0
        for i in range(1, MAX_SECTIONS + 1):
            path = prefix + str(i) + ".tga"
            if not os.path.isfile(path):
                break
            found += 1
            size = tga_size(path)
            if size:
                dims.add(size)

        if found == 0:
            problems.append("%s: declared but no section files on disk" % file)
            continue
        if found != t["sections"]:
            # Trust the FILES. A declared count that disagrees with what is installed would make us
            # draw a section that does not exist, or silently drop one that does.
            problems.append("%s: declares %d sections, %d on disk -- using %d"
                            % (file, t["sections"], found, found))
        if len(dims) > 1:
            problems.append("%s: sections differ in size (%s) -- using the first"
                            % (file, sorted(dims)))

        w, h = sorted(dims)[0] if dims else (512, 256)
        rows.append({
            "file": file, "folder": t["folder"], "name": t["name"],
            "sections": found, "overlap": t["overlap"], "w": w, "h": h,
        })
    return rows, problems


def lua_string(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def render(rows):
    out = [BEGIN]
    for r in rows:
        fields = ["name = " + lua_string(r["name"]),
                  "sections = %d" % r["sections"],
                  "w = %d, h = %d" % (r["w"], r["h"])]
        if r["overlap"]:
            fields.append("overlap = %s" % ("%.4f" % r["overlap"]).rstrip("0").rstrip("."))
        out.append("  [%s] = { %s }," % (lua_string(r["file"]), ", ".join(fields)))
    out.append(END)
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--addons", required=True, help="path to Interface/AddOns")
    ap.add_argument("--check", action="store_true",
                    help="exit 1 if the committed manifest is stale; write nothing")
    args = ap.parse_args()

    if not os.path.isdir(args.addons):
        sys.exit("not a directory: %s" % args.addons)
    if not os.path.isfile(OUT):
        sys.exit("run from the repo root: %s not found" % OUT)

    themes = collect(args.addons)
    if not themes:
        sys.exit("no Sunn packs found under %s" % args.addons)

    rows, problems = verify(args.addons, themes)
    for p in problems:
        print("warning: %s" % p, file=sys.stderr)

    current = read(OUT)
    if BEGIN not in current or END not in current:
        sys.exit("%s has no generated block to replace" % OUT)

    head = current.split(BEGIN)[0]
    tail = current.split(END, 1)[1]
    updated = head + render(rows) + tail

    folders = len({r["folder"] for r in rows})
    if args.check:
        if updated != current:
            sys.exit("manifest is stale: %d themes from %d packs on disk" % (len(rows), folders))
        print("manifest is up to date (%d themes, %d packs)" % (len(rows), folders))
        return

    if updated != current:
        with open(OUT, "w", encoding="utf-8") as fh:
            fh.write(updated)
    print("wrote %d themes from %d packs" % (len(rows), folders))


if __name__ == "__main__":
    main()
