#!/usr/bin/env python3
"""QA/skeptic/check_terrain.py — v23: terrain prompt hygiene for the
32-sortie minimap identities.

Steven's doctrine: strict 90-degree vertical aerial-recon view — no
perspective camera, no cinematic angles, no visible horizon, readable at
3,000-10,000 ft. v22 implements the 32 identities procedurally
(minimap.gd TERRAIN: theme -> [painter, variant, aerodrome damage];
takeoff/landing are the first/last sections of the scrolling map).

This check is STATIC and structural (it cannot see pixels headless — true
pixel verification stays a human review step, documented in PLAYTESTING.md):
  1. exactly 32 TERRAIN identities, each [known painter, variant, damage 0-3]
  2. every sortie's "theme" resolves to a TERRAIN identity
  3. every referenced painter function exists
  4. orthographic hygiene: no perspective/horizon/rotation tokens anywhere
     in the terrain painters (the camera iron rule, applied to the map)
  5. aerodrome strip doctrine: drawn in the bottom ~14% (first/last section)
  6. landing damage progression present (damage states 0..3 used)

Usage: check_terrain.py <godot-scripts-dir>
Exit 0 on PASS, 1 on FAIL.
"""
import os
import re
import sys

scripts = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/workspace/1918-godot/scripts")
fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)


def read(name):
    with open(os.path.join(scripts, name)) as f:
        return f.read()


minimap = read("minimap.gd")
try:
    sortie_data = read("sortie_data.gd")
except FileNotFoundError:
    sortie_data = ""

# --- 1: 32 TERRAIN identities ---
terrain = re.findall(
    r'"([a-z_0-9]+)": \["([a-z_]+)", (\d+), (\d+)\]', minimap)
check(len(terrain) == 32, "TERRAIN identities: %d != 32" % len(terrain))
painters = {"farmland", "river", "trenches", "crater", "rail", "town",
            "forest", "balloon", "composite"}
damages = set()
for key, painter, variant, dmg in terrain:
    check(painter in painters,
          "identity %s uses unknown painter %s" % (key, painter))
    check(0 <= int(dmg) <= 3,
          "identity %s aerodrome damage %s outside 0-3" % (key, dmg))
    damages.add(int(dmg))

# --- 2: every sortie theme resolves ---
themes = re.findall(r'"theme": "([a-z_0-9]+)"', sortie_data)
if themes:
    check(len(themes) == 32, "sortie themes: %d != 32" % len(themes))
    known = {k for k, _p, _v, _d in terrain}
    for t in themes:
        check(t in known, "sortie theme %s has no TERRAIN identity" % t)

# --- 3: painter functions exist ---
defined = set(re.findall(r"func (_t_[a-z_0-9]+)\(", minimap))
for key, painter, _v, _d in terrain:
    check(("_t_" + painter) in defined,
          "painter function _t_%s missing for identity %s" % (painter, key))
check("_t_aerodrome" in defined, "_t_aerodrome (takeoff/landing strip) missing")

# --- 4: orthographic hygiene: no perspective/horizon/rotation language ---
# The iron rule: the film plane stays parallel to the earth. These tokens
# in the terrain painters would mean a tilted or cinematic map.
BANNED = ["perspective", "horizon", "vanishing", "skew",
          "rotation_degrees", "cinematic", "dutch"]
for tok in BANNED:
    alllines = minimap.splitlines()
    allhits = [n for n, line in enumerate(alllines, 1)
               if tok in line.lower() and "no " + tok not in line.lower()
               and "90" not in line]
    if allhits:
        # allow the doctrine comment block (lines describing the spec)
        real = [n for n in allhits
                if "doctrine" not in alllines[n - 1].lower()
                and "spec" not in alllines[n - 1].lower()]
        check(not real, "banned token '%s' in minimap.gd lines %s" % (tok, real))

# --- 5: aerodrome strip = bottom ~14% (first/last map section) ---
m = re.search(r"func _t_aerodrome.*?y0 := size\.y \* (0\.\d+)", minimap,
              re.S)
check(m is not None, "_t_aerodrome strip origin not found")
if m:
    frac = float(m.group(1))
    check(0.84 <= frac <= 0.90,
          "aerodrome strip at %.2f of map height (doctrine: bottom ~14%%)" % frac)

# --- 6: landing damage progression 0..3 used ---
check(damages >= {0, 1, 2, 3},
      "landing damage progression incomplete: states used %s" % sorted(damages))

if fails:
    print("TERRAIN HYGIENE FAIL:")
    for f in fails:
        print("  - " + f)
    sys.exit(1)
print("TERRAIN HYGIENE PASS — %d identities, %d painters, damage states %s" % (
    len(terrain), len({p for _k, p, _v, _d in terrain}), sorted(damages)))
