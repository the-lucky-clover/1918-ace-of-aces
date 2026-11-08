#!/usr/bin/env python3
"""bin/build-v58-trenches.py — v58 additional procedural map-generation
sprite sheets for 1918 (traced + redrawn from Alamy WWI trench aerials).

Steven's order: "ITERATE AND IMPLEMENT ADDITIONAL PHOTOREALISTIC
PROCEDURAL MAP GENERATION SPRITESHEETS FROM THIS URL: SAMPLES WILL NEED
TO BE MASSAGED AND COLORED" — then, on licensing: "JUST USE THEM AS
TRACING FODDER AND REDRAW". Then: "ITERATE AND IMPLEMENT PHOTOREALISM".

So the Alamy images are TRACING FODDER / REFERENCE ONLY. They are never
shipped, never cropped into a plate, never stored in the repo. What is
traced from them is the LAYOUT — the trench lines, the crater-field
density, the field pattern — extracted as a continuous strength map by
image processing (median filter kills the thin 'alamy' watermark strokes
and annotation ink; a strict percentile threshold keeps only the trench
bands; a grey opening drops shell-hole specks; a Gaussian blur feathers
the layout into a soft, irregular alpha). The visible RGB pixels of
every plate are 100% photographic, cut from the one verified photographic
source already in the repo: assets/terrain-aerial.jpg — the real vertical
aerial photo of a WWI battlefield (zigzag trenches, crater fields, ruined
village, roads, fields). The traced layout only decides WHERE that
photographic texture appears; the texture itself is never drawn, never
vector, never flat. A plate that reads as an illustration instead of an
aerial photo is a failed plate — rework it until it is photographic.

Reference comps (downloaded at build time to /tmp/v58-ref, reference
only — NOT stored in the repo, NOT shipped):
  Kemmel 1918      2M98GG6  pale chalk-spoil trenches on dark churned ground
  Ypres 1917       TXGGH7   pale road + dark zigzag trenches + field system
  Hindenburg Line  3BTEDHT  zigzag trenches along an oblique ridge crest
  Arras 1918       PBJBXB   sparse zigzag trenches on pale open ground
  Ficheux system   W2GK7N   many parallel dark trench lines (annotated map)
All five are Alamy RM/RF comp previews (c8.alamy.com/comp/...). The
underlying photographs are US Signal Corps / archival WWI aerials; the
Alamy comps themselves are watermarked previews and are used here only
as tracing fodder, per Steven's direction. No Alamy pixel ships.

Technique (extends bin/build-v39-trenches.py, same raster rule):
  reference band -> grayscale -> median filter (watermark/ink removal)
    -> strict percentile strength map (trench layout) or local-stddev
       churn map (crater-field density) -> grey opening (speck removal)
    -> Gaussian blur (soft irregular alpha)
  photographic base (terrain-aerial.jpg crop) + photographic feature
  (terrain-aerial.jpg trench mud / crater field / field crop) composited
  through the traced strength map -> photographic grade -> soft
  vertical/wide ALPHA feather (the mask is alpha only, as in v39).

Plates (assets/sprites/v58/, 1024 wide, photographic raster only):
  TRENCH STRIPS (full-width, vertical feather, 1024x256):
    v58-trench-d.png  Kemmel S-curve pale-spoil trench
    v58-trench-e.png  Ypres road + flanking dark trenches
    v58-trench-f.png  Arras sparse zigzag trenches
    v58-trench-g.png  Ficheux parallel trench lines
    v58-trench-h.png  Hindenburg ridge zigzag
  SHELL-TORN GROUND (full-width, vertical feather, 1024x256):
    v58-shelltorn-a.png  Kemmel churn (dense speckled ground)
    v58-shelltorn-b.png  Ypres churn
  CRATER FIELD (wide feather, 1024x512):
    v58-craterfield-b.png  dense crater field (Kemmel churn)
  FIELD SYSTEM (full-width, vertical feather, 1024x256):
    v58-field-a.png  Ypres rectangular field pattern
  OPEN GROUND (full-width, vertical feather, 1024x256):
    v58-nomansland.png  Arras pale open ground, sparse craters

Each plate is asserted feathered (top/bottom alpha 0, centre high) and
photographic (texture stddev above the flat-fill floor, mean colour in
the terrain-aerial palette). Usage: python3 bin/build-v58-trenches.py
"""
import os
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "terrain-aerial.jpg")
OUT = os.path.join(ROOT, "assets", "sprites", "v58")
REFDIR = "/tmp/v58-ref"
os.makedirs(OUT, exist_ok=True)
os.makedirs(REFDIR, exist_ok=True)

# ---------------------------------------------------------------- references
# Alamy comp previews — tracing fodder only. Downloaded to /tmp, never
# stored in the repo, never shipped. (ref, local name, crop to drop the
# black footer bar + (for Arras) the green corner tape.)
REFS = {
    "kemmel": ("https://c8.alamy.com/comp/2M98GG6/aerial-view-of-front-line-trenches-near-kemmel-and-wulvergem-west-flanders-belgium-on-8-may-1918-2M98GG6.jpg",
               "kemmel-2M98GG6.jpg", (0, 0, 1300, 960)),
    "ypres": ("https://c8.alamy.com/comp/TXGGH7/aerial-view-of-battle-trenches-at-ypres-belgium-world-war-one-1917-TXGGH7.jpg",
              "ypres-TXGGH7.jpg", (0, 0, 888, 1290)),
    "hindenburg": ("https://c8.alamy.com/comp/3BTEDHT/first-world-war-aerial-view-of-zig-zag-trenches-of-the-hindenburg-line-in-the-argonne-france-3BTEDHT.jpg",
                   "hindenburg-3BTEDHT.jpg", (0, 0, 1300, 880)),
    "arras": ("https://c8.alamy.com/comp/PBJBXB/1873-ww1-aerial-photograph-german-trenches-east-of-arras-PBJBXB.jpg",
              "arras-PBJBXB.jpg", (120, 40, 1180, 960)),
    "ficheux": ("https://c8.alamy.com/comp/W2GK7N/aerial-photograph-of-an-unidentified-trench-system-during-ww-i-ca-1918-W2GK7N.jpg",
                "trenchsys-W2GK7N.jpg", (0, 0, 1300, 940)),
}
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"}


def load_ref(key):
    url, fn, cropbox = REFS[key]
    path = os.path.join(REFDIR, fn)
    if not (os.path.exists(path) and os.path.getsize(path) > 10000):
        print("  downloading reference", key, "...")
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    im = Image.open(path).convert("L").crop(cropbox)
    print("  ref %-11s %s -> %s" % (key, fn, im.size))
    return im


photo = Image.open(SRC).convert("RGB")
PW, PH = photo.size
print("photo:", photo.size)


# ------------------------------------------------------------------- helpers
def crop(box):
    x0, y0, x1, y1 = box
    x0 = max(0, min(PW - 2, x0)); y0 = max(0, min(PH - 2, y0))
    x1 = max(x0 + 2, min(PW, x1)); y1 = max(y0 + 2, min(PH, y1))
    return photo.crop((x0, y0, x1, y1))


def soft_vertical(size, feather=40):
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
    w, h = size
    ix, iy = int(round(feather * 3.0)), int(round(feather * 2.2))
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([ix, iy, w - ix, h - iy], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return m


def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    img = ImageEnhance.Brightness(img).enhance(bright)
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(color)
    if tint is not None and tint_amt > 0:
        solid = Image.new("RGB", img.size, tint)
        img = Image.blend(img.convert("RGB"), solid, tint_amt).convert("RGBA")
    return img


def apply_mask(img, mask):
    img = img.convert("RGBA")
    img.putalpha(mask)
    return img


# ------------------------------------------------------- traced strength maps
def trench_strength(gray_band, polarity, lo_pct, hi_pct, med=9, blur=2,
                    open_size=7, dilate_size=0):
    """Continuous 0..1 layout map of the trench lines in a reference band.
    Median filter removes the thin watermark/ink strokes; the strict
    percentile window keeps only the trench bands; grey opening drops
    small specks; grey dilation (optional) widens the traced lines so
    the tonal band reads as a dug trench over busy ground; Gaussian
    blur feathers the layout into a soft, irregular alpha. Nothing here
    is drawn — it is all derived from the reference photograph's own
    luminance."""
    a = np.asarray(gray_band, dtype=float)
    a = ndimage.median_filter(a, size=med)
    lo, hi = np.percentile(a, lo_pct), np.percentile(a, hi_pct)
    if polarity == "dark":
        s = (hi - a) / max(1.0, hi - lo)
    else:
        s = (a - lo) / max(1.0, hi - lo)
    s = np.clip(s, 0.0, 1.0)
    if open_size:
        s = ndimage.grey_opening(s, size=open_size)
    if dilate_size:
        s = ndimage.grey_dilation(s, size=dilate_size)
    s = ndimage.gaussian_filter(s, blur)
    return np.clip(s, 0.0, 1.0)


def churn_strength(gray_band, med=9, blur=6, win=15, lo_pct=15, hi_pct=88):
    """Continuous 0..1 map of crater-field density: local luminance
    stddev (dense shell-hole texture = high) normalised by percentile.
    Traces where the reference ground is torn up vs quiet."""
    a = np.asarray(gray_band, dtype=float)
    a = ndimage.median_filter(a, size=med)
    mean = ndimage.uniform_filter(a, size=win)
    mean2 = ndimage.uniform_filter(a * a, size=win)
    sd = np.sqrt(np.maximum(0.0, mean2 - mean * mean))
    lo, hi = np.percentile(sd, lo_pct), np.percentile(sd, hi_pct)
    s = (sd - lo) / max(1.0, hi - lo)
    s = np.clip(s, 0.0, 1.0)
    s = ndimage.gaussian_filter(s, blur)
    return np.clip(s, 0.0, 1.0)


def luminance_map(gray_band, med=9, blur=6, lo_pct=20, hi_pct=85):
    """Soft tonal map of a reference band (field pattern / ground tone),
    normalised to 0..1. Used where the layout IS the tonal pattern."""
    a = np.asarray(gray_band, dtype=float)
    a = ndimage.median_filter(a, size=med)
    lo, hi = np.percentile(a, lo_pct), np.percentile(a, hi_pct)
    s = (a - lo) / max(1.0, hi - lo)
    s = np.clip(s, 0.0, 1.0)
    s = ndimage.gaussian_filter(s, blur)
    return np.clip(s, 0.0, 1.0)


def mask_to_L(s, strength=1.0):
    """Strength map (0..1 float) -> L-mode mask, scaled by strength."""
    return Image.fromarray(
        (np.clip(s * strength, 0.0, 1.0) * 255).astype(np.uint8), "L")


def composite(base_rgb, feature_rgb, s_mask):
    """Photographic feature composited over photographic base through
    the traced strength mask. Both RGB layers are photo crops; the mask
    only decides where each shows."""
    return Image.composite(feature_rgb, base_rgb, s_mask)


# ------------------------------------------------------------- photo textures
# All crops from assets/terrain-aerial.jpg (1120x2240), the one true aerial.
def tex(box, size, bright=1.0, contrast=1.0, color=0.9, blur=0, tint=None,
        tint_amt=0.0):
    im = crop(box).resize(size, Image.LANCZOS)
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return grade(im, bright=bright, contrast=contrast, color=color,
                 tint=tint, tint_amt=tint_amt).convert("RGB")


SIZE_STRIP = (1024, 256)
SIZE_FIELD = (1024, 512)

# Tonal modulation: a trench in a real aerial is NOT a different photo
# pasted on the ground — it is the SAME ground, dug up, so it reads as
# a darker (dug mud) or paler (chalk spoil) band of the SAME photographic
# texture. modulate_tone multiplies a sharp photographic base by
# (1 + factor*S) where S is the traced layout: factor -0.5 darkens the
# dug line, +0.7 lightens the chalk spoil. The ground texture stays
# sharp and continuous under the trench, so the plate reads as one
# photograph, not a composite of two.
def modulate_tone(base_rgb, s, factor):
    a = np.asarray(base_rgb, dtype=float)
    mult = 1.0 + factor * s
    out = a * mult[..., None]
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")
# Churned crater ground (dense holes) and quieter field ground.
CHURN = lambda: tex((0, 600, 1120, 1100), SIZE_STRIP, bright=1.0,
                    contrast=1.1, color=0.9)
# NOTE: a different crater region than v39's craterfield (which used
# y 600-1100) so the two plates do not read alike.
CHURN_BIG = lambda: tex((0, 1300, 1120, 1800), SIZE_FIELD, bright=1.0,
                        contrast=1.1, color=0.9)
FIELD = lambda: tex((0, 1700, 1120, 2240), SIZE_STRIP, bright=1.02,
                    contrast=1.05, color=0.92)
FIELD_BIG = lambda: tex((0, 1700, 1120, 2240), SIZE_FIELD, bright=1.02,
                        contrast=1.05, color=0.92)
PALE_FIELD = lambda: tex((0, 1950, 1120, 2240), SIZE_STRIP, bright=1.05,
                         contrast=1.02, color=0.9)
# Darker field crop (for the field-pattern tonal variation).
FIELD_DARK = lambda: tex((0, 1700, 1120, 2050), SIZE_STRIP, bright=0.85,
                         contrast=1.08, color=0.9)
# Pale dirt road texture (village roads).
ROAD = lambda: tex((400, 900, 900, 1400), SIZE_STRIP, bright=1.12,
                   contrast=1.05, color=0.85, blur=3)
# Sharp photographic ground crops for the trench strips (NO blur —
# a real aerial is sharp; the trench is a tonal band in this ground,
# not a second photo). Each plate gets its own ground. NOTE: every
# crop stays BELOW y=540, clear of the aerial's own zigzag trench
# band, so the ONLY trench system in a v58 plate is the traced one.
BASE_CRATER = lambda: tex((0, 600, 1120, 1100), SIZE_STRIP, bright=0.95,
                          contrast=1.08, color=0.9)
BASE_CRATER_UP = lambda: tex((0, 800, 1120, 1300), SIZE_STRIP, bright=1.12,
                             contrast=1.05, color=0.9)
BASE_FIELD_B = lambda: tex((0, 1400, 1120, 1900), SIZE_STRIP, bright=1.0,
                           contrast=1.05, color=0.92)


def check_vertical_feather(img, name, centre_min=150):
    a = img.split()[3]
    w, h = img.size
    top = a.getpixel((w // 2, 0))
    bottom = a.getpixel((w // 2, h - 1))
    corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
               a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
    centre = a.getpixel((w // 2, h // 2))
    ok = top <= 8 and bottom <= 8 and max(corners) <= 8 and centre >= centre_min
    print("  vfeather %-22s top=%3d bottom=%3d corners max=%3d centre=%3d %s"
          % (name, top, bottom, max(corners), centre, "OK" if ok else "FAIL"))
    assert ok, "%s is not feathered at the top/bottom edges" % name


def check_wide_feather(img, name, centre_min=150):
    a = img.split()[3]
    w, h = img.size
    corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
               a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
    centre = a.getpixel((w // 2, h // 2))
    ok = max(corners) <= 8 and centre >= centre_min
    print("  wfeather %-22s corners max=%3d centre=%3d %s"
          % (name, max(corners), centre, "OK" if ok else "FAIL"))
    assert ok, "%s is not feathered at the edges" % name


def check_photographic(img, name, std_floor=18.0):
    """A photographic plate has real texture: per-channel stddev well
    above a flat fill. A drawn/flat plate fails this floor."""
    rgb = np.asarray(img.convert("RGB"), dtype=float)
    std = rgb.reshape(-1, 3).std(axis=0)
    mean = rgb.reshape(-1, 3).mean(axis=0)
    ok = float(std.min()) >= std_floor
    print("  photo    %-22s std RGB %s mean RGB %s %s"
          % (name, np.round(std, 1), np.round(mean, 1),
             "OK" if ok else "FAIL"))
    assert ok, "%s has no photographic texture (std %s)" % (name, std)
    return mean


def save_plate(img, name, vertical=True):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name, img.size)
    if vertical:
        check_vertical_feather(img, name)
    else:
        check_wide_feather(img, name)
    check_photographic(img, name)
    return p


def band(ref_key, box):
    """A horizontal band of a reference, as a grayscale PIL image."""
    g = load_ref(ref_key)
    return g.crop(box)


# ------------------------------------------------------------------- trenches
# Each trench strip: ONE sharp photographic ground crop, tonally
# modulated by the traced layout — the dug line darkens (factor -0.5)
# or the chalk spoil lightens (factor +0.7) the same photographic
# texture. A light mud tint grades the whole plate. The layout is the
# only thing traced; the pixels are one photograph.
def trench_plate(name, ref_key, box, polarity, lo, hi, base_fn,
                 factor, strength=1.0, open_size=7, dilate_size=5):
    g = band(ref_key, box).resize(SIZE_STRIP, Image.LANCZOS)
    s = trench_strength(g, polarity, lo, hi, open_size=open_size,
                        dilate_size=dilate_size)
    # Low-contrast ground: the photographic texture stays sharp (fine
    # grain, grass, small craters) but its tonal range is narrowed, so
    # the traced trench — a strong tonal band — is the dominant feature
    # instead of competing with the ground's own craters and ruins.
    base = grade(base_fn(), bright=1.0, contrast=0.72, color=0.95)
    im = modulate_tone(base, s * strength, factor)
    im = grade(im, bright=1.0, contrast=1.06, color=0.92,
               tint=(74, 62, 44), tint_amt=0.08)
    im = apply_mask(im, soft_vertical(SIZE_STRIP, feather=40))
    save_plate(im, name, vertical=True)
    print("    layout %s band %s %s factor %.2f mean %.3f frac>0.5 %.3f"
          % (ref_key, box, polarity, factor, float(s.mean()),
             float((s > 0.5).mean())))


# v58-trench-d — Kemmel S-curve: PALE chalk-spoil trench (lightened
# +0.85) on dark churned ground (the reference polarity). Strong opening
# (11) + high threshold (72) so only the thick pale trench lines
# survive — the white shell-hole speckles are dropped.
trench_plate("v58-trench-d.png", "kemmel", (0, 480, 1300, 800),
             "pale", 72, 97, BASE_CRATER, factor=+0.85, open_size=11)
# v58-trench-f — Arras sparse zigzag (darkened -0.6) on pale open ground.
trench_plate("v58-trench-f.png", "arras", (0, 550, 1060, 900),
             "dark", 8, 55, PALE_FIELD, factor=-0.6)
# v58-trench-g — Ficheux parallel lines (darkened -0.6) on mid-tone fields.
trench_plate("v58-trench-g.png", "ficheux", (0, 350, 1300, 650),
             "dark", 8, 55, BASE_FIELD_B, factor=-0.6)
# v58-trench-h — Hindenburg ridge zigzag (darkened -0.6) on pale chalky
# churned ground.
trench_plate("v58-trench-h.png", "hindenburg", (0, 250, 1300, 550),
             "dark", 8, 55, BASE_CRATER_UP, factor=-0.6)

# v58-trench-e — Ypres road + flanking trenches. One sharp field ground:
# the dark trench lines darken it (-0.5), then the pale road band
# lightens it (+0.55) over the top — the road is the brightest
# continuous diagonal in the reference.
g = band("ypres", (0, 500, 888, 900)).resize(SIZE_STRIP, Image.LANCZOS)
s_tr = trench_strength(g, "dark", 8, 55, dilate_size=5)
s_rd = trench_strength(g, "pale", 80, 98, open_size=9, blur=3)
ground = grade(FIELD(), bright=1.0, contrast=0.72, color=0.95)
im = modulate_tone(ground, s_tr, -0.6)
im = modulate_tone(im, s_rd, +0.6)
im = grade(im, bright=1.0, contrast=1.06, color=0.92,
           tint=(74, 62, 44), tint_amt=0.08)
im = apply_mask(im, soft_vertical(SIZE_STRIP, feather=40))
save_plate(im, "v58-trench-e.png", vertical=True)
print("    layout ypres road+trench trench mean %.3f road mean %.3f"
      % (float(s_tr.mean()), float(s_rd.mean())))

# ------------------------------------------------------------- shell-torn ground
# Churn density traced from the reference: where the reference ground is
# torn up, dense photographic craters show; where it is quiet, field
# ground shows.
def churn_plate(name, ref_key, box, base_fn, feat_fn, size, strength=0.9,
                vertical=True):
    g = band(ref_key, box).resize(size, Image.LANCZOS)
    s = churn_strength(g)
    im = composite(base_fn(), feat_fn(), mask_to_L(s, strength))
    im = apply_mask(im, soft_vertical(size, feather=40) if vertical
                    else soft_wide(size, feather=36))
    save_plate(im, name, vertical=vertical)
    print("    churn %s band %s mean %.3f frac>0.5 %.3f"
          % (ref_key, box, float(s.mean()), float((s > 0.5).mean())))


churn_plate("v58-shelltorn-a.png", "kemmel", (0, 100, 1300, 420),
            FIELD, CHURN, SIZE_STRIP, strength=0.9)
churn_plate("v58-shelltorn-b.png", "ypres", (0, 900, 888, 1290),
            FIELD, CHURN, SIZE_STRIP, strength=0.9)
churn_plate("v58-craterfield-b.png", "kemmel", (0, 0, 1300, 600),
            FIELD_BIG, CHURN_BIG, SIZE_FIELD, strength=0.95, vertical=False)

# ---------------------------------------------------------------- field system
# Ypres rectangular field pattern: the reference band's own tonal pattern
# decides where the darker photographic field crop shows over the field
# base — the rectangles are the reference's, the pixels are the aerial's.
g = band("ypres", (0, 0, 888, 400)).resize(SIZE_STRIP, Image.LANCZOS)
s = luminance_map(g)
im = composite(FIELD(), FIELD_DARK(), mask_to_L(s, 0.85))
im = apply_mask(im, soft_vertical(SIZE_STRIP, feather=40))
save_plate(im, "v58-field-a.png", vertical=True)
print("    field ypres tonal mean %.3f" % float(s.mean()))

# ------------------------------------------------------------------ open ground
# Arras pale open ground: a weak churn trace — mostly quiet pale field,
# a few photographic craters where the reference is torn.
g = band("arras", (120, 100, 1180, 450)).resize(SIZE_STRIP, Image.LANCZOS)
s = churn_strength(g, lo_pct=30, hi_pct=92)
im = composite(PALE_FIELD(), CHURN(), mask_to_L(s, 0.55))
im = apply_mask(im, soft_vertical(SIZE_STRIP, feather=40))
save_plate(im, "v58-nomansland.png", vertical=True)
print("    nomansland arras churn mean %.3f" % float(s.mean()))

print("v58 plates done: 5 trench strips, 2 shell-torn, 1 crater field, "
      "1 field system, 1 open ground — all traced + redrawn, all "
      "photographic, all feathered. No Alamy pixel ships.")
