#!/usr/bin/env python3
"""v22 photorealism visual-regression check: flags non-photoreal regressions
(flat-shaded sprites, programmer-art placeholders) in new/changed assets.

Checks:
 1. Every PNG in assets/sprites/ traces to a .blend model (basename minus
    frame suffixes) — no orphan programmer art.
 2. Flat-shade heuristic on main sprites: < 24 distinct 15-bit colors AND
    luminance std < 12 among opaque pixels -> flag. (Calibrated: darkest
    real render, boss-7-baron black livery, has 279 colors / std 14.4.)
 3. Placeholder-color scan: exact magenta (255,0,255) / pure green
    (0,255,0) opaque pixels -> flag.
 4. fx/ particle set: exactly the 6 Blender-rendered files, each with
    alpha and a sane opaque area (they are SUPPOSED to be simple bright /
    dark blobs — exempt from the flat-shade heuristic).
 5. No corrupt or degenerate (< 8px) PNGs.
"""
import os
import re
import sys
from PIL import Image

GODOT = os.path.expanduser("~/workspace/1918-godot")
SPR = os.path.join(GODOT, "assets/sprites")
FX = os.path.join(SPR, "fx")
BLEND_DIRS = [
    os.path.expanduser("~/workspace/1918-ace-of-aces/blender/models"),
    os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender/models"),
]
FX_EXPECTED = {"fx-explosion-0.png", "fx-explosion-1.png", "fx-explosion-2.png",
               "fx-flak.png", "fx-muzzle.png", "fx-smoke.png"}

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL: {msg}")


def base(fn):
    b = re.sub(r"\.png$", "", fn)
    b = re.sub(r"-(level|bank-left|bank-right|bank|left|right)$", "", b)
    b = re.sub(r"-\d+$", "", b)
    return b


blends = set()
for d in BLEND_DIRS:
    if os.path.isdir(d):
        for f in os.listdir(d):
            if f.endswith(".blend"):
                blends.add(f[:-6])
print(f"blend models indexed: {len(blends)}")

# 1. traceability --------------------------------------------------------
n_sprites = 0
for fn in sorted(os.listdir(SPR)):
    if not fn.endswith(".png"):
        continue
    n_sprites += 1
    if base(fn) not in blends:
        fail(f"orphan sprite with no .blend source: {fn}")
print(f"ok traceability: {n_sprites} sprites all map to .blend models")

# 2+3+5. per-sprite analysis ----------------------------------------------
flat_flags = 0
for fn in sorted(os.listdir(SPR)):
    if not fn.endswith(".png"):
        continue
    p = os.path.join(SPR, fn)
    try:
        im = Image.open(p).convert("RGBA")
    except Exception as e:
        fail(f"corrupt PNG: {fn} ({e})")
        continue
    if im.size[0] < 8 or im.size[1] < 8:
        fail(f"degenerate tiny sprite: {fn} {im.size}")
        continue
    px = [x for x in im.getdata() if x[3] > 16]
    if not px:
        fail(f"fully transparent sprite: {fn}")
        continue
    # placeholder colors
    bad = sum(1 for x in px if (x[0], x[1], x[2]) in ((255, 0, 255),
                                                      (0, 255, 0)))
    if bad:
        fail(f"placeholder pixels in {fn}: {bad}")
    # flat-shade heuristic
    colors = set((x[0] >> 3, x[1] >> 3, x[2] >> 3) for x in px)
    lums = [0.299 * x[0] + 0.587 * x[1] + 0.114 * x[2] for x in px]
    mean = sum(lums) / len(lums)
    std = (sum((l - mean) ** 2 for l in lums) / len(lums)) ** 0.5
    if len(colors) < 24 and std < 12.0:
        fail(f"flat-shaded (non-photoreal?) sprite: {fn} "
             f"colors={len(colors)} lum_std={std:.1f}")
        flat_flags += 1
if not flat_flags:
    print("ok flat-shade heuristic: no flat sprites among main set")

# 4. fx particle set ------------------------------------------------------
actual_fx = set(f for f in os.listdir(FX) if f.endswith(".png")) \
    if os.path.isdir(FX) else set()
if actual_fx != FX_EXPECTED:
    fail(f"fx/ set mismatch: missing={FX_EXPECTED - actual_fx} "
         f"extra={actual_fx - FX_EXPECTED}")
for fn in sorted(actual_fx):
    im = Image.open(os.path.join(FX, fn)).convert("RGBA")
    px = [x for x in im.getdata() if x[3] > 16]
    if not 500 <= len(px) <= 16000:
        fail(f"fx/{fn}: suspicious opaque area {len(px)}")
    if im.size[0] not in (64, 128):
        fail(f"fx/{fn}: unexpected size {im.size}")
print(f"ok fx particle set: {len(actual_fx)} renders present and sane")

print()
if fails:
    print(f"{len(fails)} FAILURES")
    sys.exit(1)
print("ALL VISUAL CHECKS GREEN")
