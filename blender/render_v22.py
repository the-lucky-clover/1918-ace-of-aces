"""v22 — new enemy/boss sprite renders for the 32-sortie campaign.

Reuses the v16 render pipeline (procedural PBR upgrade, v14 sun-rig
lighting, top-down ortho camera, nose +Y) for 13 new models:

  ENEMIES (enemy-*)
    enemy-eindecker     early-war monoplane (parasol-ish single wing)
    enemy-albatros-d3   biplane
    enemy-rumpler       recon two-seater, long fuselage
    enemy-gotha         twin-engine bomber
    enemy-staaken       giant twin-engine bomber (bigger/boxier than Gotha)
    enemy-searchlight   ground searchlight tower (single level frame)

  ACE LIVERIES (boss-*, 3 frames each)
    boss-bluemax   bright blue, white-banded wings
    boss-noir      black with white-striped wings
    boss-lozenge   camouflaged D.VII-ish, chunky
    boss-silver    polished metal
    boss-green     green with yellow accent
    boss-crimson   dark-red triplane
    boss-sand      sand with black cross

All geometry is original procedural work — game sprites, not photographic.
Blend files are saved per-model; PNGs go to the godot sprite dir and are
mirrored to the repo's assets/sprites/.

Run headless:
  blender-softwaregl --background --python render_v22.py [--only=model_id]
"""

import bpy
import math
import os
import sys
import shutil

PI = math.pi

REPO = os.path.expanduser("~/workspace/1918-ace-of-aces/blender")
ASSETS = os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender")
sys.path.insert(0, REPO)
sys.path.insert(0, ASSETS)

import build_models as B
from render_v16 import (normalize_pose, upgrade_materials, setup_render,
                        render_frames, add_cowling, air3, BANK)

OUT = os.path.expanduser("~/workspace/1918-godot/assets/sprites")
REPO_OUT = os.path.expanduser("~/workspace/1918-ace-of-aces/assets/sprites")
MODELS_DIR = os.path.join(REPO, "models")
for d in (OUT, REPO_OUT, MODELS_DIR):
    os.makedirs(d, exist_ok=True)

ONLY = None
for a in sys.argv:
    if a.startswith("--only="):
        ONLY = a.split("=", 1)[1]


# ---------------------------------------------------------------- searchlight
def build_searchlight(model_id):
    """Ground searchlight tower: concrete pad, 4 tapering steel legs with
    cross braces, platform, and a tilted searchlight drum with a pale lens.
    Top-down ortho render like other ground targets."""
    B.clear_scene()
    cm = B.mat(model_id + "_conc", (0.52, 0.52, 0.50), rough=0.95)
    sm = B.mat(model_id + "_steel", (0.42, 0.43, 0.45),
               metallic=0.6, rough=0.5)
    dm = B.mat(model_id + "_dark", B.DARK)
    lm = B.mat(model_id + "_lens", (0.88, 0.92, 0.95), rough=0.25)
    wm = B.mat(model_id + "_wood", B.WOOD)

    # concrete pad
    B.box("pad", (4.2, 4.2, 0.25), (0, 0, 0.12), cm)

    # 4 tapering tower legs (wide foot, narrow top)
    for lx in (-1.2, 1.2):
        for ly in (-1.2, 1.2):
            B.cone(f"leg{lx}_{ly}", 0.20, 0.10, 2.0, (lx, ly, 1.20), sm,
                   verts=8)
            # foot plates
            B.box(f"foot{lx}_{ly}", (0.45, 0.45, 0.10), (lx, ly, 0.30), sm)

    # cross braces between the legs at mid height
    for bz in (0.75, 1.55):
        B.box(f"braceN{bz}", (2.4, 0.08, 0.08), (0, 1.2, bz), sm)
        B.box(f"braceS{bz}", (2.4, 0.08, 0.08), (0, -1.2, bz), sm)
        B.box(f"braceE{bz}", (0.08, 2.4, 0.08), (1.2, 0, bz), sm)
        B.box(f"braceW{bz}", (0.08, 2.4, 0.08), (-1.2, 0, bz), sm)

    # operator platform
    B.box("plat", (1.7, 1.7, 0.12), (0, 0, 2.25), sm)
    # crank box on the platform
    B.box("crank", (0.5, 0.4, 0.45), (0.5, 0.4, 2.50), dm)

    # searchlight drum: axis tilted ~32 deg from vertical toward -Y so the
    # lens reads from the top-down camera
    tilt = 0.55
    B.cyl("drum", 0.45, 0.95, (0, 0, 2.95), dm, rot=(tilt, 0, 0), verts=14)
    # pale lens disc at the mouth of the drum
    B.cyl("lens", 0.38, 0.07,
          (0, -math.sin(tilt) * 0.48, 2.95 + math.cos(tilt) * 0.48),
          lm, rot=(tilt, 0, 0), verts=14)
    # drum rear cap ring
    B.cyl("drumring", 0.47, 0.10, (0, math.sin(tilt) * 0.42,
                                   2.95 - math.cos(tilt) * 0.42),
          sm, rot=(tilt, 0, 0), verts=14)
    # cable spool on the pad
    B.cyl("spool", 0.30, 0.45, (-1.4, 1.4, 0.48), wm, verts=10)
    return B.finish(model_id)


# ---------------------------------------------------------------- roster
# (model_id, build_fn, frames_fn_or_None, cowling?)
# frames None -> air3() bank-left / level / bank-right
ROSTER = [
    # --- ENEMIES ---
    ("enemy-eindecker",
     lambda: B.aircraft("enemy-eindecker", span=5.4, wings=1, length=5.0,
                        body=(0.42, 0.40, 0.32), wing_col=(0.66, 0.60, 0.46),
                        accent=B.BLACK, kreuz=True),
     None, True),
    ("enemy-albatros-d3",
     lambda: B.aircraft("enemy-albatros-d3", span=5.6, wings=2, length=5.0,
                        body=(0.45, 0.42, 0.30), wing_col=(0.40, 0.38, 0.28),
                        accent=B.BLACK, kreuz=True),
     None, True),
    ("enemy-rumpler",
     lambda: B.aircraft("enemy-rumpler", span=6.4, wings=2, length=6.2,
                        body=(0.38, 0.40, 0.32), wing_col=(0.55, 0.52, 0.40),
                        accent=B.BLACK, kreuz=True),
     None, True),
    ("enemy-gotha",
     lambda: B.aircraft("enemy-gotha", span=9.0, wings=2, length=7.0,
                        body=(0.35, 0.36, 0.30), wing_col=(0.45, 0.42, 0.32),
                        accent=B.BLACK, kreuz=True, engines=2, chunky=True,
                        chord=1.3),
     None, True),
    ("enemy-staaken",
     lambda: B.aircraft("enemy-staaken", span=11.0, wings=2, length=8.0,
                        body=(0.32, 0.33, 0.28), wing_col=(0.42, 0.40, 0.30),
                        accent=B.BLACK, kreuz=True, engines=2, chunky=True,
                        chord=1.4),
     None, True),
    ("enemy-searchlight",
     lambda: build_searchlight("enemy-searchlight"),
     [("level", 0.0, "enemy-searchlight.png")], False),

    # --- ACE LIVERIES ---
    ("boss-bluemax",
     lambda: B.aircraft("boss-bluemax", span=5.6, wings=2, length=5.2,
                        body=(0.10, 0.25, 0.75), wing_col=(0.10, 0.25, 0.75),
                        accent=(0.92, 0.92, 0.90), livery_wing='banded'),
     None, True),
    ("boss-noir",
     lambda: B.aircraft("boss-noir", span=5.6, wings=2, length=5.2,
                        body=(0.08, 0.08, 0.08), wing_col=(0.20, 0.20, 0.22),
                        accent=(0.92, 0.92, 0.90), livery_wing='striped'),
     None, True),
    ("boss-lozenge",
     lambda: B.aircraft("boss-lozenge", span=5.6, wings=2, length=4.8,
                        body=(0.45, 0.40, 0.30), wing_col=(0.50, 0.42, 0.30),
                        accent=B.BLACK, kreuz=True, chunky=True),
     None, True),
    ("boss-silver",
     lambda: B.aircraft("boss-silver", span=5.6, wings=2, length=5.2,
                        body=B.METAL, wing_col=(0.60, 0.61, 0.63),
                        accent=B.RED),
     None, True),
    ("boss-green",
     lambda: B.aircraft("boss-green", span=5.6, wings=2, length=5.2,
                        body=(0.25, 0.35, 0.22), wing_col=(0.30, 0.40, 0.25),
                        accent=B.YELLOW),
     None, True),
    ("boss-crimson",
     lambda: B.aircraft("boss-crimson", span=4.8, wings=3, length=4.8,
                        body=(0.55, 0.08, 0.08), wing_col=(0.50, 0.08, 0.08),
                        accent=B.BLACK, kreuz=True),
     None, True),
    ("boss-sand",
     lambda: B.aircraft("boss-sand", span=5.6, wings=2, length=5.2,
                        body=(0.55, 0.48, 0.35), wing_col=(0.60, 0.52, 0.36),
                        accent=B.BLACK, kreuz=True),
     None, True),
]


def mirror_to_repo(fnames):
    for f in fnames:
        src = os.path.join(OUT, f)
        dst = os.path.join(REPO_OUT, f)
        if os.path.exists(src):
            shutil.copy2(src, dst)


def main():
    manifest = []
    for model_id, build_fn, frames, cowling in ROSTER:
        if ONLY and ONLY != model_id:
            continue
        build_fn()
        root = bpy.data.objects.get(model_id)
        normalize_pose(root)
        nose_y = add_cowling(root, model_id) if cowling else None
        upgrade_materials(root, nose_y)
        blend = os.path.join(MODELS_DIR, model_id + ".blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        setup_render()
        fnames = frames if frames else air3(model_id)
        render_frames(model_id, fnames)
        mirror_to_repo(f for _, _, f in fnames)
        manifest.append(model_id)
    with open(os.path.join(REPO, "v22_manifest.json"), "w") as f:
        import json
        json.dump(manifest, f, indent=2)
    print(f"V22 DONE: {manifest}")


if __name__ == "__main__":
    main()
