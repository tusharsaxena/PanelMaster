#!/usr/bin/env python3
"""Turn ordinary artwork into the 32-bit TGA Ka0s Panel Master renders.

Takes an image that already carries an alpha channel — a PNG from a designer, a cutout from a
wiki, an icon you drew — and produces a square, power-of-two, transparent-background TGA the WoW
client can load. Source can be PNG, WebP, JPEG, GIF, BMP or TGA.

Two modes:

    artwork_cleaner.py --single path/to/Emblem.png
        Writes path/to/Emblem-panelmaster.tga beside the source.

    artwork_cleaner.py --batch SRC_DIR DST_DIR
        Converts every image under SRC_DIR into DST_DIR, reproducing the folder structure
        exactly and keeping each file's name (only the extension becomes .tga).

There is no manifest and no naming step. What you get out is decided entirely by what you put in:
the folder structure and the file names are yours, and `update_catalog.py` reads them back to
build the addon's catalog. Name things the way you want them to appear.

What it does to an image, in order:

    erase     blank a region of the SOURCE (a burned-in watermark or signature), --single only
    key       if the source has NO alpha at all, derive it by flooding in from the border
    solidify  push opaque color outward under the transparent pixels, so upscaling cannot
              smear an arbitrary background color into the artwork's edges
    upscale   Real-ESRGAN x4 per pass, chained, skipped when the image is already big enough
    fit       letterbox onto a square power-of-two canvas, never crop
    pad       shrink slightly if the art would otherwise touch the frame
    normalize force every fully-transparent pixel to (0,0,0,0)

Requires Pillow and numpy. The upscaler is vendored under tools/artwork/bin/.
"""

import argparse
import csv
import hashlib
import os
import re
import subprocess
import sys
import tempfile
import time

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
STAMPS = os.path.join(HERE, ".stamps.tsv")

# Extensions treated as artwork. Anything else under a --batch tree is left alone, so a README or
# a stray .txt in the source folder is not an error.
IMAGE_EXTS = {".png", ".webp", ".jpg", ".jpeg", ".gif", ".bmp", ".tga"}

# What --single appends, so a converted file sits beside its source without overwriting it and is
# obvious in a file listing.
SINGLE_SUFFIX = "-panelmaster"

# The output box. Power of two on both axes because WoW cannot wrap a non-power-of-two texture and
# the addon offers a TILE fill. Letterboxed rather than cropped, so aspect survives.
SIZE = 1024

# What counts as artwork when measuring the transparent margin, as opposed to the near-invisible
# speckle a keyed source carries. Well below the eye's threshold, well above the noise.
CONTENT_FLOOR = 24

# The transparent margin the FILL crop and the TILE wrap need so they cannot shave the motif.
MIN_MARGIN = 4

# What a fully-transparent pixel's RGB is set to. Invisible under normal blending, and therefore
# easy to assume does not matter — but three of the addon's blend modes read it:
#
#   Additive  adds the RGB to whatever is behind. Black adds nothing, which is what "transparent"
#             has to mean. White would wash the entire panel out.
#   Alpha key thresholds alpha and draws what survives fully opaque.
#   Opaque    ignores alpha completely and draws the RGB across the whole square.
#
# Black is the only value correct for Additive, which is the mode people actually reach for.
TRANSPARENT = (0, 0, 0, 0)

# One model for everything, always at its native x4, chained when more is needed. Selecting a
# smaller model per image measured 1.7x faster and was rejected: assets sit next to each other in
# one dropdown, and different models sharpen with visibly different character.
MODEL = "realesrgan-x4plus-anime"
MODEL_SCALE = 4
BIN = os.path.join(HERE, "bin", "realesrgan-ncnn-vulkan")
MODEL_DIR = os.path.join(HERE, "bin", "models")

# Below this required scale, Lanczos is used instead of the upscaler. Not a compromise: the model
# only runs at x4, so an image needing 1.1x would be blown up 4x and thrown away — a full pass to
# sharpen something already at target resolution.
AI_MIN_SCALE = 1.25

# How far short of the required scale a chain may stop, leaving Lanczos to cover the remainder.
#
# The model only runs at x4, so scale is reached in jumps of 4. An image needing 4.02x would
# otherwise chain a SECOND full pass to 16x — a 184x255 source becoming 2944x4080, twelve million
# pixels and about a minute of CPU, almost all of it discarded on the way back down to 1024. After
# one pass it is already at 736x1020, four pixels short on the short edge.
#
# Stopping there and letting Lanczos stretch the last 0.4% is invisible. This tolerance caps that
# remainder at 5%, which is well inside what resampling can cover without visible softness, and
# turns the pathological just-over-a-power-of-four case from two passes into one.
UPSCALE_TOLERANCE = 1.05

# How far opaque RGB is pushed outward before upscaling. Wider than any resampling kernel reaches.
SOLIDIFY_ITERS = 16

# Luminance bounds for keying a source that has no alpha. Below LO is certainly background, above
# HI certainly art; between them alpha ramps, which absorbs JPEG ringing around the subject.
KEY_LO, KEY_HI = 16, 48


# ------------------------------------------------------------------------------------------------
# Progress
# ------------------------------------------------------------------------------------------------
#
# Written to stderr, so piping stdout to a file still shows progress on the terminal and a captured
# log is not full of percentage spam. Silenced entirely by --quiet.

_PCT_RE = re.compile(r"^(\d+(?:\.\d+)?)%$")
_QUIET = False


def _say(text, end="\n"):
    if _QUIET:
        return
    sys.stderr.write(text + end)
    sys.stderr.flush()


def _progress(text):
    """A transient counter on the current line. Only when stderr is a terminal — writing carriage
    returns into a redirected log produces one unreadable smear of every percentage ever printed."""
    if _QUIET or not sys.stderr.isatty():
        return
    sys.stderr.write("\r\033[K" + text)
    sys.stderr.flush()


def _progress_done():
    if _QUIET or not sys.stderr.isatty():
        return
    sys.stderr.write("\r\033[K")
    sys.stderr.flush()


# ------------------------------------------------------------------------------------------------
# Image stages
# ------------------------------------------------------------------------------------------------

def parse_erase(spec):
    """`L,T,R,B` or several separated by `;` -> [(l,t,r,b), ...]."""
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
    """Blank a region of the SOURCE, before any keying or upscaling.

    Applied to the source rather than the output so the blanked area travels the same path as
    everything else and lands as genuine transparency. The fill has to match what this source
    treats as background: black for an opaque plate about to be keyed off its dark field, real
    transparency for a plate that already has alpha. Painting black into the latter would leave an
    opaque black rectangle that nothing downstream keys away.

    Exists for burned-in copyright lines and artist signatures, which are pixels rather than
    metadata, so painting over them is the only removal there is.
    """
    im = im.copy()
    for box in boxes:
        l, t, r, b = box
        if not (0 <= l < r <= im.width and 0 <= t < b <= im.height):
            # Silently doing nothing is the worst outcome: the watermark stays in the art and the
            # run still reports success.
            raise ValueError("erase box %s lies outside the %dx%d source (or is empty)"
                             % (",".join(str(v) for v in box), im.width, im.height))
        im.paste((0, 0, 0, 255) if opaque else TRANSPARENT, box)
    return im


def key_dark_background(im, lo=KEY_LO, hi=KEY_HI):
    """Opaque art on a near-black field -> alpha keyed off the background.

    Only for sources that arrive with no alpha at all. Connectivity is what makes it safe: a plain
    luminance threshold would also punch holes through every dark region INSIDE the art, and
    emblems are full of those. Flooding inward from the border means an enclosed shadow stays
    opaque no matter how dark it is, because it is not reachable from the edge.
    """
    rgb = im.convert("RGB")
    a = np.asarray(rgb, dtype=np.float32)
    lum = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114

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


def _box_sum(arr):
    """Sum over the 3x3 neighborhood, edges replicated."""
    p = np.pad(arr, ((1, 1), (1, 1), (0, 0)), mode="edge")
    total = np.zeros_like(arr)
    for dy in range(3):
        for dx in range(3):
            total += p[dy:dy + arr.shape[0], dx:dx + arr.shape[1]]
    return total


def solidify(im, iters=SOLIDIFY_ITERS):
    """Edge-extend opaque RGB outward into the transparent region.

    The stage whose absence is invisible until it is too late. Sources disagree about what RGB
    sits under a transparent pixel — (0,0,0,0) on most, (255,255,255,0) on many, and occasionally
    something arbitrary like (217,182,103,0). Nothing renders that color, so nothing complains.

    An upscaler does not care. Its kernel samples neighboring pixels including the transparent
    ones, so a white-under-alpha source grows a white halo along every edge and a black-under-alpha
    source grows a dark one. Replacing that arbitrary constant with a continuation of the adjacent
    artwork means the kernel samples something plausible instead.

    Runs BEFORE the upscaler, because afterwards the halo is already baked in.
    """
    a = np.asarray(im.convert("RGBA"), dtype=np.float32)
    rgb, alpha = a[..., :3], a[..., 3]
    known = (alpha > 0).astype(np.float32)[..., None]
    cur = rgb * known
    for _ in range(iters):
        if known.min() >= 1.0:
            break
        num = _box_sum(cur)
        den = _box_sum(known)
        grown = (den > 0).astype(np.float32)
        newly = ((grown > 0) & (known == 0))
        cur = np.where(newly, num / np.maximum(den, 1e-6), cur)
        known = ((newly | (known > 0)).astype(np.float32))
    out = np.concatenate([np.clip(cur, 0, 255), alpha[..., None]], axis=2)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def _run_upscaler(im, workdir):
    """One x4 pass through the vendored binary. PNG in, PNG out, alpha preserved.

    The binary's own percentage output is streamed rather than captured. On software Vulkan a
    single pass over a few megapixels is a minute of wall clock, and swallowing its progress is
    what makes the tool look hung — which is exactly what it looked like.
    """
    if not os.path.exists(BIN):
        raise RuntimeError("upscaler not found at %s (run with --no-ai to use Lanczos only)" % BIN)
    src = os.path.join(workdir, "in.png")
    dst = os.path.join(workdir, "out.png")
    im.save(src)
    cmd = [BIN, "-i", src, "-o", dst, "-n", MODEL, "-m", MODEL_DIR,
           "-s", str(MODEL_SCALE), "-f", "png"]

    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, bufsize=1)
    tail = []
    for line in proc.stdout:
        line = line.strip()
        if not line:
            continue
        tail.append(line)
        del tail[:-8]
        pct = _PCT_RE.match(line)
        if pct:
            _progress("%s%%" % pct.group(1))
    proc.wait()
    _progress_done()
    if proc.returncode != 0 or not os.path.exists(dst):
        raise RuntimeError("upscaler failed (%d): %s" % (proc.returncode, " | ".join(tail)[-400:]))

    out = Image.open(dst).convert("RGBA")
    out.load()
    os.remove(src)
    os.remove(dst)
    return out


def upscale_to(im, need):
    """Chain x4 passes until the image is close enough to `need` times its original size.

    "Close enough" rather than "at least": see UPSCALE_TOLERANCE. Stopping a few percent short
    saves an entire extra pass whenever the required scale lands just above a power of four, and
    Lanczos covers the remainder invisibly.
    """
    target = need / UPSCALE_TOLERANCE
    passes = 0
    factor = 1.0
    while factor < target:
        factor *= MODEL_SCALE
        passes += 1

    with tempfile.TemporaryDirectory() as workdir:
        for i in range(passes):
            before = im.size
            _say("    upscale    pass %d/%d  %dx%d -> %dx%d "
                 % (i + 1, passes, before[0], before[1],
                    before[0] * MODEL_SCALE, before[1] * MODEL_SCALE), end="")
            t = time.time()
            im = _run_upscaler(im, workdir)
            _say(" %.1fs" % (time.time() - t))
    return im


def fit_square(im, size):
    """Scale onto a transparent size x size canvas, preserving aspect.

    Sources do not arrive square, and resizing a 2560x1243 logo straight to a square would squash
    it — with nothing downstream able to tell, since the catalog declares w = h = size and the
    fill math would faithfully preserve an aspect that was already wrong. Letterboxing keeps the
    proportions and supplies the transparent margin the FILL crop and TILE wrap want.
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

    Deliberately not a crop-to-content-bbox followed by a rescale. Emblems are usually drawn
    symmetrically about the frame's center, and re-centering on a bbox that is a few pixels
    lopsided — which every antialiased plate's bbox is — would visibly tilt them off-axis.
    """
    inner = size - pad * 2
    if inner < 1:
        raise ValueError("pad %d leaves no room in a %dpx image" % (pad, size))
    canvas = Image.new("RGBA", (size, size), TRANSPARENT)
    canvas.paste(im.resize((inner, inner), Image.LANCZOS), (pad, pad))
    return canvas


def content_bbox(im):
    """Bounding box of real artwork, ignoring near-invisible speckle."""
    return im.getchannel("A").point(lambda v: 255 if v >= CONTENT_FLOOR else 0).getbbox()


def margin_of(im):
    """Smallest transparent margin on any of the four sides, or None if the plate is empty."""
    bbox = content_bbox(im)
    if not bbox:
        return None
    return min(bbox[0], bbox[1], im.width - bbox[2], im.height - bbox[3])


def normalize_transparent(im):
    """Force every fully-transparent pixel to one defined RGB.

    Must run LAST. LANCZOS premultiplies (zeroing the RGB of transparent pixels) and a paste
    carries its canvas color in, so normalizing any earlier is simply undone by the next step.
    """
    a = np.asarray(im.convert("RGBA")).copy()
    a[a[..., 3] == 0] = TRANSPARENT
    return Image.fromarray(a, "RGBA")


def convert(src_path, size=SIZE, pad=0, use_ai=True, erase="", report=None):
    """One source image -> the RGBA plate written as TGA."""
    im = Image.open(src_path)
    im = im.convert("RGBA") if im.mode != "RGBA" else im.copy()
    opaque = im.getchannel("A").getextrema()[0] == 255
    src_size = im.size

    need = min(size / im.width, size / im.height)
    will_ai = use_ai and need > AI_MIN_SCALE
    passes = 0
    if will_ai:
        f, target = 1.0, need / UPSCALE_TOLERANCE
        while f < target:
            f *= MODEL_SCALE
            passes += 1
    _say("    plan       %dx%d, need %.2fx -> %s, then fit to %dx%d"
         % (src_size[0], src_size[1], need,
            ("%d upscaler pass%s" % (passes, "" if passes == 1 else "es")) if will_ai else "Lanczos",
            size, size))

    boxes = parse_erase(erase)
    if boxes:
        _say("    erase      %d region(s)" % len(boxes))
        im = erase_regions(im, boxes, opaque)
    if opaque:
        _say("    key        source has no alpha; flooding from the border ...", end="")
        t = time.time()
        im = key_dark_background(im)
        _say(" %.1fs" % (time.time() - t))

    engine = "lanczos"
    if will_ai:
        _say("    solidify   edge-extending color under transparent pixels ...", end="")
        t = time.time()
        im = solidify(im)
        _say(" %.1fs" % (time.time() - t))
        im = upscale_to(im, need)
        engine = "realesrgan-x%d" % MODEL_SCALE

    # Resize happens inside fit_square, AFTER the upscaler, so the final resampling averages the
    # alpha channel and edges stay soft rather than hard-keyed at model resolution.
    _say("    fit        %dx%d -> %dx%d ..." % (im.width, im.height, size, size), end="")
    t = time.time()
    out = fit_square(im, size)
    _say(" %.1fs" % (time.time() - t))
    if pad > 0:
        out = pad_within(out, size, pad)
    else:
        # Auto-pad by exactly the shortfall. A letterboxed wide image always lands with zero margin
        # on its long axis, and correcting per image beats a blanket --pad that needlessly shrinks
        # art already carrying a large margin.
        have = margin_of(out)
        if have is not None and have < MIN_MARGIN:
            out = pad_within(out, size, MIN_MARGIN - have)
            if report is not None:
                report["autopad"] = MIN_MARGIN - have

    _say("    normalize  forcing transparent pixels to (0,0,0,0) ...", end="")
    t = time.time()
    out = normalize_transparent(out)
    _say(" %.1fs" % (time.time() - t))
    if report is not None:
        report.update(keyed=opaque, engine=engine, need=need, passes=passes)
    return out


def save_tga(im, path):
    """32-bit RLE TGA. RLE is a disk saving only; WoW expands to 32bpp in VRAM regardless."""
    parent = os.path.dirname(os.path.abspath(path))
    os.makedirs(parent, exist_ok=True)
    im.save(path, compression="tga_rle")


# ------------------------------------------------------------------------------------------------
# Up-to-date tracking
# ------------------------------------------------------------------------------------------------

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


def _digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def fingerprint(src, size, pad, use_ai, erase):
    """Everything that determines the output bytes, and nothing that does not.

    Source mtime alone is not enough: a changed --size or --pad leaves the source untouched, so an
    mtime check would answer "up to date", leave a stale TGA in place, and report success.
    """
    st = os.stat(src)
    parts = [_digest(src) if st.st_size <= (4 << 20) else "%d:%d" % (st.st_mtime_ns, st.st_size),
             str(size), str(pad), "1" if use_ai else "0", erase or "",
             MODEL, str(MODEL_SCALE), str(AI_MIN_SCALE)]
    return hashlib.sha256("\x00".join(parts).encode("utf-8")).hexdigest()[:32]


# ------------------------------------------------------------------------------------------------
# Driver
# ------------------------------------------------------------------------------------------------

def _report(label, dst, info, out):
    lo, hi = out.getchannel("A").getextrema()
    margin = margin_of(out)
    note = ""
    if info.get("autopad"):
        note += "  auto-padded %dpx" % info["autopad"]
    if info.get("keyed"):
        note += "  keyed (source had no alpha)"
    if hi < 200:
        note += "  WARNING: nothing near-opaque"
    if margin is None:
        note += "  WARNING: plate is empty"
    # Flushed because progress goes to stderr (unbuffered) and this goes to stdout, which is
    # block-buffered when piped — without the flush every result line lands after every stage line
    # instead of interleaved with them.
    print("  %-46s %-14s need %5.2fx  alpha %d-%d  margin %s  %6.0fKB%s"
          % (label, info.get("engine", "?"), info.get("need", 0), lo, hi,
             margin, os.path.getsize(dst) / 1024.0, note), flush=True)


def run_single(args):
    src = os.path.abspath(os.path.expanduser(args.single))
    if not os.path.isfile(src):
        sys.exit("no such file: %s" % src)
    stem, _ = os.path.splitext(src)
    dst = stem + SINGLE_SUFFIX + ".tga"
    _say("%s" % os.path.basename(src))
    started = time.time()
    info = {}
    try:
        out = convert(src, args.size, args.pad, use_ai=not args.no_ai,
                      erase=args.erase or "", report=info)
    except Exception as exc:                                      # noqa: BLE001 - reported, not raised
        sys.exit("failed: %s" % exc)
    save_tga(out, dst)
    _say("    wrote      %s  (%.1fs total)" % (dst, time.time() - started))
    _report(os.path.basename(dst), dst, info, out)
    return 0


def run_batch(args):
    src_root = os.path.abspath(os.path.expanduser(args.batch[0]))
    dst_root = os.path.abspath(os.path.expanduser(args.batch[1]))
    if not os.path.isdir(src_root):
        sys.exit("no such directory: %s" % src_root)
    if args.erase:
        sys.exit("--erase is a per-image measurement and only applies to --single")

    jobs = []
    for dirpath, _, names in os.walk(src_root):
        for name in sorted(names):
            stem, ext = os.path.splitext(name)
            if ext.lower() not in IMAGE_EXTS:
                continue
            if stem.endswith(SINGLE_SUFFIX):
                # --single deliberately writes its output beside the source, so a later --batch over
                # the same tree would otherwise re-ingest that output as if it were source art:
                # converting an already-converted plate, and shipping it under a name carrying the
                # suffix. Skipped rather than reported, because it is a normal thing to find.
                continue
            src = os.path.join(dirpath, name)
            rel = os.path.relpath(src, src_root)
            dst = os.path.join(dst_root, os.path.splitext(rel)[0] + ".tga")
            jobs.append((rel, src, dst))
    if not jobs:
        sys.exit("found no images under %s" % src_root)

    stamps = {} if args.force else read_stamps()
    failures, skipped, converted = [], [], 0

    for idx, (rel, src, dst) in enumerate(jobs, 1):
        label = rel.replace("\\", "/")
        if args.dry_run:
            try:
                with Image.open(src) as probe:
                    dims = probe.size
            except Exception as exc:                              # noqa: BLE001 - reported, not raised
                failures.append((label, "unreadable: %s" % exc))
                continue
            need = min(args.size / dims[0], args.size / dims[1])
            print("  %-46s %9s  need %5.2fx  %s"
                  % (label, "%dx%d" % dims, need,
                     "lanczos" if (args.no_ai or need <= AI_MIN_SCALE) else "realesrgan"))
            continue

        want = fingerprint(src, args.size, args.pad, not args.no_ai, "")
        if not args.force and os.path.exists(dst) and stamps.get(dst) == want:
            try:
                with Image.open(dst) as probe:
                    fresh = probe.size == (args.size, args.size)
            except Exception:                                     # noqa: BLE001 - unreadable = rebuild
                fresh = False
            if fresh:
                skipped.append(label)
                continue

        _say("[%*d/%d] %s" % (len(str(len(jobs))), idx, len(jobs), label))
        info = {}
        try:
            out = convert(src, args.size, args.pad, use_ai=not args.no_ai, report=info)
        except Exception as exc:                                  # noqa: BLE001 - reported, not raised
            _say("    FAILED     %s" % exc)
            failures.append((label, str(exc)))
            continue
        save_tga(out, dst)
        stamps[dst] = want
        converted += 1
        _report(label, dst, info, out)

    if not args.dry_run:
        write_stamps(stamps)
        print("\nconverted %d, skipped %d, failed %d" % (converted, len(skipped), len(failures)))
    if skipped:
        # Named, not just counted. "skipped 104 up-to-date" is how the one file you just changed
        # hides from you.
        print("skipped (use --force to reconvert): %s"
              % (", ".join(skipped[:8]) + (" ..." if len(skipped) > 8 else "")))
    if failures:
        print("\n%d FAILED:" % len(failures))
        for name, why in failures:
            print("  %-46s %s" % (name, why))
        return 1
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n")[0],
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="single:  artwork_cleaner.py --single art/Emblem.png\n"
               "batch:   artwork_cleaner.py --batch ~/art media/artwork")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--single", metavar="FILE",
                      help="convert one image; writes FILE%s.tga beside it" % SINGLE_SUFFIX)
    mode.add_argument("--batch", nargs=2, metavar=("SRC_DIR", "DST_DIR"),
                      help="convert every image under SRC_DIR into DST_DIR, mirroring the tree")
    ap.add_argument("--size", type=int, default=SIZE,
                    help="output edge length; must be a power of two (default %d)" % SIZE)
    ap.add_argument("--pad", type=int, default=0, metavar="PX",
                    help="force this much transparent margin (default: auto, only when short)")
    ap.add_argument("--erase", metavar="L,T,R,B",
                    help="blank these source regions first, e.g. a watermark; "
                         "several separated by ';'. --single only")
    ap.add_argument("--no-ai", action="store_true", help="Lanczos only; skip the upscaler")
    ap.add_argument("--force", action="store_true", help="reconvert even if up to date")
    ap.add_argument("--dry-run", action="store_true",
                    help="list what --batch would convert, and write nothing")
    ap.add_argument("--quiet", "-q", action="store_true",
                    help="suppress per-stage progress; only the result lines are printed")
    args = ap.parse_args(argv)

    if args.size & (args.size - 1):
        sys.exit("--size must be a power of two, got %d (WoW cannot load NPOT textures)" % args.size)
    if args.pad < 0:
        sys.exit("--pad must not be negative")

    global _QUIET
    _QUIET = args.quiet

    return run_single(args) if args.single else run_batch(args)


if __name__ == "__main__":
    sys.exit(main())
