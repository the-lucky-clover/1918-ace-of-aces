#!/usr/bin/env python3
"""bin/build-v61-secrets.py — v61 secrets-package plates for 1918.

WHAT THIS BUILDS (photographic material only — grades and masks over
real photographic pixels, never drawn art):

1. THE BLACK SPAD SET (assets/sprites/v61/player-shadow-*.png, 256x256)
   The challenger airframe: the game's own 1P SPAD XIII photographic set
   (assets/sprites/player-spad-{level,bank-left,bank-right,damaged}.png,
   themselves rebuilt in v38 from the user's SPAD photograph
   assets/spad-player.png) re-graded to a black livery. Per-pixel
   luminance is preserved and mapped into a deep blue-black range, so
   every photographic detail — fabric ribbing, roundels, the fuselage
   numeral — survives as a tonal ghost under the black. Alpha is copied
   untouched: the silhouette is the photograph's own.

2. KILLER-CLOUD PLATES (assets/sprites/v61/storm-a.png, storm-b.png)
   Two thunderhead plates cut from the v59 cloud-sea photograph
   (assets/sprites/v59/v59-cloudsea.jpg — NASA ISS073-E-0028091, public
   domain; see bin/build-v59-cloudsea.py). Crops are darkened hard
   (x0.36, slight blue shift) so they read as storm heads against the
   bright sea, and given a soft feathered elliptical alpha mask
   (mask only — the visible RGB is the photograph's own).

3. DISTANT FLYOVER SILHOUETTES (fly-zeppelin.png, fly-bomber.png)
   The v48 Zeppelin plate (assets/sprites/v48/v48-zeppelin.png) and the
   enemy bomber level plate (assets/sprites/enemy-bomber-level.png),
   each graded down to a near-black distance silhouette; alpha kept.

4. THE CUT-IN PLATE (assets/sprites/v61/contact-cutin.jpg, 440x330)
   A tight crop of the nose of the user's SPAD photograph
   (assets/spad-player.png): propeller, cowling, twin guns and the
   cockpit rim — the engine-start moment, as photographed on the real
   airframe the game already flies. Warm period grade, gentle vignette.

LICENCES: the SPAD photograph is the user's own, already shipped in
this game since v38. The cloud-sea photograph is NASA (public domain).
The Zeppelin and bomber plates are the game's own photographic plates
from earlier builds (v48 / v38 lines). No new third-party material.

Re-running reproduces the same outputs.
Usage: python3 bin/build-v61-secrets.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(SPR, "v61")
os.makedirs(OUT, exist_ok=True)


def lum_img(im):
    return im.convert("RGB").convert("L")


def grade_black_spad(src_path, dst_path):
    im = Image.open(src_path).convert("RGBA")
    lum = lum_img(im)
    # map luminance into a deep blue-black range (max ~ (36,42,58))
    r = lum.point(lambda v: int(v * 36 / 255))
    g = lum.point(lambda v: int(v * 42 / 255))
    b = lum.point(lambda v: int(v * 58 / 255))
    dark = Image.merge("RGB", (r, g, b)).convert("RGBA")
    dark.putalpha(im.split()[3])
    dark.save(dst_path)
    print("built", os.path.relpath(dst_path, ROOT), dark.size)


def grade_silhouette(src_path, dst_path):
    im = Image.open(src_path).convert("RGBA")
    lum = lum_img(im)
    # near-black with a whisper of tonal variation from the photograph
    r = lum.point(lambda v: int(8 + v * 10 / 255))
    g = lum.point(lambda v: int(10 + v * 12 / 255))
    b = lum.point(lambda v: int(15 + v * 18 / 255))
    sil = Image.merge("RGB", (r, g, b)).convert("RGBA")
    sil.putalpha(im.split()[3])
    sil.save(dst_path)
    print("built", os.path.relpath(dst_path, ROOT), sil.size)


def storm_plate(src, box, dst_path):
    im = Image.open(src).convert("RGB").crop(box)
    im = im.resize((512, 256), Image.LANCZOS)
    # darken toward storm tone while keeping the photograph's structure:
    # a gentle power curve, not a flat crush, plus a slight blue shift
    def curve(mult):
        return lambda v: min(255, int(255 * ((v / 255) ** 1.12) * mult))
    r, g, b = im.split()
    r = r.point(curve(0.50))
    g = g.point(curve(0.54))
    b = b.point(curve(0.62))
    dark = Image.merge("RGB", (r, g, b)).convert("RGBA")
    mask = Image.new("L", dark.size, 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([14, 18, dark.size[0] - 14, dark.size[1] - 18], fill=242)
    mask = mask.filter(ImageFilter.GaussianBlur(34))
    dark.putalpha(mask)
    dark.save(dst_path)
    print("built", os.path.relpath(dst_path, ROOT), dark.size)


def contact_plate():
    src = Image.open(os.path.join(ROOT, "assets", "spad-player.png")).convert("RGB")
    # nose: propeller arc, cowling, twin guns, cockpit rim (of 1680x1296)
    im = src.crop((598, 0, 1088, 368)).resize((440, 330), Image.LANCZOS)
    r, g, b = im.split()
    r = r.point(lambda v: min(255, int(v * 1.05)))
    g = g.point(lambda v: int(v * 0.99))
    b = b.point(lambda v: int(v * 0.88))
    im = Image.merge("RGB", (r, g, b))
    # gentle vignette
    vig = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(vig)
    d.ellipse([-90, -70, im.size[0] + 90, im.size[1] + 70], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(60))
    black = Image.new("RGB", im.size, (4, 4, 6))
    im = Image.composite(im, black, vig)
    dst = os.path.join(OUT, "contact-cutin.jpg")
    im.save(dst, quality=88)
    print("built", os.path.relpath(dst, ROOT), im.size)


for pose in ("level", "bank-left", "bank-right", "damaged"):
    grade_black_spad(
        os.path.join(SPR, "player-spad-%s.png" % pose),
        os.path.join(OUT, "player-shadow-%s.png" % pose),
    )

sea = os.path.join(SPR, "v59", "v59-cloudsea.jpg")
storm_plate(sea, (460, 55, 1140, 395), os.path.join(OUT, "storm-a.png"))
storm_plate(sea, (60, 40, 740, 380), os.path.join(OUT, "storm-b.png"))

grade_silhouette(os.path.join(SPR, "v48", "v48-zeppelin.png"), os.path.join(OUT, "fly-zeppelin.png"))
grade_silhouette(os.path.join(SPR, "enemy-bomber-level.png"), os.path.join(OUT, "fly-bomber.png"))

contact_plate()
print("v61 plates done")
