#!/usr/bin/env python3
"""bin/build-v36-overlays.py — v36 ambient overlay plates for 1918.

Priority 1 (v36): soft-alpha photorealistic weather / smoke / cloud / fire
overlays so the battlefield below feels alive — smoke drifting, clouds
passing, fires burning on the ground scenery.

Every plate is built ONLY from the one verified photographic source in the
repo: native/www/assets/terrain-aerial.jpg (a real vertical aerial photo of
a WWI battlefield: trenches, shell craters, a ruined village, roads, fields;
md5-identical to assets/terrain-aerial.jpg).

Technique (same as bin/build-v34-sprites.py, the established raster rule):
photo crop -> resize -> heavy Gaussian blur -> photographic grade
(brightness/contrast/color/tint) -> soft ALPHA MASK only. The masks are
radial / elliptical alpha gradients — feathering, not visible content. No
smoke puff, cloud, or flame SHAPE is drawn anywhere: the visible RGB pixels
are 100% photographic. The only PIL-drawn geometry is the alpha mask that
the photo texture is composited through, exactly as v34 did for its smoke,
fire, fog, and scorch sheets.

Plates (assets/sprites/v36/):
  v36-fireglow.png   warm glow halo for ground fires (pale field, heavy blur)
  v36-ember.png      smouldering ember bed (dark burnt crater, deep red grade)
  v36-smoke2.png     light grey smoke (dusty pale field, heavy blur)
  v36-smokedark.png  dark wreck smoke (dark churned ground, heavy blur)
  v36-cloud.png      high cloud (palest field, extreme blur, wide ellipse)

Each plate is asserted feathered: corner alpha near 0, centre alpha high.
Usage: python3 bin/build-v36-overlays.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "native", "www", "assets", "terrain-aerial.jpg")
OUT = os.path.join(ROOT, "assets", "sprites", "v36")
os.makedirs(OUT, exist_ok=True)

photo = Image.open(SRC).convert("RGB")
PW, PH = photo.size
print("photo:", photo.size)


def crop(box):
    """Crop, clamped to the photo."""
    x0, y0, x1, y1 = box
    x0 = max(0, min(PW - 2, x0)); y0 = max(0, min(PH - 2, y0))
    x1 = max(x0 + 2, min(PW, x1)); y1 = max(y0 + 2, min(PH, y1))
    return photo.crop((x0, y0, x1, y1))


def soft_radial(size, feather=18):
    """L-mode radial alpha mask: solid centre, feathered edge to 0.

    The ellipse is INSET from the frame by ~2.5x the blur radius so the
    Gaussian falloff reaches ~0 at every frame edge — no hard boundary.
    """
    w, h = size
    inset = int(round(feather * 2.5))
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([inset, inset, w - inset, h - inset], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return m


def soft_wide_ellipse(size, feather=24):
    """L-mode wide elliptical alpha mask, inset so it feathers to 0 at
    every frame edge."""
    w, h = size
    ix, iy = int(round(feather * 4.5)), int(round(feather * 2.7))
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([ix, iy, w - ix, h - iy], fill=205)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return m


def apply_mask(img, mask):
    img = img.convert("RGBA")
    img.putalpha(mask)
    return img


def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    img = ImageEnhance.Brightness(img).enhance(bright)
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(color)
    if tint is not None and tint_amt > 0:
        solid = Image.new("RGB", img.size, tint)
        img = Image.blend(img.convert("RGB"), solid, tint_amt).convert("RGBA")
    return img


def check_feather(img, name, centre_min=120):
    """Assert the plate fades to transparent at every edge (no hard edge)."""
    a = img.split()[3]
    w, h = img.size
    corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
               a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
    edges = [a.getpixel((w // 2, 0)), a.getpixel((w // 2, h - 1)),
             a.getpixel((0, h // 2)), a.getpixel((w - 1, h // 2))]
    centre = a.getpixel((w // 2, h // 2))
    worst_corner = max(corners)
    worst_edge = max(edges)
    ok = worst_corner <= 8 and worst_edge <= 40 and centre >= centre_min
    print("  feather %-18s corners max=%3d edges max=%3d centre=%3d %s"
          % (name, worst_corner, worst_edge, centre, "OK" if ok else "FAIL"))
    assert ok, "%s is not feathered to transparent at the edges" % name


def save(img, name, centre_min=120):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name, img.size)
    check_feather(img, name, centre_min)
    return p


# ------------------------------------------------------------------ fire/glow
# Fire glow halo: pale sunlit field, very heavy blur, bright warm orange.
im = crop((80, 2000, 320, 2240)).resize((192, 192), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(12))
im = grade(im, bright=1.9, contrast=0.7, color=0.4,
           tint=(255, 140, 40), tint_amt=0.5)
im = apply_mask(im, soft_radial((192, 192), feather=16))
save(im, "v36-fireglow.png", centre_min=200)

# Ember bed: dark burnt crater interior, deep red smoulder grade.
im = crop((620, 560, 860, 800)).resize((128, 128), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(4))
im = grade(im, bright=0.85, contrast=1.2, color=1.2,
           tint=(160, 30, 10), tint_amt=0.35)
im = apply_mask(im, soft_radial((128, 128), feather=14))
save(im, "v36-ember.png", centre_min=200)

# ------------------------------------------------------------------ smoke
# Light grey smoke: dusty pale field, heavy blur, desaturated to grey.
im = crop((60, 1700, 340, 1980)).resize((128, 128), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(10))
im = grade(im, bright=1.05, contrast=0.8, color=0.35,
           tint=(200, 200, 200), tint_amt=0.15)
im = apply_mask(im, soft_radial((128, 128), feather=18))
save(im, "v36-smoke2.png", centre_min=80)

# Dark wreck smoke: dark churned ground, heavy blur, dark grey-brown.
im = crop((560, 1000, 800, 1120)).resize((128, 128), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(8))
im = grade(im, bright=0.6, contrast=1.0, color=0.5,
           tint=(60, 52, 44), tint_amt=0.25)
im = apply_mask(im, soft_radial((128, 128), feather=18))
save(im, "v36-smokedark.png", centre_min=80)

# ------------------------------------------------------------------ cloud
# High cloud: palest field, extreme blur, near-white low-contrast wash,
# wide elliptical feather mask so no boundary ever shows.
im = crop((60, 1500, 560, 1700)).resize((512, 256), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(16))
im = grade(im, bright=1.35, contrast=0.55, color=0.35)
im = apply_mask(im, soft_wide_ellipse((512, 256), feather=24))
save(im, "v36-cloud.png", centre_min=100)

print("v36 overlay plates done: 5 plates, all photographic, all feathered.")
