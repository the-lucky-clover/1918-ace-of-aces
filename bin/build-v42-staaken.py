#!/usr/bin/env python3
"""v42 — Zeppelin-Staaken R.VI giant heavy bomber plate.

Photographic composite ONLY. Every pixel is cut from the real photographic
Gotha G.IV sprite (assets/sprites/enemy-gotha-level.png), itself rebuilt
from real photographs in v38 — the Gotha is the Staaken's smaller cousin,
same German giant-bomber family, same olive livery, same Iron Crosses.
No code-drawn shapes, no downloaded sprites, no vector art.

What the composite does (all cuts/pastes of photographic pixels):
  1. Upscale the Gotha 2x (512x512 working space).
  2. Cut the Gotha's two wing engine units (nacelle + prop disc, photographic)
     and move them to the nose, side by side — the R.VI's signature:
     four Maybach engines in the nose, two tractor + two pusher props.
     The wing nacelles are erased (alpha only; the fuselage column is kept).
  3. Paste a second prop-disc slice behind each nose nacelle: the pushers.
  4. Crop to the aircraft and resize to 512x300 — the long-span planform
     of the giant (42.2 m span vs 22.1 m length, ratio ~1.9).
  5. Photographic fabric-ribbing luminance overlay (same source + method
     as bin/build-v38-sprites.py: a high-pass crop of the real SPAD wing),
     period grade (slightly darker / warmer than the Gotha), feathered alpha.

Usage: python3 bin/build-v42-staaken.py
Output: assets/sprites/v42/v42-staaken.png (512x300 RGBA)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GOTHA = os.path.join(ROOT, "assets", "sprites", "enemy-gotha-level.png")
SPAD1 = os.path.join(ROOT, "assets", "spad-player.png")
OUTDIR = os.path.join(ROOT, "assets", "sprites", "v42")
OUT = os.path.join(OUTDIR, "v42-staaken.png")

# --- photographic fabric detail (same source + method as build-v38) --------
def build_fabric_detail():
    spad = Image.open(SPAD1).convert("RGB")
    # One 256x256 crop of uniform dark-green lower-wing fabric (ribbing, no
    # camo boundary, no panel, no roundel) — a single tile, never repeated.
    wing = spad.crop((200, 480, 456, 736))
    grey = wing.convert("L")
    blur = grey.filter(ImageFilter.GaussianBlur(3))
    import numpy as np
    g = np.asarray(grey).astype(np.float32)
    b = np.asarray(blur).astype(np.float32)
    detail = np.clip((g - b) * 1.6 + 128, 0, 255).astype(np.uint8)
    return Image.fromarray(detail, mode="L")


def apply_fabric(im, opacity=0.22):
    import numpy as np
    rgba = im.convert("RGBA")
    w, h = rgba.size
    tex = build_fabric_detail().resize((w, h), Image.LANCZOS)
    arr = np.asarray(rgba).astype(np.float32)
    t = np.asarray(tex).astype(np.float32)
    delta = (t - 128.0) * opacity
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c] + delta, 0, 255)
    out = Image.fromarray(arr.astype(np.uint8), mode="RGBA")
    out.putalpha(rgba.split()[3])
    return out


def grade(im, bright=0.94, contrast=1.06, color=0.92, tint=(52, 46, 30), tint_amt=0.06):
    im = ImageEnhance.Brightness(im).enhance(bright)
    im = ImageEnhance.Contrast(im).enhance(contrast)
    im = ImageEnhance.Color(im).enhance(color)
    if tint_amt > 0:
        solid = Image.new("RGB", im.size, tint)
        rgb = Image.blend(im.convert("RGB"), solid, tint_amt)
        out = rgb.convert("RGBA")
        out.putalpha(im.split()[3])
        return out
    return im


def main():
    gotha = Image.open(GOTHA).convert("RGBA")
    print("source Gotha:", gotha.size, gotha.mode)
    # 1. upscale 2x — 512x512 working space.
    #    256-coords x2: fuselage x238-274, nose tip y78, nacelle block
    #    x160-352 y128-176, wing band y172-272, tail y400-432.
    work = gotha.resize((512, 512), Image.LANCZOS)
    src = work.copy()

    # 2. cut the two photographic engine units (nacelle + prop disc).
    left_unit = src.crop((160, 128, 256, 176))   # 96x48
    right_unit = src.crop((256, 128, 352, 176))  # 96x48
    # prop-disc slice: the thin prop bar sits near the top of each unit.
    left_prop = left_unit.crop((0, 6, 96, 22))
    right_prop = right_unit.crop((0, 6, 96, 22))

    # 3. erase the wing engine units (alpha only). Keep the fuselage column.
    mask = Image.new("L", (512, 512), 0)
    d = ImageDraw.Draw(mask)
    d.rectangle([160, 128, 352, 176], fill=255)
    d.rectangle([236, 128, 276, 176], fill=0)  # fuselage column stays
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    alpha = work.split()[3]
    import numpy as np
    a = np.asarray(alpha).astype(np.float32)
    m = np.asarray(mask).astype(np.float32) / 255.0
    work.putalpha(Image.fromarray(np.clip(a * (1.0 - m), 0, 255).astype(np.uint8)))

    # 4. nose cluster: the R.VI's four engines live in the nose, two
    #    tractor + two pusher. Tractor units flank the nose tip; pusher
    #    prop discs sit just behind them.
    work.paste(left_unit, (167, 96), left_unit)
    work.paste(right_unit, (249, 96), right_unit)
    work.paste(left_prop, (167, 152), left_prop)
    work.paste(right_prop, (249, 152), right_prop)

    # 5. crop to the aircraft, resize to the giant's long-span planform.
    bbox = work.split()[3].getbbox()
    print("content bbox:", bbox)
    work = work.crop(bbox)
    work = work.resize((512, 300), Image.LANCZOS)

    # 6. photographic fabric ribbing + period grade.
    work = apply_fabric(work, opacity=0.22)
    work = grade(work)

    # 7. feather the alpha edge.
    r, g, b, a = work.split()
    a = a.filter(ImageFilter.GaussianBlur(1.2))
    work = Image.merge("RGBA", (r, g, b, a))

    os.makedirs(OUTDIR, exist_ok=True)
    work.save(OUT)
    print("saved:", OUT, work.size, work.mode)

    # --- verification ------------------------------------------------------
    arr = np.asarray(work).astype(np.float32)
    al = arr[:, :, 3]
    vis = al > 10
    n_vis = int(vis.sum())
    lum = (0.299 * arr[:, :, 0] + 0.587 * arr[:, :, 1] + 0.114 * arr[:, :, 2])[vis]
    mean_lum = float(lum.mean()) if n_vis else 0.0
    sd_lum = float(lum.std()) if n_vis else 0.0
    green = int(((arr[:, :, 1] > 70) & (arr[:, :, 1] > arr[:, :, 0]) &
                 (arr[:, :, 1] - arr[:, :, 2] > 5) & vis).sum())
    dark = int(((arr[:, :, 0] < 40) & (arr[:, :, 1] < 40) &
                (arr[:, :, 2] < 40) & vis).sum())
    corners = [int(al[0, 0]), int(al[0, -1]), int(al[-1, 0]), int(al[-1, -1])]
    centre = int(al[150, 256])
    print(f"visible px: {n_vis}, mean lum: {mean_lum:.1f}, sd: {sd_lum:.1f}, "
          f"green px: {green}, dark px (Iron Crosses): {dark}, "
          f"corners: {corners}, centre alpha: {centre}")
    bad = []
    if n_vis < 20000:
        bad.append("too few visible pixels")
    if sd_lum <= 5:
        bad.append("flat fill (no photographic variation)")
    if green < 500:
        bad.append("no olive camo green")
    if dark < 100:
        bad.append("no dark Iron Cross pixels")
    if max(corners) > 8:
        bad.append("corners not transparent")
    if centre < 80:
        bad.append("centre not visible")
    if bad:
        print("VERIFICATION FAILED:")
        for w in bad:
            print("  -", w)
        sys.exit(1)
    print("v42 Staaken plate VERIFIED: photographic composite OK")


if __name__ == "__main__":
    main()
