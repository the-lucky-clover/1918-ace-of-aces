#!/usr/bin/env python3
"""v19 nightly: model coverage + 5s post-loop invulnerability + wingman anim.

1. POST_LOOP_INVULN == 5.0 in scripts/player.gd and try_loop() uses it
   (Steven's explicit order — the old LOOP_DUR + STAB_DUR window is retired).
2. Every gameplay sprite has a Blender render source: parses ROSTER from
   blender/render_v19.py (regex — never imports it, needs bpy) plus the
   known pipelines (v16 airframes, render_sprites.py, build_locales.py,
   loop frames, wingman roll frames). Flags orphans and missing files.
3. Wingman animation wiring present: wingman.gd has begin_arrival/barrel_roll,
   player.gd try_loop() triggers wingman rolls.
"""
import os
import re
import sys

REPO = os.path.expanduser("~/workspace/1918-ace-of-aces")
GODOT = os.path.expanduser("~/workspace/1918-godot")
SCRIPT = os.path.join(REPO, "blender", "render_v19.py")
SPRITES = os.path.join(GODOT, "assets", "sprites")
PLAYER = os.path.join(GODOT, "scripts", "player.gd")
WINGMAN = os.path.join(GODOT, "scripts", "wingman.gd")

fails = []

# --- 1. 5s post-loop invulnerability -------------------------------------
psrc = open(PLAYER).read()
m = re.search(r"const POST_LOOP_INVULN\s*:=\s*([0-9.]+)", psrc)
if not m:
    fails.append("POST_LOOP_INVULN const missing in player.gd")
elif abs(float(m.group(1)) - 5.0) > 1e-6:
    fails.append(f"POST_LOOP_INVULN is {m.group(1)}, want 5.0 (Steven's order)")
if "invuln = maxf(invuln, POST_LOOP_INVULN)" not in psrc:
    fails.append("try_loop() does not grant POST_LOOP_INVULN")
# STAB_DUR retired: no code reference may remain (comments documenting the
# retirement are fine).
code_lines = [l for l in psrc.splitlines()
              if not l.strip().startswith("#") and not l.strip().startswith("##")]
code_src = "\n".join(code_lines)
if "STAB_DUR" in code_src:
    fails.append("STAB_DUR still referenced in player.gd code (retired in v19)")
# unmistakable flashing: hard square-wave blink present
if "sin(invuln * 34.0)" not in psrc:
    fails.append("invulnerability hard-blink missing in player.gd")

# --- 2. model coverage ----------------------------------------------------
if not os.path.isfile(SCRIPT):
    fails.append("blender/render_v19.py missing")
else:
    src = open(SCRIPT).read()
    rm = re.search(r"ROSTER = \[(.*?)\n\]", src, re.S)
    if not rm:
        fails.append("could not find ROSTER in render_v19.py")
    else:
        entries = re.findall(r'^\s+\("([a-z0-9\-]+)",\s*\S+,\s*"([a-z0-9\-]+\.png)"\)',
                             rm.group(1), re.M)
        if not entries:
            fails.append("could not parse ROSTER entries from render_v19.py")
        for model_id, fname in entries:
            if not os.path.isfile(os.path.join(SPRITES, fname)):
                fails.append(f"missing v19 sprite: {fname} (model {model_id})")

# wingman roll frames: 8, matching the wingman SPAD build
wingdir = os.path.join(SPRITES, "wingman")
for i in range(8):
    f = f"wingman-roll-{i:02d}.png"
    if not os.path.isfile(os.path.join(wingdir, f)):
        fails.append(f"missing wingman roll frame: wingman/{f}")

# known-source registry: every gameplay PNG must come from a Blender pipeline.
# (v16 airframes, render_sprites.py manifest, build_locales fns, loop frames,
# wingman rolls, v19 roster.) Intentionally vector: infantry dots, atmosphere
# runtime gradients, gas-mask icon (generated at runtime in pickup.gd).
KNOWN = {
    # v19 roster
    "tank-german", "tank-french", "tank-uk", "tank-a7v", "tank-barrel",
    "truck", "barge", "mg-nest",
    "item-fuel", "item-rapid", "item-spread", "item-wingman",
    # v16 airframes (render_v16.py ROSTER) — stems
    "player-spad", "wingman-spad",
    "enemy-triplane", "enemy-scout", "enemy-fighter", "enemy-bomber",
    "enemy-fokker-dr1", "enemy-fokker-d7", "enemy-albatros",
    "enemy-balloon", "zeppelin",
    "boss-1-red", "boss-2-checker", "boss-3-stripes", "boss-4-tiger",
    "boss-5-jester", "boss-6-ghost", "boss-7-baron",
    # v22 roster (render_v22.py): E1-E10 types + ace liveries
    "enemy-eindecker", "enemy-albatros-d3", "enemy-rumpler", "enemy-gotha",
    "enemy-staaken", "enemy-searchlight",
    "boss-bluemax", "boss-noir", "boss-lozenge", "boss-silver",
    "boss-green", "boss-crimson", "boss-sand",
    # render_sprites.py / build_locales.py pipelines
    "enemy-aagun", "enemy-railwaygun",
    "ammodepot", "uboat", "subpen", "train", "arty",
    "setpiece-trench", "setpiece-aerodrome", "setpiece-farm",
    "setpiece-nomansland",
    "item-ammo", "item-repair", "item-bomb",
}
for f in sorted(os.listdir(SPRITES)):
    if not f.endswith(".png"):
        continue
    stem = f[:-4]
    for suf in ("-bank-left", "-bank-right", "-level"):
        if stem.endswith(suf):
            stem = stem[: -len(suf)]
            break
    if stem not in KNOWN:
        fails.append(f"sprite with no Blender source: {f}")
for f in sorted(os.listdir(wingdir)):
    if f.endswith(".png") and not re.match(r"wingman-roll-\d{2}\.png", f):
        fails.append(f"wingman/ sprite with no render source: {f}")

# --- 3. wingman animation wiring ------------------------------------------
wsrc = open(WINGMAN).read()
for needle in ("func begin_arrival", "func barrel_roll", "roll_frames"):
    if needle not in wsrc:
        fails.append(f"wingman.gd missing {needle}")
if 'w.barrel_roll(' not in psrc and ".barrel_roll(" not in psrc:
    fails.append("player.gd try_loop() does not trigger wingman barrel rolls")
if "begin_arrival()" not in psrc:
    fails.append("player.gd add_wingman() does not start the arrival animation")

if fails:
    print("FAIL: v19 model coverage / wingman anim / 5s invuln")
    for x in fails:
        print("  " + x)
    sys.exit(1)
print(f"v19 coverage OK: POST_LOOP_INVULN=5.0, wingman anim wired, "
      f"{len(KNOWN)} sprite stems have Blender sources")
