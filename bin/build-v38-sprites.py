#!/usr/bin/env python3
"""bin/build-v38-sprites.py — v38 aircraft spritesheet iteration for 1918.

Priority 3: iterate the aircraft spritesheets + fix the dead-ahead chateau.

WHAT WAS WRONG (audited 2026-11-07, pixel-counted):
- 44 aircraft sprite files draw as a BLACK BOX in-game: their background is
  opaque black (alpha 255, RGB ~0) instead of transparent. Affected: all 4
  files of enemy-clii, enemy-dri, enemy-dva, enemy-dvii, enemy-eiii,
  enemy-gotha, enemy-junkers, enemy-pfalz, enemy-rumpler, enemy-taube
  (40 files), plus player-spad-bank-left/right and
  player-spad-2-bank-left/right (4 files). The German aircraft and both
  players' banking poses render with a black rectangle around them.
- The 1P SPAD (player-spad-level/bank/damaged) is a flat grey-green
  vector-looking silhouette with no camo, no fabric, no roundel detail —
  while the user's photorealistic SPAD photo (assets/spad-player.png) sits
  in the repo unused by the in-game sprite.
- The 2P bank sprites were rotated without preserving transparency, so the
  rotated photo sits on an opaque black field.
- The v34 chateau plate is a tight, darkened crop of ruined foundations
  that reads as blocky toy logs ("Lincoln Logs").

WHAT THIS SCRIPT DOES (photographic material only, no generated pixels):
- Rebuilds the 1P SPAD banked set from the photorealistic spad-player.png
  (level / bank-left / bank-right / damaged), 256px, transparency kept.
- Rebuilds the 2P SPAD banked set from spad-player-2.png the same way
  (fixes the opaque-black bank backgrounds, shrinks 1680px files to 256px).
- Fixes the black-box defect in every enemy/boss sprite: flood-fills the
  opaque-black background to transparent (border-connected near-black only,
  so interior black details like iron crosses and cockpits are kept).
- Applies a photographic fabric-ribbing luminance detail overlay (cut from
  the SPAD photo's wing) to every enemy/boss sprite, masked by its alpha —
  adds photographic grain without changing livery or silhouette.
- Boosts the Ghost boss (boss-6-ghost) so the red reads instead of a faint
  grey smear; it stays spectral, just visible.
- Builds a new photographic estate plate assets/sprites/v38/v38-chateau.png
  from the aerial photo: a wide, bright, natural-graded crop of the largest
  village building with its grounds, roads and gardens — an estate, not
  bare foundation walls, and pale stone, not dark logs.

Originals are backed up to assets/sprites/.v38-backup/ before any overwrite.
Re-running the script reproduces the same outputs.
Usage: python3 bin/build-v38-sprites.py
"""
import os
import shutil
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
BACKUP = os.path.join(SPR, ".v38-backup")
V38 = os.path.join(SPR, "v38")
os.makedirs(BACKUP, exist_ok=True)
os.makedirs(V38, exist_ok=True)

AERIAL = os.path.join(ROOT, "assets", "terrain-aerial.jpg")
SPAD1 = os.path.join(ROOT, "assets", "spad-player.png")
SPAD2 = os.path.join(ROOT, "assets", "spad-player-2.png")
SMOKEDARK = os.path.join(SPR, "v36", "v36-smokedark.png")
EMBER = os.path.join(SPR, "v36", "v36-ember.png")
FIREGLOW = os.path.join(SPR, "v36", "v36-fireglow.png")

photo = Image.open(AERIAL).convert("RGB")
PW, PH = photo.size
print("aerial photo:", photo.size)

# ------------------------------------------------------------------ helpers
def crop_photo(box):
    x0, y0, x1, y1 = box
    x0 = max(0, min(PW - 2, x0)); y0 = max(0, min(PH - 2, y0))
    x1 = max(x0 + 2, min(PW, x1)); y1 = max(y0 + 2, min(PH, y1))
    return photo.crop((x0, y0, x1, y1))

def soft_ellipse_mask(size, feather=8):
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([0, 0, w, h], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return m

def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    """Grade RGB only; the alpha channel is preserved exactly (a tint or a
    brightness change must never turn a transparent background opaque)."""
    has_alpha = img.mode == "RGBA"
    alpha = img.split()[3] if has_alpha else None
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Color(rgb).enhance(color)
    if tint is not None and tint_amt > 0:
        solid = Image.new("RGB", rgb.size, tint)
        rgb = Image.blend(rgb, solid, tint_amt)
    out = rgb.convert("RGBA")
    if alpha is not None:
        out.putalpha(alpha)
    return out

def save(img, path):
    img.save(path, "PNG")
    print("wrote", os.path.relpath(path, ROOT), img.size, img.mode)
    return path

def backup(path):
    """Copy the original to .v38-backup/ before the first overwrite."""
    name = os.path.basename(path)
    dst = os.path.join(BACKUP, name)
    if not os.path.exists(dst) and os.path.exists(path):
        shutil.copy2(path, dst)
    return dst

def opaque_black_frac(im):
    """Fraction of pixels that are opaque AND near-black (the black-box defect)."""
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    bad = 0
    total = w * h
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 200 and r < 10 and g < 10 and b < 10:
                bad += 1
    return bad / total

def visible_px(im):
    rgba = im.convert("RGBA")
    px = rgba.load()
    w, h = rgba.size
    n = 0
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 10:
                n += 1
    return n

# ------------------------------------------------- photographic fabric detail
# High-frequency luminance detail (fabric ribbing + grain) cut from the SPAD
# photo's upper wing. Grayscale, centred on 128, so it can be blended as a
# luminance-only overlay without shifting hue.
def build_fabric_detail():
    spad = Image.open(SPAD1).convert("RGB")
    # One 256x256 crop of uniform dark-green lower-wing fabric (ribbing, no
    # camo boundary, no panel, no roundel) — a single tile, never repeated,
    # so there are no tiling seams. High-pass detail only.
    wing = spad.crop((200, 480, 456, 736))
    grey = wing.convert("L")
    blur = grey.filter(ImageFilter.GaussianBlur(3))
    # detail = grey - blur + 128 (high-pass, centred), gentle amplification
    import numpy as np
    g = np.asarray(grey).astype(np.float32)
    b = np.asarray(blur).astype(np.float32)
    detail = np.clip((g - b) * 1.6 + 128, 0, 255).astype(np.uint8)
    return Image.fromarray(detail, mode="L")

FABRIC = build_fabric_detail()
print("fabric detail texture built:", FABRIC.size)

def apply_fabric(im, opacity=0.25):
    """Add photographic fabric luminance detail onto a sprite, masked by its
    own alpha. Additive (not multiplicative) so the grain reads on dark
    livery too. The detail is a single 256x256 photographic crop, used
    whole (never tiled), so there are no seams. Hue/livery untouched."""
    import numpy as np
    rgba = im.convert("RGBA")
    w, h = rgba.size
    # single photographic detail crop, resized to the sprite (no tiling)
    tex = FABRIC.resize((w, h), Image.LANCZOS)
    arr = np.asarray(rgba).astype(np.float32)
    t = np.asarray(tex).astype(np.float32)
    # additive luminance detail: brightens the ribs, darkens the weave
    delta = (t - 128.0) * opacity
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c] + delta, 0, 255)
    out = Image.fromarray(arr.astype(np.uint8), mode="RGBA")
    # keep the original alpha exactly
    out.putalpha(rgba.split()[3])
    return out

def flood_fill_background_to_transparent(im, thresh=16):
    """Turn the border-connected near-black background transparent.
    Only pixels connected to the image border through near-black pixels are
    cleared, so interior black details (iron crosses, cockpit) are kept.
    Returns (image, cleared_fraction)."""
    import numpy as np
    rgba = im.convert("RGBA")
    w, h = rgba.size
    arr = np.asarray(rgba)
    # near-black mask (all channels < thresh)
    near = (arr[:, :, 0] < thresh) & (arr[:, :, 1] < thresh) & (arr[:, :, 2] < thresh)
    # flood fill from the border through near-black pixels
    from collections import deque
    seen = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if near[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if near[y, x] and not seen[y, x]:
                seen[y, x] = True; q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and near[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((nx, ny))
    # build the new alpha: 0 where flood-filled, else original alpha
    alpha = arr[:, :, 3].copy()
    cleared = seen & (alpha > 10)
    alpha[seen] = 0
    # feather the alpha edge by 1px so the cut is not hard
    am = Image.fromarray(alpha, mode="L").filter(ImageFilter.GaussianBlur(0.8))
    out = rgba.copy()
    out.putalpha(am)
    return out, float(cleared.sum()) / (w * h)

# ------------------------------------------------------- player SPAD rebuild
def fit_into_square(im, size=256):
    """Resize a photo so it fits in a size x size transparent canvas,
    preserving aspect, centred. The game draws the sprite at dw x dh from
    its aspect, so a square canvas keeps the existing draw math."""
    w, h = im.size
    scale = size / max(w, h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    small = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(small, ((size - nw) // 2, (size - nh) // 2), small)
    return canvas

def build_spad_set(src_path, prefix):
    """Rebuild one player's 4 banked sprites from its photorealistic photo.
    level: the photo itself. bank-left/right: rotated +/-14 deg (matching the
    old bank pose), transparency preserved. damaged: darkened/scorched photo
    with photographic smoke puffs + ember glints composited."""
    src = Image.open(src_path).convert("RGBA")
    print(prefix, "source:", src.size, "visible px:", visible_px(src))
    # level
    level = fit_into_square(src, 256)
    backup(os.path.join(SPR, prefix + "-level.png"))
    save(level, os.path.join(SPR, prefix + "-level.png"))
    # bank-left: rotate counter-clockwise (+14), bank-right: clockwise (-14)
    for name, angle in (("bank-left", 14), ("bank-right", -14)):
        rot = src.rotate(angle, resample=Image.BICUBIC, expand=True)
        out = fit_into_square(rot, 256)
        backup(os.path.join(SPR, prefix + "-" + name + ".png"))
        save(out, os.path.join(SPR, prefix + "-" + name + ".png"))
    # damaged: scorched photo + photographic smoke + embers
    dmg = level.copy()
    dmg = grade(dmg, bright=0.55, contrast=1.15, color=0.7,
                tint=(30, 22, 14), tint_amt=0.25)
    smoke = Image.open(SMOKEDARK).convert("RGBA").resize((90, 90), Image.LANCZOS)
    ember = Image.open(EMBER).convert("RGBA").resize((36, 36), Image.LANCZOS)
    glow = Image.open(FIREGLOW).convert("RGBA").resize((70, 70), Image.LANCZOS)
    # smoke puffs over the fuselage / wings, embers as hot glints
    for (cx, cy, s, a) in ((128, 110, 90, 200), (96, 150, 70, 170), (160, 140, 70, 170)):
        puff = smoke.copy()
        puff.putalpha(puff.split()[3].point(lambda v: int(v * a / 255)))
        dmg.alpha_composite(puff, (cx - s // 2, cy - s // 2))
    for (cx, cy) in ((118, 96), (140, 128), (108, 150), (152, 168)):
        e = ember.copy()
        dmg.alpha_composite(e, (cx - 18, cy - 18))
    g = glow.copy()
    g.putalpha(g.split()[3].point(lambda v: int(v * 0.45)))
    dmg.alpha_composite(g, (128 - 35, 118 - 35))
    backup(os.path.join(SPR, prefix + "-damaged.png"))
    save(dmg, os.path.join(SPR, prefix + "-damaged.png"))
    return {"level": level}

build_spad_set(SPAD1, "player-spad")
build_spad_set(SPAD2, "player-spad-2")

# ------------------------------------------------- enemy / boss fix + texture
ENEMY_PREFIXES = [
    "enemy-triplane", "enemy-scout", "enemy-fighter", "enemy-bomber",
    "enemy-dri", "enemy-dvii", "enemy-dva", "enemy-eiii", "enemy-pfalz",
    "enemy-gotha", "enemy-clii", "enemy-rumpler", "enemy-junkers",
    "enemy-taube", "enemy-balloon",
    "boss-1-red", "boss-2-checker", "boss-3-stripes", "boss-4-tiger",
    "boss-5-jester", "boss-6-ghost",
]
SUFFIXES = ["-bank-left.png", "-level.png", "-bank-right.png", "-damaged.png"]
fixed = 0
textured = 0
for prefix in ENEMY_PREFIXES:
    for suf in SUFFIXES:
        name = prefix + suf
        path = os.path.join(SPR, name)
        if not os.path.exists(path) and not os.path.exists(os.path.join(BACKUP, name)):
            continue
        # Always rebuild from the pristine original in .v38-backup/ when it
        # exists, so re-running the script is idempotent (no double texture).
        src_path = os.path.join(BACKUP, name) if os.path.exists(os.path.join(BACKUP, name)) else path
        im = Image.open(src_path)
        before_black = opaque_black_frac(im)
        backup(path)
        # 1) fix the black-box defect: flood-fill background to transparent
        if before_black > 0.05:
            im, cleared = flood_fill_background_to_transparent(im)
            fixed += 1
            print(f"  {name}: black-box {before_black:.0%} -> cleared {cleared:.0%}")
        # 2) photographic fabric detail overlay (luminance only)
        im = apply_fabric(im, opacity=0.25)
        textured += 1
        # 3) Ghost boss: boost so the red reads (stays spectral, just visible)
        if prefix == "boss-6-ghost":
            im = grade(im, bright=1.35, contrast=1.25, color=1.4,
                       tint=(200, 40, 30), tint_amt=0.18)
            print(f"  {name}: ghost boosted (bright 1.35, red tint)")
        save(im.convert("RGBA"), path)
print(f"enemy/boss: {fixed} black-box files fixed, {textured} files textured")

# ------------------------------------------------------------- chateau plate
# A wide, bright, natural-graded crop of the largest village building with
# its grounds, roads and gardens — a country estate, not bare foundation
# walls, and pale stone, not dark logs. Soft elliptical feathered mask.
ch = crop_photo((380, 1060, 800, 1375)).resize((256, 192), Image.LANCZOS)
ch = grade(ch, bright=1.08, contrast=1.06, color=0.95)
ch = ch.convert("RGBA")
ch.putalpha(soft_ellipse_mask((256, 192), feather=8))
save(ch, os.path.join(V38, "v38-chateau.png"))
print("chateau plate: crop (380,1060,800,1375), bright 1.08, no burnt tint")

# --------------------------------------------------------------- verification
print("\n--- v38 verification ---")
bad = []
# 1) no output sprite may keep the black-box defect
for prefix in ["player-spad", "player-spad-2"] + ENEMY_PREFIXES:
    for suf in SUFFIXES:
        path = os.path.join(SPR, prefix + suf)
        if not os.path.exists(path):
            continue
        im = Image.open(path)
        frac = opaque_black_frac(im)
        if frac > 0.05:
            bad.append((prefix + suf, f"opaque-black {frac:.0%}"))
        if im.mode != "RGBA":
            bad.append((prefix + suf, f"mode {im.mode} (want RGBA)"))
# 2) chateau plate: RGBA, feathered corners, bright (pale stone, not dark logs)
ch_im = Image.open(os.path.join(V38, "v38-chateau.png"))
if ch_im.mode != "RGBA":
    bad.append(("v38-chateau.png", "mode " + ch_im.mode))
import numpy as np
ca = np.asarray(ch_im.convert("RGBA"))
corner_a = max(ca[0, 0, 3], ca[0, -1, 3], ca[-1, 0, 3], ca[-1, -1, 3])
centre_a = ca[96, 128, 3]
if corner_a > 8 or centre_a < 80:
    bad.append(("v38-chateau.png", f"feather corners={corner_a} centre={centre_a}"))
mean_lum = float(np.asarray(ch_im.convert("L")).mean())
print(f"chateau mean luminance: {mean_lum:.1f} (old dark plate was ~62; want > 80)")
if mean_lum < 80:
    bad.append(("v38-chateau.png", f"too dark, mean lum {mean_lum:.1f}"))
# 3) player SPAD level must carry the photo's camo/roundel colours
spad = Image.open(os.path.join(SPR, "player-spad-level.png")).convert("RGBA")
sa = np.asarray(spad)
# count strongly red (roundel) and strongly green (camo) pixels among opaque
opaque = sa[:, :, 3] > 200
r, g, b = sa[:, :, 0].astype(int), sa[:, :, 1].astype(int), sa[:, :, 2].astype(int)
red_px = ((r > 150) & (r - g > 60) & (r - b > 40) & opaque).sum()
green_px = ((g > 80) & (g > r) & (g - b > 10) & opaque).sum()
print(f"player SPAD: red (roundel) px={red_px}, green (camo) px={green_px}, visible px={visible_px(spad)}")
if red_px < 50 or green_px < 200:
    bad.append(("player-spad-level.png", f"photo colours missing (red {red_px}, green {green_px})"))
# 4) fabric detail actually added (high-frequency energy up vs backup)
def hf_energy(im):
    arr = np.asarray(im.convert("L")).astype(np.float32)
    blur = np.asarray(Image.fromarray(arr.astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))).astype(np.float32)
    return float(np.abs(arr - blur).mean())
for name in ["enemy-dvii-level.png", "enemy-triplane-level.png", "boss-1-red-level.png"]:
    new_e = hf_energy(Image.open(os.path.join(SPR, name)))
    old_e = hf_energy(Image.open(os.path.join(BACKUP, name)))
    print(f"{name}: high-freq energy {old_e:.2f} -> {new_e:.2f}")
    if new_e <= old_e:
        bad.append((name, "fabric detail did not increase"))
print()
if bad:
    print("VERIFICATION FAILED:")
    for n, w in bad:
        print("  -", n, "—", w)
    raise SystemExit(1)
print("v38 sprite build VERIFIED: no black-box defect, photographic plates OK")
print("backup of originals in:", BACKUP)
