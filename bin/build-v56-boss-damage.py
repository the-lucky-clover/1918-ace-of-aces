#!/usr/bin/env python3
"""bin/build-v56-boss-damage.py — v56 battle-damaged boss plates for 1918.

No boss carries an HP bar any more — the boss's condition is read off her own
airframe. So every boss gets a battle-damaged sprite sheet (a photographic
scorch/char/smoke treatment of her own clean plate) that the game swaps in
once she is hurt, plus a burning state (the existing photographic fire sheet
and a trailing smoke column).

Photographic material ONLY — no generated pixels, no vector art, no
downloaded sprites. Every plate is a grade / blur / mask of a real
photograph already on disk:
- assets/sprites/boss-{1..6}-{livery}-level.png (the boss's own clean plate)
- assets/sprites/v42/v42-staaken.png (the real Staaken plate)
- assets/sprites/v48/v48-zeppelin.png (the real L-33 hull plate)
- assets/terrain-aerial.jpg (the one true battlefield aerial — char texture
  is the DARKEST crater patch of it, so the scorch is real burnt ground)
- assets/sprites/v36/v36-smokedark.png (photographic smoke for the stains)

The only PIL-drawn shapes are alpha MASKS (soft blobs and streaks) that
photographic texture is composited through — the same rule as the v34/v48
builds. The alpha silhouette of every source is preserved exactly
(putalpha restores the source alpha), so hitboxes and geometry never move.

Outputs:
- assets/sprites/boss-{1..6}-{livery}-damaged.png (256x256, one per ace —
  picked up automatically by loadBankedSprites, exactly like the enemy
  -damaged.png convention)
- assets/sprites/v56/staaken-damaged.png (512x300)
- assets/sprites/v56/zeppelin-damaged.png (440x150)

Re-running the script reproduces the same outputs (fixed seeds).
Usage: python3 bin/build-v56-boss-damage.py
"""
import os
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
V56 = os.path.join(SPR, "v56")
os.makedirs(V56, exist_ok=True)

AERIAL = os.path.join(ROOT, "assets", "terrain-aerial.jpg")
SMOKE = os.path.join(SPR, "v36", "v36-smokedark.png")
STAAKEN = os.path.join(SPR, "v42", "v42-staaken.png")
ZEPPELIN = os.path.join(SPR, "v48", "v48-zeppelin.png")

BOSSES = [
    ("boss-1-red", "red"),
    ("boss-2-checker", "checker"),
    ("boss-3-stripes", "stripes"),
    ("boss-4-tiger", "tiger"),
    ("boss-5-jester", "jester"),
    ("boss-6-ghost", "ghost"),
]

photo = Image.open(AERIAL).convert("RGB")
PW, PH = photo.size
print("aerial:", photo.size)


def darkest_patch(size=96, stride=32):
    """The darkest square window of the aerial — real burnt crater ground."""
    arr = np.asarray(photo.convert("L"), dtype=np.float32)
    best = None
    best_val = 1e9
    for y0 in range(0, PH - size + 1, stride):
        for x0 in range(0, PW - size + 1, stride):
            val = float(arr[y0:y0 + size, x0:x0 + size].mean())
            if val < best_val:
                best_val = val
                best = (x0, y0)
    x0, y0 = best
    print("darkest aerial patch at", best, "mean luminance %.1f" % best_val)
    return photo.crop((x0, y0, x0 + size, y0 + size))


DARK = darkest_patch()


def grade(img, bright=1.0, contrast=1.0, color=1.0):
    img = ImageEnhance.Brightness(img).enhance(bright)
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(color)
    return img


def char_texture(size, seed):
    """Charred-fabric texture: darkest crater ground, resized, blurred, dark."""
    rnd = random.Random(seed)
    tex = DARK.resize(size, Image.LANCZOS)
    tex = tex.filter(ImageFilter.GaussianBlur(max(6, min(size) // 20)))
    tex = grade(tex, bright=0.52 + rnd.random() * 0.06, contrast=1.18, color=0.5)
    return tex.convert("RGBA")


def airframe_points(alpha, n, rnd):
    """n random points on the airframe (alpha > 128)."""
    arr = np.asarray(alpha)
    ys, xs = np.where(arr > 128)
    if len(xs) == 0:
        return []
    idx = [rnd.randrange(len(xs)) for _ in range(n)]
    return [(int(xs[i]), int(ys[i])) for i in idx]


def scorch_mask(size, alpha, seed):
    """Soft scorch blobs + trailing streaks, as an L mask (0-255)."""
    w, h = size
    rnd = random.Random(seed)
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    pts = airframe_points(alpha, 7, rnd)
    for (x, y) in pts:
        rx = int(w * rnd.uniform(0.09, 0.22))
        ry = int(h * rnd.uniform(0.07, 0.18))
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=int(rnd.uniform(120, 220)))
    # smoke streaks trailing toward the tail (down-screen, the direction of
    # flight is up, so damage streaks run back along the airframe)
    for (x, y) in pts[:3]:
        length = int(h * rnd.uniform(0.25, 0.55))
        drift = int(w * rnd.uniform(-0.06, 0.06))
        d.line([x, y, x + drift, min(h - 2, y + length)],
               fill=int(rnd.uniform(90, 160)), width=int(w * rnd.uniform(0.03, 0.07)))
    mask = mask.filter(ImageFilter.GaussianBlur(max(6, min(size) // 22)))
    return mask


def smoke_streak_mask(size, alpha, seed):
    """Narrow vertical smoke stains."""
    w, h = size
    rnd = random.Random(seed + 777)
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    pts = airframe_points(alpha, 3, rnd)
    for (x, y) in pts:
        length = int(h * rnd.uniform(0.3, 0.6))
        d.line([x, y, x + int(w * rnd.uniform(-0.04, 0.04)), min(h - 2, y + length)],
               fill=int(rnd.uniform(100, 170)), width=int(w * rnd.uniform(0.02, 0.05)))
    return mask.filter(ImageFilter.GaussianBlur(max(5, min(size) // 28)))


def crater_dots(src, alpha, seed, n=5):
    """Small real crater crops pasted as scorch craters on the fabric."""
    w, h = src.size
    rnd = random.Random(seed + 31337)
    pts = airframe_points(alpha, n, rnd)
    layer = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for (x, y) in pts:
        r = int(min(w, h) * rnd.uniform(0.03, 0.06))
        crop = DARK.resize((r * 2, r * 2), Image.LANCZOS)
        crop = grade(crop, bright=0.4, contrast=1.25, color=0.45).convert("RGBA")
        hole = Image.new("L", (r * 2, r * 2), 0)
        hd = ImageDraw.Draw(hole)
        hd.ellipse([2, 2, r * 2 - 2, r * 2 - 2], fill=int(rnd.uniform(110, 170)))
        hole = hole.filter(ImageFilter.GaussianBlur(2))
        layer.paste(crop, (x - r, y - r), hole)
    return layer


def build_damaged(src_path, out_path, seed):
    src = Image.open(src_path).convert("RGBA")
    w, h = src.size
    alpha = src.split()[3]
    # battle wear: grade the clean plate a touch darker and duller first
    base = grade(src.convert("RGB"), bright=0.85, contrast=1.04, color=0.82).convert("RGBA")
    base.putalpha(alpha)
    # charred scorch, composited through the soft mask, airframe only
    char = char_texture((w, h), seed)
    smask = scorch_mask((w, h), alpha, seed)
    char_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    char_layer.paste(char, (0, 0), smask.point(lambda v: int(v * 0.70)))
    out = Image.alpha_composite(base, char_layer)
    # photographic smoke stains
    smoke = Image.open(SMOKE).convert("RGBA").resize((w, h), Image.LANCZOS)
    stmask = smoke_streak_mask((w, h), alpha, seed)
    smoke_layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    smoke_layer.paste(smoke, (0, 0), stmask.point(lambda v: int(v * 0.45)))
    out = Image.alpha_composite(out, smoke_layer)
    # real crater dots
    out = Image.alpha_composite(out, crater_dots(src, alpha, seed))
    # silhouette is sacred: restore the source alpha exactly
    out.putalpha(alpha)
    # never pure opaque black (the black-box defect): lift any (0,0,0,255)
    arr = np.array(out)  # writable copy (asarray may be read-only)
    black = (arr[:, :, 0] < 8) & (arr[:, :, 1] < 8) & (arr[:, :, 2] < 8) & (arr[:, :, 3] == 255)
    if black.any():
        arr[black] = (10, 9, 8, 255)
        out = Image.fromarray(arr, "RGBA")
    out.save(out_path, "PNG")
    return out, src


def verify(out, src, name):
    a = np.asarray(out).astype(np.float32)
    b = np.asarray(src).astype(np.float32)
    opaque = b[:, :, 3] > 0
    diff = float(np.abs(a[:, :, :3] - b[:, :, :3])[opaque].mean()) if opaque.any() else 0.0
    black = float((((a[:, :, 0] < 8) & (a[:, :, 1] < 8) & (a[:, :, 2] < 8) & (a[:, :, 3] == 255)).mean()) * 100)
    same_alpha = bool((a[:, :, 3] == b[:, :, 3]).all())
    print("  %-28s %s airframe-mean-abs-diff %.2f  opaque-black %.2f%%  alpha-identical %s"
          % (name, out.size, diff, black, same_alpha))
    assert diff > 8.0, name + ": damaged plate barely differs from clean"
    assert black == 0.0, name + ": opaque black present"
    assert same_alpha, name + ": silhouette moved"
    return True


def main():
    for i, (prefix, _livery) in enumerate(BOSSES):
        src_path = os.path.join(SPR, prefix + "-level.png")
        out_path = os.path.join(SPR, prefix + "-damaged.png")
        out, src = build_damaged(src_path, out_path, seed=5600 + i * 17)
        print("wrote", os.path.basename(out_path), out.size, out.mode)
        verify(out, src, prefix + "-damaged")
    out, src = build_damaged(STAAKEN, os.path.join(V56, "staaken-damaged.png"), seed=5611)
    print("wrote staaken-damaged.png", out.size, out.mode)
    verify(out, src, "staaken-damaged")
    out, src = build_damaged(ZEPPELIN, os.path.join(V56, "zeppelin-damaged.png"), seed=5623)
    print("wrote zeppelin-damaged.png", out.size, out.mode)
    verify(out, src, "zeppelin-damaged")
    print("v56 boss damage plates done: 6 ace sheets + staaken + zeppelin")


if __name__ == "__main__":
    main()
