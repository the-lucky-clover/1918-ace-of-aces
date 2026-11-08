#!/usr/bin/env python3
"""bin/build-v60-p38.py — v60 secret P-38 Lightning player aircraft for 1918.

WHAT STEVEN ORDERED (2026-11-07): a secret, photorealistic raster P-38
Lightning as a 1P aircraft option, unlocked by completing Sortie 33 with
no continues, drawn at TRUE SCALE against the SPAD XIII (v54 yardstick:
SPAD span 8.25 m -> 69.12 px; P-38 span 15.85 m -> ~133 px). P2 flies a
distinctly marked second P-38 when the host picks it in co-op. PLUS the
boss-fight fuel coin (1943-style gauge refill drops) in the same v34
power-coin design language.

SOURCE (verified 2026-11-07):
  "A 96th Fighter Squadron, 82nd Fighter Group P-38 Lightning clearly
  displays the distinctive twin-boom design" — United States Army Air
  Forces official photograph, 1944 (15th Air Force, Italy). A genuine
  planform (top-down) in-flight photograph of a P-38 over terrain: nose
  up, full twin-boom layout, US star insignia on the port wing.
  Wikimedia Commons: File:A 96th FS P-38 clearly displays the
  distinctive twin-boom design.jpg (735x460 JPEG).
  Download: https://upload.wikimedia.org/wikipedia/commons/8/87/
    A_96th_FS_P-38_clearly_displays_the_distinctive_twin-boom_design.jpg
  LICENCE: Public domain — a work of the U.S. federal government
  (U.S. Army Air Forces). Commons licence tag: PD. No attribution
  required; recorded here for provenance.

TECHNIQUE (the established raster rule — photographic pixels only):
- The photograph is black-and-white. The aircraft is extracted with a
  luminance strength map (the silver airframe is bright against dark
  terrain): bright core components -> small-hole fill (insignia disc,
  canopy) -> banded luminance growth + short gap fills for the shaded
  tones -> one soft alpha polygon closing the near-black nose pod's
  outline, fitted to the pod silhouette in the print. numpy/ImageDraw
  touch MASKS ONLY, never the visible RGB.
- Colour is a photographic GRADE, not paint: per-pixel luminance is
  mapped through a natural-metal silver palette (late-war P-38s flew
  unpainted aluminium), exactly the tonal-modulation precedent of
  bin/build-v58-trenches.py ("samples massaged and colored"). The 2P
  ship is the SAME photograph remapped through an olive-drab palette
  with per-pixel luminance preserved (the bin/build-v51-2p.py method),
  the early-war scheme — clearly distinct from 1P's silver at a glance.
- Bank poses are true photographic rotations of the level plate
  (+14 deg / -14 deg, bin/build-v47-bank.py pipeline: rotate with
  expand, fit into the 256px square). Damaged poses add soot (radial
  masks darkening the photographic pixels) plus one stamped crop of
  the repo's own photographic v37 explosion plate at the port boom.
- Plates are 256x256 with the airframe's alpha bbox spanning the FULL
  256 width (fillW=256, exactly like the player SPAD plates), so the
  game's draw width IS the wingspan: 69.12 px * (15.85/8.25) = 132.8 px
  on screen at pilot scale. NOTE: the source photograph is a true
  planform with mild aerial perspective — its length/span ratio
  (~0.59) is a little shorter than the book figure (11.53/15.85 =
  0.73). The photograph ships as photographed; nothing is stretched.

FUEL COIN (v60-power-fuel.png): the v34 power-coin recipe verbatim
(bin/build-v34-sprites.py _coin_face): a photographic aerial texture
(the repo's terrain-aerial.jpg) in a brass-rimmed medallion, letter
'F' embossed. 1943-style gauge refill drops during boss fights.

Plates (assets/sprites/v60/):
  player-p38-level.png / -bank-left / -bank-right / -damaged   (1P silver)
  player-p38-2-level.png / -bank-left / -bank-right / -damaged (2P olive)
  v60-power-fuel.png                                           (fuel coin)

Usage: python3 bin/build-v60-p38.py
"""
import io
import math
import os
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(SPR, "v60")
os.makedirs(OUT, exist_ok=True)

SRC_URL = ("https://upload.wikimedia.org/wikipedia/commons/8/87/"
           "A_96th_FS_P-38_clearly_displays_the_distinctive_twin-boom_design.jpg")
SRC_CACHE = "/tmp/v60-p38-source.jpg"


def fetch_source():
    if not os.path.exists(SRC_CACHE):
        req = urllib.request.Request(SRC_URL, headers={"User-Agent": "1918-build/1.0"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        with open(SRC_CACHE, "wb") as f:
            f.write(data)
    return Image.open(SRC_CACHE).convert("RGB")


def palette_map(lum, stops):
    """lum: HxW float 0..1 -> HxWx3 float via piecewise-linear palette stops."""
    xs = np.array([s[0] for s in stops])
    out = np.zeros(lum.shape + (3,), dtype=np.float64)
    for ch in range(3):
        ys = np.array([s[1][ch] for s in stops])
        out[..., ch] = np.interp(lum, xs, ys)
    return out


SILVER = [(0.0, (0.10, 0.11, 0.15)), (0.35, (0.40, 0.44, 0.51)),
          (0.70, (0.71, 0.74, 0.78)), (1.0, (0.98, 0.99, 1.00))]
OLIVE = [(0.0, (0.07, 0.08, 0.04)), (0.35, (0.29, 0.30, 0.18)),
         (0.70, (0.51, 0.52, 0.37)), (1.0, (0.84, 0.84, 0.70))]


def fill_small_holes(mask, max_hole):
    """Fill background holes up to max_hole px — insignia discs and canopy
    glass fill; the big open bay between the booms stays open."""
    inv = ~mask
    lab, n = ndimage.label(inv)
    out = mask.copy()
    border = set(np.unique(np.concatenate(
        [lab[0, :], lab[-1, :], lab[:, 0], lab[:, -1]])))
    for i in range(1, n + 1):
        if i in border:
            continue
        c = lab == i
        if c.sum() <= max_hole:
            out |= c
    return out


def extract_airframe(photo, lum):
    """Photographic airframe -> feathered alpha mask + bbox.

    Pipeline (masks only; visible RGB is never touched here):
    bright-silver core (lum > 0.40, big components merged) -> small-hole
    fill -> banded luminance growth for the shaded airframe tones ->
    short row/column gap fills (boom shadow wedges, seams) -> bright
    island merge (the boom radiator fairing sits detached in the print)
    -> the nose pod: the pod's anti-glare top is nearly as dark as the
    terrain, so its outline is closed with a soft alpha polygon fitted
    to the pod silhouette visible in the photograph (the established
    v39/v40 hand-fitted alpha-mask step; the RGB inside is the pod's
    own photographic pixels) -> erode 1px -> gaussian feather.
    """
    core = lum > 0.40
    core = ndimage.binary_closing(core, iterations=2)
    lab, n = ndimage.label(core)
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1]
    mask = np.zeros_like(core)
    for i in order:
        if sizes[i] > 900:
            mask |= (lab == (1 + i))

    def fill(mask, max_hole=4000):
        return fill_small_holes(mask, max_hole)

    mask = fill(ndimage.binary_closing(mask, structure=np.ones((9, 9)), iterations=1))

    def grow_into(mask, thresh, band_px, max_comp):
        band = ndimage.binary_dilation(mask, iterations=band_px)
        g = (lum > thresh) & band
        lab2, n2 = ndimage.label(g)
        touch = ndimage.binary_dilation(mask, iterations=2)
        keep = np.zeros_like(g)
        for i in range(1, n2 + 1):
            c = lab2 == i
            if (c & touch).any() and c.sum() < max_comp:
                keep |= c
        return mask | keep

    def gap_fill(mask, axis, max_gap, min_mean):
        out = mask.copy()
        cross = mask.shape[1 - axis]
        for i in range(cross):
            line = mask[:, i] if axis == 0 else mask[i, :]
            vals = lum[:, i] if axis == 0 else lum[i, :]
            idx = np.where(line)[0]
            if len(idx) < 2:
                continue
            for a, b in zip(idx[:-1], idx[1:]):
                gap = b - a - 1
                if 0 < gap <= max_gap and vals[a + 1:b].mean() > min_mean:
                    if axis == 0:
                        out[a + 1:b, i] = True
                    else:
                        out[i, a + 1:b] = True
        return out

    mask = grow_into(mask, 0.20, 18, 6000)
    mask = gap_fill(mask, axis=1, max_gap=76, min_mean=0.10)
    mask = gap_fill(mask, axis=0, max_gap=44, min_mean=0.10)
    # bright detached islands hugging the airframe (boom radiator fairing)
    near = ndimage.binary_dilation(mask, iterations=6)
    isl = (lum > 0.30) & near & ~mask
    lab3, n3 = ndimage.label(isl)
    for i in range(1, n3 + 1):
        c = lab3 == i
        if 60 < c.sum() < 3000:
            mask |= c
    # nose pod: soft alpha polygon fitted to the pod outline in the photo
    ys, xs = np.where(mask)
    cx = int((xs.min() + xs.max()) / 2)
    pod = Image.new("L", (lum.shape[1], lum.shape[0]), 0)
    pd = ImageDraw.Draw(pod)
    pd.polygon([(cx, 52), (cx + 18, 80), (cx + 24, 105), (cx + 26, 130),
                (cx + 24, 154), (cx - 24, 154), (cx - 26, 130),
                (cx - 24, 105), (cx - 18, 80)], fill=255)
    mask |= np.asarray(pod) > 0
    mask = fill(mask)
    mask = ndimage.binary_erosion(mask, iterations=1)
    alpha = np.clip(ndimage.gaussian_filter(mask.astype(np.float64), 1.1) * 1.5, 0, 1)
    ys, xs = np.where(alpha > 0.5)
    bbox = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    return alpha, bbox


def compose_level(lum, alpha, bbox, stops):
    x0, y0, x1, y1 = bbox
    lum_c = lum[y0:y1, x0:x1]
    a_c = alpha[y0:y1, x0:x1]
    # gentle contrast stretch so the flat B&W print reads as metal
    lum_g = np.clip((lum_c - 0.06) / 0.88, 0, 1)
    rgb = palette_map(lum_g, stops)
    h, w = lum_c.shape
    scale = 256.0 / w
    nh = max(1, int(round(h * scale)))
    plate = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    body = Image.fromarray(
        np.dstack([np.clip(rgb * 255, 0, 255).astype(np.uint8),
                   np.clip(a_c * 255, 0, 255).astype(np.uint8)]), "RGBA")
    body = body.resize((256, nh), Image.LANCZOS)
    plate.paste(body, (0, (256 - nh) // 2), body)
    return plate


def fit_into_square(im, size=256):
    """v47: scale to fit inside size x size, centred (RGBA preserved)."""
    w, h = im.size
    s = min(size / w, size / h)
    nw, nh = max(1, int(round(w * s))), max(1, int(round(h * s)))
    r = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(r, ((size - nw) // 2, (size - nh) // 2), r)
    return canvas


def bank_set(level):
    left = fit_into_square(level.rotate(14, resample=Image.BICUBIC, expand=True))
    right = fit_into_square(level.rotate(-14, resample=Image.BICUBIC, expand=True))
    return left, right


def radial_patch(shape, cx, cy, r):
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    return np.clip(1 - d, 0, 1) ** 2


def make_damaged(level):
    arr = np.asarray(level).astype(np.float64)
    rgb, a = arr[..., :3], arr[..., 3]
    solid = a > 40
    ys, xs = np.where(solid)
    w = xs.max() - xs.min()
    cx = xs.min()
    cy_mid = (ys.min() + ys.max()) / 2
    # soot: port boom engine (left of centre pod) + starboard wing root
    soot = np.zeros(a.shape)
    soot += radial_patch(a.shape, cx + w * 0.335, cy_mid - 6, 26) * 0.85
    soot += radial_patch(a.shape, cx + w * 0.60, cy_mid + 4, 20) * 0.6
    soot += radial_patch(a.shape, cx + w * 0.50, cy_mid + 16, 15) * 0.5
    rgb *= (1 - 0.62 * soot[..., None] * (a[..., None] > 0))
    out = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a]).astype(np.uint8), "RGBA")
    # one stamped crop of the repo's photographic v37 explosion plate
    boom = Image.open(os.path.join(SPR, "v37", "v37-explosion-2.png")).convert("RGBA")
    boom = boom.resize((54, 54), Image.LANCZOS)
    ba = boom.getchannel("A").point(lambda v: int(v * 0.85))
    boom.putalpha(ba)
    out.alpha_composite(boom, (int(cx + w * 0.335) - 27, int(cy_mid) - 30))
    return out


def save(img, name):
    img.save(os.path.join(OUT, name))
    bb = img.getchannel("A").getbbox()
    print("  %-28s fillW=%s bbox=%s" % (name, (bb[2] - bb[0]) if bb else 0, bb))


def build_ship(photo, lum, alpha, bbox, stops, prefix):
    level = compose_level(lum, alpha, bbox, stops)
    left, right = bank_set(level)
    damaged = make_damaged(level)
    save(level, prefix + "-level.png")
    save(left, prefix + "-bank-left.png")
    save(right, prefix + "-bank-right.png")
    save(damaged, prefix + "-damaged.png")


def fuel_coin():
    """v34 _coin_face recipe: photographic aerial texture, brass rim, letter F."""
    base = Image.open(os.path.join(ROOT, "assets", "terrain-aerial.jpg")).convert("RGB")
    tex = base.crop((150, 900, 450, 1200)).resize((192, 192), Image.LANCZOS)
    arr = np.asarray(tex).astype(np.float64)
    lum = arr.mean(axis=2, keepdims=True) / 255.0
    tint = np.array([176, 138, 62], dtype=np.float64)
    arr = arr * 0.95 * 1.02 + (tint - arr) * 0.18 * lum
    tex = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")
    size = 192
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse([4, 4, size - 4, size - 4], fill=255)
    im.paste(tex, (0, 0), mask)
    d = ImageDraw.Draw(im)
    cx = cy = size / 2
    for k in range(48):
        ang = k / 48 * 2 * math.pi
        d.line([cx + math.cos(ang) * 88, cy + math.sin(ang) * 88,
                cx + math.cos(ang) * 80, cy + math.sin(ang) * 80],
               fill=(90, 66, 30, 255), width=2)
    d.ellipse([4, 4, size - 4, size - 4], outline=(122, 90, 40, 255), width=8)
    d.ellipse([16, 16, size - 16, size - 16], outline=(216, 178, 110, 255), width=3)
    d.ellipse([16, 16, size - 16, size - 16], outline=(60, 44, 20, 255), width=1)
    try:
        fl = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 84)
    except Exception:
        fl = ImageFont.load_default()
    d.text((98, 99), "F", font=fl, fill=(40, 28, 12, 255), anchor="mm")
    d.text((96, 96), "F", font=fl, fill=(245, 230, 190, 255), anchor="mm")
    im.save(os.path.join(OUT, "v60-power-fuel.png"))
    print("  v60-power-fuel.png           192x192 coin")


def main():
    photo = fetch_source()
    print("source:", photo.size, "USAAF 1944, public domain")
    lum = np.asarray(photo.convert("L"), dtype=np.float64) / 255.0
    alpha, bbox = extract_airframe(photo, lum)
    print("airframe bbox in source:", bbox,
          "fill %.0f%%" % (100 * (alpha > 0.5).mean()))
    build_ship(photo, lum, alpha, bbox, SILVER, "player-p38")
    build_ship(photo, lum, alpha, bbox, OLIVE, "player-p38-2")
    fuel_coin()
    print("done:", sorted(os.listdir(OUT)))


if __name__ == "__main__":
    main()
