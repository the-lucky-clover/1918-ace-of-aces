#!/usr/bin/env python3
"""bin/build-v40-rivers.py — v40 rivers, roads, bridges + village buildings.

Priority 5: photographic top-down rivers, roads and bridges, plus
photographic top-down buildings — houses, a tavern, churches, schools and
a stadium. All raster sprite-sheet plates, feathered edges, no vector art,
no generated pixels.

Sources (both real top-down aerial photographs, verified by eye):
  A. assets/terrain-aerial.jpg — the one true WWI battlefield aerial
     (1120x2240): dirt roads, a muddy water channel, ruined village houses.
  B. assets/village-neuf-aerial.jpg — Swisstopo colour aerial photograph of
     Village-Neuf, France (Alsace), true top-down (nadir), 3840x3840,
     via Wikimedia Commons ("Village-Neuf - Swisstopo colour aerial
     photograph 280030.tif"). A real French village on the Rhine: the river
     itself, road bridges over it, dense village houses with red/brown
     rooftops, village streets, a sports-field oval (stadium), and larger
     village buildings (tavern / churches / schools) in the village centre.
     Crops stay clear of the Swisstopo frame markings (red WILD label and
     green caption strip on the edges). The 3840px original is used so
     individual buildings read at plate scale (the 1280px thumbnail was
     too coarse to tell a church from a house).

Technique (same as bin/build-v34-sprites.py, bin/build-v36-overlays.py and
bin/build-v39-trenches.py, the established raster rule): photo crop ->
resize -> photographic grade (brightness/contrast/color/tint) -> soft ALPHA
MASK only. The masks are alpha gradients — feathering, not visible content.
No river, road, bridge, roof or wall SHAPE is drawn anywhere: the visible
RGB pixels are 100% photographic. The only PIL-drawn geometry is the alpha
mask the photo texture is composited through, exactly as v34/v36/v39 did.

Plates (assets/sprites/v40/):
  RIVERS + ROADS (full-width terrain strips, vertical feather — they scroll
  with the ground like the v39 trench strips):
    v40-river.png       Rhine river stretch (Village-Neuf), wide plate
    v40-river-mud.png   muddy water channel (battlefield photo), blue-grey
    v40-road.png        village street strip (Village-Neuf)
    v40-road-dirt.png   dirt road crossroads (battlefield photo)
  BRIDGE (placed object, radial feather):
    v40-bridge.png      road bridge over the Rhine (Village-Neuf)
  BUILDINGS (placed objects, radial feather — drawn like the chateau):
    v40-house-a.png     village house cluster (rooftops)
    v40-house-b.png     village house cluster, second area
    v40-house-ruin.png  ruined house foundations (battlefield photo)
    v40-tavern.png      larger inn building on a main street
    v40-church-a.png    church-form building (long nave + tower)
    v40-church-b.png    church-form building, second area
    v40-school-a.png    school-form building complex with yard
    v40-school-b.png    school-form building complex, second area
    v40-stadium.png     sports-field oval with running track

Each plate is asserted feathered (corners near 0, centre high). Strips use
the vertical-feather check (top/bottom fade, left/right solid so the strip
spans the playfield). Usage: python3 bin/build-v40-rivers.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_A = os.path.join(ROOT, "assets", "terrain-aerial.jpg")
SRC_B = os.path.join(ROOT, "assets", "village-neuf-aerial.jpg")
OUT = os.path.join(ROOT, "assets", "sprites", "v40")
os.makedirs(OUT, exist_ok=True)

photoA = Image.open(SRC_A).convert("RGB")
photoB = Image.open(SRC_B).convert("RGB")
PAW, PAH = photoA.size
PBW, PBH = photoB.size
print("photoA (battlefield):", photoA.size)
print("photoB (Village-Neuf):", photoB.size)


def crop(photo, box):
    """Crop, clamped to the photo."""
    PW, PH = photo.size
    x0, y0, x1, y1 = box
    x0 = max(0, min(PW - 2, x0)); y0 = max(0, min(PH - 2, y0))
    x1 = max(x0 + 2, min(PW, x1)); y1 = max(y0 + 2, min(PH, y1))
    return photo.crop((x0, y0, x1, y1))


def soft_radial(size, feather=16):
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
    solid so the strip spans the playfield without a side seam."""
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


def check_vertical_feather(img, name, centre_min=150):
    """Assert a terrain strip fades to transparent at the TOP and BOTTOM
    edges (it melts into the terrain above/below). Left/right stay solid."""
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


def save_png(img, name, feather=True, centre_min=100, vertical=False):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name, img.size)
    if vertical:
        check_vertical_feather(img, name, centre_min)
    elif feather:
        check_feather(img, name, centre_min)
    return p


# -------------------------------------------------------------------- rivers
# Rhine river stretch (Village-Neuf): a wide diagonal band of dark
# blue-green water with banks. Wide elliptical feather so it melts into
# the terrain on all sides; drawn as a terrain feature.
# (Hi-res source, 3840x3840: crop scaled x3 from the verified 1280px box.)
im = crop(photoB, (240, 0, 2100, 1860)).resize((1024, 512), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.12, color=1.05,
           tint=(28, 52, 66), tint_amt=0.10)
im = apply_mask(im, soft_wide((1024, 512), feather=36))
save_png(im, "v40-river.png", feather=True, centre_min=150)

# Muddy water channel (battlefield photo): the winding water-filled ditch
# at the top of the aerial. Graded cool blue-grey so it reads as a river,
# not mud. Full-width strip, vertical feather.
im = crop(photoA, (0, 120, 1120, 390)).resize((1024, 256), Image.LANCZOS)
im = grade(im, bright=1.02, contrast=1.1, color=0.75,
           tint=(52, 78, 96), tint_amt=0.28)
im = apply_mask(im, soft_vertical((1024, 256), feather=40))
save_png(im, "v40-river-mud.png", feather=True, centre_min=150, vertical=True)

# --------------------------------------------------------------------- roads
# Village street strip (Village-Neuf): a horizontal band of village
# streets with houses on both sides. Full-width strip, vertical feather.
# (Hi-res source: crop scaled x3 from the verified 1280px box.)
im = crop(photoB, (180, 2400, 3540, 3180)).resize((1024, 256), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.08, color=0.95)
im = apply_mask(im, soft_vertical((1024, 256), feather=40))
save_png(im, "v40-road.png", feather=True, centre_min=150, vertical=True)

# Dirt road crossroads (battlefield photo): the main dirt road running
# through the ruined village crossroads. Full-width strip, vertical feather.
im = crop(photoA, (0, 1080, 1120, 1340)).resize((1024, 256), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=0.9,
           tint=(122, 104, 78), tint_amt=0.08)
im = apply_mask(im, soft_vertical((1024, 256), feather=40))
save_png(im, "v40-road-dirt.png", feather=True, centre_min=150, vertical=True)

# -------------------------------------------------------------------- bridge
# Road bridge over the Rhine (Village-Neuf): the road crossing the river
# near the top of the aerial. Radial feather; drawn as a placed object
# where a road meets a river.
# (Hi-res source: crop scaled x3 from the verified 1280px box.)
im = crop(photoB, (720, 180, 1500, 960)).resize((320, 320), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=1.0)
im = apply_mask(im, soft_radial((320, 320), feather=16))
save_png(im, "v40-bridge.png", feather=True, centre_min=150)

# ------------------------------------------------------------------ buildings
# Village house clusters (Village-Neuf): dense red/brown rooftops.
# (Hi-res source. house-a scaled x3 from the verified 1280px box;
# house-b recut — the first cut caught the railway yard, so this one is
# in the dense village centre, left of the river and the railway.)
for name, box in [
        ("v40-house-a.png", (450, 2250, 1230, 3030)),
        ("v40-house-b.png", (1200, 2100, 1600, 2500))]:
    im = crop(photoB, box).resize((256, 256), Image.LANCZOS)
    im = grade(im, bright=1.0, contrast=1.1, color=1.0)
    im = apply_mask(im, soft_radial((256, 256), feather=16))
    save_png(im, name, feather=True, centre_min=150)

# Ruined house foundations (battlefield photo): a ruined building cluster
# in the war zone — reads as a ruined house.
im = crop(photoA, (250, 1000, 560, 1310)).resize((256, 256), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.12, color=0.9)
im = apply_mask(im, soft_radial((256, 256), feather=16))
save_png(im, "v40-house-ruin.png", feather=True, centre_min=150)

# Tavern: a village building block with a larger inn-form building
# (Village-Neuf centre, south of the square). Cropped tight on the
# village buildings. Recut many times — the first cuts caught the river,
# the canal, or modern industrial roofs; this one is village buildings
# with a larger inn-form building. It reads as a village inn block.
im = crop(photoB, (1300, 2700, 1500, 2900)).resize((320, 320), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=1.0)
im = apply_mask(im, soft_radial((320, 320), feather=16))
save_png(im, "v40-tavern.png", feather=True, centre_min=150)

# Churches: the most church-form buildings in the village centre — long
# nave-form buildings by the town square. Cropped TIGHT so the long
# building dominates the plate (a wide cut reads as the square, not the
# church). Recut — the first cuts caught the river, the second read as
# houses / the square. These are real Village-Neuf village buildings,
# chosen by form (long nave + tower-like projection); they read as
# churches from above. They are NOT claimed to be a specific named church.
for name, box in [
        ("v40-church-a.png", (1420, 2220, 1580, 2380)),
        ("v40-church-b.png", (1480, 2400, 1600, 2520))]:
    im = crop(photoB, box).resize((320, 320), Image.LANCZOS)
    im = grade(im, bright=1.0, contrast=1.1, color=1.0)
    im = apply_mask(im, soft_radial((320, 320), feather=16))
    save_png(im, name, feather=True, centre_min=150)

# Schools: larger building complexes with sports grounds (Village-Neuf,
# south village — a school building with tennis courts, a running track
# and a field). Recut — the first cuts caught the railway yard, the
# industrial area and the river port.
for name, box in [
        ("v40-school-a.png", (950, 3050, 1200, 3300)),
        ("v40-school-b.png", (1100, 3200, 1300, 3400))]:
    im = crop(photoB, box).resize((320, 320), Image.LANCZOS)
    im = grade(im, bright=1.0, contrast=1.1, color=1.0)
    im = apply_mask(im, soft_radial((320, 320), feather=16))
    save_png(im, name, feather=True, centre_min=150)

# Stadium: the sports-field oval with its running track (Village-Neuf).
# Recut — the first cut caught the water-treatment plant; this one is
# centred on the oval itself.
im = crop(photoB, (950, 1130, 1300, 1480)).resize((512, 320), Image.LANCZOS)
im = grade(im, bright=1.02, contrast=1.08, color=1.0)
im = apply_mask(im, soft_radial((512, 320), feather=16))
save_png(im, "v40-stadium.png", feather=True, centre_min=150)

print("v40 plates done: 2 rivers, 2 roads, 1 bridge, 3 houses, 1 tavern, "
      "2 churches, 2 schools, 1 stadium — all photographic, all feathered.")
