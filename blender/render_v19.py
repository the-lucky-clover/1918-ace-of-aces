"""v19 — model coverage: every hand-drawn/PIL gameplay entity gets a real
Blender model render. Ground/naval units (tanks, A7V, truck, barge, MG nest),
pickup icons, and wingman animation frames (arrival roll + barrel roll).

Follows the v16 pipeline (render_v16.py): same PBR upgrade, same v14 sun-rig
lighting convention (screen-up = North, key sun due SOUTH at 60°), same
32 px/unit orthographic framing. Ground models are built small (~1-3 units)
so sprites land near their current on-screen sizes.

Run headless:  blender --background --python render_v19.py [--only=model_id]
"""
import bpy
import math
import os
import sys

PI = math.pi
ASSETS = os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender")
sys.path.insert(0, ASSETS)
sys.path.insert(0, os.path.expanduser("~/workspace/1918-ace-of-aces/blender"))
import build_models as B
import render_v16 as R16

OUT = os.path.expanduser("~/workspace/1918-godot/assets/sprites")
WING_OUT = os.path.join(OUT, "wingman")
os.makedirs(OUT, exist_ok=True)
os.makedirs(WING_OUT, exist_ok=True)

ONLY = None
for a in sys.argv:
    if a.startswith("--only="):
        ONLY = a.split("=", 1)[1]


def render_single(model_id, out_path):
    root = bpy.data.objects.get(model_id)
    assert root is not None, f"no object {model_id}"
    bpy.context.view_layer.update()
    cx, cy, ztop = R16.frame_model(root, 0, 0)
    R16.setup_render()
    R16.add_lighting(cx, cy, ztop)
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)
    print(f"V19 SPRITE {out_path}")


def finish_and_render(model_id, out_path, pbr=True):
    root = bpy.data.objects.get(model_id)
    if pbr:
        R16.upgrade_materials(root)
    blend = os.path.join(ASSETS, "models", model_id + ".blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    render_single(model_id, out_path)


# ------------------------------------------------------------------ tanks
# Top-down WWI tanks, long axis along X (barrels train left/right in code).
TANK_COLS = {
    "german": (0.36, 0.37, 0.34),   # field grey  (matches tank_duel.gd)
    "french": (0.44, 0.52, 0.62),   # horizon blue
    "uk": (0.52, 0.46, 0.33),       # khaki drab
}


def build_tank(variant):
    mid = f"tank-{variant}"
    B.clear_scene()
    col = TANK_COLS[variant]
    body = B.mat(mid + "_body", col, rough=0.72)
    dark = B.mat(mid + "_dark", (0.13, 0.12, 0.11), rough=0.92)
    steel = B.mat(mid + "_steel", (0.30, 0.30, 0.31), metallic=0.55, rough=0.5)
    # tracks: dark boxes flanking the hull
    B.box(mid + "_trkL", (1.9, 0.30, 0.24), (0, 0.52, 0.12), dark)
    B.box(mid + "_trkR", (1.9, 0.30, 0.24), (0, -0.52, 0.12), dark)
    for wx in (-0.6, 0.0, 0.6):
        for wy in (0.52, -0.52):
            B.cyl(f"{mid}_wh{wx}_{wy}", 0.13, 0.32, (wx, wy, 0.12), steel,
                  rot=(PI / 2, 0, 0), verts=10)
    # hull + upper works
    B.box(mid + "_hull", (1.65, 0.85, 0.34), (0, 0, 0.36), body)
    B.box(mid + "_upper", (1.25, 0.68, 0.24), (-0.05, 0, 0.62), body)
    # turret ring (barrel is a separate sprite, trained in code)
    B.cyl(mid + "_tur", 0.30, 0.22, (0.1, 0, 0.80), body, verts=14)
    B.cyl(mid + "_turcap", 0.20, 0.10, (0.1, 0, 0.95), dark, verts=12)
    # faction marking plate on the hull roof
    mark = B.mat(mid + "_mark", (0.85, 0.84, 0.80), rough=0.85)
    B.box(mid + "_plate", (0.34, 0.34, 0.03), (-0.55, 0, 0.76), mark)
    return B.finish(mid)


def build_a7v():
    mid = "tank-a7v"
    B.clear_scene()
    body = B.mat(mid + "_body", (0.33, 0.33, 0.30), rough=0.7)
    dark = B.mat(mid + "_dark", (0.12, 0.12, 0.11), rough=0.92)
    steel = B.mat(mid + "_steel", (0.32, 0.32, 0.33), metallic=0.5, rough=0.55)
    # wide tall tracks of the 30-tonne box
    B.box(mid + "_trkL", (2.75, 0.42, 0.34), (0, 0.78, 0.17), dark)
    B.box(mid + "_trkR", (2.75, 0.42, 0.34), (0, -0.78, 0.17), dark)
    # armored box hull + tall casemate (no turret — the land-ship look)
    B.box(mid + "_hull", (2.45, 1.35, 0.50), (0, 0, 0.50), body)
    B.box(mid + "_case", (1.85, 1.05, 0.55), (-0.1, 0, 1.00), body)
    B.box(mid + "_cup", (0.35, 0.35, 0.22), (-0.75, 0, 1.38), dark)
    # front gun port (the 57mm juts toward +X; barrel sprite aims in code)
    B.cyl(mid + "_port", 0.12, 0.30, (1.30, 0, 0.95), dark, rot=(0, PI / 2, 0),
          verts=10)
    # rivet rows along the casemate
    for rx in (-0.8, -0.1, 0.6):
        for ry in (0.53, -0.53):
            B.sphere(f"{mid}_rv{rx}_{ry}", 0.045, (rx, ry, 1.05), dark,
                     segs=6, rings=4)
    return B.finish(mid)


def build_tank_barrel():
    mid = "tank-barrel"
    B.clear_scene()
    dark = B.mat(mid + "_dark", (0.10, 0.10, 0.10), rough=0.6)
    # long gun pointing +X; code flips it toward the foe
    B.cyl(mid + "_gun", 0.075, 1.05, (0.55, 0, 0.80), dark, rot=(0, PI / 2, 0),
          verts=10)
    B.cyl(mid + "_mant", 0.14, 0.22, (0.05, 0, 0.80), dark, rot=(0, PI / 2, 0),
          verts=10)
    return B.finish(mid)


# ------------------------------------------------------------------ truck
def build_truck():
    mid = "truck"
    B.clear_scene()
    canvas = B.mat(mid + "_canvas", (0.52, 0.47, 0.34), rough=0.95)
    cabm = B.mat(mid + "_cab", (0.16, 0.15, 0.13), rough=0.7)
    wood = B.mat(mid + "_wood", (0.35, 0.26, 0.16), rough=0.9)
    dark = B.mat(mid + "_dark", (0.08, 0.08, 0.08), rough=0.9)
    glass = B.mat(mid + "_glass", (0.35, 0.42, 0.50), metallic=0.4, rough=0.3)
    # chassis + canvas-covered bed (troop lorry, drives toward +Y on screen).
    # NOTE: Blender +Y renders to image TOP = Godot -Y (up-screen), so the
    # cab (front) is built at Blender -Y to face down-screen (+Y Godot).
    B.box(mid + "_chas", (0.95, 1.95, 0.18), (0, 0, 0.28), wood)
    B.box(mid + "_bed", (1.0, 1.15, 0.42), (0, 0.35, 0.58), canvas)
    for i, ry in enumerate((0.75, 0.35, -0.05)):
        B.box(f"{mid}_rib{i}", (1.04, 0.07, 0.46), (0, ry, 0.58), canvas)
    # cab at the front (-Y Blender = +Y Godot = down-screen)
    B.box(mid + "_cab", (0.92, 0.55, 0.52), (0, -0.72, 0.55), cabm)
    B.box(mid + "_shield", (0.80, 0.06, 0.30), (0, -0.86, 0.72), glass)
    # six wheels
    for wx in (-0.55, 0.55):
        for wy in (0.75, -0.05, -0.72):
            B.cyl(f"{mid}_wh{wx}_{wy}", 0.17, 0.12, (wx, wy, 0.17), dark,
                  rot=(PI / 2, 0, 0), verts=10)
    return B.finish(mid)


# ------------------------------------------------------------------ barge
def build_barge():
    mid = "barge"
    B.clear_scene()
    # S2 secondary objective: sized to match the old sprite's on-screen
    # footprint (~90x220 px at 32 px/unit).
    hullm = B.mat(mid + "_hull", (0.30, 0.26, 0.20), rough=0.85)
    dark = B.mat(mid + "_dark", (0.12, 0.11, 0.10), rough=0.9)
    wood = B.mat(mid + "_wood", (0.45, 0.34, 0.22), rough=0.9)
    canvas = B.mat(mid + "_canvas", (0.55, 0.50, 0.38), rough=0.95)
    # long river hull along Y (drifts downriver), bluff bow
    B.box(mid + "_hull", (2.76, 7.44, 0.77), (0, 0, 0.38), hullm)
    B.box(mid + "_bow", (1.92, 1.32, 0.72), (0, 4.20, 0.36), hullm)
    B.box(mid + "_rake", (2.76, 0.72, 0.82), (0, -3.84, 0.41), dark)
    # cargo: crates + tarp-covered mound
    for i, cy in enumerate((-2.16, -0.24, 1.68)):
        B.box(f"{mid}_crate{i}", (2.04, 1.32, 1.01), (0, cy, 1.27), wood)
    B.box(mid + "_tarp", (2.28, 1.68, 0.34), (0, 1.68, 1.92), canvas)
    # wheelhouse aft
    B.box(mid + "_house", (1.68, 1.32, 1.32), (0, -3.00, 1.44), wood)
    B.box(mid + "_roof", (1.87, 1.51, 0.19), (0, -3.00, 2.21), dark)
    return B.finish(mid)


# ----------------------------------------------------------------- mg nest
def build_mg_nest():
    mid = "mg-nest"
    B.clear_scene()
    sand = B.mat(mid + "_sand", (0.55, 0.50, 0.36), rough=1.0)
    gunm = B.mat(mid + "_gun", (0.22, 0.23, 0.20), metallic=0.45, rough=0.55)
    dark = B.mat(mid + "_dark", (0.10, 0.10, 0.10), rough=0.9)
    # sandbag ring: 10 lumps in a circle
    for i in range(10):
        a = 2 * PI * i / 10.0
        B.sphere(f"{mid}_bag{i}", 0.16, (math.cos(a) * 0.52,
                                         math.sin(a) * 0.52, 0.10), sand,
                 segs=8, rings=5, scale=(1.0, 0.8, 0.62))
    # MG08 on sled mount, armored shield, trained toward +Y (down-screen)
    B.box(mid + "_sled", (0.42, 0.55, 0.12), (0, 0, 0.10), gunm)
    B.box(mid + "_shield", (0.62, 0.08, 0.42), (0, 0.10, 0.30), gunm)
    B.cyl(mid + "_body", 0.09, 0.45, (0, 0.02, 0.32), gunm, rot=(PI / 2, 0, 0),
          verts=8)
    B.cyl(mid + "_barrel", 0.045, 0.55, (0, 0.45, 0.32), dark, rot=(PI / 2, 0, 0),
          verts=8)
    return B.finish(mid)


# ----------------------------------------------------------------- pickups
# Sized ~1.5 units so icons land near the old ~35 px on-screen footprint.
def build_pickup(kind):
    mid = f"item-{kind}"
    B.clear_scene()
    if kind == "fuel":
        red = B.mat(mid + "_red", (0.62, 0.16, 0.12), rough=0.6)
        dark = B.mat(mid + "_dark", (0.15, 0.12, 0.10), rough=0.8)
        B.cyl(mid + "_drum", 0.51, 0.82, (0, 0, 0.42), red, verts=16)
        B.cyl(mid + "_band", 0.53, 0.15, (0, 0, 0.63), dark, verts=16)
        B.cyl(mid + "_cap", 0.12, 0.12, (0.18, 0.15, 0.90), dark, verts=8)
    elif kind == "rapid":
        wood = B.mat(mid + "_wood", (0.45, 0.34, 0.22), rough=0.9)
        gunm = B.mat(mid + "_gun", (0.20, 0.20, 0.22), metallic=0.5, rough=0.5)
        B.box(mid + "_crate", (1.08, 1.08, 0.63), (0, 0, 0.32), wood)
        for sx in (-0.21, 0.21):
            B.cyl(f"{mid}_mg{sx}", 0.10, 0.93, (sx, 0.38, 0.82), gunm,
                  rot=(PI / 2, 0, 0), verts=8)
    elif kind == "spread":
        wood = B.mat(mid + "_wood", (0.45, 0.34, 0.22), rough=0.9)
        gunm = B.mat(mid + "_gun", (0.20, 0.20, 0.22), metallic=0.5, rough=0.5)
        B.box(mid + "_crate", (1.08, 1.08, 0.63), (0, 0, 0.32), wood)
        for i, ang in enumerate((-0.35, 0.0, 0.35)):
            B.cyl(f"{mid}_mg{i}", 0.09, 0.87, (math.sin(ang) * 0.45, 0.38, 0.82),
                  gunm, rot=(PI / 2, 0, ang), verts=8)
    elif kind == "wingman":
        # tiny biplane silhouette
        linen = B.mat(mid + "_linen", (0.55, 0.61, 0.66), rough=0.85)
        wood = B.mat(mid + "_wood", (0.42, 0.50, 0.58), rough=0.8)
        B.box(mid + "_wing", (1.72, 0.45, 0.09), (0, 0.15, 0.45), linen)
        B.box(mid + "_wing2", (1.42, 0.39, 0.09), (0, -0.08, 0.24), linen)
        B.box(mid + "_fus", (0.24, 1.42, 0.21), (0, 0, 0.33), wood)
        B.box(mid + "_tail", (0.68, 0.24, 0.08), (0, -0.72, 0.36), linen)
    return B.finish(mid)


# ------------------------------------------------------- wingman roll frames
def render_wingman_roll():
    """8-frame barrel roll about the forward (+Y) axis, from the v16
    wingman SPAD build — frame 0 matches wingman-spad.png."""
    R16.build_wingman_spad()
    root = bpy.data.objects.get("wingman-spad")
    R16.normalize_pose(root)
    R16.add_spad_roundels("wingman-spad")
    nose_y = R16.add_cowling(root, "wingman-spad")
    R16.upgrade_materials(root, nose_y)
    bpy.context.view_layer.update()
    cx, cy, ztop = R16.frame_model(root, 0, 0)
    R16.setup_render()
    R16.add_lighting(cx, cy, ztop)
    for i in range(8):
        theta = math.radians(i * 45.0)
        root.rotation_euler = (0.0, theta, 0.0)
        bpy.context.view_layer.update()
        bpy.context.scene.render.filepath = os.path.join(
            WING_OUT, f"wingman-roll-{i:02d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"V19 ROLL wingman-roll-{i:02d}.png")


ROSTER = [
    ("tank-german", lambda: build_tank("german"), "tank-german.png"),
    ("tank-french", lambda: build_tank("french"), "tank-french.png"),
    ("tank-uk", lambda: build_tank("uk"), "tank-uk.png"),
    ("tank-a7v", build_a7v, "tank-a7v.png"),
    ("tank-barrel", build_tank_barrel, "tank-barrel.png"),
    ("truck", build_truck, "truck.png"),
    ("barge", build_barge, "barge.png"),
    ("mg-nest", build_mg_nest, "mg-nest.png"),
    ("item-fuel", lambda: build_pickup("fuel"), "item-fuel.png"),
    ("item-rapid", lambda: build_pickup("rapid"), "item-rapid.png"),
    ("item-spread", lambda: build_pickup("spread"), "item-spread.png"),
    ("item-wingman", lambda: build_pickup("wingman"), "item-wingman.png"),
]


def main():
    manifest = []
    for model_id, build_fn, out_name in ROSTER:
        if ONLY and ONLY != model_id and ONLY != "roll":
            continue
        build_fn()
        finish_and_render(model_id, os.path.join(OUT, out_name))
        manifest.append(model_id)
    if (not ONLY) or ONLY == "roll":
        render_wingman_roll()
        manifest.append("wingman-roll")
    with open(os.path.join(ASSETS, "v19_manifest.json"), "w") as f:
        import json
        json.dump(manifest, f, indent=2)
    print(f"V19 DONE: {manifest}")


if __name__ == "__main__":
    main()
