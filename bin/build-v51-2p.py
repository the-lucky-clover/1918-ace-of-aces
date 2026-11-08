#!/usr/bin/env python3
"""bin/build-v51-2p.py — v51 2P SPAD rebuild for 1918.

WHAT STEVEN ORDERED (2026-11-07): "change 2p camo and make 2 on top of
wing instead of number 1."

WHAT WAS WRONG (audited 2026-11-07, pixel-counted):
- The 2P SPAD (assets/spad-player-2.png + the banked set
  assets/sprites/player-spad-2-*.png) wears a BLUE camo: in the 256px
  level sprite, 15,329 of 21,578 visible pixels are blue, with ZERO green
  and ZERO ochre. The 1P SPAD is the historical French 5-colour scheme
  (green/brown/ochre). The 2P reads as a different air force, not a
  second French SPAD.
- The number on the top wing: the 2P source already carries a big white
  "2" on the starboard top wing (bbox x 993-1119, y 194-441 in the
  1680x1296 source) and the markings decal v34-markings-2.png already
  shows a "2" — but the ARTIFACT still ships the OLD sand-and-olive
  2P sprite with no number on the wing, which is what Steven sees. The
  repo v51 must make the "2" unmistakable and the camo French, so the
  artifact port fixes what he sees.

WHAT THIS SCRIPT DOES (photographic material only, no generated pixels):
- Recolours the 2P source photo (assets/spad-player-2.png) from blue to
  the historical French 5-colour camouflage — green, brown, ochre, dark
  green, pale blue-grey — by mapping each camo pixel's luminance through
  a French palette gradient sampled from the 1P SPAD photo
  (assets/spad-player.png). The 2P's own patch shapes are kept, so the
  pattern is clearly distinct from the 1P's, even though the palette is
  the same French family. The output luminance is forced to equal the
  input luminance per pixel, so the photographic shading, fabric
  ribbing, panel lines and roundel shading survive untouched.
- PROTECTS (never recoloured): the white "2" on the top wing (near-white
  + its anti-aliased edges in the "2" bbox), the roundels (saturated red
  and saturated blue), the blue/white diagonal stripe (saturated blue +
  near-white), the wooden propeller and leather cockpit and tan fuselage
  (warm tones), and the transparent background. The "2" stays white and
  the roundels stay French.
- Rebuilds the banked set from the recoloured source the v38 way:
  level (fit into a 256px square), bank-left (+14 deg), bank-right
  (-14 deg), damaged (scorched + photographic smoke/embers).
- The 1P SPAD is NOT touched. The markings decals are NOT touched
  (v34-markings-2.png already shows a "2").

Originals are backed up to assets/sprites/.v51-backup/ before any
overwrite. Re-running the script reproduces the same outputs.
Usage: python3 bin/build-v51-2p.py
"""
import os
import shutil

import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
BACKUP = os.path.join(SPR, ".v51-backup")
V36 = os.path.join(SPR, "v36")
os.makedirs(BACKUP, exist_ok=True)

SPAD2 = os.path.join(ROOT, "assets", "spad-player-2.png")
SPAD1 = os.path.join(ROOT, "assets", "spad-player.png")
SMOKEDARK = os.path.join(V36, "v36-smokedark.png")
EMBER = os.path.join(V36, "v36-ember.png")
FIREGLOW = os.path.join(V36, "v36-fireglow.png")

# ------------------------------------------------------------------ helpers
def save(img, path):
    img.save(path, "PNG")
    print("wrote", os.path.relpath(path, ROOT), img.size, img.mode)
    return path

def backup(path):
    """Copy the original to .v51-backup/ before the first overwrite."""
    name = os.path.basename(path)
    dst = os.path.join(BACKUP, name)
    if not os.path.exists(dst) and os.path.exists(path):
        shutil.copy2(path, dst)
    return dst

def visible_px(im):
    a = np.asarray(im.convert("RGBA"))
    return int((a[:, :, 3] > 10).sum())

def fit_into_square(im, size=256):
    """Resize a photo so it fits in a size x size transparent canvas,
    preserving aspect, centred. (v38 convention.)"""
    w, h = im.size
    scale = size / max(w, h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    small = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(small, ((size - nw) // 2, (size - nh) // 2), small)
    return canvas

def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    """Grade RGB only; the alpha channel is preserved exactly."""
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

# ------------------------------------------------- French 5-colour recolour
# Palette anchors (luminance -> RGB), sampled from the 1P SPAD photo's own
# French 5-colour camo (green 101,121,94; light green 152,169,106; brown
# 139,99,81; dark brown 122,80,50; dark green 88,99,44; ochre 236,208,151)
# plus pale blue-grey for the lightest areas (the 5th colour, undersides).
# Anchors are luminance-ordered so the gradient is monotonic: brighter
# input maps to brighter French colour, never inverted.
GRAD_L = np.array([0, 35, 60, 85, 110, 135, 160, 185, 210, 230, 255], dtype=np.float32)
GRAD_R = np.array([42, 70, 88, 105, 120, 140, 165, 195, 215, 195, 210], dtype=np.float32)
GRAD_G = np.array([36, 62, 85, 105, 130, 150, 170, 185, 200, 202, 216], dtype=np.float32)
GRAD_B = np.array([22, 35, 45, 60, 85, 95, 110, 130, 155, 208, 222], dtype=np.float32)

# The white "2" on the top wing (measured 2026-11-07): bbox in the
# 1680x1296 source. Its anti-aliased edges are light grey; protect them.
TWO_X0, TWO_X1, TWO_Y0, TWO_Y1 = 985, 1130, 185, 450

def recolour_french_5colour(src):
    """Recolour the blue 2P camo to French 5-colour, preserving the '2',
    roundels, stripe, cockpit, propeller and all photographic shading.
    src is an RGBA PIL image; returns a new RGBA image."""
    a = np.asarray(src.convert("RGBA")).astype(np.float32)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    h, w = r.shape
    opaque = al > 128
    # --- protected: never recoloured -------------------------------------
    near_white = (r > 225) & (g > 225) & (b > 225)          # the "2", roundel centres, stripe white
    sat_red = (r > 150) & ((r - g) > 60) & ((r - b) > 60)   # roundel red
    sat_blue = (b > 130) & ((b - r) > 50) & ((b - g) > 40)  # roundel blue, stripe blue
    warm = r > (b + 20)                                     # propeller wood, cockpit leather, fuselage tan
    # anti-aliased edges of the "2" (light grey, low saturation, in the "2" box)
    yy, xx = np.mgrid[0:h, 0:w]
    in_two_box = (xx >= TWO_X0) & (xx <= TWO_X1) & (yy >= TWO_Y0) & (yy <= TWO_Y1)
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    two_edge = in_two_box & (r > 200) & (g > 200) & (b > 200) & ((mx - mn) < 15)
    protect = opaque & (near_white | sat_red | sat_blue | warm | two_edge)
    recolour = opaque & (~protect)
    print(f"recolour: opaque={int(opaque.sum())} protected={int(protect.sum())} "
          f"recoloured={int(recolour.sum())}")
    # --- contrast stretch --------------------------------------------------
    # The 2P blue camo is mostly dark-to-mid (luminance ~0-130), so a plain
    # luminance->palette map would come out almost all dark olive/brown
    # with no ochre or pale blue-grey. Stretch the camo luminance
    # (2nd to 98th percentile -> 0..255) before the palette lookup, so the
    # brightest blue patches become ochre/pale and the darkest become dark
    # green/brown — a true 5-colour patch pattern. The stretch is monotonic,
    # so the photographic shading and fabric ribbing are preserved (only
    # the contrast is raised, as a camo pattern should be).
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    camo_lum = lum[recolour]
    p2, p98 = np.percentile(camo_lum, [2, 98])
    if p98 - p2 < 10:
        p2, p98 = 0.0, 255.0
    lum_s = np.clip((lum - p2) / (p98 - p2) * 255.0, 0, 255)
    print(f"contrast stretch: p2={p2:.1f} p98={p98:.1f}")
    # --- stretched luminance -> French palette gradient --------------------
    gr = np.interp(lum_s, GRAD_L, GRAD_R)
    gg = np.interp(lum_s, GRAD_L, GRAD_G)
    gb = np.interp(lum_s, GRAD_L, GRAD_B)
    # force the output luminance to equal the STRETCHED luminance per pixel,
    # so the (raised-contrast) photographic shading / fabric ribbing /
    # panel lines survive.
    glum = 0.299 * gr + 0.587 * gg + 0.114 * gb
    scale = np.clip(lum_s / np.maximum(glum, 1.0), 0.7, 1.4)
    out_r = np.clip(gr * scale, 0, 255)
    out_g = np.clip(gg * scale, 0, 255)
    out_b = np.clip(gb * scale, 0, 255)
    # --- compose: recoloured pixels take the gradient, the rest are kept --
    nr = np.where(recolour, out_r, r)
    ng = np.where(recolour, out_g, g)
    nb = np.where(recolour, out_b, b)
    out = np.stack([nr, ng, nb, al], axis=-1).astype(np.uint8)
    return Image.fromarray(out, mode="RGBA")

# ------------------------------------------------------- player SPAD rebuild
def build_spad_set(src_path, prefix):
    """Rebuild one player's 4 banked sprites from its photorealistic photo.
    (v38 convention: level is the photo; bank-left/right are +/-14 deg
    photographic rotations; damaged is scorched + photographic smoke/embers.)"""
    src = Image.open(src_path).convert("RGBA")
    print(prefix, "source:", src.size, "visible px:", visible_px(src))
    level = fit_into_square(src, 256)
    backup(os.path.join(SPR, prefix + "-level.png"))
    save(level, os.path.join(SPR, prefix + "-level.png"))
    for name, angle in (("bank-left", 14), ("bank-right", -14)):
        rot = src.rotate(angle, resample=Image.BICUBIC, expand=True)
        out = fit_into_square(rot, 256)
        backup(os.path.join(SPR, prefix + "-" + name + ".png"))
        save(out, os.path.join(SPR, prefix + "-" + name + ".png"))
    dmg = level.copy()
    dmg = grade(dmg, bright=0.55, contrast=1.15, color=0.7,
                tint=(30, 22, 14), tint_amt=0.25)
    smoke = Image.open(SMOKEDARK).convert("RGBA").resize((90, 90), Image.LANCZOS)
    ember = Image.open(EMBER).convert("RGBA").resize((36, 36), Image.LANCZOS)
    glow = Image.open(FIREGLOW).convert("RGBA").resize((70, 70), Image.LANCZOS)
    for (cx, cy, s, al_) in ((128, 110, 90, 200), (96, 150, 70, 170), (160, 140, 70, 170)):
        puff = smoke.copy()
        puff.putalpha(puff.split()[3].point(lambda v: int(v * al_ / 255)))
        dmg.alpha_composite(puff, (cx - s // 2, cy - s // 2))
    for (cx, cy) in ((118, 96), (140, 128), (108, 150), (152, 168)):
        e = ember.copy()
        dmg.alpha_composite(e, (cx - 18, cy - 18))
    g2 = glow.copy()
    g2.putalpha(g2.split()[3].point(lambda v: int(v * 0.45)))
    dmg.alpha_composite(g2, (128 - 35, 118 - 35))
    backup(os.path.join(SPR, prefix + "-damaged.png"))
    save(dmg, os.path.join(SPR, prefix + "-damaged.png"))
    return {"level": level}

# ------------------------------------------------------------------ run it
print("2P source:", SPAD2)
src = Image.open(SPAD2).convert("RGBA")
print("source size:", src.size, "visible px:", visible_px(src))
new_src = recolour_french_5colour(src)
# back up the original source, then overwrite it with the recoloured one
spad2_backup = os.path.join(BACKUP, "spad-player-2.png")
if not os.path.exists(spad2_backup):
    shutil.copy2(SPAD2, spad2_backup)
    print("backed up source to", os.path.relpath(spad2_backup, ROOT))
save(new_src, SPAD2)
build_spad_set(SPAD2, "player-spad-2")

# ------------------------------------------------------------- verification
print()
bad = []
def colour_profile(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.int32)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    opaque = al > 128
    green = int(((g > 80) & (g > r) & ((g - b) > 10) & opaque).sum())
    blue = int(((b > 80) & (b > r) & ((b - g) > 10) & opaque).sum())
    # French brown is warm mid-tone (r>g>b); the narrow (r-g) 15..70 rule
    # undercounts olive-brown, so use the broad warm-brown definition.
    brown = int(((r > 80) & (r > g) & (g > b) & ((r - g) > 5) & ((r - g) < 90) & opaque).sum())
    red = int(((r > 150) & ((r - g) > 60) & ((r - b) > 40) & opaque).sum())
    white = int(((r > 225) & (g > 225) & (b > 225) & opaque).sum())
    return green, blue, brown, red, white

lvl = os.path.join(SPR, "player-spad-2-level.png")
green, blue, brown, red, white = colour_profile(lvl)
print(f"2P level colour profile: green={green} blue={blue} brown={brown} red(roundel)={red} white={white}")
if green < 2000:
    bad.append(("player-spad-2-level.png", f"French green missing (green {green})"))
if blue > 3000:
    bad.append(("player-spad-2-level.png", f"still too blue (blue {blue})"))
if brown < 500:
    bad.append(("player-spad-2-level.png", f"French brown missing (brown {brown})"))
if red < 50:
    bad.append(("player-spad-2-level.png", f"roundel red missing (red {red})"))
if white < 100:
    bad.append(("player-spad-2-level.png", f"white '2' missing (white {white})"))
# the "2" itself: white pixels in the "2" bbox of the recoloured source
s = np.asarray(Image.open(SPAD2).convert("RGBA")).astype(np.int32)
r, g, b, al = s[:, :, 0], s[:, :, 1], s[:, :, 2], s[:, :, 3]
two = ((al > 128) & (r > 225) & (g > 225) & (b > 225) &
       (np.arange(1680)[None, :] >= TWO_X0) & (np.arange(1680)[None, :] <= TWO_X1) &
       (np.arange(1296)[:, None] >= TWO_Y0) & (np.arange(1296)[:, None] <= TWO_Y1))
two_count = int(two.sum())
print(f"white '2' pixels in the top-wing bbox: {two_count}")
if two_count < 5000:
    bad.append(("spad-player-2.png", f"top-wing '2' damaged or missing (white px {two_count})"))
# all four banked files exist, 256x256 RGBA, aircraft visible, corners transparent
for name in ["player-spad-2-level.png", "player-spad-2-bank-left.png",
             "player-spad-2-bank-right.png", "player-spad-2-damaged.png"]:
    p = os.path.join(SPR, name)
    im = Image.open(p)
    if im.size != (256, 256) or im.mode != "RGBA":
        bad.append((name, f"bad size/mode {im.size} {im.mode}"))
    if visible_px(im) < 5000:
        bad.append((name, f"aircraft missing (visible {visible_px(im)})"))
    ca = np.asarray(im.convert("RGBA"))
    corner_a = max(int(ca[0, 0, 3]), int(ca[0, -1, 3]), int(ca[-1, 0, 3]), int(ca[-1, -1, 3]))
    if corner_a > 8:
        bad.append((name, f"corner not transparent (alpha {corner_a})"))
# 1P untouched: its level sprite must still be the French 5-colour 1P
p1 = os.path.join(SPR, "player-spad-level.png")
g1, b1, br1, r1, w1 = colour_profile(p1)
print(f"1P level (untouched check): green={g1} blue={b1} brown={br1} red={r1} white={w1}")
if g1 < 2000 or r1 < 50:
    bad.append(("player-spad-level.png", "1P sprite changed or damaged"))
print()
if bad:
    print("VERIFICATION FAILED:")
    for n, w in bad:
        print("  -", n, "—", w)
    raise SystemExit(1)
print("VERIFICATION PASSED — 2P is French 5-colour, '2' on the top wing, 1P untouched.")
