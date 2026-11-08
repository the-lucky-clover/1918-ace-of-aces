#!/usr/bin/env python3
"""v44 — sheared wing + tail plates for the fiery crash-and-burn deaths.

Cuts two photographic plates from the real player SPAD sprite
(assets/sprites/player-spad-level.png, itself rebuilt from the real SPAD
photograph in v38): the upper wing and the tailplane. These are the pieces
that shear off the airframe in the WINGSHEAR FIREBALL death (variant 1) and
tumble away trailing fire. Photo crop -> feathered alpha only; visible RGB
is 100% photographic, no generated pixels, no vector art.
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'assets/sprites/player-spad-level.png')
OUT = os.path.join(ROOT, 'assets/sprites/v44')
os.makedirs(OUT, exist_ok=True)


def feather(im, edge_x=26, edge_y=4):
    """Fade alpha to transparent at the left/right/top/bottom edges so the
    plate never draws as a hard rectangle."""
    w, h = im.size
    px = im.load()
    for y in range(h):
        fy = min(1.0, y / max(1, edge_y), (h - 1 - y) / max(1, edge_y))
        for x in range(w):
            fx = min(1.0, x / max(1, edge_x), (w - 1 - x) / max(1, edge_x))
            f = min(fx, fy)
            if f < 1.0:
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, int(a * f))
    return im


def stats(im, name):
    a = im.split()[3]
    w, h = im.size
    corners = max(a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
                  a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1)))
    centre = a.getpixel((w // 2, h // 2))
    px = list(im.getdata())
    vis = [p for p in px if p[3] > 10]
    lum = [0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2] for p in vis]
    mean = sum(lum) / max(1, len(lum))
    sd = (sum((v - mean) ** 2 for v in lum) / max(1, len(lum))) ** 0.5
    print(f'{name}: {w}x{h} corners_max={corners} centre={centre} '
          f'visible={len(vis)} mean_lum={mean:.1f} sd={sd:.1f}')
    return corners <= 8 and centre >= 80 and sd > 5


src = Image.open(SRC).convert('RGBA')
print('source:', SRC, src.size, src.mode)

# Upper wing: the full-width wing band, rows 64-98 (alpha analysis shows the
# wing spans x 3-252 there; rows above are the nose, below the lower wing).
wing = feather(src.crop((0, 64, 256, 98)), edge_x=26, edge_y=4)
wing.save(os.path.join(OUT, 'v44-wing.png'))
ok_w = stats(wing, 'v44-wing.png')

# Tailplane: rows 182-218, x 72-184 (alpha analysis: tailplane spans
# x 79-177 there).
tail = feather(src.crop((72, 182, 184, 218)), edge_x=14, edge_y=4)
tail.save(os.path.join(OUT, 'v44-tail.png'))
ok_t = stats(tail, 'v44-tail.png')

# Contact sheet for a human eyeball check.
sheet = Image.new('RGBA', (512, 120), (24, 22, 18, 255))
sheet.paste(wing.resize((256, 34)), (0, 10))
sheet.paste(tail.resize((224, 72)), (280, 20))
sheet.convert('RGB').save('/tmp/v44-contact.jpg', quality=88)
print('contact sheet: /tmp/v44-contact.jpg')
print('OK' if (ok_w and ok_t) else 'CHECK FAILED')
