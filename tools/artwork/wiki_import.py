#!/usr/bin/env python3
"""Batch-import downloaded artwork into Ka0s Panel Master.

Where `import.py` converts ONE generated plate that has no alpha and must have some derived, this
converts MANY downloaded images that already carry alpha and must not lose it. The two scripts
share their downstream half (see plate.py) and nothing else, because the problems are opposites:
running `to_tintable` or `chroma_key` over a wiki cutout would throw away the alpha it arrived
with and re-derive a worse one from luminance.

The run is driven by a manifest rather than by whatever happens to be in a directory. Catalog ids
are written into saved variables and can never be renamed without silently breaking every panel
using them, so the names are reviewed as data before a single file is written.

Usage:
    python3 tools/artwork/wiki_import.py --scaffold ~/Downloads/artwork   # propose the manifest
    python3 tools/artwork/wiki_import.py --dry-run                        # plan, touch nothing
    python3 tools/artwork/wiki_import.py --only 'classes/*'               # convert a subset
    python3 tools/artwork/wiki_import.py                                  # convert everything
    python3 tools/artwork/wiki_import.py --emit-catalog                   # print the Lua rows

Requires Pillow and numpy. The upscaler is vendored under tools/artwork/bin/.
"""

import argparse
import csv
import fnmatch
import os
import re
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

from plate import (
    MIN_MARGIN,
    TRANSPARENT,
    fit_square,
    margin_of,
    normalize_transparent,
    pad_within,
)

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(REPO, "media", "artwork")
RAW_DIR = os.path.join(OUT_DIR, "raw")
MANIFEST = os.path.join(HERE, "manifest.tsv")

# The output box. Power of two on both axes because WoW cannot wrap a non-power-of-two texture,
# and the addon offers a TILE fill type. Letterboxed rather than cropped, so aspect survives.
SIZE = 1024

# One model for the whole catalog, always at its native x4, chained when more is needed.
#
# The alternative — picking the smallest model that reaches the target, from the x2/x3/x4
# animevideov3 set — measured 1.7x faster (19 min against 33 min for 86 files). It was rejected
# because these assets sit adjacent to each other in a dropdown, and three models sharpen with
# visibly different character; a catalog that switches model by happenstance of source resolution
# would not read as one set. 33 minutes is a one-off cost and the consistency is permanent.
MODEL = "realesrgan-x4plus-anime"
MODEL_SCALE = 4
BIN = os.path.join(HERE, "bin", "realesrgan-ncnn-vulkan")
MODEL_DIR = os.path.join(HERE, "bin", "models")

# Below this required scale, Lanczos is used instead of the upscaler.
#
# Not a quality compromise. The upscaler only runs at x4, so a source needing 1.1x would be blown
# up to 4x and then thrown away down to 1.1x — paying a full pass (a 979px source becomes 3916px,
# ~100 seconds) to sharpen an image that is already at essentially the target resolution. Under
# 1.25x Lanczos introduces no softness the eye can find, because there is almost no new pixel to
# invent.
AI_MIN_SCALE = 1.25

# How far opaque RGB is pushed outward into the transparent region before upscaling. 16px at
# source resolution is comfortably wider than any resampling kernel reaches, and the cost is a
# handful of array operations.
SOLIDIFY_ITERS = 16

# Luminance bounds for keying an opaque source. Below LO is certainly background; above HI is
# certainly art; between them alpha ramps, which is what absorbs JPEG ringing around the subject.
KEY_LO, KEY_HI = 16, 48

# Directory name -> the exact catalog category string. C.ARTWORK_CATEGORY_SET validates against
# these, so the capitalisation is not cosmetic.
CATEGORY_LABEL = {
    "general": "General",
    "races": "Races",
    "classes": "Classes",
    "expansions": "Expansions",
    "factions": "Factions",
}

# `raw` is not available as a category: media/artwork/raw/ already holds the unshipped source
# plates and is excluded from packaging by .pkgmeta.
RESERVED_DIRS = {"raw"}

MANIFEST_FIELDS = ["source", "category", "subject", "label", "credit", "erase"]

# A subject becomes both a filename under media/artwork/<category>/ and a Lua string literal in the
# catalog. Restricting it to lowercase kebab-case keeps it safe in both, and matches the naming rule
# docs/artwork-spec.md already states.
_SUBJECT_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")

# Records what each output was built FROM, so the up-to-date check can consider every input rather
# than only the source file's mtime. Lives under tools/, which .pkgmeta excludes wholesale, so it
# never reaches a player; a sidecar next to the .tga would ship.
STAMPS = os.path.join(HERE, ".stamps.tsv")


# --------------------------------------------------------------------------------------------
# Naming
# --------------------------------------------------------------------------------------------

_RES_PREFIX = re.compile(r"^\d+px-")
_DUP_SUFFIX = re.compile(r"\s*\(\d+\)$")

# Stripped from the END of a stem, longest first so `_Race_Icon` wins over `_Icon`.
_SUFFIXES = [
    "-MajorFactionsIcons", "_banner_cleaned_WoD", "_Race_Icon", "_noRays",
    "_Crest", "_crest", "-Crest", "_sigil", "_Sigil",
    "_Icon", "-Icon", "_icon", "-icon",
    "_logo", "_Logo", "-logo", "logo", "Logo",
]

# Stripped from the START of a stem.
_PREFIXES = ["Race-icon-", "MajorFactionsIcons-"]

# Checked against the stem BEFORE any prefix/suffix stripping, because for these the thing the
# generic rules would strip is exactly the thing that distinguishes them. `AllianceLogo` and
# `Alliance_Crest` are a wordmark and a heraldic crest — two different artworks that both reduce
# to "alliance" the moment `Logo` and `_Crest` come off.
_RAW_ALIASES = {
    "alliancelogo": "alliance-logo",
    "hordelogo": "horde-logo",
    "alliance_crest": "alliance-crest",
    "horde_crest": "horde-crest",
    # Archaeology icons whose subject the generic rules mangle or collide with a race crest.
    "legion_icon": "demon",                       # the Legion archaeology race, not the expansion
    "drustraceicon": "drust",
    "nightborne_race_icon": "nightborne-legion",  # race/Nightborne_Crest keeps the plain name
    "highmountain_tauren_legion_icon": "highmountain-tauren-legion",
    "race-icon-arakkoabig": "arakkoa",
}

# Names the generic rules cannot get right, because the source stem is either an abbreviation
# (`MoP`) or a run-on with no case boundary to split on (`AssemblyoftheDeeps`). Keyed on the
# cleaned stem, case-insensitively. Anything not here falls through to the generic rules and can
# be corrected in the manifest, which is the file that actually decides.
_ALIASES = {
    # Expansions
    "wow": "classic",
    "tbc": "the-burning-crusade",
    "wrath": "wrath-of-the-lich-king",
    "cataclysm": "cataclysm",
    "mop": "mists-of-pandaria",
    "wod": "warlords-of-draenor",
    "legion": "legion",
    "battle_for_azeroth": "battle-for-azeroth",
    "shadowlands": "shadowlands",
    "dragonflight": "dragonflight",
    "the_war_within": "the-war-within",
    "midnight_2024": "midnight",
    "the_last_titan": "the-last-titan",
    # Run-on faction names
    "assemblyofthedeeps": "assembly-of-the-deeps",
    "cartelsofundermine": "cartels-of-undermine",
    "councilofdornogal": "council-of-dornogal",
    "flamesradiance": "flames-radiance",
    "gallagioloyaltyrewardsclub": "gallagio-loyalty-rewards-club",
    "hallowfallarathi": "hallowfall-arathi",
    "manaforgevandals": "manaforge-vandals",
    "severedthreads": "severed-threads",
    "thekareshtrust": "the-karesh-trust",
    "dragonscaleexpedition": "dragonscale-expedition",
    "dreamwardens": "dream-wardens",
    "iskaaratuskarr": "iskaara-tuskarr",
    "loammniffen": "loamm-niffen",
    "maruukcentaur": "maruuk-centaur",
    "valdrakkenaccord": "valdrakken-accord",
    "keglegscrew": "keg-legs-crew",
    "amanitribe": "amani-tribe",
    "silvermooncourt": "silvermoon-court",
    "ritualsites": "ritual-sites",
    "harati": "harati",
    "singularity": "singularity",
    "bleeding_hollow": "bleeding-hollow",
    "twilight's_hammer": "twilights-hammer",
    # Races whose stem collides with an archaeology icon of the same subject
    "nightborne_race": "nightborne-legion",
    "highmountain_tauren_legion": "highmountain-tauren-legion",
    "drustrace": "drust",
    "draenororcs": "draenor-orc",
    "arakkoabig": "arakkoa",
    "mogu": "mogu",
    "worgen": "worgen",
    "goblin": "goblin",
}


# Applied after the category is known, for subjects whose correct name depends on which dropdown
# group they land in. One entry today: the wiki has no Evoker crest, so class/Dracthyr_Crest.webp
# is the Evoker stand-in — byte-identical to race/Dracthyr_Crest.webp and identically named, so
# the filename alone cannot tell them apart. Under Classes it must read "Evoker", because a
# dropdown listing Dracthyr beside Warrior and Mage is naming a race as a class.
_CATEGORY_ALIASES = {
    ("classes", "dracthyr"): ("evoker", "Evoker"),
}


def _split_camel(text):
    """`ValdrakkenAccord` -> `Valdrakken Accord`, leaving acronym runs alone."""
    text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", " ", text)
    return re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", " ", text)


def slugify(text):
    """Lowercase kebab-case, apostrophes dropped rather than hyphenated."""
    text = text.replace("'", "").replace("’", "")
    text = re.sub(r"[^A-Za-z0-9]+", "-", text)
    return re.sub(r"-{2,}", "-", text).strip("-").lower()


def derive_subject(filename):
    """Source filename -> proposed catalog subject.

    Best effort by design. The manifest it feeds is hand-editable and is what the conversion
    actually reads, so a wrong guess here is a one-line correction rather than a bad id.
    """
    stem = os.path.splitext(os.path.basename(filename))[0]
    stem = _DUP_SUFFIX.sub("", stem)
    stem = _RES_PREFIX.sub("", stem)
    raw = _RAW_ALIASES.get(stem.lower().strip("_-"))
    if raw:
        return raw
    for pre in _PREFIXES:
        if stem.lower().startswith(pre.lower()):
            stem = stem[len(pre):]
    changed = True
    while changed:
        changed = False
        for suf in _SUFFIXES:
            if stem.lower().endswith(suf.lower()) and len(stem) > len(suf):
                stem, changed = stem[: -len(suf)], True
                break
    alias = _ALIASES.get(stem.lower().strip("_-"))
    return alias if alias else slugify(_split_camel(stem))


def derive_category(relpath):
    """Source path -> category directory name.

    Mapped by what the art depicts rather than by which folder it was downloaded into. The
    archaeology set is the case that matters: it lives under faction/ upstream but every one of
    its icons depicts a race, and filing them under Factions would put races in the wrong
    dropdown group.
    """
    parts = [p.lower() for p in relpath.replace("\\", "/").split("/")]
    head = parts[0] if parts else ""
    name = os.path.basename(relpath).lower()
    if "00-archeology" in parts or "00-archaeology" in parts:
        return "races"
    if head == "class":
        return "classes"
    if head == "race":
        return "general" if name.startswith("icon_of_") else "races"
    if head == "expansion":
        return "expansions"
    if head == "faction":
        return "factions"
    if head == "other":
        return "general" if name.startswith("icon_of_") else "factions"
    return "general"


# --------------------------------------------------------------------------------------------
# Image stages
# --------------------------------------------------------------------------------------------

def solidify(im, iters=SOLIDIFY_ITERS):
    """Edge-extend opaque RGB outward into the transparent region.

    The single most important stage, and the one whose absence is invisible until it is too late.
    Sources disagree about what RGB sits under a transparent pixel: (0,0,0,0) on most of them,
    (255,255,255,0) across the MajorFactionsIcons set and much of class/, and (217,182,103,0) on
    race/Human_Crest.png. Nothing renders that color, so nothing complains about it.

    An upscaler does not care. Its kernel samples neighbouring pixels including the transparent
    ones, so a white-under-alpha source grows a white halo along every emblem edge and a
    black-under-alpha source grows a dark one. Replacing that arbitrary constant with a
    continuation of the adjacent artwork means the kernel samples something plausible instead,
    and the rim keeps the emblem's own color.

    Runs BEFORE the upscaler, because after it the halo is already baked in.
    """
    a = np.asarray(im.convert("RGBA"), dtype=np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    known = (alpha > 0).astype(np.float32)[..., None]
    cur = rgb * known
    for _ in range(iters):
        if known.min() >= 1.0:
            break
        # Sum of the 3x3 neighbourhood of both the premultiplied color and the mask, so the
        # quotient is the mean of whichever neighbours were actually known.
        num = _box_sum(cur)
        den = _box_sum(known)
        grown = (den > 0).astype(np.float32)
        newly = ((grown > 0) & (known == 0))
        cur = np.where(newly, num / np.maximum(den, 1e-6), cur)
        known = ((newly | (known > 0)).astype(np.float32))
    out = np.concatenate([np.clip(cur, 0, 255), alpha[..., None]], axis=2)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def _box_sum(arr):
    """Sum over the 3x3 neighbourhood, edges replicated."""
    p = np.pad(arr, ((1, 1), (1, 1), (0, 0)), mode="edge")
    total = np.zeros_like(arr)
    for dy in range(3):
        for dx in range(3):
            total += p[dy:dy + arr.shape[0], dx:dx + arr.shape[1]]
    return total


def key_dark_background(im, lo=KEY_LO, hi=KEY_HI):
    """Opaque art on a near-black field -> alpha keyed off the background.

    Only for the handful of sources that arrive with no alpha at all. Connectivity is what makes
    it safe: a plain luminance threshold would also punch holes through every dark region INSIDE
    the emblem, and heraldry is full of those. Flooding inward from the border instead means an
    enclosed shadow stays opaque no matter how dark it is, because it is not reachable from the
    edge.

    Between `lo` and `hi` the alpha ramps rather than stepping, which is what absorbs the JPEG
    ringing that surrounds a subject on a dark field. These sources are the weakest inputs in the
    set and their results warrant an eyeball.
    """
    rgb = im.convert("RGB")
    a = np.asarray(rgb, dtype=np.float32)
    lum = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114

    # Flood the "certainly background" mask inward from the border, using a C-speed max filter
    # rather than a Python BFS.
    dark = np.asarray(((lum < hi) * 255).astype(np.uint8))
    seed = np.zeros(lum.shape, dtype=np.uint8)
    seed[0, :] = seed[-1, :] = seed[:, 0] = seed[:, -1] = 255
    seed = np.minimum(seed, dark)
    dark_im = Image.fromarray(dark, "L")
    prev = -1
    while True:
        grown = Image.fromarray(seed, "L").filter(ImageFilter.MaxFilter(3))
        seed = np.minimum(np.asarray(grown), np.asarray(dark_im))
        cur = int(seed.sum())
        if cur == prev:
            break
        prev = cur

    background = seed > 0
    ramp = np.clip((lum - lo) / max(1.0, float(hi - lo)), 0.0, 1.0)
    alpha = np.where(background, ramp, 1.0) * 255.0
    out = np.concatenate([a, alpha[..., None]], axis=2)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def _run_upscaler(im, workdir):
    """One x4 pass through the vendored binary. PNG in, PNG out, alpha preserved."""
    src = os.path.join(workdir, "in.png")
    dst = os.path.join(workdir, "out.png")
    im.save(src)
    cmd = [BIN, "-i", src, "-o", dst, "-n", MODEL, "-m", MODEL_DIR,
           "-s", str(MODEL_SCALE), "-f", "png"]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0 or not os.path.exists(dst):
        raise RuntimeError("upscaler failed (%d): %s" % (proc.returncode, proc.stderr.strip()[-400:]))
    out = Image.open(dst).convert("RGBA")
    out.load()
    os.remove(src)
    os.remove(dst)
    return out


def upscale_to(im, need):
    """Chain x4 passes until the image is at least `need` times its original size."""
    factor = 1.0
    with tempfile.TemporaryDirectory() as workdir:
        while factor < need:
            im = _run_upscaler(im, workdir)
            factor *= MODEL_SCALE
    return im


def parse_erase(spec):
    """`L,T,R,B;L,T,R,B` -> [(l,t,r,b), ...]. Empty string means nothing to erase."""
    boxes = []
    for chunk in (spec or "").split(";"):
        chunk = chunk.strip()
        if not chunk:
            continue
        parts = [p.strip() for p in chunk.split(",")]
        if len(parts) != 4 or not all(p.lstrip("-").isdigit() for p in parts):
            raise ValueError("erase box wants four integers L,T,R,B; got %r" % chunk)
        boxes.append(tuple(int(p) for p in parts))
    return boxes


def erase_regions(im, boxes, opaque):
    """Blank a region of the SOURCE before any keying or upscaling.

    Applied to the source rather than the output so the erased area goes through exactly the same
    path as everything else and lands as genuine transparency. The fill has to match what the
    source treats as background: black for an opaque plate about to be keyed off its dark field,
    and real transparency for a plate that already has an alpha channel. Painting black into the
    latter would leave an opaque black rectangle, since nothing downstream would key it away.

    This exists because several wiki sources carry a burned-in copyright line or an artist
    signature. Those are part of the JPEG, not metadata, so nothing but painting over them removes
    them.
    """
    im = im.copy()
    for box in boxes:
        l, t, r, b = box
        if not (0 <= l < r <= im.width and 0 <= t < b <= im.height):
            # Silently doing nothing is the worst outcome here: the watermark the box was measured
            # for stays in the shipped art, and the run still reports success.
            raise ValueError("erase box %s lies outside the %dx%d source (or is empty)"
                             % (",".join(str(v) for v in box), im.width, im.height))
        im.paste((0, 0, 0, 255) if opaque else TRANSPARENT, box)
    return im


def convert(src_path, size=SIZE, pad=0, use_ai=True, erase="", report=None):
    """One source image -> the RGBA plate that gets written as TGA."""
    im = Image.open(src_path)
    im = im.convert("RGBA") if im.mode != "RGBA" else im.copy()
    opaque = im.getchannel("A").getextrema()[0] == 255

    boxes = parse_erase(erase)
    if boxes:
        im = erase_regions(im, boxes, opaque)

    if opaque:
        im = key_dark_background(im)

    need = min(size / im.width, size / im.height)
    engine = "lanczos"
    if use_ai and need > AI_MIN_SCALE:
        im = solidify(im)
        im = upscale_to(im, need)
        engine = "realesrgan-x%d" % MODEL_SCALE

    # Resize happens inside fit_square, AFTER the upscaler, so the final resampling averages the
    # alpha channel and the emblem's edges stay soft rather than hard-keyed at model resolution.
    out = fit_square(im, size)
    if pad > 0:
        out = pad_within(out, size, pad)
    elif pad == 0:
        # Auto-pad by exactly the shortfall. docs/artwork-spec.md wants >= MIN_MARGIN px of clear
        # frame so the FILL crop and the TILE wrap cannot shave the motif, and a letterboxed wide
        # logo always lands with zero margin on its long axis. Correcting it per image beats
        # emitting a warning the author has to notice and re-run 104 times, and beats a blanket
        # --pad that needlessly shrinks art already carrying a 68px margin.
        have = margin_of(out)
        if have is not None and have < MIN_MARGIN:
            out = pad_within(out, size, MIN_MARGIN - have)
            if report is not None:
                report["autopad"] = MIN_MARGIN - have

    # LAST, after every resize and paste. Each of those can reintroduce a stray RGB under a zero
    # alpha — LANCZOS by premultiplying, a paste by carrying its canvas color in — so
    # normalizing any earlier just gets undone by the next step.
    out = normalize_transparent(out)

    if report is not None:
        report.update(keyed=opaque, engine=engine, need=need)
    return out


def save_tga(im, path):
    """32-bit RLE TGA. RLE is a disk saving only; WoW expands it to 32bpp in VRAM regardless."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, compression="tga_rle")


# --------------------------------------------------------------------------------------------
# Manifest
# --------------------------------------------------------------------------------------------

def scaffold(root):
    """Propose a manifest row per source image, resolving duplicates and collisions.

    Best effort, and deliberately loud about every choice it makes on your behalf. The manifest it
    writes is what conversion actually reads, so a wrong call here costs a one-line edit — but a
    SILENT wrong call costs a shipped id that can never be renamed.
    """
    exts = {".png", ".webp", ".jpg", ".jpeg", ".gif", ".bmp", ".tga"}
    candidates, seen_hash, dropped = [], {}, []

    for dirpath, _, names in os.walk(root):
        # A canonical name sorts ahead of its `… (1)` twin, so the duplicate check below keeps the
        # clean filename and discards the browser's copy rather than the other way round.
        for name in sorted(names, key=lambda n: (bool(_DUP_SUFFIX.search(os.path.splitext(n)[0])), n)):
            if os.path.splitext(name)[1].lower() not in exts:
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root).replace("\\", "/")
            category = derive_category(rel)

            # A byte-identical file already claimed under the SAME category is a true duplicate
            # (`… (1).png`). The same bytes under a DIFFERENT category is not: class/Dracthyr and
            # race/Dracthyr are one image serving as both the Evoker crest and the Dracthyr crest,
            # and both rows are wanted.
            key = (_digest(full), category)
            if key in seen_hash:
                dropped.append((rel, "byte-identical to %s" % seen_hash[key]))
                continue
            seen_hash[key] = rel

            try:
                with Image.open(full) as probe:
                    pixels = probe.width * probe.height
                    dims = "%dx%d" % probe.size
            except Exception:                                     # noqa: BLE001 - unreadable is a drop
                dropped.append((rel, "unreadable"))
                continue

            subject = derive_subject(name)
            override = _CATEGORY_ALIASES.get((category, subject))
            label = override[1] if override else None
            if override:
                subject = override[0]
            candidates.append({"source": rel, "category": category, "subject": subject,
                               "label": label, "pixels": pixels, "dims": dims})

    # Two sources claiming one id means the wiki served two cuts of one image — a 75x90 thumbnail
    # and a 188x276 original, say. Keeping the larger is strictly better than upscaling the
    # smaller, and far better than the old behavior of silently minting `arakkoa-2`, which would
    # have shipped the thumbnail forever under a name nobody could interpret.
    by_slot = {}
    for c in candidates:
        by_slot.setdefault((c["category"], c["subject"]), []).append(c)

    rows = []
    for slot in sorted(by_slot):
        group = sorted(by_slot[slot], key=lambda c: -c["pixels"])
        winner = group[0]
        for loser in group[1:]:
            dropped.append((loser["source"], "same id as %s, which is larger (%s vs %s)"
                            % (winner["source"], winner["dims"], loser["dims"])))
        rows.append({
            "source": winner["source"],
            "category": winner["category"],
            "subject": winner["subject"],
            "label": winner.get("label") or _titleize(winner["subject"]),
            "credit": "Warcraft Wiki (Blizzard Entertainment)",
            "erase": "",
        })

    rows.sort(key=lambda r: (r["category"], r["subject"]))
    rows, orphans = _carry_over_edits(rows)
    return rows, dropped, orphans


def _carry_over_edits(rows, path=MANIFEST):
    """Preserve hand-authored columns across a re-scaffold.

    Re-scaffolding is the normal way to pick up freshly downloaded art, and without this it would
    silently discard every correction already made — a fixed label, a credit, and above all the
    `erase` boxes that took real effort to locate. Losing those quietly is worse than losing them
    loudly, because the watermark simply reappears in the output.

    Matched on `source` first, falling back to the id, so a row survives either a rename of the
    downloaded file or a change to which file backs a given subject.
    """
    if not os.path.exists(path):
        return rows, []
    with open(path, newline="", encoding="utf-8") as fh:
        old = [r for r in csv.DictReader(fh, delimiter="\t") if r.get("source")]
    by_source = {r["source"]: r for r in old}
    by_id = {(r.get("category"), r.get("subject")): r for r in old}
    matched = set()
    for r in rows:
        exact = by_source.get(r["source"])
        prev = exact or by_id.get((r["category"], r["subject"]))
        if not prev:
            continue
        matched.add(id(prev))
        for field in ("label", "credit", "erase"):
            if not (prev.get(field) or "").strip():
                continue
            # `erase` is the one column expressed in the SOURCE image's pixel coordinates, so it is
            # only meaningful for the same source file. Carrying it across an id match whose source
            # changed — a re-download at a different resolution, say — would paint a box at
            # coordinates that mean nothing in the new image, silently blanking artwork or silently
            # missing the watermark it was measured against.
            if field == "erase" and not exact:
                continue
            r[field] = prev[field]

    # An orphaned old row only matters if it carries something a re-scaffold cannot regenerate: an
    # erase box, or a label that is not simply what _titleize would produce. Those are the edits
    # whose loss is silent and expensive.
    orphans = [r for r in old if id(r) not in matched
               and ((r.get("erase") or "").strip()
                    or (r.get("label") or "").strip() != _titleize(r.get("subject", "")))]
    return rows, orphans


def read_stamps(path=STAMPS):
    """dst path -> the fingerprint it was built from. Missing file means nothing is up to date."""
    if not os.path.exists(path):
        return {}
    out = {}
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.reader(fh, delimiter="\t"):
            if len(row) == 2:
                out[row[0]] = row[1]
    return out


def write_stamps(stamps, path=STAMPS):
    tmp = path + ".tmp"
    with open(tmp, "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, delimiter="\t", lineterminator="\n")
        for k in sorted(stamps):
            w.writerow([k, stamps[k]])
    os.replace(tmp, path)


def fingerprint(src, row, size, pad, use_ai):
    """Everything that determines the output bytes, and nothing that does not.

    The source file's mtime alone is not enough. An edited `erase` box, or a different --size,
    --pad or --no-ai, changes the result while leaving the source untouched — and the old check
    would answer "up to date", leave a stale TGA in place, and report success. That is the worst
    class of bug this tool can have: the watermark stays in the shipped art, or the catalog
    declares w=256 for a file that is 64px on disk, and nothing downstream notices.

    `label` and `credit` are deliberately excluded. They feed only --emit-catalog and cannot move a
    pixel, so folding them in (as a whole-manifest hash would) forces a needless multi-hour
    reconvert every time a caption is corrected.
    """
    import hashlib
    st = os.stat(src)
    parts = [_digest(src) if st.st_size <= (4 << 20) else "%d:%d" % (st.st_mtime_ns, st.st_size),
             str(size), str(pad), "1" if use_ai else "0", row.get("erase", "") or "",
             MODEL, str(MODEL_SCALE), str(AI_MIN_SCALE)]
    return hashlib.sha256("\x00".join(parts).encode("utf-8")).hexdigest()[:32]


def _digest(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


# Display labels the slug cannot round-trip, because slugify drops the apostrophe that the
# subject's real name carries. The id stays punctuation-free; only what the user reads is fixed.
_LABEL_OVERRIDES = {
    "maghar": "Mag'har",
    "twilights-hammer": "Twilight's Hammer",
    "tolvir": "Tol'vir",
    "keg-legs-crew": "Keg Leg's Crew",
    "classic": "Classic (Vanilla)",
    "demon": "Demon (Legion)",
    "nightborne-legion": "Nightborne (Legion)",
    "highmountain-tauren-legion": "Highmountain Tauren (Legion)",
}


def _titleize(subject):
    if subject in _LABEL_OVERRIDES:
        return _LABEL_OVERRIDES[subject]
    small = {"of", "the", "and", "for"}
    words = subject.split("-")
    return " ".join(w if (i and w in small) else w.capitalize() for i, w in enumerate(words))


def read_manifest(path=MANIFEST):
    if not os.path.exists(path):
        sys.exit("no manifest at %s — run with --scaffold <source-dir> first" % path)
    with open(path, newline="", encoding="utf-8") as fh:
        rows = [r for r in csv.DictReader(fh, delimiter="\t") if r.get("source")]
    # Validated up front rather than trusted, because every one of these becomes either a permanent
    # catalog id or a filesystem path, and a bad value fails late and quietly: a duplicate slot
    # converts both rows to one file and reports success, so an asset silently never ships.
    seen, problems = {}, []
    for r in rows:
        cat, subj = r.get("category", ""), r.get("subject", "")
        if cat in RESERVED_DIRS:
            problems.append("%s: reserved category %r" % (r["source"], cat))
        elif cat not in CATEGORY_LABEL:
            problems.append("%s: unknown category %r (want one of %s)"
                            % (r["source"], cat, ", ".join(sorted(CATEGORY_LABEL))))
        if not _SUBJECT_RE.match(subj or ""):
            # A subject becomes a filename AND a Lua string. A path separator would escape the
            # category directory; a backslash or quote would break the emitted catalog.
            problems.append("%s: subject %r must match %s" % (r["source"], subj, _SUBJECT_RE.pattern))
        slot = (cat, subj)
        if slot in seen:
            problems.append("%s: duplicate id %s/%s, already claimed by %s"
                            % (r["source"], cat, subj, seen[slot]))
        seen[slot] = r["source"]
        try:
            parse_erase(r.get("erase", ""))
        except ValueError as exc:
            problems.append("%s: %s" % (r["source"], exc))
    if problems:
        sys.exit("manifest has %d problem(s):\n  %s" % (len(problems), "\n  ".join(problems)))
    return rows


def write_manifest(rows, path=MANIFEST):
    """Atomic. The manifest is the only record of hand-authored erase boxes and corrected labels,
    and truncating it in place means an exception or a Ctrl-C part-way through leaves a half-written
    file with no backup."""
    tmp = path + ".tmp"
    with open(tmp, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=MANIFEST_FIELDS, delimiter="\t",
                           lineterminator="\n", extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    os.replace(tmp, path)


def emit_catalog(rows, size=SIZE):
    """The Lua catalog rows, ready to paste into modules/Artwork.lua.

    `file` carries a backslash so the stem joins C.ARTWORK_PATH_PREFIX into a path with one
    separator convention throughout. modules/Artwork.lua concatenates it verbatim, so no resolver
    change is needed for the art to live in per-category subdirectories.
    """
    out = []
    for r in sorted(rows, key=lambda r: (r["category"], r["subject"])):
        out.append(
            '  { id       = "%s-%s",\n'
            '    category = "%s",\n'
            '    label    = "%s",\n'
            '    file     = "%s\\\\%s",\n'
            '    w        = %d, h = %d,\n'
            '    tintable = false,\n'
            '    credit   = "%s" },'
            % (r["category"], r["subject"], CATEGORY_LABEL[r["category"]], r["label"],
               r["category"], r["subject"], size, size, r["credit"])
        )
    return "\n".join(out)


# --------------------------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------------------------

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--scaffold", metavar="DIR",
                    help="walk DIR and propose tools/artwork/manifest.tsv, then exit")
    ap.add_argument("--force-scaffold", action="store_true",
                    help="overwrite the manifest even when hand-authored rows would be lost")
    ap.add_argument("--source-root", metavar="DIR",
                    help="where the manifest's source paths are rooted (default: the scaffolded root)")
    ap.add_argument("--only", metavar="GLOB", action="append", default=[],
                    help="convert only rows whose <category>/<subject> matches; repeatable")
    ap.add_argument("--out", metavar="DIR", default=OUT_DIR,
                    help="output root (default media/artwork/)")
    ap.add_argument("--size", type=int, default=SIZE, help="output edge length, power of two")
    ap.add_argument("--pad", type=int, default=0, metavar="PX",
                    help="guarantee this much transparent margin, in output pixels")
    ap.add_argument("--no-ai", action="store_true", help="Lanczos only; skip the upscaler")
    ap.add_argument("--force", action="store_true", help="reconvert even if the output is newer")
    ap.add_argument("--dry-run", action="store_true", help="print the plan and touch nothing")
    ap.add_argument("--emit-catalog", action="store_true",
                    help="print the Lua catalog rows for the manifest and exit")
    ap.add_argument("--copy-raw", action="store_true",
                    help="also copy each source into media/artwork/raw/<category>/")
    ap.add_argument("--contact-sheet", metavar="PNG",
                    help="write a grid of every converted plate for review")
    args = ap.parse_args(argv)

    if args.size & (args.size - 1):
        sys.exit("--size must be a power of two, got %d (WoW cannot load NPOT textures)" % args.size)

    if args.scaffold:
        root = os.path.abspath(os.path.expanduser(args.scaffold))
        if not os.path.isdir(root):
            sys.exit("no such directory: %s" % root)
        rows, dropped, orphans = scaffold(root)
        # A zero-row scaffold is never a useful artifact, only a destroyed manifest.
        if not rows:
            sys.exit("found no images under %s — refusing to overwrite %s" % (root, MANIFEST))
        # The precise signal that the source root is wrong is not "no rows" but "rows I already had
        # hand-authored data for have no counterpart here". A half-wrong root still produces plenty
        # of rows while quietly discarding the erase boxes that took real effort to measure.
        if orphans and not args.force_scaffold:
            print("refusing to overwrite %s: %d hand-authored row(s) have no counterpart under %s"
                  % (MANIFEST, len(orphans), root))
            for r in orphans[:10]:
                print("  %s/%s  (%s)" % (r.get("category"), r.get("subject"), r.get("source")))
            if len(orphans) > 10:
                print("  ... and %d more" % (len(orphans) - 10))
            sys.exit("pass --force-scaffold to discard them anyway")
        write_manifest(rows)
        with open(MANIFEST + ".root", "w", encoding="utf-8") as fh:
            fh.write(root + "\n")
        print("wrote %s (%d rows) from %s" % (MANIFEST, len(rows), root))
        by_cat = {}
        for r in rows:
            by_cat[r["category"]] = by_cat.get(r["category"], 0) + 1
        for c in sorted(by_cat):
            print("  %-11s %3d" % (c, by_cat[c]))
        if dropped:
            # Never silent. A dropped source is a decision made on the author's behalf, and the
            # only way to notice a wrong one is to see it.
            print("\ndropped %d source(s):" % len(dropped))
            for name, why in dropped:
                print("  %-58s %s" % (name, why))
        print("\nReview the subject column before converting — ids are permanent once shipped.")
        return 0

    rows = read_manifest()

    if args.emit_catalog:
        print(emit_catalog(rows, args.size))
        return 0

    root = args.source_root
    if not root and os.path.exists(MANIFEST + ".root"):
        root = open(MANIFEST + ".root", encoding="utf-8").read().strip()
    if not root:
        sys.exit("no source root known — pass --source-root DIR")
    root = os.path.abspath(os.path.expanduser(root))

    if args.only:
        rows = [r for r in rows
                if any(fnmatch.fnmatch("%s/%s" % (r["category"], r["subject"]), g)
                       for g in args.only)]
        if not rows:
            sys.exit("--only matched no manifest rows")

    plates, failures, skipped = [], [], []
    stamps = {} if args.force else read_stamps()
    for r in rows:
        src = os.path.join(root, r["source"])
        dst = os.path.join(args.out, r["category"], r["subject"] + ".tga")
        if not os.path.exists(src):
            failures.append((r["source"], "source missing"))
            continue
        want = fingerprint(src, r, args.size, args.pad, not args.no_ai)
        if not args.force and os.path.exists(dst) and stamps.get(dst) == want:
            # Belt and braces on the one mismatch that corrupts the catalog rather than merely
            # dating it: --emit-catalog declares w/h from --size, so a stale file of the wrong
            # dimensions would have the fill math scaling against a lie. One header read.
            try:
                with Image.open(dst) as probe:
                    fresh = probe.size == (args.size, args.size)
            except Exception:                                     # noqa: BLE001 - unreadable = rebuild
                fresh = False
            if fresh:
                skipped.append("%s/%s" % (r["category"], r["subject"]))
                continue
        if args.dry_run:
            try:
                with Image.open(src) as probe:
                    dims = probe.size
            except Exception as exc:                              # noqa: BLE001 - reported, not raised
                # The cheap pre-flight is exactly where a corrupt source should be REPORTED, not
                # where the whole run should die before listing the other 103 rows.
                failures.append((r["source"], "unreadable: %s" % exc))
                continue
            need = min(args.size / dims[0], args.size / dims[1])
            print("  %-11s %-32s %9s  need %5.2fx  %s"
                  % (r["category"], r["subject"], "%dx%d" % dims, need,
                     "lanczos" if (args.no_ai or need <= AI_MIN_SCALE) else "realesrgan"))
            continue

        info = {}
        try:
            out = convert(src, args.size, args.pad, use_ai=not args.no_ai,
                          erase=r.get("erase", ""), report=info)
        except Exception as exc:                                  # noqa: BLE001 - reported, not raised
            failures.append((r["source"], str(exc)))
            continue

        save_tga(out, dst)
        stamps[dst] = want
        if args.copy_raw:
            raw_dst = os.path.join(RAW_DIR, r["category"],
                                   r["subject"] + os.path.splitext(src)[1].lower())
            os.makedirs(os.path.dirname(raw_dst), exist_ok=True)
            shutil.copy2(src, raw_dst)
        if args.contact_sheet:
            plates.append((r["category"] + "/" + r["subject"], out))

        lo, hi = out.getchannel("A").getextrema()
        margin = margin_of(out)
        note = ""
        if info.get("autopad"):
            note += "  auto-padded %dpx" % info["autopad"]
        if hi < 200:
            note += "  WARNING: nothing near-opaque"
        if margin is not None and margin < MIN_MARGIN:
            note += "  WARNING: only %dpx margin (want >=%d); re-run with --pad %d" % (
                margin, MIN_MARGIN, MIN_MARGIN - margin)
        if margin is None:
            note += "  WARNING: plate is empty"
        print("  %-11s %-32s %-14s need %5.2fx  alpha %d-%d  margin %s  %6.0fKB%s"
              % (r["category"], r["subject"], info.get("engine", "?"), info.get("need", 0),
                 lo, hi, margin, os.path.getsize(dst) / 1024.0, note))

    if args.contact_sheet and plates:
        _contact_sheet(plates, args.contact_sheet)
        print("contact sheet: %s" % args.contact_sheet)

    if not args.dry_run:
        write_stamps(stamps)
    if skipped:
        # Named, not just counted. "skipped 104 up-to-date" is exactly how the one row you just
        # edited hides from you.
        print("skipped %d up-to-date (use --force to reconvert): %s"
              % (len(skipped), ", ".join(skipped[:8]) + (" ..." if len(skipped) > 8 else "")))
    if failures:
        print("\n%d FAILED:" % len(failures))
        for name, why in failures:
            print("  %-50s %s" % (name, why))
        return 1
    return 0


def _contact_sheet(plates, path, cell=160, cols=10):
    """A grid of every plate, on a mid gray so both dark and light art stay visible."""
    rows = (len(plates) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (72, 72, 78))
    for i, (_, im) in enumerate(plates):
        thumb = im.copy()
        thumb.thumbnail((cell - 8, cell - 8), Image.LANCZOS)
        x = (i % cols) * cell + (cell - thumb.width) // 2
        y = (i // cols) * cell + (cell - thumb.height) // 2
        sheet.paste(thumb, (x, y), thumb)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    sheet.save(path)


if __name__ == "__main__":
    sys.exit(main())
