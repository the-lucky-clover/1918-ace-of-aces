"""Render the SPAD XIII loop-de-loop frame sequence — strictly top-down.

A real Immelmann/loop viewed with the film plane parallel to the earth:
level -> nose-up foreshorten -> nose-on edge -> inverted belly-up ->
nose-down foreshorten (tail-on edge) -> level recovery. 12 frames.

CRITICAL pose fact (verified empirically): build_models.aircraft() joins
parts keeping the fuselage cylinder's baked rotation, so the joined
"player-spad" object's TRUE level top-down pose is
rotation_euler = (pi/2, 0, 0) — NOT identity. Zeroing it pitches the plane
nose-on. The loop pitches BACKWARD from that base (negative theta about X)
so the nose climbs first: level -> up -> over -> down -> level.

The French roundels are joined INTO the airframe so they pitch with it.
Camera framing is computed ONCE at the level pose and held fixed for all
frames so the airframe never jumps between frames.

Run headless: blender --background --python render_loop.py
"""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender"))
import build_models as B
import render_sprites as R

OUT_DIR = os.path.expanduser("~/workspace/1918-godot/assets/sprites/loop")
os.makedirs(OUT_DIR, exist_ok=True)

FRAMES = 12  # pitch steps of 30 degrees
BASE_PITCH = math.pi / 2  # the model's true level top-down pose (do not zero!)

# --- identical SPAD build to render_player.py (same livery) ---
B.aircraft("player-spad", span=5.0, wings=2, length=5.2,
           body=(0.40, 0.38, 0.26), wing_col=(0.68, 0.62, 0.48),
           accent=(0.88, 0.88, 0.90))
blue = B.mat("player-spad_blue", (0.10, 0.20, 0.55), rough=0.9)
white = B.mat("player-spad_white", (0.92, 0.92, 0.90), rough=0.9)
red = B.mat("player-spad_red", (0.75, 0.12, 0.15), rough=0.9)
ZWING_TOP = 0.50 + 0.045
for side in (-1, 1):
    x = side * 5.0 * 0.30
    B.cyl(f"roundelB{side}", 0.42, 0.03, (x, 0.25, ZWING_TOP + 0.015), blue, verts=24)
    B.cyl(f"roundelW{side}", 0.28, 0.035, (x, 0.25, ZWING_TOP + 0.018), white, verts=24)
    B.cyl(f"roundelR{side}", 0.14, 0.04, (x, 0.25, ZWING_TOP + 0.021), red, verts=24)

R.setup_render()
root = bpy.data.objects.get("player-spad")

# join the roundels into the airframe so they pitch WITH the plane
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.object.join()
root = bpy.data.objects.get("player-spad")

# level pose = the baked base pitch; frame the camera once and hold it
root.rotation_euler = (BASE_PITCH, 0.0, 0.0)
bpy.context.view_layer.update()
ws = [root.matrix_world @ Vector(c) for c in root.bound_box]
xs = [v.x for v in ws]; ys = [v.y for v in ws]; zs = [v.z for v in ws]
R.add_camera_lighting(sum(xs) / 8, sum(ys) / 8, max(zs))

for i in range(FRAMES):
    theta = math.radians(i * 360.0 / FRAMES)
    # negative theta: nose climbs first (Immelmann), over the top, dives out
    root.rotation_euler = (BASE_PITCH - theta, 0.0, 0.0)
    bpy.context.view_layer.update()
    out = os.path.join(OUT_DIR, f"loop-{i:02d}.png")
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print(f"LOOP FRAME {i:02d}/{FRAMES} pitch={-math.degrees(theta):.0f}deg -> {out}")

print(f"RENDERED {FRAMES} loop frames")
