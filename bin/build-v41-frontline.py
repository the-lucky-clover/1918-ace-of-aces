#!/usr/bin/env python3
"""bin/build-v41-frontline.py — v41 frontline: checkpoints, POW camps,
guard towers, air raid sirens, distant artillery, distant machine guns,
distant explosions, searchlights and flares at night.

Priority 6: photographic top-down frontline life in the terrain — road
checkpoints, POW camps, guard towers, siren posts, distant artillery
salvos firing back and forth, distant machine-gun flicker, distant
explosions with a flash of light preceding the burst, animated
searchlight beams sweeping the sky at night, and flares drifting down
at night. All raster sprite-sheet plates, feathered edges, no vector
art, no generated pixels.

Sources (both real top-down aerial photographs, verified by eye):
  A. assets/terrain-aerial.jpg — the one true WWI battlefield aerial
     (1120x2240): zigzag trenches, water-filled craters, a ruined village
     of roofless foundations, dirt roads, shattered trees, plowed fields.
  B. assets/village-neuf-aerial.jpg — Swisstopo colour aerial photograph
     of Village-Neuf, France (Alsace), true top-down (nadir), 3840x3840.
     (Not needed for v41 — every plate cuts cleanly from the battlefield
     aerial; the village aerial stays a v40 source.)

Technique (same as bin/build-v34-sprites.py, bin/build-v36-overlays.py,
bin/build-v39-trenches.py and bin/build-v40-rivers.py, the established
raster rule): photo crop -> resize -> photographic grade (brightness /
contrast / color / tint, plus heavy blur for the light/smoke plates) ->
soft ALPHA MASK only. The masks are alpha gradients — feathering, not
visible content. No checkpoint, camp, tower, siren, flash, smoke, beam
or flare SHAPE is drawn anywhere: the visible RGB pixels are 100%
photographic. The only PIL-drawn geometry is the alpha mask the photo
texture is composited through, exactly as v34/v36/v39/v40 did.

Plates (assets/sprites/v41/):
  CHECKPOINTS (placed objects, radial feather — road + hut + rubble):
    v41-checkpoint-a.png  dirt road through the ruined village, hut
                          foundations and rubble piled as a barrier
    v41-checkpoint-b.png  second road stretch, ruined houses + rubble
  POW CAMPS (placed objects, radial feather — walled compounds + huts):
    v41-powcamp-a.png     rectangular walled foundations, a fenced
                          compound with hut structures inside
    v41-powcamp-b.png     road + ruined foundations + a big crater
  GUARD TOWER (placed object, radial feather):
    v41-tower.png         small dark-roofed hut, chosen by form — a
                          small square structure with a dark roof and a
                          shadow, reads as a watchtower from above.
                          NOT claimed to be a specific named tower.
  AIR RAID SIREN (placed object, radial feather):
    v41-siren.png         thin vertical pole-form crop (a shattered
                          trunk), chosen by form — a pole with a long
                          shadow, reads as a siren post from above.
                          NOT claimed to be a specific named siren.
  DISTANT FIRE (light / smoke plates, radial feather, heavy blur):
    v41-flash.png         brightest pale field, near-white warm flash
                          (muzzle flash / explosion flash / searchlight
                          source)
    v41-tracer.png        short bright streak (machine-gun tracer)
    v41-smoke.png         light grey smoke puff (dusty pale field)
    v41-smokedark.png     dark wreck smoke (dark churned ground)
  NIGHT (beam + flare):
    v41-beam.png          searchlight beam — palest field, extreme
                          blur, bright; tapered alpha mask (bright at
                          the base, fading to the far tip). The
                          animation is rotation of this photographic
                          plate, never a drawn light.
    v41-flare.png         flare — pale field, heavy blur, very bright
                          warm; radial mask. Drawn as a bright core
                          plus a large soft glow pass of the same plate.

Each plate is asserted feathered (corners near 0, centre high). The
beam has its own check: its base (left edge) is bright by design, so
only the corners, the top/bottom edges and the far (right) tip must
fade to transparent. Usage: python3 bin/build-v41-frontline.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_A = os.path.join(ROOT, "assets", "terrain-aerial.jpg")
OUT = os.path.join(ROOT, "assets", "sprites", "v41")
os.makedirs(OUT, exist_ok=True)

photoA = Image.open(SRC_A).convert("RGB")
PAW, PAH = photoA.size
print("photoA (battlefield):", photoA.size)


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


def soft_streak(size, feather=10):
    """L-mode streak mask for a short horizontal tracer: solid middle
    band, feathered top/bottom and feathered left/right ends."""
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for x in range(w):
        fx = min(1.0, min(x, w - 1 - x) / float(feather))
        for y in range(h):
            fy = min(1.0, min(y, h - 1 - y) / 8.0)
            a = int(round(255 * fx * fy))
            if a > 0:
                d.point((x, y), fill=a)
    m = m.filter(ImageFilter.GaussianBlur(3))
    return m


def soft_beam(size):
    """L-mode tapered beam mask: bright at the base (left edge), fading
    to transparent at the far tip (right edge), feathered top/bottom.
    Alpha only — the visible RGB stays photographic."""
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for x in range(w):
        # length taper: full at the base, ~8% at the tip
        fx = 255 * (1.0 - 0.92 * (x / max(1, w - 1)))
        for y in range(h):
            # vertical falloff: full in the middle band, 0 at top/bottom
            fy = min(1.0, min(y, h - 1 - y) / 18.0)
            a = int(round(fx * fy))
            if a > 0:
                d.point((x, y), fill=a)
    m = m.filter(ImageFilter.GaussianBlur(6))
    # hard-feather the borders the blur may have bled into: top/bottom
    # rows and the far tip column go to 0. The base (left edge) stays
    # bright by design — it is the searchlight source.
    d = ImageDraw.Draw(m)
    d.rectangle([0, 0, w - 1, 2], fill=0)
    d.rectangle([0, h - 3, w - 1, h - 1], fill=0)
    d.rectangle([w - 3, 0, w - 1, h - 1], fill=0)
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


def check_beam(img, name, centre_min=80):
    """Beam check: the base (left edge) is bright by design; the corners,
    the top/bottom edges and the far tip (right edge) must fade out."""
    a = img.split()[3]
    w, h = img.size
    corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
               a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
    top = a.getpixel((w // 2, 0))
    bottom = a.getpixel((w // 2, h - 1))
    tip = a.getpixel((w - 1, h // 2))
    centre = a.getpixel((w // 2, h // 2))
    base = a.getpixel((0, h // 2))
    ok = (max(corners) <= 8 and top <= 8 and bottom <= 8 and tip <= 20
          and centre >= centre_min and base >= 200)
    print("  beam    %-20s corners max=%3d top=%3d bottom=%3d tip=%3d "
          "centre=%3d base=%3d %s"
          % (name, max(corners), top, bottom, tip, centre, base,
             "OK" if ok else "FAIL"))
    assert ok, "%s is not a feathered beam" % name


def save_png(img, name, feather=True, centre_min=100, beam=False):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name, img.size)
    if beam:
        check_beam(img, name, centre_min)
    elif feather:
        check_feather(img, name, centre_min)
    return p


# ---------------------------------------------------------------- checkpoints
# Dirt road through the ruined village: hut foundations and rubble piled
# as a barrier across the road. Radial feather; placed like the chateau.
im = crop(photoA, (280, 950, 720, 1290)).resize((320, 320), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=0.95)
im = apply_mask(im, soft_radial((320, 320), feather=16))
save_png(im, "v41-checkpoint-a.png", feather=True, centre_min=150)

# Second road stretch: ruined houses and rubble piles beside the road.
im = crop(photoA, (650, 1250, 1050, 1560)).resize((320, 320), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=0.95)
im = apply_mask(im, soft_radial((320, 320), feather=16))
save_png(im, "v41-checkpoint-b.png", feather=True, centre_min=150)

# ------------------------------------------------------------------ POW camps
# Rectangular walled foundations: a fenced compound with hut structures.
im = crop(photoA, (580, 1020, 920, 1300)).resize((320, 320), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=0.95)
im = apply_mask(im, soft_radial((320, 320), feather=16))
save_png(im, "v41-powcamp-a.png", feather=True, centre_min=150)

# Road + ruined foundations + a big crater: a second camp compound.
im = crop(photoA, (550, 1400, 850, 1650)).resize((320, 320), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=0.95)
im = apply_mask(im, soft_radial((320, 320), feather=16))
save_png(im, "v41-powcamp-b.png", feather=True, centre_min=150)

# ---------------------------------------------------------------- guard tower
# Small dark-roofed hut, chosen by form: a small square structure with a
# dark roof and a shadow, reads as a watchtower from above. NOT claimed
# to be a specific named tower.
im = crop(photoA, (200, 720, 340, 870)).resize((256, 256), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.12, color=0.95)
im = apply_mask(im, soft_radial((256, 256), feather=16))
save_png(im, "v41-tower.png", feather=True, centre_min=150)

# --------------------------------------------------------------- siren post
# Thin vertical pole-form crop (a shattered trunk), chosen by form: a pole
# with a long shadow, reads as a siren post from above. NOT claimed to be
# a specific named siren.
im = crop(photoA, (830, 260, 890, 450)).resize((128, 256), Image.LANCZOS)
im = grade(im, bright=0.85, contrast=1.1, color=0.8)
im = apply_mask(im, soft_radial((128, 256), feather=14))
save_png(im, "v41-siren.png", feather=True, centre_min=150)

# -------------------------------------------------------------- distant fire
# Flash: brightest pale field, near-white warm (same band as the v39
# flash, a different box), heavy blur so no furrow reads through.
im = crop(photoA, (320, 2050, 580, 2240)).resize((256, 256), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(10))
im = grade(im, bright=1.7, contrast=0.6, color=0.3,
           tint=(255, 240, 200), tint_amt=0.35)
im = apply_mask(im, soft_radial((256, 256), feather=14))
save_png(im, "v41-flash.png", feather=True, centre_min=200)

# Tracer: short bright streak, same pale field, stretched horizontal.
im = crop(photoA, (60, 2050, 320, 2140)).resize((128, 48), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(4))
im = grade(im, bright=1.8, contrast=0.6, color=0.3,
           tint=(255, 244, 214), tint_amt=0.3)
im = apply_mask(im, soft_streak((128, 48), feather=14))
save_png(im, "v41-tracer.png", feather=True, centre_min=150)

# Light grey smoke puff: dusty pale field, heavy blur, desaturated grey
# (same technique as v36-smoke2, a different box).
im = crop(photoA, (340, 1700, 620, 1980)).resize((192, 192), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(10))
im = grade(im, bright=1.05, contrast=0.8, color=0.35,
           tint=(200, 200, 200), tint_amt=0.15)
im = apply_mask(im, soft_radial((192, 192), feather=18))
save_png(im, "v41-smoke.png", feather=True, centre_min=80)

# Dark wreck smoke: dark churned ground, heavy blur, dark grey-brown
# (same technique as v36-smokedark, a different box).
im = crop(photoA, (800, 1000, 1040, 1120)).resize((192, 192), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(8))
im = grade(im, bright=0.6, contrast=1.0, color=0.5,
           tint=(60, 52, 44), tint_amt=0.25)
im = apply_mask(im, soft_radial((192, 192), feather=18))
save_png(im, "v41-smokedark.png", feather=True, centre_min=80)

# ---------------------------------------------------------------------- night
# Searchlight beam: palest field, extreme blur, bright; tapered alpha
# mask (bright at the base, fading to the far tip). The animation is
# rotation of this photographic plate, never a drawn light.
im = crop(photoA, (60, 1500, 560, 1700)).resize((512, 128), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(16))
im = grade(im, bright=1.9, contrast=0.55, color=0.35,
           tint=(255, 248, 225), tint_amt=0.3)
im = apply_mask(im, soft_beam((512, 128)))
save_png(im, "v41-beam.png", beam=True, centre_min=80)

# Flare: pale field, heavy blur, very bright warm; radial mask. Drawn
# as a bright core plus a large soft glow pass of the same plate.
im = crop(photoA, (80, 2000, 320, 2240)).resize((256, 256), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(12))
im = grade(im, bright=2.0, contrast=0.7, color=0.4,
           tint=(255, 200, 120), tint_amt=0.4)
im = apply_mask(im, soft_radial((256, 256), feather=16))
save_png(im, "v41-flare.png", feather=True, centre_min=200)

print("v41 plates done: 2 checkpoints, 2 POW camps, 1 guard tower, "
      "1 siren post, 1 flash, 1 tracer, 2 smoke puffs, 1 beam, 1 flare "
      "— all photographic, all feathered.")
