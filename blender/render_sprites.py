"""Top-down orthographic sprite renders for the 1918 asset set.
Transparent PNGs, Cycles CPU, neutral 3-point lighting, consistent 32 px/unit.
Run headless: blender --background --python render_sprites.py
"""
import bpy
import math
import os
import json
from mathutils import Vector

PI = math.pi
BLENDER_DIR = os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender")
MODELS_DIR = os.path.join(BLENDER_DIR, "models")
SPRITES_DIR = os.path.expanduser("~/workspace/1918-ace-of-aces-assets/sprites")
os.makedirs(SPRITES_DIR, exist_ok=True)

RES = 256
ORTHO_SCALE = 8.0          # 32 px per world unit, identical for every sprite
BANK = 0.45                # roll radians for bank frames

# (model_id, kind) — 'air3' = bank-left/level/bank-right, 'single' = one frame
MANIFEST = [
    ("enemy-triplane", "air3"), ("enemy-scout", "air3"),
    ("enemy-fighter", "air3"), ("enemy-bomber", "air3"),
    ("enemy-balloon", "air3"),
    ("boss-1-red", "air3"), ("boss-2-checker", "air3"),
    ("boss-3-stripes", "air3"), ("boss-4-tiger", "air3"),
    ("boss-5-jester", "air3"), ("boss-6-ghost", "air3"),
    ("boss-7-baron", "air3"),
    ("enemy-aagun", "single"), ("enemy-railwaygun", "single"),
    ("item-ammo", "single"), ("item-repair", "single"),
    ("item-bomb", "single"),
    ("setpiece-trench", "single"), ("setpiece-aerodrome", "single"),
    ("setpiece-farm", "single"), ("setpiece-nomansland", "single"),
]

def setup_render():
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = 32
    s.view_settings.view_transform = 'Standard'
    s.render.resolution_x = RES
    s.render.resolution_y = RES
    s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.render.image_settings.color_depth = '8'

def add_camera_lighting(cx, cy, ztop):
    # orthographic top-down camera
    cam_data = bpy.data.cameras.new("SpriteCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ORTHO_SCALE
    cam = bpy.data.objects.new("SpriteCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (cx, cy, ztop + 12.0)
    cam.rotation_euler = (0, 0, 0)
    bpy.context.scene.camera = cam
    # neutral 3-point sun lighting
    def sun(name, energy, rot):
        bpy.ops.object.light_add(type='SUN', location=(cx, cy, ztop + 5))
        l = bpy.context.active_object
        l.name = name
        l.data.energy = energy
        l.rotation_euler = rot
        return l
    sun("Key", 1.4, (0.35, 0.15, -0.3))
    sun("Fill", 0.35, (1.2, -0.2, 2.6))
    sun("Rim", 0.4, (-1.1, 0.3, 1.2))

def render_all():
    setup_render()
    produced = []
    for model_id, kind in MANIFEST:
        blend = os.path.join(MODELS_DIR, model_id + ".blend")
        bpy.ops.wm.open_mainfile(filepath=blend)
        setup_render()
        root = bpy.data.objects.get(model_id)
        if root is None:
            # fall back to the first mesh object
            meshes = [o for o in bpy.data.objects if o.type == 'MESH']
            assert meshes, f"no mesh in {model_id}"
            root = meshes[0]
        # frame on XY bounds (Z extent irrelevant for top-down ortho)
        ws = [root.matrix_world @ Vector(c) for c in root.bound_box]
        xs = [v.x for v in ws]; ys = [v.y for v in ws]; zs = [v.z for v in ws]
        cx, cy, ztop = sum(xs) / 8, sum(ys) / 8, max(zs)
        add_camera_lighting(cx, cy, ztop)
        frames = ([("bank-left", BANK), ("level", 0.0), ("bank-right", -BANK)]
                  if kind == "air3" else [("single", 0.0)])
        for suffix, roll in frames:
            root.rotation_euler = (0, roll, 0)
            bpy.context.view_layer.update()
            if suffix == "single":
                out = os.path.join(SPRITES_DIR, f"{model_id}.png")
            else:
                out = os.path.join(SPRITES_DIR, f"{model_id}-{suffix}.png")
            bpy.context.scene.render.filepath = out
            bpy.ops.render.render(write_still=True)
            produced.append(out)
            print(f"SPRITE {os.path.basename(out)}")
    with open(os.path.join(BLENDER_DIR, "sprites.json"), "w") as f:
        json.dump([os.path.basename(p) for p in produced], f, indent=2)
    print(f"RENDERED {len(produced)} sprites")

if __name__ == "__main__":
    render_all()
