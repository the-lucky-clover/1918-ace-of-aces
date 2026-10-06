#!/usr/bin/env python3
"""v16 nightly: every airframe sprite in the roster must have a Blender
source render script (no orphan sprites), and every rostered sprite file
must exist on disk. Parses ROSTER from blender/render_v16.py (regex —
never imports it, since it needs bpy)."""
import os
import re
import sys

REPO = os.path.expanduser("~/workspace/1918-ace-of-aces")
GODOT = os.path.expanduser("~/workspace/1918-godot")
SCRIPT = os.path.join(REPO, "blender", "render_v16.py")
SPRITES = os.path.join(GODOT, "assets", "sprites")

fails = []

if not os.path.isfile(SCRIPT):
    print("FAIL: blender/render_v16.py missing")
    sys.exit(1)

src = open(SCRIPT).read()

# extract the ROSTER block and pull model_ids in order.
# ROSTER entries start at line-beginning: `    ("model-id", ...`
rm = re.search(r"ROSTER = \[(.*?)\n\]", src, re.S)
if not rm:
    print("FAIL: could not find ROSTER in render_v16.py")
    sys.exit(1)
roster_src = rm.group(1)
# model_id lines: `    ("model-id", build_...` or `    ("model-id", lambda:`
model_ids = re.findall(r'^\s+\("([a-z0-9\-]+)"\s*,\s*(?:build_|lambda)', roster_src, re.M)
if not model_ids:
    print("FAIL: could not parse ROSTER entries from render_v16.py")
    sys.exit(1)

# frames rule mirrors render_v16.py: explicit single-frame models are the
# two SPADs; balloon has 3 explicit frames; zeppelin is single; the rest
# use the air3 bank-left/level/bank-right pattern.
SINGLE = {"player-spad": ["player-spad.png"],
          "wingman-spad": ["wingman-spad.png"],
          "zeppelin": ["zeppelin.png"]}
TRIPLE = {"enemy-balloon": ["enemy-balloon-level.png",
                            "enemy-balloon-bank-left.png",
                            "enemy-balloon-bank-right.png"]}
expected = set()
for mid in model_ids:
    if mid in SINGLE:
        expected.update(SINGLE[mid])
    elif mid in TRIPLE:
        expected.update(TRIPLE[mid])
    else:
        for suf in ("bank-left", "level", "bank-right"):
            expected.add(f"{mid}-{suf}.png")
# loop frames are rendered by render_loop_frames()
for i in range(12):
    expected.add(f"loop/loop-{i:02d}.png")

for f in sorted(expected):
    if not os.path.isfile(os.path.join(SPRITES, f)):
        fails.append(f"missing rostered sprite: {f}")

# no orphans: every airframe-ish png on disk must be rostered in v16.
# Ground units (aagun, railwaygun) come from the legacy render_sprites.py
# pipeline — they are not v16 airframes and are not flagged.
# v22: the 13 render_v22.py models (E1-E10 roster + ace liveries).
LEGACY_GROUND = {"enemy-aagun", "enemy-railwaygun"}
V22_MODELS = {"enemy-eindecker", "enemy-albatros-d3", "enemy-rumpler",
              "enemy-gotha", "enemy-staaken", "enemy-searchlight",
              "boss-bluemax", "boss-noir", "boss-lozenge", "boss-silver",
              "boss-green", "boss-crimson", "boss-sand"}
roster_stems = set(model_ids) | V22_MODELS
for f in os.listdir(SPRITES):
    if not f.endswith(".png"):
        continue
    if not re.match(r"^(enemy|boss|player|wingman)-", f):
        continue
    stem = f[:-4]
    for suf in ("-bank-left", "-bank-right", "-level"):
        if stem.endswith(suf):
            stem = stem[:-len(suf)]
            break
    if stem in roster_stems or stem in LEGACY_GROUND:
        continue
    fails.append(f"orphan airframe sprite with no render source: {f}")
loopdir = os.path.join(SPRITES, "loop")
if os.path.isdir(loopdir):
    for f in os.listdir(loopdir):
        if f.endswith(".png") and f"loop/{f}" not in expected:
            fails.append(f"orphan loop sprite with no render source: {f}")

if fails:
    print("FAIL: v16 sprite sources")
    for x in fails:
        print("  " + x)
    sys.exit(1)
print(f"OK: v16 sprite sources ({len(expected)} rostered sprites, no orphans)")
