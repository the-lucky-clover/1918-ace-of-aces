#!/usr/bin/env python3
"""v20 nightly: Steven's playtest feedback — formation, entries, brains, camo.

1. Wingman formation slots are exactly 45° off the player's 6 o'clock:
   wingman.gd must offset laterally by the SAME distance as behind
   (-fwd*78 + side*±78 → atan(78/78) = 45°).
2. Top entry: every aircraft spawn path in main.gd spawns at y <= -80
   (off the top). No side entries.
3. No dumb wiggle: enemy.gd must not contain a bare single-sine weave
   (the v20 _lateral personalities replace it); _slash_run commits to a
   dive line.
4. No radioactive glow: no full-body overdrive strobes (Color(2.x …) on
   sprite.modulate) in enemy.gd or wingman.gd. The sanctioned hit-flash
   (Color(3,3,3) in effects.gd) and the boss charge telegraph (boss.gd,
   now a white pulse) are outside this check's scope.
5. Player tracers brighter: bullet.gd player streak must carry the v20
   brightness (wider glow + 4-layer draw); FX.muzzle supports boost and
   player.gd passes 1.35.
"""
import os
import re
import sys

GODOT = os.path.expanduser("~/workspace/1918-godot")
ENEMY = os.path.join(GODOT, "scripts", "enemy.gd")
WINGMAN = os.path.join(GODOT, "scripts", "wingman.gd")
MAIN = os.path.join(GODOT, "scripts", "main.gd")
BULLET = os.path.join(GODOT, "scripts", "bullet.gd")
PLAYER = os.path.join(GODOT, "scripts", "player.gd")
EFFECTS = os.path.join(GODOT, "scripts", "effects.gd")
MUZZLE = os.path.join(GODOT, "scripts", "fx", "muzzle.gd")

fails = []


def read(p):
    with open(p) as f:
        return f.read()


esrc = read(ENEMY)
wsrc = read(WINGMAN)
msrc = read(MAIN)
bsrc = read(BULLET)
psrc = read(PLAYER)
fxsrc = read(EFFECTS)
mzsrc = read(MUZZLE)

# --- 1. 45° formation slots ---------------------------------------------
m = re.search(r"var off := -fwd \* ([0-9.]+) \+ side \* \(-([0-9.]+) if slot == 0 else ([0-9.]+)\)", wsrc)
if not m:
    fails.append("wingman.gd _slot_target offset pattern missing")
else:
    behind, l, r = float(m.group(1)), float(m.group(2)), float(m.group(3))
    if abs(l - behind) > 1e-6 or abs(r - behind) > 1e-6:
        fails.append(f"formation slots not 45°: behind={behind}, side=({l},{r}) — lateral must equal behind")
if "45" not in wsrc.split("_slot_target")[0][-400:]:
    # comment documents the spec near the slot math
    pass

# --- 2. top entry ---------------------------------------------------------
# every aircraft spawn in main.gd must be off the top edge (y < 0).
# The y-literal is extracted at the top nesting level of the Vector2 call
# (so clampf(cx + o.x, 70.0, ...) inner args can't false-positive).
def top_level_y(s):
    start = s.find("Vector2(")
    if start < 0:
        return None
    inner = s[start + 8:]
    depth = 0
    for idx, ch in enumerate(inner):
        if ch == "(":
            depth += 1
        elif ch == ")":
            if depth == 0:
                return None
            depth -= 1
        elif ch == "," and depth == 0:
            m = re.match(r"\s*(-?[0-9.]+)", inner[idx + 1:])
            return float(m.group(1)) if m else None
    return None


for i, line in enumerate(msrc.splitlines(), 1):
    s = line.strip()
    if "global_position = Vector2(" not in s:
        continue
    if "randf_range" not in s and "VIEW_W" not in s:
        continue
    y = top_level_y(s)
    if y is not None and y >= 0.0:
        fails.append(f"main.gd:{i} non-top spawn (y={y} on-screen): {s[:70]}")

# --- 3. no dumb wiggle ------------------------------------------------------
if re.search(r"sin\(age \* wfreq \+ weave_phase\) \* speed", esrc):
    fails.append("enemy.gd still has the bare metronome weave")
if "func _lateral" not in esrc:
    fails.append("enemy.gd missing _lateral() personalities")
if "func _slash_run" not in esrc:
    fails.append("enemy.gd missing _slash_run() committed dive")
if "dive_line" not in esrc:
    fails.append("enemy.gd missing committed dive_line")

# --- 4. no radioactive glow ---------------------------------------------------
# full-body overdrive strobes look like Color(2.x, ...) assigned to
# sprite.modulate in enemy/wingman code. (effects.gd hit_flash and the
# boss telegraph are deliberately out of scope.)
for path, src, name in [(ENEMY, esrc, "enemy.gd"), (WINGMAN, wsrc, "wingman.gd")]:
    for i, line in enumerate(src.splitlines(), 1):
        s = line.strip()
        if s.startswith("#"):
            continue
        if "sprite.modulate" in s and re.search(r"Color\(2\.[0-9]", s):
            fails.append(f"{name}:{i} full-body overdrive strobe: {s[:80]}")
if "windup_glint" not in esrc:
    fails.append("enemy.gd missing local windup_glint telegraph")

# --- 5. player tracers brighter -----------------------------------------------
if "draw_line(-dir * 30.0" not in bsrc:
    fails.append("bullet.gd player tracer not brightened (v20)")
if "var boost" not in mzsrc:
    fails.append("fx/muzzle.gd missing boost param")
if 'FX.muzzle(get_parent(), pos, false, 1.35)' not in psrc:
    fails.append("player.gd does not pass muzzle boost 1.35")
if "boost: float = 1.0" not in fxsrc:
    fails.append("effects.gd FX.muzzle missing boost param")

if fails:
    print("FAIL")
    for f in fails:
        print(" -", f)
    sys.exit(1)
print("PASS — v20: 45° slots, top entry, personalities, muted camo, bright tracers")
