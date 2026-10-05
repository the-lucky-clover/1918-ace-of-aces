"""v16 — skeuomorphic 2.5D photorealism: material-rich PBR re-renders.

AUDIT (v16): the whole airframe roster failed the bar — flat Principled
materials (single base color + roughness), no wood grain, no fabric ribbing,
no doped-linen sheen, no metal reflections, no exhaust grime, no wear.
player-spad, wingman-spad, enemy-fighter, zeppelin visually confirmed flat;
the rest share the identical builder/material pipeline, so all re-rendered.

APPROACH: rebuild every airframe through build_models, then UPGRADE each
material slot to procedural PBR (no image textures, all original):
  - doped linen  : rib bump (wave bands) + clearcoat sheen + roughness noise
  - plywood skin : stretched-noise wood grain under paint + clearcoat
  - metal cowling: new geometry — cowling ring + exhaust stubs, metallic PBR
  - chipped paint: noise-threshold primer show-through
  - exhaust grime: nose-ward oily gradient, noise-broken
  - laminated prop: striped wood
  - markings     : painted, slight wear
LIGHTING: v14 sun-rig convention — screen-up is North, canonical solar-noon
key sun due SOUTH at 60° elevation, so in-engine sun grading stays coherent.
Shadows/grades are applied in-engine (sun.gd); renders stay neutral-noon.

Run headless:  blender --background --python render_v16.py [--only=model_id]
"""

import bpy
import math
import os
import sys
import json
from mathutils import Vector

PI = math.pi
ASSETS = os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender")
sys.path.insert(0, ASSETS)
import build_models as B
import build_locales as L

OUT = os.path.expanduser("~/workspace/1918-godot/assets/sprites")
LOOP_OUT = os.path.join(OUT, "loop")
os.makedirs(OUT, exist_ok=True)
os.makedirs(LOOP_OUT, exist_ok=True)

RES = 256
ORTHO_SCALE = 8.0
BANK = 0.45
SAMPLES = 48

ONLY = None
for a in sys.argv:
    if a.startswith("--only="):
        ONLY = a.split("=", 1)[1]


# ---------------------------------------------------------------- PBR nodes
def _nt(mat):
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    out.location = (400, 0)
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (100, 0)
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return nt, bsdf


def _has(bsdf, name):
    return name in bsdf.inputs


def _set(bsdf, name, val):
    if _has(bsdf, name):
        bsdf.inputs[name].default_value = val


def _obj_tex(nt, ttype, scale, x= -300):
    """Procedural texture in Generated space (0..1 across the bounds).
    Object space proved degenerate on joined meshes (constant output);
    Generated is predictable. Scales are tuned for the 0..1 range."""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.location = (x - 260, 200)
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.location = (x - 100, 200)
    mp.inputs["Scale"].default_value = scale
    t = nt.nodes.new(ttype)
    t.location = (x, 200)
    nt.links.new(tc.outputs["Generated"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], t.inputs["Vector"])
    return t


def _ramp(nt, tex, stops, x= -100):
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.location = (x, 200)
    els = r.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], (*stops[0][1], 1.0)
    els[1].position, els[1].color = stops[-1][0], (*stops[-1][1], 1.0)
    for pos, col in stops[1:-1]:
        e = els.new(pos)
        e.color = (*col, 1.0)
    nt.links.new(tex.outputs["Fac"], r.inputs["Fac"])
    return r


def _bump(nt, bsdf, tex, strength=0.4, x= -100):
    b = nt.nodes.new("ShaderNodeBump")
    b.location = (x, -160)
    b.inputs["Strength"].default_value = strength
    nt.links.new(tex.outputs["Fac"], b.inputs["Height"])
    if _has(bsdf, "Normal"):
        nt.links.new(b.outputs["Normal"], bsdf.inputs["Normal"])


def _rough_noise(nt, bsdf, lo, hi, scale=(6, 6, 6)):
    n = _obj_tex(nt, "ShaderNodeTexNoise", (scale[0], scale[1], scale[2]), x=-420)
    r = _ramp(nt, n, [(0.0, (lo, lo, lo)), (1.0, (hi, hi, hi))], x=-260)
    if _has(bsdf, "Roughness"):
        nt.links.new(r.outputs["Color"], bsdf.inputs["Roughness"])


def _sheen(nt, bsdf, weight=0.30, rough=0.5):
    _set(bsdf, "Coat Weight", weight)
    _set(bsdf, "Coat Roughness", rough)


def _albedo_bands(nt, tex, base, dark=0.70, light=1.25, amount=0.85, x=-260):
    """Modulate base color by a texture's Fac: valleys darker, ridges
    lighter. This is what reads as 'material' under a high sun, where
    bump shading vanishes. Strong variation — lighting compresses the
    range, so subtle doesn't survive. Returns the Mix node; caller links
    its Result onward."""
    r = _ramp(nt, tex,
        [(0.0, (base[0] * dark, base[1] * dark, base[2] * dark)),
         (1.0, (min(1.0, base[0] * light), min(1.0, base[1] * light),
                min(1.0, base[2] * light)))],
        x=x)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.location = (x + 180, 80)
    mix.data_type = 'RGBA'
    mix.inputs["Factor"].default_value = amount
    mix.inputs["A"].default_value = (*base, 1.0)
    nt.links.new(r.outputs["Color"], mix.inputs["B"])
    return mix


def _chips(nt, bsdf, base, amount=0.5, prior=None):
    """Noise-threshold primer show-through. If prior (a Mix node) is given,
    the chips build on its Result instead of the flat base."""
    n = _obj_tex(nt, "ShaderNodeTexNoise", (24, 24, 24), x=-420)
    n.inputs["Detail"].default_value = 3.0
    r = _ramp(nt, n, [(0.0, (0, 0, 0)), (0.80, (0, 0, 0)),
                      (0.86, (1, 1, 1)), (1.0, (1, 1, 1))], x=-260)
    mix = nt.nodes.new("ShaderNodeMix")
    mix.location = (-80, -40)
    mix.data_type = 'RGBA'
    mix.inputs["Factor"].default_value = amount
    if prior is not None:
        nt.links.new(prior.outputs["Result"], mix.inputs["A"])
    else:
        mix.inputs["A"].default_value = (*base, 1.0)
    mix.inputs["B"].default_value = (0.16, 0.14, 0.11, 1.0)  # primer
    nt.links.new(r.outputs["Color"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    return mix


def _grime_nose(nt, mix_out, nose_y, strength=0.55):
    """Oily exhaust gradient toward the nose (+Y), noise-broken.
    Uses Generated Y (0..1 across bounds); nose sits at Y=1."""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    tc.location = (-620, -260)
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    sep.location = (-460, -260)
    nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.location = (-300, -260)
    mr.clamp = True
    mr.inputs["From Min"].default_value = 0.62
    mr.inputs["From Max"].default_value = 1.0
    mr.inputs["To Min"].default_value = 0.0
    mr.inputs["To Max"].default_value = 1.0
    nt.links.new(sep.outputs["Y"], mr.inputs["Value"])
    nz = _obj_tex(nt, "ShaderNodeTexNoise", (9, 9, 9), x=-300)
    nz.location = (-300, -420)
    mul = nt.nodes.new("ShaderNodeMath")
    mul.location = (-140, -300)
    mul.operation = 'MULTIPLY'
    mul.inputs[1].default_value = strength
    nt.links.new(mr.outputs["Result"], mul.inputs[0])
    nt.links.new(nz.outputs["Fac"], mul.inputs[1])
    return mul


# ---------------------------------------------------------------- role PBR
def pbr_linen(name, base):
    m = bpy.data.materials.new(name=name + "_PBR")
    nt, bsdf = _nt(m)
    _set(bsdf, "Roughness", 0.72)
    _set(bsdf, "Specular IOR Level", 0.4)
    # ribbing: fine spanwise bands, DIRECT to Base Color (complex Mix chains
    # proved unreliable in the booth; direct texture->color renders correctly).
    # Strong variation — the v14 sun compresses subtle ranges.
    w = _obj_tex(nt, "ShaderNodeTexWave", (5.0, 5.0, 5.0), x=-420)
    w.wave_type = 'BANDS'
    w.bands_direction = 'X'
    w.inputs["Distortion"].default_value = 0.4
    dark = (base[0] * 0.70, base[1] * 0.70, base[2] * 0.70)
    light = (min(1.0, base[0] * 1.30), min(1.0, base[1] * 1.30),
             min(1.0, base[2] * 1.30))
    r = _ramp(nt, w, [(0.0, dark), (1.0, light)], x=-260)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    _bump(nt, bsdf, w, strength=0.35)
    _rough_noise(nt, bsdf, 0.62, 0.80)
    _sheen(nt, bsdf, 0.30, 0.55)
    return m


def pbr_skin(name, base, nose_y=None):
    """Painted plywood / doped skin: grain under paint, nose grime.
    Direct texture->color (Mix chains proved unreliable in the booth)."""
    m = bpy.data.materials.new(name=name + "_PBR")
    nt, bsdf = _nt(m)
    _set(bsdf, "Roughness", 0.58)
    # wood grain stretched along Y, ghosting through the paint — direct
    g = _obj_tex(nt, "ShaderNodeTexNoise", (2.2, 13.0, 2.2), x=-420)
    # grain darkens the base; strong so it survives the sun
    gd = (base[0] * 0.72, base[1] * 0.72, base[2] * 0.72)
    gl = (min(1.0, base[0] * 1.12), min(1.0, base[1] * 1.12),
          min(1.0, base[2] * 1.12))
    r = _ramp(nt, g, [(0.0, gd), (0.55, base), (1.0, gl)], x=-260)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    _rough_noise(nt, bsdf, 0.50, 0.66)
    _sheen(nt, bsdf, 0.35, 0.5)
    return m


def pbr_metal(name, base, rough=0.42):
    m = bpy.data.materials.new(name=name + "_PBR")
    nt, bsdf = _nt(m)
    # brushed metal: subtle tonal mottling, direct to color
    n = _obj_tex(nt, "ShaderNodeTexNoise", (12, 12, 12), x=-420)
    md = (base[0] * 0.85, base[1] * 0.85, base[2] * 0.85)
    ml = (min(1.0, base[0] * 1.12), min(1.0, base[1] * 1.12),
          min(1.0, base[2] * 1.12))
    r = _ramp(nt, n, [(0.0, md), (1.0, ml)], x=-260)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    # metallic kept moderate: no HDRI in the sprite booth, full mirror = black
    _set(bsdf, "Metallic", 0.62)
    _set(bsdf, "Roughness", rough)
    _rough_noise(nt, bsdf, rough - 0.12, rough + 0.18, scale=(10, 10, 10))
    return m


def pbr_wood(name, base):
    m = bpy.data.materials.new(name=name + "_PBR")
    nt, bsdf = _nt(m)
    g = _obj_tex(nt, "ShaderNodeTexNoise", (2.0, 16.0, 2.0), x=-420)
    r = _ramp(nt, g, [(0.0, (0.24, 0.16, 0.09)), (0.5, base), (1.0, (0.42, 0.30, 0.17))], x=-260)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    _set(bsdf, "Roughness", 0.7)
    _rough_noise(nt, bsdf, 0.62, 0.78)
    _sheen(nt, bsdf, 0.15, 0.6)
    return m


def pbr_marking(name, base):
    m = bpy.data.materials.new(name=name + "_PBR")
    nt, bsdf = _nt(m)
    _set(bsdf, "Base Color", (*base, 1.0))
    _set(bsdf, "Roughness", 0.66)
    _rough_noise(nt, bsdf, 0.58, 0.74)
    _sheen(nt, bsdf, 0.25, 0.55)
    return m


def pbr_envelope(name, base):
    """Balloon/zeppelin envelope: ribbed doped fabric, direct to color."""
    m = bpy.data.materials.new(name=name + "_PBR")
    nt, bsdf = _nt(m)
    _set(bsdf, "Roughness", 0.68)
    w = _obj_tex(nt, "ShaderNodeTexWave", (3.0, 9.0, 3.0), x=-420)
    w.wave_type = 'BANDS'
    w.bands_direction = 'Y'
    dark = (base[0] * 0.72, base[1] * 0.72, base[2] * 0.72)
    light = (min(1.0, base[0] * 1.22), min(1.0, base[1] * 1.22),
             min(1.0, base[2] * 1.22))
    r = _ramp(nt, w, [(0.0, dark), (1.0, light)], x=-260)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    _bump(nt, bsdf, w, strength=0.5)
    _rough_noise(nt, bsdf, 0.60, 0.76)
    _sheen(nt, bsdf, 0.30, 0.55)
    return m


def pbr_prop(name):
    """Laminated wooden propeller."""
    m = bpy.data.materials.new(name=name + "_PBR")
    nt, bsdf = _nt(m)
    w = _obj_tex(nt, "ShaderNodeTexWave", (1.2, 14.0, 1.2), x=-420)
    w.wave_type = 'BANDS'
    w.bands_direction = 'Y'
    r = _ramp(nt, w, [(0.0, (0.30, 0.20, 0.11)), (0.5, (0.55, 0.40, 0.24)),
                      (1.0, (0.30, 0.20, 0.11))], x=-260)
    nt.links.new(r.outputs["Color"], bsdf.inputs["Base Color"])
    _set(bsdf, "Roughness", 0.5)
    _sheen(nt, bsdf, 0.4, 0.45)
    return m


ROLE_ORDER = [
    ("kreuz", "marking"), ("_blue", "marking"), ("_white", "marking"),
    ("_red", "marking"), ("roundel", "marking"), ("_seg", "marking"),
    ("band", "marking"), ("rnd", "marking"),
    ("_wing", "linen"), ("_env", "envelope"), ("envelope", "envelope"),
    ("_body", "skin"), ("fuselage", "skin"), ("hull", "skin"),
    ("_accent", "linen"), ("_wood", "wood"), ("basket", "wood"),
    ("_metal", "metal"), ("cowl", "metal"),
    ("_dark", "wooddark"), ("prop", "prop"),
]


def role_of(mat_name):
    n = mat_name.lower()
    for key, role in ROLE_ORDER:
        if key in n:
            return role
    return "plain"


def base_color_of(mat):
    try:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf and "Base Color" in bsdf.inputs:
            c = bsdf.inputs["Base Color"].default_value
            return (c[0], c[1], c[2])
    except Exception:
        pass
    return (0.5, 0.5, 0.5)


def upgrade_materials(root, nose_y=None):
    """Replace every material slot with a PBR version by role.
    Slots are replaced IN PLACE (never cleared/rebuilt): clearing slots
    resets polygon material_index values and scrambles assignments."""
    seen = {}
    for i, slot in enumerate(root.data.materials):
        if slot is None:
            continue
        if slot.name in seen:
            slot_new = seen[slot.name]
        else:
            base = base_color_of(slot)
            role = role_of(slot.name)
            nm = slot.name
            if role == "linen":
                slot_new = pbr_linen(nm, base)
            elif role == "skin":
                slot_new = pbr_skin(nm, base, nose_y)
            elif role == "metal":
                slot_new = pbr_metal(nm, base)
            elif role in ("wood", "wooddark"):
                slot_new = pbr_wood(nm, base)
            elif role == "marking":
                slot_new = pbr_marking(nm, base)
            elif role == "envelope":
                slot_new = pbr_envelope(nm, base)
            elif role == "prop":
                slot_new = pbr_prop(nm)
            else:
                slot_new = pbr_marking(nm, base)
            seen[slot.name] = slot_new
        root.data.materials[i] = slot_new


def normalize_pose(root):
    """Bake the join's baked (pi/2,0,0) rotation into the mesh so the object
    rests at identity: flat, nose +Y, up +Z. join_all() keeps an arbitrary
    part's transform (usually the fuselage's), which made renders
    non-deterministic — this makes the v16 pipeline deterministic."""
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    root.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()


def add_cowling(root, model_id):
    """Metal cowling ring + exhaust stubs at the nose (+Y)."""
    ws = [root.matrix_world @ Vector(c) for c in root.bound_box]
    nose_y = max(v.y for v in ws)
    cx = sum(v.x for v in ws) / 8
    cowl_mat = B.mat(model_id + "_cowlm", (0.42, 0.41, 0.39), metallic=0.7, rough=0.45)
    soot_mat = B.mat(model_id + "_sootm", (0.10, 0.09, 0.08), rough=0.95)
    B.cyl(model_id + "_cowl", 0.37, 0.85, (cx, nose_y - 0.55, 0.02),
          cowl_mat, rot=(PI / 2, 0, 0), verts=14)
    for i, sx in enumerate((-1, 1)):
        B.cyl(f"{model_id}_exh{i}", 0.055, 0.42, (cx + sx * 0.34, nose_y - 0.62, 0.10),
              soot_mat, rot=(PI / 2, 0, sx * 0.35), verts=8)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and (o.name.startswith(model_id + "_cowl")
                                 or o.name.startswith(model_id + "_exh")):
            o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.object.join()
    return nose_y

# ---------------------------------------------------------------- lighting
def setup_render():
    s = bpy.context.scene
    s.render.engine = 'CYCLES'
    s.cycles.device = 'CPU'
    s.cycles.samples = SAMPLES
    s.view_settings.view_transform = 'Standard'
    s.render.resolution_x = RES
    s.render.resolution_y = RES
    s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.render.image_settings.color_depth = '8'


def add_lighting(cx, cy, ztop):
    """v14 sun-rig convention: screen-up = North; canonical solar-noon key
    sun due SOUTH at 60° elevation (warm), cool fill, western rim."""
    cam_data = bpy.data.cameras.new("SpriteCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = ORTHO_SCALE
    cam = bpy.data.objects.new("SpriteCam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = (cx, cy, ztop + 12.0)
    cam.rotation_euler = (0, 0, 0)
    bpy.context.scene.camera = cam

    def sun(name, energy, rot, color):
        bpy.ops.object.light_add(type='SUN', location=(cx, cy, ztop + 5))
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy
        light.data.color = color
        light.rotation_euler = rot
        return light

    # key: from due south (-Y), 60° elevation -> light travels +Y (north), down
    sun("Key", 1.65, (0.52, 0.0, 0.0), (1.0, 0.96, 0.90))
    # fill: cool, from the north-east
    sun("Fill", 0.42, (-0.90, 0.0, -0.55), (0.86, 0.91, 1.0))
    # rim: from the west for edge definition
    sun("Rim", 0.55, (0.15, -0.93, 0.0), (1.0, 0.98, 0.95))


def frame_model(root, cx, cy):
    ws = [root.matrix_world @ Vector(c) for c in root.bound_box]
    xs = [v.x for v in ws]
    ys = [v.y for v in ws]
    zs = [v.z for v in ws]
    return sum(xs) / 8, sum(ys) / 8, max(zs)


def render_frames(model_id, out_names):
    """Render bank-left / level / bank-right (or singles) for a built model."""
    root = bpy.data.objects.get(model_id)
    assert root is not None, f"no object {model_id}"
    bpy.context.view_layer.update()
    cx, cy, ztop = frame_model(root, 0, 0)
    add_lighting(cx, cy, ztop)
    for suffix, roll, fname in out_names:
        root.rotation_euler = (0, roll, 0)
        bpy.context.view_layer.update()
        bpy.context.scene.render.filepath = os.path.join(OUT, fname)
        bpy.ops.render.render(write_still=True)
        print(f"V16 SPRITE {fname}")


def air3(model_id):
    return [("bank-left", BANK, f"{model_id}-bank-left.png"),
            ("level", 0.0, f"{model_id}-level.png"),
            ("bank-right", -BANK, f"{model_id}-bank-right.png")]


# ---------------------------------------------------------------- builds
def build_player_spad():
    # NOTE: roundels are added AFTER normalize_pose (see add_spad_roundels),
    # in the clean normalized frame — never in the baked join frame.
    B.aircraft("player-spad", span=5.0, wings=2, length=5.2,
               body=(0.40, 0.38, 0.26), wing_col=(0.68, 0.62, 0.48),
               accent=(0.88, 0.88, 0.90))


def build_wingman_spad():
    B.aircraft("wingman-spad", span=5.0, wings=2, length=5.2,
               body=(0.42, 0.50, 0.58), wing_col=(0.55, 0.61, 0.66),
               accent=(0.85, 0.55, 0.25))


# roundel colors per SPAD, applied after normalize_pose
SPAD_ROUNDELS = {
    "player-spad": ((0.10, 0.20, 0.55), (0.92, 0.92, 0.90), (0.75, 0.12, 0.15), "roundel"),
    "wingman-spad": ((0.15, 0.55, 0.55), (0.90, 0.86, 0.74), (0.85, 0.45, 0.15), "wroundel"),
}


def add_spad_roundels(model_id):
    """Concentric roundel discs on the top wing, in the NORMALIZED frame
    (flat, nose +Y): top wing center y=0.45, top surface z=0.545."""
    c1, c2, c3, prefix = SPAD_ROUNDELS[model_id]
    m1 = B.mat(f"{model_id}_{prefix}1", c1, rough=0.9)
    m2 = B.mat(f"{model_id}_{prefix}2", c2, rough=0.9)
    m3 = B.mat(f"{model_id}_{prefix}3", c3, rough=0.9)
    for side in (-1, 1):
        x = side * 5.0 * 0.30
        B.cyl(f"{prefix}B{side}", 0.42, 0.03, (x, 0.45, 0.560), m1, verts=24)
        B.cyl(f"{prefix}W{side}", 0.28, 0.035, (x, 0.45, 0.563), m2, verts=24)
        B.cyl(f"{prefix}R{side}", 0.14, 0.04, (x, 0.45, 0.566), m3, verts=24)
    # join into the airframe so they pitch with it (v8 gotcha)
    bpy.ops.object.select_all(action='DESELECT')
    root = bpy.data.objects.get(model_id)
    root.select_set(True)
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.name.startswith(prefix):
            o.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.object.join()


# (model_id, build_fn, frames_fn, cowling?)
# build_fn runs with a CLEAR scene (each B.aircraft/balloon clears).
ROSTER = [
    ("player-spad", build_player_spad,
     [("level", 0.0, "player-spad.png")], True),
    ("wingman-spad", build_wingman_spad,
     [("level", 0.0, "wingman-spad.png")], True),
    ("enemy-triplane", lambda: B.aircraft("enemy-triplane", span=4.6, wings=3, length=4.8,
        body=B.OLIVE, wing_col=B.OLIVE, accent=(0.55, 0.50, 0.38)), None, True),
    ("enemy-scout", lambda: B.aircraft("enemy-scout", span=5.2, wings=2, length=5.6,
        body=B.GRAYGR, wing_col=B.LINEN, accent=B.DARKGR, chord=0.85), None, True),
    ("enemy-fighter", lambda: B.aircraft("enemy-fighter", span=4.8, wings=2, length=4.6,
        body=B.DARKGR, wing_col=B.DARKGR, accent=(0.50, 0.50, 0.52), chunky=True), None, True),
    ("enemy-bomber", lambda: B.aircraft("enemy-bomber", span=7.6, wings=2, length=6.8,
        body=B.DARKGN, wing_col=B.DARKGN, accent=B.METAL, engines=2, chunky=True, chord=1.25),
     None, True),
    ("enemy-fokker-dr1", lambda: B.aircraft("enemy-fokker-dr1", span=4.8, wings=3, length=4.4,
        body=B.FELDGRAU, wing_col=(0.42, 0.40, 0.30), accent=B.BLACK, kreuz=True, chord=1.05),
     None, True),
    ("enemy-fokker-d7", lambda: B.aircraft("enemy-fokker-d7", span=5.6, wings=2, length=4.8,
        body=B.LOZENG, wing_col=(0.38, 0.36, 0.28), accent=B.BLACK, kreuz=True, chunky=True),
     None, True),
    ("enemy-albatros", lambda: B.aircraft("enemy-albatros", span=5.8, wings=2, length=5.2,
        body=B.PLYWOOD, wing_col=(0.40, 0.40, 0.28), accent=B.BLACK, kreuz=True), None, True),
    ("boss-1-red", lambda: B.aircraft("boss-1-red", span=4.6, wings=3, length=4.8,
        body=B.RED, wing_col=B.RED, accent=B.WHITE), None, True),
    ("boss-2-checker", lambda: B.aircraft("boss-2-checker", span=4.8, wings=2, length=4.6,
        body=B.BLACK, wing_col=B.YELLOW, accent=B.BLACK, livery_wing='checker', chunky=True),
     None, True),
    ("boss-3-stripes", lambda: B.aircraft("boss-3-stripes", span=5.2, wings=2, length=5.6,
        body=B.BLUE, wing_col=B.WHITE, accent=B.RED, livery_fus='segmented', chord=0.85),
     None, True),
    ("boss-4-tiger", lambda: B.aircraft("boss-4-tiger", span=5.2, wings=2, length=5.4,
        body=B.ORANGE, wing_col=B.ORANGE, accent=B.BLACK, livery_wing='banded', chord=0.9),
     None, True),
    ("boss-5-jester", lambda: B.aircraft("boss-5-jester", span=4.6, wings=3, length=4.8,
        body=B.PURPLE, wing_col=B.TEAL, accent=B.WHITE, livery_wing='checker'), None, True),
    ("boss-6-ghost", lambda: B.aircraft("boss-6-ghost", span=6.0, wings=2, length=5.8,
        body=B.WHITE, wing_col=B.WHITE, accent=B.RED, livery_wing='striped', chunky=True),
     None, True),
    ("boss-7-baron", lambda: B.aircraft("boss-7-baron", span=6.2, wings=3, length=5.6,
        body=B.RED, wing_col=B.RED, accent=B.BLACK, livery_wing='banded', chunky=True),
     None, True),
    ("enemy-balloon", lambda: B.balloon("enemy-balloon"),
     [("level", 0.0, "enemy-balloon-level.png"),
      ("bank-left", BANK, "enemy-balloon-bank-left.png"),
      ("bank-right", -BANK, "enemy-balloon-bank-right.png")], False),
    ("zeppelin", lambda: L.zeppelin(),
     [("level", 0.0, "zeppelin.png")], False),
]


def render_loop_frames():
    """12-frame Immelmann from the v16 SPAD — normalized pose, so level is
    identity and the loop pitches forward about X: level -> nose-up climb ->
    over the top -> inverted -> nose-down -> level recovery."""
    build_player_spad()
    root = bpy.data.objects.get("player-spad")
    normalize_pose(root)
    add_spad_roundels("player-spad")
    nose_y = add_cowling(root, "player-spad")
    upgrade_materials(root, nose_y)
    blend = os.path.join(ASSETS, "models", "player-spad.blend")
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    bpy.context.view_layer.update()
    cx, cy, ztop = frame_model(root, 0, 0)
    setup_render()
    add_lighting(cx, cy, ztop)
    FRAMES = 12
    for i in range(FRAMES):
        theta = math.radians(i * 360.0 / FRAMES)
        root.rotation_euler = (theta, 0.0, 0.0)
        bpy.context.view_layer.update()
        bpy.context.scene.render.filepath = os.path.join(LOOP_OUT, f"loop-{i:02d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"V16 LOOP loop-{i:02d}.png")


def main():
    manifest = []
    for model_id, build_fn, frames, cowling in ROSTER:
        if ONLY and ONLY != model_id and ONLY != "loop":
            continue
        if model_id == "player-spad" and "loop" in sys.argv:
            continue  # loop run handles the SPAD itself
        build_fn()
        root = bpy.data.objects.get(model_id)
        normalize_pose(root)
        if model_id in SPAD_ROUNDELS:
            add_spad_roundels(model_id)
        nose_y = add_cowling(root, model_id) if cowling else None
        upgrade_materials(root, nose_y)
        blend = os.path.join(ASSETS, "models", model_id + ".blend")
        bpy.ops.wm.save_as_mainfile(filepath=blend)
        setup_render()
        render_frames(model_id, frames if frames else air3(model_id))
        manifest.append(model_id)
    if (not ONLY) or ONLY == "loop":
        render_loop_frames()
        manifest.append("loop")
    with open(os.path.join(ASSETS, "v16_manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"V16 DONE: {manifest}")


if __name__ == "__main__":
    main()
