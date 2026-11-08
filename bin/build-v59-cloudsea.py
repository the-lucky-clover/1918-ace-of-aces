#!/usr/bin/env python3
"""bin/build-v59-cloudsea.py — v59 Sortie 33 "WILD BLUE YONDER" sky plates.

The prestige duel flies ABOVE the clouds at magic hour: blue sky above, a
photorealistic cloud sea below, scrolling forever. Both plates are cut from
ONE real photograph — no drawn clouds, no vector art, no generated pixels.
The only processing is crop -> resize -> photographic grade (gamma lift,
warm colour balance, saturation), exactly the established raster rule
(bin/build-v34-sprites.py, bin/build-v39-trenches.py, bin/build-v40-rivers.py).

SOURCE (verified 2026-11-07):
  NASA astronaut photograph ISS073-E-0028091 — "An orbital sunrise breaks
  above the clouds", taken by an Expedition 73 crew member aboard the
  International Space Station (Nikon body, ISS Crew Earth Observations
  Facility / Earth Science and Remote Sensing Unit, NASA Johnson Space
  Center). 4928x2768 JPEG.
  Download: https://images-assets.nasa.gov/image/iss073e0028091/iss073e0028091~orig.jpg
  Also catalogued in Wikimedia Commons, Category:Sunrises from orbit, as
  "An orbital sunrise breaks above the clouds (iss073e0028091).jpg".
  LICENCE: Public domain — a work of the U.S. federal government (NASA).
  NASA imagery is not copyright protected (17 U.S.C. 105; NASA media use
  guidelines). No attribution required; recorded here for provenance.

The frame is an orbital-sunrise oblique: a deep blue sky gradient across
the top, a band of cumulus cloud tops catching pink sunrise light around
the horizon, and a shadowed cloud deck below. Two plates are cut:
  v59-skyband.jpg   the photographic blue sky band (drawn still, top of
                    the screen — the sky does not scroll, the world does)
  v59-cloudsea.jpg  the cloud deck band, warm magic-hour grade (drawn
                    mirror-tiled, scrolling vertically at the game's
                    92 px/s world speed for the whole duel)

Plates (assets/sprites/v59/):
  v59-skyband.jpg    1600x260
  v59-cloudsea.jpg   1600x500
"""
import io
import os
import sys
import urllib.request

from PIL import Image, ImageEnhance

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_DIR = os.path.join(ROOT, "assets", "sprites", "v59")
CACHE = "/tmp/v59-iss073e0028091.jpg"
URL = "https://images-assets.nasa.gov/image/iss073e0028091/iss073e0028091~orig.jpg"
UA = {"User-Agent": "1918-v59-build/1.0 (asset sourcing; NASA public domain)"}


def fetch():
    if os.path.exists(CACHE) and os.path.getsize(CACHE) > 100000:
        print("  source: cache", CACHE)
        return Image.open(CACHE).convert("RGB")
    print("  downloading", URL)
    req = urllib.request.Request(URL, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        data = r.read()
    with open(CACHE, "wb") as f:
        f.write(data)
    print("  source bytes:", len(data))
    return Image.open(io.BytesIO(data)).convert("RGB")


def warm_grade(im, gamma=0.80, r_mul=1.10, b_mul=0.90, sat=1.16, bright=1.05):
    """Photographic grade only: gamma lift + warm balance + saturation."""
    if gamma != 1.0:
        lut = [min(255, int(((i / 255.0) ** gamma) * 255)) for i in range(256)]
        im = im.point(lut * 3)
    r, g, b = im.split()
    r = r.point(lambda i: min(255, int(i * r_mul)))
    b = b.point(lambda i: min(255, int(i * b_mul)))
    im = Image.merge("RGB", (r, g, b))
    im = ImageEnhance.Color(im).enhance(sat)
    im = ImageEnhance.Brightness(im).enhance(bright)
    return im


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    src = fetch()
    W, H = src.size
    print("  source size:", W, "x", H)
    assert W >= 4000 and H >= 2000, "unexpected source dimensions"

    # Sky band: the clean blue gradient across the top of the frame
    # (below the dark vignette at the very top edge, above the horizon glow).
    sky = src.crop((0, 90, W, 700)).resize((1600, 260), Image.LANCZOS)
    sky = warm_grade(sky, gamma=0.94, r_mul=1.05, b_mul=0.96, sat=1.06, bright=1.03)
    sky_path = os.path.join(OUT_DIR, "v59-skyband.jpg")
    sky.save(sky_path, quality=88)
    print("  wrote", sky_path, sky.size)

    # Cloud sea: the cumulus band with pink-lit tops and the shadowed deck
    # below it. Gamma lift opens the deck shadows; warm balance pushes the
    # magic-hour gold/pink. Every visible pixel is photographic.
    sea = src.crop((0, 880, W, 2420)).resize((1600, 500), Image.LANCZOS)
    sea = warm_grade(sea, gamma=0.70, r_mul=1.12, b_mul=0.88, sat=1.18, bright=1.09)
    sea_path = os.path.join(OUT_DIR, "v59-cloudsea.jpg")
    sea.save(sea_path, quality=88)
    print("  wrote", sea_path, sea.size)


if __name__ == "__main__":
    sys.exit(main())
