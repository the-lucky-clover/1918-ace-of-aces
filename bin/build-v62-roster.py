#!/usr/bin/env python3
"""bin/build-v62-roster.py — v62 enemy roster: GERMAN TYPES ONLY.

WHAT STEVEN ORDERED (2026-11-08, playtesting v61): "i shouldnt be
shooting down other spads in squadrons." Audit of the v61 roster found
exactly two Allied types hiding in the generic classes:

- enemy-scout (the 'small' archetype, the rank-and-file enemy from
  Sortie 1 on) was built in v57 from the player's own SPAD XIII
  photograph — de-badged, recoloured khaki, French roundels KEPT. The
  player was quite literally shooting down SPADs in French colours.
- enemy-triplane (the 'triplane' elite archetype) was built in v57
  from the Fokker Dr.I plate: crosses covered, airframe recoloured
  PC10 olive, French roundels pasted on — a Sopwith Triplane.

Every other set is already German (Albatros fighter, AEG bomber,
Dr.I/D.VII/D.Va/Eindecker/Pfalz/Gotha/Halberstadt/Rumpler/Junkers/
Taube lines, the Zeppelin fleet, the Staaken, the ace bosses).
EXEMPT BY DESIGN and NOT touched: the player's SPAD, the Sortie 33
mirror SPAD and the v61 black-SPAd shadow — deliberate doppelgangers
of the player's own aircraft, confined to the secret sorties, never
fielded by any wave table.

WHAT THIS SCRIPT DOES (photographic material only — the v47/v51/v57
pipeline methods, cloned from bin/build-v57-enemy.py):

- scout -> PFALZ D.III (line finish). Source: enemy-pfalz-level.png,
  the project's own top-down Pfalz D.III photograph. The airframe is
  recoloured from the Pfalz archetype's silver factory finish to the
  muted olive-lozenge field finish Pfalz scouts wore at the front, so
  the rank-and-file 'small' and the silver elite 'pfalz' read as the
  same German type in different Jasta dress — never as twins. The
  Balkenkreuz crosses (near-black) map to the palette's darkest stop
  and stay dark; the wooden prop is warm-protected.
  Scale: AIRCRAFT_SPAN_M.small becomes 9.4 (Pfalz D.III span) and the
  archetype size is re-based in the game file so v54 true scale holds
  (drawn span = size * 168/256 = 78.7 px = 69.12 * 9.4/8.25).
- triplane -> FOKKER DR.I (line finish). Source: enemy-dri-level.png,
  the project's own top-down Dr.I photograph. v57's treatment is run
  in reverse: the red is recoloured to the streaked olive finish of a
  line Jasta Dr.I and the Balkenkreuz crosses are KEPT (near-black ->
  darkest palette stop). No roundels are pasted; nothing Allied
  survives. The all-red plate remains the 'dri' ace archetype and the
  boss Barons, untouched.
  Scale: AIRCRAFT_SPAN_M.triplane becomes 7.19 (Dr.I span) and the
  archetype size is re-based in the game file (drawn span =
  size * 150/256 = 60.3 px = 69.12 * 7.19/8.25).
- Banks are true +/-14 deg photographic rotations of the new levels
  (v47 method); damaged poses use the v51 method (scorch grade + the
  photographic v36 smoke/ember/fireglow plates).
- Reframes keep the v54 SPRITE_FILLW targets (scout 168, triplane 150)
  so the true-scale staging constants stay valid.
- Originals are backed up to assets/sprites/.v62-backup/ first.

Usage: python3 bin/build-v62-roster.py
"""
import os
import shutil

import numpy as np
from PIL import Image, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
BACKUP = os.path.join(SPR, ".v62-backup")
V36 = os.path.join(SPR, "v36")
os.makedirs(BACKUP, exist_ok=True)

SMOKEDARK = os.path.join(V36, "v36-smokedark.png")
EMBER = os.path.join(V36, "v36-ember.png")
FIREGLOW = os.path.join(V36, "v36-fireglow.png")

BANK_ANGLE = 14  # deg, v38/v47 convention

# v54 SPRITE_FILLW table values — the reframe targets these exactly.
TARGET_FILLW = {"scout": 168, "triplane": 150}


# ------------------------------------------------------------------ helpers
def save(img, path):
    img.save(path, "PNG")
    print("wrote", os.path.relpath(path, ROOT), img.size, img.mode)
    return path


def backup(path):
    """Copy the original to .v62-backup/ before the first overwrite."""
    name = os.path.basename(path)
    dst = os.path.join(BACKUP, name)
    if not os.path.exists(dst) and os.path.exists(path):
        shutil.copy2(path, dst)
    return dst


def alpha_bbox_w(im, threshold=10):
    """Width of the alpha bounding box (the v54 fillW measure)."""
    a = np.asarray(im.split()[3])
    ys, xs = np.where(a > threshold)
    if len(xs) == 0:
        return 0
    return int(xs.max() - xs.min() + 1)


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
    target_fillw, then centre in a 256 square. (v57 method.)"""
    w = alpha_bbox_w(im, threshold)
    if w == 0:
        return im
    scale = target_fillw / w
    nw, nh = max(1, round(im.width * scale)), max(1, round(im.height * scale))
    small = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    canvas.paste(small, ((256 - nw) // 2, (256 - nh) // 2), small)
    return canvas


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


# Luminance stops shared by every palette (v51 convention).
GRAD_L = np.array([0, 35, 60, 85, 110, 135, 160, 185, 210, 230, 255],
                  dtype=np.float32)


def make_grad(rgb_stops):
    """rgb_stops: 11 (r, g, b) tuples, luminance-ordered, one per GRAD_L."""
    arr = np.array(rgb_stops, dtype=np.float32)
    return arr[:, 0], arr[:, 1], arr[:, 2]


# Pfalz D.III line finish: muted olive-brown lozenge field tones — darker
# and browner than the silver factory finish of the 'pfalz' archetype
# plate, so the two Pfalz sets never read as the same crate twice.
PFALZ_LINE = make_grad([
    (42, 40, 24), (64, 62, 34), (82, 78, 42), (96, 92, 52),
    (110, 104, 60), (122, 116, 70), (134, 128, 80), (148, 140, 92),
    (160, 154, 104), (172, 166, 118), (184, 178, 132),
])
# Fokker Dr.I line finish: the streaked olive of a Jasta Dr.I — greener
# than the Pfalz lozenge, uniform as the streaky factory dope was.
DR1_STREAK = make_grad([
    (44, 50, 24), (64, 72, 34), (82, 92, 44), (96, 106, 54),
    (110, 120, 64), (122, 132, 74), (134, 144, 86), (148, 156, 98),
    (160, 168, 112), (172, 180, 126), (184, 190, 140),
])


def recolour_palette(src, grad, warm_max_rg=999, protect_sat_red=True,
                     stretch=True):
    """Recolour a photographic plate by mapping each camo pixel's
    luminance through a palette gradient (v51/v57 method, cloned).
    PROTECTS (never recoloured): near-white, saturated blue, warm tones
    (wooden prop, leather) and — unless protect_sat_red=False —
    saturated red. Near-black (Balkenkreuz crosses) maps to the
    palette's darkest stop and stays dark. Output luminance equals the
    input luminance per pixel, so photographic shading, fabric ribbing
    and panel lines survive untouched."""
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


def build_damaged(level):
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
    backing up the originals first."""
    dst = os.path.join(SPR, prefix + "-level.png")
    backup(dst)
    save(level, dst)
    for name, angle in (("bank-left", BANK_ANGLE), ("bank-right", -BANK_ANGLE)):
        rot = level.rotate(angle, resample=Image.BICUBIC, expand=True)
        posed = fit_into_square(rot, 256)
        dst = os.path.join(SPR, prefix + "-" + name + ".png")
        backup(dst)
        save(posed, dst)
    dmg = build_damaged(level)
    dst = os.path.join(SPR, prefix + "-damaged.png")
    backup(dst)
    save(dmg, dst)
    return level


# ------------------------------------------------------------------ builds
def build_scout():
    """'small' scout -> Pfalz D.III (line finish) <- the project's own
    Pfalz D.III top-down photograph (enemy-pfalz-level.png). Recoloured
    silver -> olive-lozenge field finish; Balkenkreuz crosses survive
    as the palette's darkest stop; prop protected as warm wood."""
    print("scout <- enemy-pfalz-level.png (Pfalz D.III, lozenge field finish)")
    src = Image.open(os.path.join(SPR, "enemy-pfalz-level.png")).convert("RGBA")
    img = recolour_palette(src, PFALZ_LINE)
    level = reframe_to_fillw(img, TARGET_FILLW["scout"])
    return build_set("enemy-scout", level)


def build_triplane():
    """'triplane' elite -> Fokker Dr.I (line finish) <- the project's
    own Dr.I top-down photograph (enemy-dri-level.png). The v57
    treatment reversed: red -> streaked olive via the raw-luminance
    map (a single-colour finish maps to a single palette colour),
    warm cap 80 so the red airframe (r-g ~120-190) is NOT protected
    as 'warm', saturated-red protection OFF because no roundels are
    pasted afterwards — the Balkenkreuz crosses (near-black) survive
    as the palette's darkest stop."""
    print("triplane <- enemy-dri-level.png (Fokker Dr.I, streaked olive)")
    src = Image.open(os.path.join(SPR, "enemy-dri-level.png")).convert("RGBA")
    img = recolour_palette(src, DR1_STREAK, warm_max_rg=80,
                            protect_sat_red=False, stretch=False)
    level = reframe_to_fillw(img, TARGET_FILLW["triplane"])
    return build_set("enemy-triplane", level)


def main():
    build_scout()
    build_triplane()
    print("v62 roster done: scout=Pfalz D.III, triplane=Fokker Dr.I (both German)")


if __name__ == "__main__":
    main()
