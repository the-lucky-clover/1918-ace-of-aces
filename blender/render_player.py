"""Render the player's SPAD XIII (Allied French livery) from the existing
procedural aircraft builder. Single top-down frame -> Godot player sprite."""
import bpy
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender"))
import build_models as B
import render_sprites as R

OUT = os.path.expanduser("~/workspace/1918-godot/assets/sprites/player-spad.png")

# French khaki fuselage, linen wings, white accent
B.aircraft("player-spad", span=5.0, wings=2, length=5.2,
           body=(0.40, 0.38, 0.26), wing_col=(0.68, 0.62, 0.48),
           accent=(0.88, 0.88, 0.90))

# --- French roundels on the top wing (blue/white/red concentric) ---
# aircraft() joins parts into one mesh; top wing known analytically:
# 2-wing rig -> zoff [0.50, -0.35], yoff [0.25, -0.30], thickness 0.09
blue = B.mat("player-spad_blue", (0.10, 0.20, 0.55), rough=0.9)
white = B.mat("player-spad_white", (0.92, 0.92, 0.90), rough=0.9)
red = B.mat("player-spad_red", (0.75, 0.12, 0.15), rough=0.9)
ZWING_TOP = 0.50 + 0.045
for side in (-1, 1):
    x = side * 5.0 * 0.30
    B.cyl(f"roundelB{side}", 0.42, 0.03, (x, 0.25, ZWING_TOP + 0.015), blue, verts=24)
    B.cyl(f"roundelW{side}", 0.28, 0.035, (x, 0.25, ZWING_TOP + 0.018), white, verts=24)
    B.cyl(f"roundelR{side}", 0.14, 0.04, (x, 0.25, ZWING_TOP + 0.021), red, verts=24)

# --- top-down render, same rig as the sprite set ---
R.setup_render()
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
root = bpy.data.objects.get("player-spad") or meshes[0]
ws = [root.matrix_world @ Vector(c) for c in root.bound_box]
xs = [v.x for v in ws]; ys = [v.y for v in ws]; zs = [v.z for v in ws]
R.add_camera_lighting(sum(xs) / 8, sum(ys) / 8, max(zs))
bpy.context.scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print(f"PLAYER SPRITE -> {OUT}")
