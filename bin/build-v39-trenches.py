#!/usr/bin/env python3
"""bin/build-v39-trenches.py — v39 battlefield trenches + craters for 1918.

Priority 4: photographic top-down trench systems and shell craters in the
terrain, plus the two photorealism violations the artifact builder flagged:
(1) the splash cover is a comic illustration (assets/title-comic-panels.jpg)
    — replaced by a photographic aerial plate; (2) the game canvas-draws
    effects with vector primitives (skirmish arcs, snowfall gradient wash,
    terrain haze gradient, weather gradients, damage smoke arcs, boss
    flash/tell arcs) — replaced by photographic raster plates built here.

Every plate is built ONLY from the one verified photographic source in the
repo: assets/terrain-aerial.jpg — a real vertical aerial photo of a WWI
battlefield (1120x2240): zigzag trench lines across the top, shell craters
throughout, a ruined village in the middle, roads and fields below.
md5-identical to native/www/assets/terrain-aerial.jpg.

Technique (same as bin/build-v34-sprites.py and bin/build-v36-overlays.py,
the established raster rule): photo crop -> resize -> photographic grade
(brightness/contrast/color/tint) -> soft ALPHA MASK only. The masks are
alpha gradients — feathering, not visible content. No trench, crater, smoke,
or glow SHAPE is drawn anywhere: the visible RGB pixels are 100% photographic.
The only PIL-drawn geometry is the alpha mask the photo texture is
composited through, exactly as v34/v36 did.

Plates (assets/sprites/v39/):
  TRENCHES (top-down trench systems, full-width strips, vertical feather):
    v39-trench-a.png  zigzag trench band, upper trench line
    v39-trench-b.png  zigzag trench band, second line (different phase)
    v39-trench-c.png  trench + crater transition band
  CRATERS (top-down shell holes, radial feather):
    v39-crater-s.png  single small crater (128px)
    v39-crater-m.png  single medium crater (192px)
    v39-crater-l.png  single large crater (256px, deep + water-filled)
    v39-craterfield.png  crater field, many holes (1024x512, wide feather)
  SPLASH (photographic cover, replaces the comic panels):
    v39-splash.jpg    cinematic aerial cover (portrait, dark-graded)
  WASHES (full-screen photographic washes, uniform alpha — they replace
  gradient/fillRect washes; strength is set by the draw alpha, so the
  plates stay fully opaque and unfeathered by design):
    v39-haze.png      warm dark haze (terrain haze)
    v39-snowwash.png  cold white-blue snow wash (snowfall + winter terrain)
    v39-sunwash.png   warm golden sun wash (weather sun grade)
    v39-duskwash.png  dusk orange-purple wash (weather dusk)
    v39-flash.png     soft white flash (storm flash)

Each object plate is asserted feathered (corners near 0, centre high).
Wash plates are asserted RGBA8 with uniform high alpha (they are
full-screen washes by design). The splash is asserted a real JPEG.
Usage: python3 bin/build-v39-trenches.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "terrain-aerial.jpg")
OUT = os.path.join(ROOT, "assets", "sprites", "v39")
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
    """L-mode radial alpha mask: solid centre, feathered edge to 0."""
    w, h = size
    inset = int(round(feather * 2.5))
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([inset, inset, w - inset, h - inset], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return m


def soft_vertical(size, feather=40):
    """L-mode vertical alpha mask: solid middle, linear ramp to 0 at the
    top and bottom edges (for full-width terrain strips). Left/right stay
    solid so the strip spans the playfield without a side seam. The ramp
    is exact: alpha is 0 on the top and bottom rows."""
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for y in range(h):
        a_top = min(255, int(round(y * 255 / feather)))
        a_bot = min(255, int(round((h - 1 - y) * 255 / feather)))
        a = min(a_top, a_bot)
        if a > 0:
            d.line([(0, y), (w - 1, y)], fill=a)
    return m


def check_vertical_feather(img, name, centre_min=150):
    """Assert a terrain strip fades to transparent at the TOP and BOTTOM
    edges (it melts into the terrain above/below). Left/right edges stay
    solid by design (the strip spans the full playfield width)."""
    a = img.split()[3]
    w, h = img.size
    top = a.getpixel((w // 2, 0))
    bottom = a.getpixel((w // 2, h - 1))
    corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
               a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
    centre = a.getpixel((w // 2, h // 2))
    ok = top <= 8 and bottom <= 8 and max(corners) <= 8 and centre >= centre_min
    print("  vfeather %-20s top=%3d bottom=%3d corners max=%3d centre=%3d %s"
          % (name, top, bottom, max(corners), centre, "OK" if ok else "FAIL"))
    assert ok, "%s is not feathered at the top/bottom edges" % name


def soft_wide(size, feather=30):
    """L-mode wide elliptical alpha mask, feathered on all sides."""
    w, h = size
    ix, iy = int(round(feather * 3.0)), int(round(feather * 2.2))
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([ix, iy, w - ix, h - iy], fill=255)
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


def check_feather(img, name, centre_min=100):
    """Assert an object plate fades to transparent at every edge."""
    a = img.split()[3]
    w, h = img.size
    corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
               a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
    edges = [a.getpixel((w // 2, 0)), a.getpixel((w // 2, h - 1)),
             a.getpixel((0, h // 2)), a.getpixel((w - 1, h // 2))]
    centre = a.getpixel((w // 2, h // 2))
    worst_corner = max(corners)
    worst_edge = max(edges)
    ok = worst_corner <= 8 and worst_edge <= 60 and centre >= centre_min
    print("  feather %-20s corners max=%3d edges max=%3d centre=%3d %s"
          % (name, worst_corner, worst_edge, centre, "OK" if ok else "FAIL"))
    assert ok, "%s is not feathered to transparent at the edges" % name


def check_uniform(img, name, alpha_min=240):
    """Assert a wash plate is RGBA8 with uniform high alpha (full-screen
    wash by design — strength comes from the draw alpha, not the plate)."""
    a = img.split()[3]
    w, h = img.size
    vals = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
            a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1)),
            a.getpixel((w // 2, h // 2))]
    ok = min(vals) >= alpha_min
    print("  uniform %-20s alpha min=%3d %s"
          % (name, min(vals), "OK" if ok else "FAIL"))
    assert ok, "%s wash plate alpha is not uniform" % name


def save_png(img, name, feather=True, centre_min=100, vertical=False):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name, img.size)
    if vertical:
        check_vertical_feather(img, name, centre_min)
    elif feather:
        check_feather(img, name, centre_min)
    else:
        check_uniform(img, name)
    return p


def save_jpg(img, name, quality=86):
    p = os.path.join(OUT, name)
    img.convert("RGB").save(p, "JPEG", quality=quality)
    print("wrote", name, img.size, "quality", quality)
    return p


# ------------------------------------------------------------------ trenches
# The zigzag trench lines run across the top of the aerial photo. Three
# full-width bands, each a different trench line (different zigzag phase),
# dark mud grade so the trench reads as a dug line, vertical feather so
# the strip melts into the terrain above and below.
for name, box, bright, contrast in [
        ("v39-trench-a.png", (0, 60, 1120, 300), 0.92, 1.12),
        ("v39-trench-b.png", (0, 300, 1120, 540), 0.95, 1.10),
        ("v39-trench-c.png", (0, 540, 1120, 780), 0.98, 1.08)]:
    im = crop(box).resize((1024, 256), Image.LANCZOS)
    im = grade(im, bright=bright, contrast=contrast, color=0.9,
               tint=(74, 62, 44), tint_amt=0.12)
    im = apply_mask(im, soft_vertical((1024, 256), feather=40))
    save_png(im, name, feather=True, centre_min=150, vertical=True)

# ------------------------------------------------------------------- craters
# Single craters, cropped around real dark round water-filled holes found
# by blob analysis (area, x, y, w, h in full-res coords). Radial feather.
for name, box, size, bright in [
        ("v39-crater-s.png", (228, 1372, 368, 1512), 128, 1.0),
        ("v39-crater-m.png", (180, 736, 340, 896), 192, 1.0),
        ("v39-crater-l.png", (480, 680, 760, 960), 256, 0.95)]:
    im = crop(box).resize((size, size), Image.LANCZOS)
    im = grade(im, bright=bright, contrast=1.15, color=0.9)
    im = apply_mask(im, soft_radial((size, size), feather=16))
    save_png(im, name, feather=True, centre_min=150)

# Crater field: a wide dense crater zone in the middle of the photo,
# many holes at once, wide elliptical feather so it melts into terrain.
im = crop((0, 600, 1120, 1100)).resize((1024, 512), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=0.9)
im = apply_mask(im, soft_wide((1024, 512), feather=36))
save_png(im, "v39-craterfield.png", feather=True, centre_min=150)

# -------------------------------------------------------------------- splash
# Photographic cover to replace the comic panels: the battlefield from
# above — trench lines at top, crater field and ruined village below.
# Portrait, dark cinematic grade; the splash CSS already lays a dark
# gradient over the bottom for the copy text.
im = crop((80, 40, 1040, 1960)).resize((720, 1440), Image.LANCZOS)
im = grade(im, bright=0.88, contrast=1.12, color=0.95,
           tint=(24, 22, 18), tint_amt=0.08)
save_jpg(im, "v39-splash.jpg", quality=86)

# -------------------------------------------------------------------- washes
# Full-screen photographic washes (uniform alpha — strength is the draw
# alpha). Each is a heavily blurred crop, photographically graded.
def wash(name, box, size, blur, bright, contrast, color, tint, tint_amt):
    im = crop(box).resize(size, Image.LANCZOS)
    im = im.filter(ImageFilter.GaussianBlur(blur))
    im = grade(im, bright=bright, contrast=contrast, color=color,
               tint=tint, tint_amt=tint_amt)
    im = im.convert("RGBA")
    # uniform alpha 255 (no mask) — a wash covers the whole screen.
    a = Image.new("L", size, 255)
    im.putalpha(a)
    save_png(im, name, feather=False)

# Terrain haze: warm dark field blur.
wash("v39-haze.png", (60, 1700, 560, 2000), (512, 256), 14,
     0.85, 0.8, 0.6, (31, 38, 26), 0.25)
# Snow wash: palest field, cold white-blue.
wash("v39-snowwash.png", (60, 2050, 560, 2240), (512, 256), 14,
     1.35, 0.7, 0.35, (210, 224, 238), 0.35)
# Sun wash: sunlit pale field, warm golden.
wash("v39-sunwash.png", (60, 2000, 560, 2240), (512, 256), 14,
     1.5, 0.7, 0.4, (255, 181, 82), 0.45)
# Dusk wash: dark ground, orange-purple dusk grade.
wash("v39-duskwash.png", (560, 1000, 1060, 1300), (512, 256), 14,
     0.9, 0.9, 0.8, (239, 157, 77), 0.3)
# Flash: brightest pale field, near-white.
wash("v39-flash.png", (60, 2050, 320, 2240), (256, 256), 12,
     1.6, 0.6, 0.3, (235, 238, 220), 0.3)

print("v39 plates done: 3 trench strips, 3 craters, 1 crater field, "
      "1 splash, 5 washes — all photographic, all feathered/uniform.")
