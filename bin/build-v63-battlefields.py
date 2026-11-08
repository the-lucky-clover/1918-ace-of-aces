#!/usr/bin/env python3
"""v63 battlefield plates — denser, and every drawn plate replaced.

WHY THIS FILE EXISTS
--------------------
The audit for v63 found the last drawn scenery in the game: the four
setpiece strips (assets/sprites/setpiece-*.png) were flat vector
illustrations from the game's infancy — a solid-red barn, hangar
silhouettes, drawn crater rings, a sandbag pattern — scrolling over
the photographic battlefield at up to 82% opacity. They are replaced
here, at the same paths, with photographic cuts. The chateau Steven
flagged from the artifact build was already photographic in the repo
(v38 plate); these setpieces were the real remaining offenders.

SOURCES (the project's own photography only)
--------------------------------------------
A  assets/terrain-aerial.jpg (1120x2240) — the one true battlefield:
   zigzag trenches, crater fields, ruined village, fields. Every
   terrain-sourced plate below is a crop of it, so altitude, light,
   grade and grain match the base tiles BY CONSTRUCTION.
B  assets/village-neuf-aerial.jpg (3840x3840) — Swisstopo survey of
   Village-Neuf. TRIED for two intact rear-area buildings and
   REJECTED: at plate scale its districts read as a pasted modern
   map chunk, the wrong altitude entirely. Every shipped v63 plate
   is from source A. (The v40 plates cut from B at tighter boxes
   remain as they were — a different, already-accepted register.)

METHOD (the standing raster rule)
---------------------------------
Visible RGB is 100% photographic. Code touches only: the crop, a
gentle grade, a resize, and the ALPHA channel (feathered edges so a
plate sits IN the ground instead of reading as a pasted rectangle).
No pixel is drawn, painted, or synthesized.

PLATES
------
Setpiece strips (768x768, vertical edge feather, same paths as the
drawn originals, which are backed up to assets/sprites/.v63-backup/):
  setpiece-trench.png      A(100,20,780,700)    the zigzag system
  setpiece-nomansland.png  A(480,480,1100,1100) crater field
  setpiece-farm.png        A(120,1300,800,1980) ruins + fields
  setpiece-aerodrome.png   A(340,1560,1020,2240) rear fields + road
New spots (assets/sprites/v63/, radial/edge feather):
  v63-farmhouse.png  A(850,1420,1100,1700)  farmstead ruin + fields
  v63-barn.png       A(120,1450,420,1700)   barn-like ruin on the road
  v63-factory.png    A(260,1000,460,1180)   largest roofless ruin
  v63-ruin.png       A(480,1080,660,1240)   single roofless house
  v63-ruin-row.png   A(180,1240,600,1400)   ruin row along the road
  v63-houses.png     A(660,1120,900,1320)   ruined house cluster
  v63-farm.png       A(840,1660,1100,1960)  fields + lone ruin
  v63-crater-dense.png  A(20,560,480,900)   tight crater field
  v63-crater-water.png  A(620,560,1100,1000) water-filled craters
  v63-crater-wide.png   A(300,1900,800,2200) field crater scatter
  v63-trench-long.png   A(80,180,600,400)   extended zigzag run
  v63-trench-zigzag.png A(560,240,1100,700) trench + crater composite
  v63-hedgerow.png      A(0,1800,300,2100)  marsh/hedgerow ground
"""
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
A = Image.open(os.path.join(ROOT, "assets/terrain-aerial.jpg")).convert("RGB")
B = Image.open(os.path.join(ROOT, "assets/village-neuf-aerial.jpg")).convert("RGB")
SPRITES = os.path.join(ROOT, "assets/sprites")
OUT = os.path.join(SPRITES, "v63")
os.makedirs(OUT, exist_ok=True)
BACKUP = os.path.join(SPRITES, ".v63-backup")
os.makedirs(BACKUP, exist_ok=True)


def feather_alpha(size, edge):
    """Alpha mask: opaque centre, linear falloff over `edge` px on all sides."""
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rectangle([edge, edge, w - 1 - edge, h - 1 - edge], fill=255)
    return m.filter(ImageFilter.GaussianBlur(edge * 0.55))


def strip_alpha(size, edge):
    """Alpha mask for full-width strips: feather top/bottom only."""
    w, h = size
    col = Image.new("L", (1, h), 0)
    px = col.load()
    for y in range(h):
        px[0, y] = max(0, min(255, int(255 * min(y, h - 1 - y) / edge)))
    return col.resize((w, h))


def grade_village(im):
    im = ImageEnhance.Color(im).enhance(0.82)
    im = ImageEnhance.Brightness(im).enhance(1.02)
    warm = Image.new("RGB", im.size, (122, 104, 78))
    return Image.blend(im, warm, 0.07)


def emit(im, alpha, path):
    out = im.convert("RGBA")
    out.putalpha(alpha)
    out.save(path)
    print("wrote", os.path.relpath(path, ROOT), out.size)


def spot(photo, box, size, name, edge=26, village=False):
    im = photo.crop(box)
    if village:
        im = grade_village(im)
    im = im.resize(size, Image.LANCZOS)
    emit(im, feather_alpha(size, edge), os.path.join(OUT, name))


def strip(photo, box, name):
    im = photo.crop(box).resize((768, 768), Image.LANCZOS)
    src = os.path.join(SPRITES, name)
    bak = os.path.join(BACKUP, name)
    if os.path.exists(src) and not os.path.exists(bak):
        Image.open(src).save(bak)
        print("backed up drawn original ->", os.path.relpath(bak, ROOT))
    emit(im, strip_alpha((768, 768), 130), src)


# --- setpiece strips: the drawn offenders, replaced photographically ---
strip(A, (100, 20, 780, 700), "setpiece-trench.png")
strip(A, (480, 480, 1100, 1100), "setpiece-nomansland.png")
strip(A, (120, 1300, 800, 1980), "setpiece-farm.png")
strip(A, (340, 1560, 1020, 2240), "setpiece-aerodrome.png")

# --- new battlefield spots ---
spot(A, (850, 1420, 1100, 1700), (448, 512), "v63-farmhouse.png")
spot(A, (120, 1450, 420, 1700), (512, 424), "v63-barn.png")
spot(A, (260, 1000, 460, 1180), (448, 400), "v63-factory.png")
spot(A, (480, 1080, 660, 1240), (400, 360), "v63-ruin.png")
spot(A, (180, 1240, 600, 1400), (640, 244), "v63-ruin-row.png", edge=34)
spot(A, (660, 1120, 900, 1320), (448, 376), "v63-houses.png")
spot(A, (840, 1660, 1100, 1960), (448, 512), "v63-farm.png")
spot(A, (20, 560, 480, 900), (576, 424), "v63-crater-dense.png", edge=40)
spot(A, (620, 560, 1100, 1000), (576, 528), "v63-crater-water.png", edge=40)
spot(A, (300, 1900, 800, 2200), (640, 384), "v63-crater-wide.png", edge=40)
spot(A, (80, 180, 600, 400), (768, 324), "v63-trench-long.png", edge=36)
spot(A, (560, 240, 1100, 700), (640, 544), "v63-trench-zigzag.png", edge=36)
spot(A, (0, 1800, 300, 2100), (384, 384), "v63-hedgerow.png", edge=30)
print("v63 battlefield plates done")
