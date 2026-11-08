#!/usr/bin/env python3
"""v62 — recover the title / manual / flight-desk art that was referenced by
the game but never committed in the early build, plus the one missing
damaged pose (balloon). Photographic sources only — no drawn art, no
generated pixels. Every output is a crop / grade / composite of a real
photograph already in the project's own library:

  assets/ace-of-aces-mobile-cover.png   (splash cover art)
      <- artifact library splash-frame-one.jpg: a period glass-plate
         photograph of a SPAD XIII (US 94th Aero markings, fuselage "25")
         on its aerodrome. Composed onto a portrait canvas over its own
         blurred, darkened self (standard cover-bleed), so the whole
         aircraft fits the tall splash slot.
  assets/historic-spad-xiii.jpg         (flight-desk archive snapshot)
      <- the same period plate, full frame, plate border kept — it IS
         the historic photograph the desk snapshot pretends to be.
  assets/flight-desk-airmen-spad-xiii.png
      <- artifact library splash-frame-two.jpg: period photograph of
         five airmen standing before two biplanes on the aerodrome.
  assets/flight-desk-pilot-mechanics-spad.png
      <- tight crop of splash-frame-one on the nose: propeller, engine
         cowling, landing gear and the pilot at the cockpit — the
         engine a mechanic's hands live on.
  assets/flight-desk-pilot-spad-fuselage.png
      <- crop of splash-frame-one on the rear fuselage: the "25", the
         US star insignia and the tail unit.
  assets/field-almanac-spad-xiii.png    (Field Almanac figure)
      <- assets/spad-player.png, Steven's own supplied photograph of
         the Hat-in-the-Ring SPAD XIII (French five-colour camouflage,
         white "1" on the upper wing — the aircraft the player flies).
         A wide band across wings + cockpit, composited on the almanac
         figure's own dark stock colour (#2b261c).
  assets/sprites/enemy-balloon-damaged.png
      <- assets/sprites/enemy-balloon-level.png treated with the exact
         v51/v57 damaged method (bin/build-v57-enemy.py build_damaged):
         scorch grade + photographic v36 smoke / ember / fireglow
         plates composited over the envelope. The balloon was the only
         one of the 26 banked sets missing its damaged pose.

Source library (read-only): ~/workspace/ts-spaces/1918-ace-of-aces/assets/
(the artifact's photo library — real photographs from the project's own
history). The comic panels in that library were NOT used: this build is
photographic from pillar to post, per the standing doctrine.

Also copied verbatim: assets/fokker-dr1.glb from the same library. The
game's preload fetch for it is inert (no GLTF loader ships), but the file
existed in the old wrapper; restoring it silences one 404. The other two
preloaded GLBs (enemy-ace, gotha-iv) exist nowhere and stay missing —
they render nothing either way.
"""

import os
import shutil

from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
SPR = os.path.join(ASSETS, "sprites")
V36 = os.path.join(SPR, "v36")
LIB = os.path.expanduser("~/workspace/ts-spaces/1918-ace-of-aces/assets")

FRAME_ONE = os.path.join(LIB, "splash-frame-one.jpg")   # SPAD XIII plate
FRAME_TWO = os.path.join(LIB, "splash-frame-two.jpg")   # airmen group
SPAD = os.path.join(ASSETS, "spad-player.png")          # Steven's SPAD
BALLOON = os.path.join(SPR, "enemy-balloon-level.png")


def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    """Grade RGB only; alpha preserved exactly. (v51/v57 convention.)"""
    has_alpha = img.mode == "RGBA"
    alpha = img.split()[3] if has_alpha else None
    rgb = img.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(bright)
    rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    rgb = ImageEnhance.Color(rgb).enhance(color)
    if tint is not None and tint_amt > 0:
        rgb = Image.blend(rgb, Image.new("RGB", rgb.size, tint), tint_amt)
    out = rgb.convert("RGBA")
    if alpha is not None:
        out.putalpha(alpha)
    return out


def save(img, path):
    img.save(path)
    print("wrote", os.path.relpath(path, ROOT), img.size)


# ---------------------------------------------------------------- cover
def build_cover():
    """Portrait 900x1350. The period plate (interior 1164x840) is laid at
    full width over its own blurred + darkened enlargement, so the tall
    splash slot is filled with photographic pixels edge to edge and the
    whole SPAD stays in frame under object-fit:cover."""
    src = Image.open(FRAME_ONE).convert("RGB")
    # well inside the glass-plate border — also clear of the plate's
    # handwritten corner mark (x<90, y<60 in the source)
    plate = src.crop((100, 55, 1170, 845))
    plate = grade(plate, bright=1.02, contrast=1.07,
                  tint=(38, 30, 18), tint_amt=0.10).convert("RGB")
    W, H = 900, 1350
    back = plate.resize((W, int(plate.height * W / plate.width)),
                        Image.LANCZOS)
    back = back.resize((W, H), Image.LANCZOS)                # stretch-fill
    back = back.filter(ImageFilter.GaussianBlur(28))
    back = ImageEnhance.Brightness(back).enhance(0.42)
    canvas = back
    front = plate.resize((W, int(plate.height * W / plate.width)),
                         Image.LANCZOS)                      # 900x649
    canvas.paste(front, (0, (H - front.height) // 2))
    # melt the top and bottom into the splash's dark field (#070705):
    # composite toward the dark shade by distance from the middle band
    shade = Image.new("RGB", (W, H), (7, 7, 5))
    import numpy as np
    yy = np.arange(H, dtype=np.float32)
    a = np.clip((np.abs(yy - H / 2) - (H / 2 - 320)) / 320.0, 0, 1) ** 1.6
    alpha = Image.fromarray((a[:, None] * 235).astype("uint8"), "L").resize((W, H))
    canvas = Image.composite(shade, canvas, alpha)
    save(canvas, os.path.join(ASSETS, "ace-of-aces-mobile-cover.png"))


def build_historic():
    """The full period plate, border and all — the desk's archive snapshot
    is sepia-treated by CSS; the file stays the honest photograph."""
    src = Image.open(FRAME_ONE).convert("RGB")
    src = grade(src, contrast=1.04).convert("RGB")
    save(src, os.path.join(ASSETS, "historic-spad-xiii.jpg"))


def build_airmen():
    src = Image.open(FRAME_TWO).convert("RGB")
    save(src, os.path.join(ASSETS, "flight-desk-airmen-spad-xiii.png"))


def build_mechanics():
    """Nose crop: propeller, cowling, gear, pilot at the cockpit."""
    src = Image.open(FRAME_ONE).convert("RGB")
    crop = src.crop((185, 165, 665, 645))
    crop = grade(crop, contrast=1.06).convert("RGB")
    save(crop, os.path.join(ASSETS, "flight-desk-pilot-mechanics-spad.png"))


def build_fuselage():
    """Rear-fuselage crop: the '25', the star insignia, the tail."""
    src = Image.open(FRAME_ONE).convert("RGB")
    crop = src.crop((545, 285, 1135, 665))
    crop = grade(crop, contrast=1.06).convert("RGB")
    save(crop, os.path.join(ASSETS, "flight-desk-pilot-spad-fuselage.png"))


def build_almanac():
    """Steven's SPAD photograph, wide band, on the figure's dark stock."""
    src = Image.open(SPAD).convert("RGBA")
    corner = src.getpixel((5, 5))[3]
    assert corner < 10, f"spad-player.png corner alpha {corner} != transparent"
    band = src.crop((0, 290, src.width, 1020))
    stock = Image.new("RGBA", band.size, (43, 38, 28, 255))   # #2b261c
    stock.alpha_composite(band, (0, 0))
    out = stock.convert("RGB").resize((1260, 548), Image.LANCZOS)
    save(out, os.path.join(ASSETS, "field-almanac-spad-xiii.png"))


def build_balloon_damaged():
    """The v51/v57 damaged method, verbatim, centred on the envelope."""
    level = Image.open(BALLOON).convert("RGBA")
    dmg = grade(level, bright=0.55, contrast=1.15, color=0.7,
                tint=(30, 22, 14), tint_amt=0.25)
    smoke = Image.open(os.path.join(V36, "v36-smokedark.png")) \
        .convert("RGBA").resize((90, 90), Image.LANCZOS)
    ember = Image.open(os.path.join(V36, "v36-ember.png")) \
        .convert("RGBA").resize((36, 36), Image.LANCZOS)
    glow = Image.open(os.path.join(V36, "v36-fireglow.png")) \
        .convert("RGBA").resize((70, 70), Image.LANCZOS)
    for (cx, cy, s, al_) in ((128, 105, 90, 200), (100, 155, 70, 170),
                             (160, 140, 70, 170)):
        puff = smoke.copy()
        if s != 90:
            puff = puff.resize((s, s), Image.LANCZOS)
        puff.putalpha(puff.split()[3].point(lambda v: int(v * al_ / 255)))
        dmg.alpha_composite(puff, (cx - s // 2, cy - s // 2))
    for (cx, cy) in ((118, 92), (140, 124), (108, 148), (150, 168)):
        dmg.alpha_composite(ember.copy(), (cx - 18, cy - 18))
    g2 = glow.copy()
    g2.putalpha(g2.split()[3].point(lambda v: int(v * 0.45)))
    dmg.alpha_composite(g2, (128 - 35, 112 - 35))
    save(dmg, os.path.join(SPR, "enemy-balloon-damaged.png"))


def main():
    build_cover()
    build_historic()
    build_airmen()
    build_mechanics()
    build_fuselage()
    build_almanac()
    build_balloon_damaged()
    glb_src = os.path.join(LIB, "fokker-dr1.glb")
    glb_dst = os.path.join(ASSETS, "fokker-dr1.glb")
    shutil.copyfile(glb_src, glb_dst)
    print("copied", os.path.relpath(glb_dst, ROOT),
          os.path.getsize(glb_dst), "bytes (inert preload, restored)")


if __name__ == "__main__":
    main()
