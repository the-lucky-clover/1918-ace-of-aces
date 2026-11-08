#!/usr/bin/env python3
"""bin/build-v57-enemy.py — v57 enemy aircraft: un-pin them from the ground.

WHAT STEVEN ORDERED (2026-11-07): "some enemy airplanes look pinned to
the ground. iterate and improve all animation spritesheets for enemy
aircraft as well as staging their correct scaling in comparison to the
spad xiii"

WHAT WAS WRONG (audited 2026-11-07, pixel-measured):
- The four oldest enemy sets are flat, dark, near-featureless STRIPS, not
  photorealistic top-down aircraft (viewed directly):
    enemy-scout-level    168x56 px of aircraft in a 256 frame, 2,718 vis px
    enemy-fighter-level  154x56 px, 2,673 vis px
    enemy-triplane-level 148x57 px, 2,893 vis px
    enemy-bomber-level   244x53 px, 3,927 vis px
  A real top-down aircraft plate (SPAD / D.Va / Dr.I / Gotha) carries
  15,000-22,000 visible px with a span/length ratio of ~1.3-1.6. The flat
  strips read as ground objects because they ARE flat: no planform, no
  banking read, no altitude cue, and the glued canvas shadow in
  drawBlenderSprite (offsetY 7, blur 9) sits right under them like a
  contact shadow — the aircraft looks glued to the terrain.
- The four flat sets have NO *-damaged.png files. loadBankedSprites still
  creates a set.damaged Image (404 src), and drawEnemy picks it whenever
  hp <= 25% — so a damaged scout/fighter/triplane/bomber VANISHES instead
  of showing damage. (The other 10 sets + 6 boss sets all have damaged
  files; the fix there is a code fallback, not new art.)
- The other 10 enemy sets + 6 boss sets already wear true +/-14 deg
  photographic bank poses (v47, mask-IoU verified). Their "pinned" read
  comes from the DRAW PATH, not the art: the glued canvas shadow, the
  ignored pathZ/pathPitch (no altitude variation, no pitch), and the
  altitude-0 shadow. Those are fixed in the game file (v57 code), not here.

WHAT THIS SCRIPT DOES (photographic material only, no generated pixels):
- Rebuilds the four flat LEVEL sprites from real top-down aircraft photos
  already on disk, retouched and recoloured photographically:
    scout    <- player-spad-level.png (SPAD XIII top-down): the "1" and the
              94th Aero diagonal stripe are covered with alpha-masked clone
              patches from the wing's own clean camo, then recoloured to a
              pale khaki/olive Nieuport palette (roundels + prop kept).
    fighter  <- enemy-dva-level.png (Albatros D.Va top-down): the lozenge
              camo is recoloured to a streaked green-olive Albatros palette;
              the Balkenkreuz crosses and the wooden prop are protected.
    triplane <- enemy-dri-level.png (Fokker Dr.I top-down, all red): the six
              wing crosses + the fuselage cross are covered with red-camo
              clone patches, the red is recoloured to olive-drab PC10, and
              French roundels lifted from the SPAD plate are pasted on the
              top wing (Sopwith Triplane, British).
    bomber   <- enemy-gotha-level.png (Gotha G.IV top-down): recoloured to
              a darker brown-green bomber livery; crosses and props kept.
- Reframes each rebuilt level so its alpha-bbox width EQUALS the v54
  SPRITE_FILLW table value (scout 168, fighter 156, triplane 150,
  bomber 246) — so the v54 true-scale staging is preserved exactly:
  drawn wingspan = st.size * (fillW/256) is unchanged, and the v54 QA
  still passes. The aircraft is smaller in its frame (more transparent
  margin), not smaller on screen.
- Rebuilds bank-left/bank-right for the four sets as true +/-14 deg
  photographic rotations of their new levels (v47 method, mask-IoU > 0.98).
- Builds damaged poses for the four sets (v51 method: scorched + the
  photographic v36 smoke/ember/fireglow plates), so damaged enemies show
  damage instead of vanishing.
- The other 10 enemy sets + 6 boss sets are NOT re-rendered: their poses
  are already true +/-14 deg photographic rotations (v47). Their
  "pinned" fix is the v57 draw path (noShadow + pathZ altitude shadow +
  pitch squash + damaged fallback) in the game file.
- Originals are backed up to assets/sprites/.v57-backup/ before any
  overwrite. Re-running the script reproduces the same outputs.

Usage: python3 bin/build-v57-enemy.py
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
BACKUP = os.path.join(SPR, ".v57-backup")
V36 = os.path.join(SPR, "v36")
os.makedirs(BACKUP, exist_ok=True)

SMOKEDARK = os.path.join(V36, "v36-smokedark.png")
EMBER = os.path.join(V36, "v36-ember.png")
FIREGLOW = os.path.join(V36, "v36-fireglow.png")

BANK_ANGLE = 14  # deg, v38/v47 convention

# v54 SPRITE_FILLW table values — the reframe targets these exactly so the
# true-scale staging (drawn wingspan = st.size * fillW/256) is preserved.
TARGET_FILLW = {"scout": 168, "fighter": 156, "triplane": 150, "bomber": 246}


# ------------------------------------------------------------------ helpers
def save(img, path):
    img.save(path, "PNG")
    print("wrote", os.path.relpath(path, ROOT), img.size, img.mode)
    return path


def backup(path):
    """Copy the original to .v57-backup/ before the first overwrite."""
    name = os.path.basename(path)
    dst = os.path.join(BACKUP, name)
    if not os.path.exists(dst) and os.path.exists(path):
        shutil.copy2(path, dst)
    return dst


def visible_px(im):
    a = np.asarray(im.convert("RGBA"))
    return int((a[:, :, 3] > 10).sum())


def alpha_bbox_w(im, threshold=10):
    """Width of the alpha bounding box (the v54 fillW measure)."""
    a = np.asarray(im.split()[3])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return 0
    return int(xs.max() - xs.min() + 1)


def corner_alpha_max(im):
    a = np.asarray(im.split()[3], dtype=np.uint8)
    return int(max(a[0, 0], a[0, -1], a[-1, 0], a[-1, -1]))


def fit_into_square(im, size=256):
    """Scale the image to fit inside a transparent square canvas. (v38.)"""
    w, h = im.size
    scale = size / max(w, h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    small = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(small, ((size - nw) // 2, (size - nh) // 2), small)
    return canvas


def reframe_to_fillw(im, target_fillw, threshold=10):
    """Scale the whole frame so the aircraft's alpha-bbox width equals
    target_fillw, then centre in a 256 square. The aircraft reads the
    same size on screen (v54 true scale is preserved); it just carries
    more transparent margin in its frame."""
    w = alpha_bbox_w(im, threshold)
    if w == 0:
        return im
    scale = target_fillw / w
    nw, nh = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    small = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.paste(small, ((256 - nw) // 2, (256 - nh) // 2), small)
    return canvas


def cover_rect(img, src_box, dst_box):
    """Cover dst_box with the photographic texture of src_box, tiling it
    (alternating horizontal flips) so no stretch distortion shows. The
    paste is masked by the DESTINATION's own alpha, so the cover never
    extends beyond the wing/fuselage silhouette it repairs.
    src_box, dst_box: (x0, y0, x1, y1). Operates in place, returns img."""
    dw, dh = dst_box[2] - dst_box[0], dst_box[3] - dst_box[1]
    tile = img.crop(src_box)
    tw, th = tile.size
    # build a dst-sized patch by tiling the src (flip every other tile)
    patch = Image.new("RGBA", (dw, dh), (0, 0, 0, 0))
    x = 0
    flip = False
    while x < dw:
        t = tile.transpose(Image.FLIP_LEFT_RIGHT) if flip else tile
        patch.paste(t, (x, 0))
        x += tw
        flip = not flip
    if th != dh:
        patch = patch.resize((dw, dh), Image.LANCZOS)
    dst_region = img.crop(dst_box)
    mask = dst_region.split()[3]
    img.paste(patch, dst_box, mask)
    return img


def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    """Grade RGB only; the alpha channel is preserved exactly. (v51.)"""
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


# Luminance stops shared by every v57 palette (v51 convention).
GRAD_L = np.array([0, 35, 60, 85, 110, 135, 160, 185, 210, 230, 255],
                  dtype=np.float32)


def make_grad(rgb_stops):
    """rgb_stops: 11 (r, g, b) tuples, luminance-ordered, one per GRAD_L."""
    arr = np.array(rgb_stops, dtype=np.float32)
    return arr[:, 0], arr[:, 1], arr[:, 2]


# Nieuport khaki/olive (scout): pale linen-khaki to olive. Roundels and the
# wooden prop are protected, so the French identity survives the recolour.
NIEUPORT = make_grad([
    (58, 54, 28), (88, 84, 44), (104, 100, 58), (122, 118, 62),
    (140, 130, 84), (152, 142, 96), (168, 152, 96), (182, 166, 110),
    (196, 182, 128), (206, 192, 142), (216, 204, 158),
])
# Albatros streaked green-olive (fighter): greener than the Nieuport, so the
# two French/German scouts never read as the same crate.
ALBATROS = make_grad([
    (40, 48, 22), (62, 72, 32), (80, 92, 42), (96, 108, 52),
    (110, 122, 62), (122, 134, 72), (134, 146, 84), (148, 158, 98),
    (162, 170, 112), (174, 182, 126), (186, 194, 140),
])
# Sopwith olive drab PC10 (triplane): neutral olive drab, uniform as the
# real PC10 finish was.
PC10 = make_grad([
    (50, 48, 26), (72, 70, 38), (88, 86, 48), (102, 100, 58),
    (116, 112, 66), (128, 124, 76), (140, 136, 86), (152, 148, 98),
    (164, 160, 110), (176, 172, 124), (188, 184, 138),
])
# AEG dark brown-green (bomber): darker and browner than the Gotha's olive,
# so the two German giants read apart.
AEG = make_grad([
    (38, 36, 20), (58, 54, 30), (74, 70, 40), (88, 84, 48),
    (100, 96, 56), (112, 106, 64), (124, 118, 74), (136, 130, 86),
    (148, 142, 98), (160, 154, 110), (172, 166, 124),
])


def recolour_palette(src, grad, warm_max_rg=999, protect_sat_red=True,
                     stretch=True):
    """Recolour a photographic plate by mapping each camo pixel's luminance
    through a palette gradient (v51 method). PROTECTS (never recoloured):
    near-white, saturated red, saturated blue (roundels, crosses, white
    markings) and warm tones (wooden prop, leather cockpit, tan fuselage).
    The output luminance is forced to equal the contrast-stretched input
    luminance per pixel, so the photographic shading, fabric ribbing and
    panel lines survive untouched.
    warm_max_rg caps the warm rule: a pixel whose red exceeds its green by
    more than this is NOT warm — it is a saturated colour to recolour, not
    wood to keep. The default (999) is the v51 rule. The triplane passes
    80, because the Dr.I's wings are saturated red (r-g ~120-190) and the
    v51 warm rule would protect the whole red airframe from the PC10
    recolour; the wooden prop (r-g ~40) stays protected under the cap.
    protect_sat_red=False drops the saturated-red protection entirely.
    The triplane passes False, because the Dr.I's WHOLE airframe is
    saturated red — the sat_red rule would protect the wings from the
    PC10 recolour just as the warm rule did. The only red that must
    survive is the roundels, and those are pasted AFTER the recolour, so
    nothing red needs protecting during it.
    stretch=False skips the p2/p98 contrast stretch and maps the RAW
    luminance straight to the palette. The triplane passes False, because
    the Dr.I is one uniform red (a narrow luminance band): the stretch
    would normalise that band to the top of the palette and turn her pale
    cream instead of mid-olive PC10. A single-colour finish maps to a
    single palette colour — the raw luminance picks the mid-olive."""
    gr, gg, gb = grad
    a = np.asarray(src.convert("RGBA")).astype(np.float32)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    opaque = al > 128
    near_white = (r > 225) & (g > 225) & (b > 225)
    sat_red = (r > 150) & ((r - g) > 60) & ((r - b) > 60)
    sat_blue = (b > 130) & ((b - r) > 50) & ((b - g) > 40)
    warm = (r > (b + 20)) & ((r - g) < warm_max_rg)
    protect = opaque & (near_white | sat_blue | warm)
    if protect_sat_red:
        protect = protect | (opaque & sat_red)
    recolour = opaque & (~protect)
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    camo_lum = lum[recolour]
    p2, p98 = np.percentile(camo_lum, [2, 98]) if camo_lum.size else (0.0, 255.0)
    if p98 - p2 < 10:
        p2, p98 = 0.0, 255.0
    if stretch:
        lum_s = np.clip((lum - p2) / (p98 - p2) * 255.0, 0, 255)
    else:
        lum_s = np.clip(lum, 0, 255)
    pr = np.interp(lum_s, GRAD_L, gr)
    pg = np.interp(lum_s, GRAD_L, gg)
    pb = np.interp(lum_s, GRAD_L, gb)
    glum = 0.299 * pr + 0.587 * pg + 0.114 * pb
    scale = np.clip(lum_s / np.maximum(glum, 1.0), 0.7, 1.4)
    nr = np.where(recolour, np.clip(pr * scale, 0, 255), r)
    ng = np.where(recolour, np.clip(pg * scale, 0, 255), g)
    nb = np.where(recolour, np.clip(pb * scale, 0, 255), b)
    out = np.stack([nr, ng, nb, al], axis=-1).astype(np.uint8)
    print(f"    recolour: opaque={int(opaque.sum())} protected={int(protect.sum())} "
          f"recoloured={int(recolour.sum())} lum stretch "
          f"{('p2=%.1f p98=%.1f' % (p2, p98)) if stretch else 'OFF (raw luminance)'}")
    return Image.fromarray(out, mode="RGBA")


def mask_iou(a_im, b_im):
    """IoU of the visible (alpha>40) masks, both downsampled to 128px."""
    a = np.asarray(a_im.split()[3].resize((128, 128))) > 40
    b = np.asarray(b_im.split()[3].resize((128, 128))) > 40
    inter = int((a & b).sum())
    union = int((a | b).sum())
    return inter / union if union else 0.0


def principal_angle(im):
    """Orientation (deg) of the visible silhouette's principal axis."""
    a = np.asarray(im.split()[3], dtype=np.float64)
    ys, xs = np.where(a > 40)
    if len(xs) < 50:
        return None
    xs = xs.astype(np.float64)
    ys = ys.astype(np.float64)
    cx, cy = xs.mean(), ys.mean()
    cxx = ((xs - cx) ** 2).mean()
    cyy = ((ys - cy) ** 2).mean()
    cxy = ((xs - cx) * (ys - cy)).mean()
    return round(0.5 * float(np.degrees(np.arctan2(2 * cxy, cxx - cyy))), 2)


def build_damaged(level, prefix):
    """Damaged pose (v51 method): scorched + photographic v36 smoke,
    embers and fireglow, centred on the aircraft."""
    dmg = level.copy()
    dmg = grade(dmg, bright=0.55, contrast=1.15, color=0.7,
                tint=(30, 22, 14), tint_amt=0.25)
    smoke = Image.open(SMOKEDARK).convert("RGBA").resize((90, 90), Image.LANCZOS)
    ember = Image.open(EMBER).convert("RGBA").resize((36, 36), Image.LANCZOS)
    glow = Image.open(FIREGLOW).convert("RGBA").resize((70, 70), Image.LANCZOS)
    for (cx, cy, s, al_) in ((128, 110, 90, 200), (96, 150, 70, 170),
                            (160, 140, 70, 170)):
        puff = smoke.copy()
        puff.putalpha(puff.split()[3].point(lambda v: int(v * al_ / 255)))
        dmg.alpha_composite(puff, (cx - s // 2, cy - s // 2))
    for (cx, cy) in ((118, 96), (140, 128), (108, 150), (152, 168)):
        e = ember.copy()
        dmg.alpha_composite(e, (cx - 18, cy - 18))
    g2 = glow.copy()
    g2.putalpha(g2.split()[3].point(lambda v: int(v * 0.45)))
    dmg.alpha_composite(g2, (128 - 35, 118 - 35))
    return dmg


def build_set(prefix, level):
    """Write level + bank-left/bank-right + damaged for one enemy set,
    backing up the originals first. Returns the level image."""
    for name, img in (("level", level),):
        dst = os.path.join(SPR, prefix + "-" + name + ".png")
        backup(dst)
        save(img, dst)
    for name, angle in (("bank-left", BANK_ANGLE), ("bank-right", -BANK_ANGLE)):
        rot = level.rotate(angle, resample=Image.BICUBIC, expand=True)
        posed = fit_into_square(rot, 256)
        dst = os.path.join(SPR, prefix + "-" + name + ".png")
        backup(dst)
        save(posed, dst)
    dmg = build_damaged(level, prefix)
    dst = os.path.join(SPR, prefix + "-damaged.png")
    backup(dst)
    save(dmg, dst)
    return level


# ------------------------------------------------------------------ retouches
def build_scout():
    """Nieuport scout <- SPAD XIII top-down photo. The white '1' (bbox
    x 152-170, y 59-95, measured) and the 94th Aero red/white diagonal
    stripe (x 74-124, y 54-103) are covered with clone patches from the
    wing's own clean camo (x 50-74, y 57-98 — clear of the left roundel,
    which ends at x ~48, and clear of the stripe, which starts at x ~74).
    Then the French 5-colour camo is recoloured to a pale khaki/olive
    Nieuport palette; the roundels and the wooden prop are protected."""
    print("scout <- player-spad-level.png (de-badged SPAD, Nieuport khaki)")
    src = Image.open(os.path.join(SPR, "player-spad-level.png")).convert("RGBA")
    img = src.copy()
    cover_rect(img, (50, 57, 74, 98), (150, 57, 172, 97))   # the white "1"
    cover_rect(img, (50, 57, 74, 98), (74, 54, 124, 103))   # the stripe
    img = recolour_palette(img, NIEUPORT)
    level = reframe_to_fillw(img, TARGET_FILLW["scout"])
    return build_set("enemy-scout", level)


def build_fighter():
    """Albatros fighter <- Albatros D.Va top-down photo. The lozenge camo
    is recoloured to a streaked green-olive Albatros palette; the
    Balkenkreuz crosses (near-black + white outlines) and the wooden prop
    are protected, so she stays German and distinct from the D.Va."""
    print("fighter <- enemy-dva-level.png (Albatros, green-olive lozenge)")
    src = Image.open(os.path.join(SPR, "enemy-dva-level.png")).convert("RGBA")
    img = recolour_palette(src, ALBATROS)
    level = reframe_to_fillw(img, TARGET_FILLW["fighter"])
    return build_set("enemy-fighter", level)


def lift_roundel(spad):
    """Lift one French roundel from the SPAD plate. The roundel centre is
    the centroid of its saturated-red centre disc (right wing); the disc
    radius is the farthest saturated-blue ring pixel from that centre.
    Returns (roundel_image, radius)."""
    a = np.asarray(spad.convert("RGBA")).astype(np.int32)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    op = al > 128
    red = op & (r > 150) & ((r - g) > 60) & ((r - b) > 40)
    yy, xx = np.mgrid[0:256, 0:256]
    # right-wing roundel centre disc (x 180-235, y 60-95; the "1" is white,
    # so it never pollutes the red mask)
    m = red & (xx >= 180) & (xx <= 235) & (yy >= 58) & (yy <= 98)
    ys, xs = np.where(m)
    cx, cy = float(xs.mean()), float(ys.mean())
    blue = op & (b > 110) & ((b - r) > 45) & ((b - g) > 30)
    dist = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    ring = blue & (dist < 32)
    radius = float(dist[ring].max()) if ring.any() else 20.0
    print(f"    roundel centre=({cx:.1f},{cy:.1f}) radius={radius:.1f}")
    side = int(np.ceil(radius)) * 2 + 2
    x0, y0 = int(round(cx)) - side // 2, int(round(cy)) - side // 2
    crop = spad.crop((x0, y0, x0 + side, y0 + side))
    # circular mask: only the roundel disc survives the lift
    mask = Image.new("L", (side, side), 0)
    px = mask.load()
    for j in range(side):
        for i in range(side):
            if (i - side / 2) ** 2 + (j - side / 2) ** 2 <= radius ** 2:
                px[i, j] = 255
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.paste(crop, (0, 0), mask)
    return out, radius


def build_triplane():
    """Sopwith Triplane <- Fokker Dr.I top-down photo (all red). The six
    wing crosses + the fuselage cross are covered with red-camo clone
    patches from clean wing/fuselage areas, the red is recoloured to
    olive-drab PC10, and French roundels lifted from the SPAD plate are
    pasted on the top wing at the two old cross positions (70,100) and
    (185,100) — the Sopwith reads British, not German."""
    print("triplane <- enemy-dri-level.png (Sopwith, PC10 + roundels)")
    src = Image.open(os.path.join(SPR, "enemy-dri-level.png")).convert("RGBA")
    img = src.copy()
    # cover the crosses with clean red (alpha-masked, never past the wing)
    cover_rect(img, (100, 92, 160, 108), (60, 89, 81, 111))    # top wing L
    cover_rect(img, (100, 92, 160, 108), (174, 89, 196, 111))  # top wing R
    cover_rect(img, (100, 124, 160, 140), (60, 120, 82, 142))  # mid wing L
    cover_rect(img, (100, 124, 160, 140), (174, 120, 196, 142))  # mid wing R
    cover_rect(img, (100, 144, 160, 162), (62, 141, 84, 166))  # bottom L
    cover_rect(img, (100, 144, 160, 162), (176, 143, 198, 166))  # bottom R
    cover_rect(img, (120, 130, 136, 146), (120, 116, 136, 130))  # fuselage
    # warm_max_rg=80 + protect_sat_red=False + stretch=False: the Dr.I's
    # saturated-red wings (r-g ~120-190) must be recoloured to PC10, not
    # protected as "warm" wood or "saturated red" roundels (the v51 rules
    # would protect the whole red airframe and she would stay a red Dr.I,
    # not a Sopwith). The wooden prop (r-g ~40) stays protected under the
    # cap, and the roundels are pasted after the recolour, so no red needs
    # protecting during it. stretch=False because the Dr.I is one uniform
    # red: the p2/p98 stretch would normalise that narrow band to the top
    # of the palette and turn her pale cream instead of mid-olive PC10.
    img = recolour_palette(img, PC10, warm_max_rg=80, protect_sat_red=False,
                           stretch=False)
    # roundels on the top wing (pasted AFTER the recolour, so they keep
    # their French colours). 22 px pre-reframe -> ~15 px in the final
    # frame, the most the 22 px-tall top wing can carry.
    spad = Image.open(os.path.join(SPR, "player-spad-level.png")).convert("RGBA")
    roundel, _radius = lift_roundel(spad)
    r22 = roundel.resize((22, 22), Image.LANCZOS)
    for (cx, cy) in ((70, 100), (185, 100)):
        img.alpha_composite(r22, (cx - 11, cy - 11))
    level = reframe_to_fillw(img, TARGET_FILLW["triplane"])
    return build_set("enemy-triplane", level)


def build_bomber():
    """AEG-type bomber <- Gotha G.IV top-down photo. Recoloured to a darker
    brown-green bomber livery; the Balkenkreuz crosses and the engine
    details are protected, so she stays German and distinct from the
    Gotha archetype's lighter olive."""
    print("bomber <- enemy-gotha-level.png (AEG, dark brown-green)")
    src = Image.open(os.path.join(SPR, "enemy-gotha-level.png")).convert("RGBA")
    img = recolour_palette(src, AEG)
    level = reframe_to_fillw(img, TARGET_FILLW["bomber"])
    return build_set("enemy-bomber", level)


# ------------------------------------------------------------------ verify
def colour_profile(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.int32)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    op = al > 128
    green = int(((g > 80) & (g > r) & ((g - b) > 10) & op).sum())
    blue = int(((b > 80) & (b > r) & ((b - g) > 10) & op).sum())
    brown = int(((r > 80) & (r > g) & (g > b) & ((r - g) > 5) & ((r - g) < 90) & op).sum())
    red = int(((r > 150) & ((r - g) > 60) & ((r - b) > 40) & op).sum())
    white = int(((r > 225) & (g > 225) & (b > 225) & op).sum())
    black = int(((r < 45) & (g < 45) & (b < 45) & op).sum())
    return green, blue, brown, red, white, black


def main():
    failures = []
    levels = {}
    levels["scout"] = build_scout()
    levels["fighter"] = build_fighter()
    levels["triplane"] = build_triplane()
    levels["bomber"] = build_bomber()

    print()
    print("verification — the four rebuilt sets:")
    for prefix, target in (("enemy-scout", 168), ("enemy-fighter", 156),
                           ("enemy-triplane", 150), ("enemy-bomber", 246)):
        level_path = os.path.join(SPR, prefix + "-level.png")
        level = Image.open(level_path)
        fw10 = alpha_bbox_w(level, 10)
        fw40 = alpha_bbox_w(level, 40)
        vis = visible_px(level)
        ok = (level.size == (256, 256) and level.mode == "RGBA"
              and vis > 5000 and corner_alpha_max(level) <= 8
              and abs(fw10 - target) <= 2)
        if not ok:
            failures.append(f"{prefix}-level: size={level.size} vis={vis} "
                            f"fillW(a>10)={fw10} fillW(a>40)={fw40} target={target}")
        # bank poses: true +/-14 deg rotations of the new level (v47 check)
        for name, angle in (("bank-left", BANK_ANGLE), ("bank-right", -BANK_ANGLE)):
            posed = Image.open(os.path.join(SPR, prefix + "-" + name + ".png"))
            expect = fit_into_square(
                level.rotate(angle, resample=Image.BICUBIC, expand=True), 256)
            iou = mask_iou(posed, expect)
            ang = principal_angle(posed)
            good = (posed.size == (256, 256) and visible_px(posed) > 5000
                    and corner_alpha_max(posed) <= 8 and iou > 0.98)
            if not good:
                failures.append(f"{prefix}-{name}: iou={iou:.3f} angle={ang} "
                                f"vis={visible_px(posed)}")
            print(f"  {'PASS ' if good else 'FAIL '} {prefix}-{name}: "
                  f"angle={ang} iou={iou:.3f} vis={visible_px(posed)}")
        dmg = Image.open(os.path.join(SPR, prefix + "-damaged.png"))
        if not (dmg.size == (256, 256) and visible_px(dmg) > 5000):
            failures.append(f"{prefix}-damaged: bad size/visible")
        g, bl, br, rd, wh, bk = colour_profile(level_path)
        print(f"  {'PASS ' if ok else 'FAIL '} {prefix}-level: fillW(a>10)={fw10} "
              f"fillW(a>40)={fw40} target={target} vis={vis} "
              f"green={g} blue={bl} brown={br} red={rd} white={wh} black={bk}")

    # --- marking checks ------------------------------------------------------
    print()
    print("marking checks:")
    # scout: the "1" is gone (white px in the old "1" bbox, pre-reframe
    # coordinates are scaled by 168/255 — check the final frame's right
    # wing for a white numeral shape instead: white px must be roundel
    # white only, and no white blob wider than a roundel ring)
    scout = np.asarray(Image.open(os.path.join(SPR, "enemy-scout-level.png"))
                       .convert("RGBA")).astype(np.int32)
    r, g, b, al = scout[:, :, 0], scout[:, :, 1], scout[:, :, 2], scout[:, :, 3]
    op = al > 128
    white = op & (r > 225) & (g > 225) & (b > 225)
    # the two roundels each carry a white ring (~60-90 px); a surviving "1"
    # would add ~200 white px on the right wing between fuselage and roundel
    ys, xs = np.where(white & (np.arange(256)[None, :] >= 96)
                      & (np.arange(256)[None, :] < 150))
    one_white = len(xs)
    print(f"  scout: white px in the old '1' zone (x 96-150) = {one_white}")
    if one_white > 40:
        failures.append(f"enemy-scout-level: white '1' may survive ({one_white} px)")
    red = op & (r > 150) & ((r - g) > 60) & ((r - b) > 40)
    print(f"  scout: saturated red (roundel centres) = {int(red.sum())} px")
    if int(red.sum()) < 50:
        failures.append("enemy-scout-level: roundel red missing")
    blue = op & (b > 80) & (b > r) & ((b - g) > 10)
    print(f"  scout: saturated blue (roundel rings) = {int(blue.sum())} px")
    if int(blue.sum()) < 50:
        failures.append("enemy-scout-level: roundel blue missing")

    # triplane: roundels present, crosses gone
    tri = np.asarray(Image.open(os.path.join(SPR, "enemy-triplane-level.png"))
                     .convert("RGBA")).astype(np.int32)
    r, g, b, al = tri[:, :, 0], tri[:, :, 1], tri[:, :, 2], tri[:, :, 3]
    op = al > 128
    tri_blue = int(((b > 110) & ((b - r) > 45) & ((b - g) > 30) & op).sum())
    tri_red = int(((r > 150) & ((r - g) > 60) & ((r - b) > 40) & op).sum())
    tri_black = int(((r < 45) & (g < 45) & (b < 45) & op).sum())
    print(f"  triplane: roundel blue={tri_blue} roundel red={tri_red} "
          f"near-black={tri_black} (Dr.I had 2081)")
    if tri_blue < 80:
        failures.append(f"enemy-triplane-level: roundels missing (blue {tri_blue})")
    if tri_red < 30:
        failures.append(f"enemy-triplane-level: roundel red missing ({tri_red})")
    if tri_red > 1000:
        failures.append(f"enemy-triplane-level: still red — PC10 recolour "
                        f"failed (saturated red {tri_red}, want < 1000)")
    if tri_black > 800:
        failures.append(f"enemy-triplane-level: crosses may survive (black {tri_black})")

    # fighter + bomber: crosses kept (German), and the recolour landed.
    # Both palettes are green/brown, so the recolour check is green+brown
    # (the AEG bomber is brown-dominant, green=0, by design).
    for prefix in ("enemy-fighter", "enemy-bomber"):
        im = np.asarray(Image.open(os.path.join(SPR, prefix + "-level.png"))
                         .convert("RGBA")).astype(np.int32)
        r, g, b, al = im[:, :, 0], im[:, :, 1], im[:, :, 2], im[:, :, 3]
        op = al > 128
        black = int(((r < 45) & (g < 45) & (b < 45) & op).sum())
        green = int(((g > 80) & (g > r) & ((g - b) > 10) & op).sum())
        brown = int(((r > 80) & (r > g) & (g > b) & ((r - g) > 5) & ((r - g) < 90) & op).sum())
        print(f"  {prefix}: near-black (crosses)={black} green={green} brown={brown}")
        if black < 300:
            failures.append(f"{prefix}-level: crosses lost (black {black})")
        if green + brown < 500:
            failures.append(f"{prefix}-level: recolour missing "
                            f"(green+brown {green + brown})")

    # --- the other 10 sets + 6 bosses: poses already true (v47); confirm
    # the files are intact and still 256x256 --------------------------------
    print()
    print("the other 10 enemy sets + 6 boss sets (v47 poses, untouched):")
    for prefix in ("enemy-dri", "enemy-dvii", "enemy-dva", "enemy-eiii",
                   "enemy-pfalz", "enemy-gotha", "enemy-clii", "enemy-rumpler",
                   "enemy-junkers", "enemy-taube",
                   "boss-1-red", "boss-2-checker", "boss-3-stripes",
                   "boss-4-tiger", "boss-5-jester", "boss-6-ghost"):
        for name in ("level", "bank-left", "bank-right", "damaged"):
            p = os.path.join(SPR, prefix + "-" + name + ".png")
            if not os.path.exists(p):
                failures.append(f"{prefix}-{name}: missing")
                continue
            im = Image.open(p)
            if im.size != (256, 256) or visible_px(im) < 500:
                failures.append(f"{prefix}-{name}: bad size/visible")
    print("  all 16 sets x 4 poses present, 256x256, aircraft visible")

    print()
    if failures:
        print("VERIFICATION FAILED:")
        for f in failures:
            print("  - " + f)
        return 1
    print("VERIFICATION PASSED — four flat strips rebuilt as photorealistic "
          "top-down aircraft; fillW targets held (v54 true scale intact); "
          "bank poses are true +/-14 deg; damaged poses exist for all 14.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
