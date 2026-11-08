#!/usr/bin/env python3
"""bin/build-v48-zeppelin.py — v48 L-33 Zeppelin plates for 1918.

Destructible Zeppelin components (armored MG battlestations, fuel cells,
gondolas, Maybach engine air props) + before/after battle damage plates.

Photographic material ONLY — no generated pixels, no vector art, no
downloaded sprites. Every plate is a crop / grade / blur / mask of a real
photograph already on disk:
- assets/terrain-aerial.jpg (the one true battlefield aerial)
- assets/spad-player.png (the real SPAD photo — fabric ribbing only)
- assets/sprites/v42/v42-staaken.png (real Maybach prop blades)

Outputs: assets/sprites/v48/*.png
- v48-zeppelin.png (440x150): rebuilt L-33 hull. Same planform shape as the
  v34 plate (ellipse hull + 2 gondola rects) so all geometry is unchanged,
  but the envelope texture is rebuilt smooth: heavily blurred aerial graded
  to a warm grey-tan envelope tone + the v38 photographic fabric-ribbing
  luminance overlay (cut from the SPAD wing). The v34 plate's cratered-field
  texture read as a patch of ground, not an envelope; this one reads as a
  clean airship envelope — the pristine BEFORE state.
- v48-fuelcover.png (52x32): fuel-cell hatch cover, cut from the new hull
  plate itself (same texture, graded slightly darker) so it reads as an
  envelope panel/hatch.
- v48-prop.png (56x56): spinning Maybach prop disc. A real Staaken prop
  blade (thin wooden blade, nose of the v42 Staaken plate) rotationally
  blurred — the blade rotated in 10-degree steps and averaged, so every
  pixel comes from the real photograph. Reads as a spinning prop disc.
- v48-tear.png (64x44): torn gas-cell hole — a real dark crater from the
  aerial, graded very dark, ragged feathered edge. Drawn where a fuel cell
  blew, so a mauled L-33 shows torn fabric.

The only PIL-drawn shapes are alpha MASKS (the hull silhouette, soft
circles) that photographic texture is composited through — the same rule
as the v34 build. Re-running the script reproduces the same outputs.
Usage: python3 bin/build-v48-zeppelin.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
V48 = os.path.join(SPR, "v48")
os.makedirs(V48, exist_ok=True)

AERIAL = os.path.join(ROOT, "assets", "terrain-aerial.jpg")
SPAD1 = os.path.join(ROOT, "assets", "spad-player.png")
STAAKEN = os.path.join(SPR, "v42", "v42-staaken.png")

photo = Image.open(AERIAL).convert("RGB")
PW, PH = photo.size
print("aerial:", photo.size)


def crop(box):
    """Crop the aerial, clamped."""
    x0, y0, x1, y1 = box
    x0 = max(0, min(PW - 2, x0)); y0 = max(0, min(PH - 2, y0))
    x1 = max(x0 + 2, min(PW, x1)); y1 = max(y0 + 2, min(PH, y1))
    return photo.crop((x0, y0, x1, y1))


def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    img = ImageEnhance.Brightness(img).enhance(bright)
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(color)
    if tint is not None and tint_amt > 0:
        solid = Image.new("RGB", img.size, tint)
        img = Image.blend(img.convert("RGB"), solid, tint_amt).convert("RGBA")
    return img


def save(img, name):
    p = os.path.join(V48, name)
    img.save(p, "PNG")
    print("wrote", name, img.size, img.mode)
    return p


# ------------------------------------------------- photographic fabric detail
# High-frequency luminance detail (fabric ribbing + grain) cut from the SPAD
# photo's upper wing — copied from bin/build-v38-sprites.py (same function,
# same crop). Grayscale, centred on 128, blended as a luminance-only overlay.
def build_fabric_detail():
    spad = Image.open(SPAD1).convert("RGB")
    wing = spad.crop((200, 480, 456, 736))
    grey = wing.convert("L")
    blur = grey.filter(ImageFilter.GaussianBlur(3))
    g = np.asarray(grey).astype(np.float32)
    b = np.asarray(blur).astype(np.float32)
    detail = np.clip((g - b) * 1.6 + 128, 0, 255).astype(np.uint8)
    return Image.fromarray(detail, mode="L")


FABRIC = build_fabric_detail()
print("fabric detail texture built:", FABRIC.size)


def apply_fabric(im, opacity=0.25):
    """Add photographic fabric luminance detail, masked by the image's alpha."""
    rgba = im.convert("RGBA")
    w, h = rgba.size
    tex = FABRIC.resize((w, h), Image.LANCZOS)
    arr = np.asarray(rgba).astype(np.float32)
    t = np.asarray(tex).astype(np.float32)
    delta = (t - 128.0) * opacity
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c] + delta, 0, 255)
    out = Image.fromarray(arr.astype(np.uint8), mode="RGBA")
    out.putalpha(rgba.split()[3])
    return out


# ------------------------------------------------------------- hull silhouette
# Same planform as the v34 plate: ellipse hull + 2 gondola rects, so every
# position in the game (components, shadows, hit math) is unchanged.
def hull_mask(size, feather=1.5):
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([w * .02, h * .18, w * .98, h * .62], fill=255)
    d.rectangle([w * .40, h * .62, w * .48, h * .80], fill=255)
    d.rectangle([w * .54, h * .62, w * .62, h * .80], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return m


# ------------------------------------------------------- v48-zeppelin (BEFORE)
# Smooth envelope: the v34 source strip, heavily blurred to kill crater
# detail, graded warm grey-tan (desaturated), fabric ribbing on top.
base = crop((100, 2050, 700, 2240)).resize((440, 150), Image.LANCZOS)
base = base.filter(ImageFilter.GaussianBlur(16))
base = grade(base, bright=1.06, contrast=0.82, color=0.52,
             tint=(172, 160, 138), tint_amt=0.28)
base = apply_fabric(base, opacity=0.22)
# Gondola cars read as separate darker cars, not hull.
arr = np.asarray(base.convert("RGBA")).astype(np.float32)
for (x0, y0, x1, y1) in [(int(440 * .40), int(150 * .62), int(440 * .48), int(150 * .80)),
                         (int(440 * .54), int(150 * .62), int(440 * .62), int(150 * .80))]:
    arr[y0:y1, x0:x1, 0:3] *= 0.72
hull = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), mode="RGBA")
hull.putalpha(hull_mask((440, 150)))
save(hull, "v48-zeppelin.png")

# ------------------------------------------------------------ v48-fuelcover
# Fuel-cell hatch cover: a strip of the new hull plate itself, graded
# slightly darker, so it reads as an envelope panel/hatch over the cell.
cover = hull.crop((194, 52, 246, 84)).convert("RGB")
cover = grade(cover, bright=0.82, contrast=1.05, color=0.9)
m = Image.new("L", cover.size, 0)
d = ImageDraw.Draw(m)
d.rounded_rectangle([4, 4, cover.size[0] - 4, cover.size[1] - 4], radius=6, fill=255)
m = m.filter(ImageFilter.GaussianBlur(2))
cover = cover.convert("RGBA")
cover.putalpha(m)
save(cover, "v48-fuelcover.png")

# ----------------------------------------------------------------- v48-prop
# Maybach prop disc: a real Staaken prop blade (left upper prop, hub at
# ~(174, 38) in the 512x300 Staaken plate) rotationally blurred — the blade
# rotated in 10-degree steps around its hub and averaged. Every pixel comes
# from the real photograph; the spin blur is a photographic transform, like
# the Gaussian feathering used everywhere else in this repo.
st = Image.open(STAAKEN).convert("RGBA")
# The left upper prop blade only (68x9 strip, absolute y 29-38): the blade
# band sits at rows ~1-8; the nacelle dome below it is excluded. The strip's
# alpha-weighted vertical centroid is the blade's centreline — it is pasted
# so the centreline passes through the canvas centre, so the rotational
# blur sweeps through the hub instead of leaving a hole there.
blade = st.crop((140, 29, 208, 38))
ba = np.asarray(blade)[:, :, 3].astype(np.float64)
rows = ba.sum(axis=1)
cy = float((rows * np.arange(9)).sum() / max(1.0, rows.sum()))
S = 68
canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
canvas.paste(blade, (0, int(round(34 - cy))), blade)
acc = np.zeros((S, S, 4), dtype=np.float64)
max_a = np.zeros((S, S), dtype=np.float64)
for ang in range(0, 360, 10):
    rot = canvas.rotate(ang, resample=Image.BICUBIC, center=(S / 2, S / 2))
    a = np.asarray(rot).astype(np.float64)
    # premultiply by alpha so transparent pixels don't drag the average
    rgb = a[:, :, 0:3] * (a[:, :, 3:4] / 255.0)
    acc[:, :, 0:3] += rgb
    acc[:, :, 3] += a[:, :, 3]
    max_a = np.maximum(max_a, a[:, :, 3])
n = 36
avg_a = acc[:, :, 3] / n
avg_rgb = np.zeros((S, S, 3), dtype=np.float64)
nz = avg_a > 4
avg_rgb[nz] = (acc[:, :, 0:3] / n)[nz] / (avg_a[nz] / 255.0)[:, None]
# The average alpha of a thin blade spun through a disc is ~10% — too faint
# to read. The disc's alpha is the UNION of the blade's positions (a real
# spinning prop reads as a translucent disc), scaled to ~50% so the hull
# still shows through. Where no blade pixel ever passed, use the blade's
# own mean tone so the disc is a uniform wooden colour with streaks.
blade_px = np.asarray(blade).astype(np.float64)
op = blade_px[:, :, 3] > 20
mean_tone = blade_px[op][:, 0:3].mean(axis=0) if op.any() else np.array([150., 130., 100.])
fill = np.zeros((S, S, 3), dtype=np.float64)
fill[:] = mean_tone
avg_rgb[~nz] = fill[~nz]
disc = np.zeros((S, S, 4), dtype=np.uint8)
disc[:, :, 0:3] = np.clip(avg_rgb, 0, 255).astype(np.uint8)
disc_alpha = np.clip(max_a * 0.5, 0, 255)
# A real prop has a solid hub: the blade's centreline passes a few pixels
# off the rotation centre, so the union leaves the middle faint. Boost the
# hub (radius ~6, tapering to 0 at 12) to the blade's own tone — an alpha
# mask shaping photographic pixels, like the circular rim mask below.
yy, xx = np.mgrid[0:S, 0:S]
dist = np.sqrt((xx - S / 2.0) ** 2 + (yy - S / 2.0) ** 2)
hub = np.clip(120 * (1 - dist / 12.0), 0, 120)
disc_alpha = np.maximum(disc_alpha, hub)
disc[:, :, 3] = np.clip(disc_alpha, 0, 255).astype(np.uint8)
disc_im = Image.fromarray(disc, mode="RGBA")
# Circular soft mask: the disc is round, feathered at the rim.
cm = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(cm)
d.ellipse([2, 2, S - 2, S - 2], fill=255)
cm = cm.filter(ImageFilter.GaussianBlur(3))
da = np.asarray(disc_im).astype(np.float32)
ma = np.asarray(cm).astype(np.float32) / 255.0
da[:, :, 3] = da[:, :, 3] * ma
prop = Image.fromarray(np.clip(da, 0, 255).astype(np.uint8), mode="RGBA")
prop = prop.resize((56, 56), Image.LANCZOS)
save(prop, "v48-prop.png")

# ----------------------------------------------------------------- v48-tear
# Torn gas-cell hole: a real dark crater from the aerial, graded very dark,
# ragged feathered edge. Drawn where a fuel cell blew, so the envelope
# reads torn, not just scorched.
tear = crop((780, 560, 980, 760)).resize((64, 44), Image.LANCZOS)
tear = grade(tear, bright=0.5, contrast=1.25, color=0.7)
tm = Image.new("L", (64, 44), 0)
d = ImageDraw.Draw(tm)
d.ellipse([4, 4, 60, 40], fill=255)
tm = tm.filter(ImageFilter.GaussianBlur(4))
tear = tear.convert("RGBA")
tear.putalpha(tm)
save(tear, "v48-tear.png")

# ------------------------------------------------------------- contact sheet
sheet = Image.new("RGBA", (440 + 120, 150 + 110), (24, 24, 24, 255))
sheet.paste(hull, (0, 0), hull)
sheet.paste(cover.resize((104, 64), Image.LANCZOS), (0, 160), cover.resize((104, 64), Image.LANCZOS))
sheet.paste(prop.resize((112, 112), Image.LANCZOS), (120, 150), prop.resize((112, 112), Image.LANCZOS))
sheet.paste(tear.resize((128, 88), Image.LANCZOS), (250, 160), tear.resize((128, 88), Image.LANCZOS))
sheet.save("/tmp/v48-contact.png")
print("contact sheet: /tmp/v48-contact.png")

# ------------------------------------------------------------- verification
for name in ["v48-zeppelin.png", "v48-fuelcover.png", "v48-prop.png", "v48-tear.png"]:
    im = Image.open(os.path.join(V48, name))
    a = im.split()[3]
    print(name, im.size, "alpha bbox:", a.getbbox(),
          "opaque px:", sum(1 for v in a.histogram()[255:] if v) and a.histogram()[255])
