"""Single-frame top-down renders for the 6 new locale models.
Same rig as render_sprites.py (256px, ortho 8.0, transparent, Cycles CPU).
Zeppelin gets a wider ortho scale to fit its length.
Run headless: blender --background --python render_locales.py"""
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender"))
import render_sprites as R

MODELS_DIR = os.path.join(os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender"), "models")
OUT_DIR = os.path.expanduser("~/workspace/1918-godot/assets/sprites")
os.makedirs(OUT_DIR, exist_ok=True)

# model_id -> ortho scale override
MODELS = {
    "uboat": 8.0,
    "subpen": 8.0,
    "zeppelin": 10.5,
    "ammodepot": 8.0,
    "train": 9.5,
    "arty": 8.0,
}

import bpy


def render_one(model_id, ortho):
    blend = os.path.join(MODELS_DIR, model_id + ".blend")
    bpy.ops.wm.open_mainfile(filepath=blend)
    R.setup_render()
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    root = bpy.data.objects.get(model_id) or meshes[0]
    ws = [root.matrix_world @ Vector(c) for c in root.bound_box]
    xs = [v.x for v in ws]
    ys = [v.y for v in ws]
    zs = [v.z for v in ws]
    # camera with custom ortho scale
    s = bpy.context.scene
    cam_data = bpy.data.cameras.new("LocaleCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ortho
    cam = bpy.data.objects.new("LocaleCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cx, cy, ztop = sum(xs) / 8, sum(ys) / 8, max(zs)
    cam.location = (cx, cy, ztop + 12.0)
    cam.rotation_euler = (0, 0, 0)
    s.camera = cam

    def sun(name, energy, rot):
        bpy.ops.object.light_add(type='SUN', location=(cx, cy, ztop + 5))
        l = bpy.context.active_object
        l.name = name
        l.data.energy = energy
        l.rotation_euler = rot

    sun("Key", 1.4, (0.35, 0.15, -0.3))
    sun("Fill", 0.35, (1.2, -0.2, 2.6))
    sun("Rim", 0.4, (-1.1, 0.3, 1.2))
    out = os.path.join(OUT_DIR, model_id + ".png")
    s.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print(f"SPRITE {model_id}.png")


if __name__ == "__main__":
    for mid, ortho in MODELS.items():
        render_one(mid, ortho)
    print("LOCALE SPRITES DONE")
