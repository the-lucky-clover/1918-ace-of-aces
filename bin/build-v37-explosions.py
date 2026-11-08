#!/usr/bin/env python3
"""bin/build-v37-explosions.py — v37 photorealistic kill-explosion frames.

Priority 2 (v37): when an enemy is destroyed, the kill should look like a
real explosion — a white-hot flash, an orange fireball blooming, dark smoke
rolling, embers falling — not a cartoon puff and not a code-drawn star.

Every frame is built ONLY from photographic source already in the repo:
  - the v34 fire strip (assets/sprites/v34/v34-fire.png, 4 photographic
    flame frames) and v34-flash.png (photographic flash plate);
  - the v36 smoke/ember plates (assets/sprites/v36/v36-smokedark.png,
    v36-smoke2.png, v36-ember.png — themselves crops of the one true aerial
    photograph, native/www/assets/terrain-aerial.jpg).
Technique (same as bin/build-v34-sprites.py and bin/build-v36-overlays.py,
the established raster rule): photo crop -> resize -> heavy Gaussian blur
-> photographic grade (brightness/contrast/color/tint) -> soft ALPHA MASK
only. The masks are radial alpha gradients — feathering, not visible
content. No fireball, flame, smoke puff, or debris shape is drawn anywhere:
the visible RGB pixels are 100% photographic. The only PIL-drawn geometry
is the alpha mask the photo texture is composited through, and the fixed
seeded ember-fleck positions (placements, not shapes).

Frames (assets/sprites/v37/, 256x256 RGBA, 8 frames, ~0.65-0.9s of play):
  v37-explosion-0.png  FLASH — near-white hot bloom (v34-flash)
  v37-explosion-1.png  FIREBALL I — small orange fireball (v34-fire f0)
  v37-explosion-2.png  FIREBALL II — growing fireball (v34-fire f1)
  v37-explosion-3.png  FIREBALL III — full fireball, deep orange (v34-fire f2)
  v37-explosion-4.png  FIRE+SMOKE — dark smoke base, warm core (smokedark + fire f3)
  v37-explosion-5.png  SMOKE — dark smoke billowing (v36-smokedark)
  v37-explosion-6.png  SMOKE+EMBERS — grey smoke with ember flecks (smoke2 + ember)
  v37-explosion-7.png  EMBERS FADE — dying embers, low alpha (v36-ember)

Each frame is asserted feathered: corner alpha near 0, centre alpha high.
Usage: python3 bin/build-v37-explosions.py
"""
import os
import random
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "v37")
os.makedirs(OUT, exist_ok=True)

FIRE = Image.open(os.path.join(ROOT, "assets", "sprites", "v34", "v34-fire.png")).convert("RGB")
FLASH = Image.open(os.path.join(ROOT, "assets", "sprites", "v34", "v34-flash.png")).convert("RGB")
SMOKE = Image.open(os.path.join(ROOT, "assets", "sprites", "v34", "v34-smoke.png")).convert("RGB")
SMOKEDARK = Image.open(os.path.join(ROOT, "assets", "sprites", "v36", "v36-smokedark.png")).convert("RGB")
SMOKE2 = Image.open(os.path.join(ROOT, "assets", "sprites", "v36", "v36-smoke2.png")).convert("RGB")
EMBER = Image.open(os.path.join(ROOT, "assets", "sprites", "v36", "v36-ember.png")).convert("RGB")
print("sources: fire", FIRE.size, "flash", FLASH.size, "smoke", SMOKE.size,
      "smokedark", SMOKEDARK.size, "smoke2", SMOKE2.size, "ember", EMBER.size)


def fire_frame(i):
    """One 128x128 frame of the v34 fire strip (4 frames side by side)."""
    return FIRE.crop((i * 128, 0, (i + 1) * 128, 128))


def soft_radial(size, feather=20, fill=255):
    """L-mode radial alpha mask: solid centre, feathered edge to 0.

    The ellipse is INSET from the frame by ~2.5x the blur radius so the
    Gaussian falloff reaches ~0 at every frame edge — no hard boundary.
    """
    w, h = size
    inset = int(round(feather * 2.5))
    inset = min(inset, max(0, min(w, h) // 2 - 1))
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([inset, inset, w - inset, h - inset], fill=fill)
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


def frame_stats(img, name):
    """Print mean luminance and mean red so the flash->fire->smoke arc is visible."""
    g = img.convert("L")
    px = list(g.getdata())
    mean_lum = sum(px) / len(px)
    r = img.convert("RGB").split()[0]
    mean_r = sum(r.getdata()) / (img.size[0] * img.size[1])
    a = img.split()[3]
    alpha_mean = sum(a.getdata()) / (img.size[0] * img.size[1])
    print("  stats %-20s lum=%5.1f red=%5.1f alpha=%5.1f" % (name, mean_lum, mean_r, alpha_mean))
    return mean_lum


def check_feather(img, name, centre_min=100):
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


def save(img, name, centre_min=100):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name, img.size)
    frame_stats(img, name)
    check_feather(img, name, centre_min)
    return p


SIZE = (256, 256)

# 0 — FLASH: near-white hot bloom from the photographic flash plate.
f0 = FLASH.resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(5))
f0 = grade(f0, bright=1.9, contrast=1.15, color=0.25)
f0 = apply_mask(f0, soft_radial(SIZE, feather=22, fill=255))
save(f0, "v37-explosion-0.png")

# 1 — FIREBALL I: small orange fireball from v34-fire frame 0.
f1 = fire_frame(0).resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(4))
f1 = grade(f1, bright=1.2, contrast=1.25, color=1.5, tint=(255, 120, 20), tint_amt=0.22)
f1 = apply_mask(f1, soft_radial(SIZE, feather=20, fill=255))
save(f1, "v37-explosion-1.png")

# 2 — FIREBALL II: growing fireball from v34-fire frame 1.
f2 = fire_frame(1).resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(4))
f2 = grade(f2, bright=1.15, contrast=1.3, color=1.5, tint=(255, 110, 15), tint_amt=0.24)
f2 = apply_mask(f2, soft_radial(SIZE, feather=20, fill=255))
save(f2, "v37-explosion-2.png")

# 3 — FIREBALL III: full fireball, deep orange-red, from v34-fire frame 2.
f3 = fire_frame(2).resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(5))
f3 = grade(f3, bright=1.05, contrast=1.35, color=1.45, tint=(220, 70, 10), tint_amt=0.26)
f3 = apply_mask(f3, soft_radial(SIZE, feather=20, fill=255))
save(f3, "v37-explosion-3.png")

# 4 — FIRE+SMOKE: dark smoke base (v36-smokedark) with a warm fire core
# (v34-fire frame 3) composited into the centre through a soft mask.
# Both layers are photographic; the mask is feathering only.
base4 = SMOKEDARK.resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(6))
base4 = grade(base4, bright=0.95, contrast=1.1, color=0.9)
core4 = fire_frame(3).resize((150, 150), Image.LANCZOS).filter(ImageFilter.GaussianBlur(3))
core4 = grade(core4, bright=1.1, contrast=1.3, color=1.5, tint=(230, 90, 15), tint_amt=0.22)
core_mask = soft_radial((150, 150), feather=14, fill=255)
base4.paste(core4, (53, 53), core_mask)
f4 = apply_mask(base4, soft_radial(SIZE, feather=20, fill=245))
save(f4, "v37-explosion-4.png")

# 5 — SMOKE: dark smoke billowing, from the v36 dark-smoke plate.
f5 = SMOKEDARK.resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(7))
f5 = grade(f5, bright=0.9, contrast=1.05, color=0.85)
f5 = apply_mask(f5, soft_radial(SIZE, feather=22, fill=225))
save(f5, "v37-explosion-5.png")

# 6 — SMOKE+EMBERS: grey smoke (v36-smoke2) with ember flecks — small crops
# of the v36 ember plate pasted at fixed seeded positions through soft masks.
# Positions are placements only; every visible pixel is photographic.
f6 = SMOKE2.resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(6))
f6 = grade(f6, bright=0.95, contrast=1.05, color=0.9)
rng = random.Random(19181111)
for _ in range(6):
    ex = rng.randint(40, 180)
    ey = rng.randint(40, 180)
    es = rng.randint(26, 44)
    fleck = EMBER.resize((es, es), Image.LANCZOS).filter(ImageFilter.GaussianBlur(2))
    fleck = grade(fleck, bright=1.25, contrast=1.2, color=1.3)
    f6.paste(fleck, (ex, ey), soft_radial((es, es), feather=6, fill=235))
f6 = apply_mask(f6, soft_radial(SIZE, feather=22, fill=215))
save(f6, "v37-explosion-6.png")

# 7 — EMBERS FADE: dying embers, low alpha, from the v36 ember plate.
f7 = EMBER.resize(SIZE, Image.LANCZOS).filter(ImageFilter.GaussianBlur(8))
f7 = grade(f7, bright=0.75, contrast=1.0, color=0.7)
f7 = apply_mask(f7, soft_radial(SIZE, feather=24, fill=150))
save(f7, "v37-explosion-7.png", centre_min=40)

print("v37 explosion frames done: 8 plates in", OUT)
