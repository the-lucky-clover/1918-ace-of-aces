"""Procedural low-poly WWI asset set for 1918: Ace of Aces.
Builds 20 original models, saves .blend + exports .glb, writes manifest JSON.
Run headless: blender --background --python build_models.py
"""
import bpy
import math
import os
import json

PI = math.pi
MODELS_DIR = os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender/models")
os.makedirs(MODELS_DIR, exist_ok=True)
MANIFEST = []

# ---------------------------------------------------------------- helpers
def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for x in list(coll):
            if getattr(x, "users", 1) == 0:
                try:
                    coll.remove(x)
                except Exception:
                    pass

def mat(name, rgb, metallic=0.0, rough=0.85):
    m = bpy.data.materials.new(name=name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = rough
    return m

def paint(obj, material):
    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)
    return obj

def box(name, dims, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = (dims[0], dims[1], dims[2])
    return paint(o, material)

def cyl(name, r, depth, loc, material, rot=(0, 0, 0), verts=10):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts,
                                       location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return paint(o, material)

def sphere(name, r, loc, material, segs=10, rings=6, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=segs,
                                        ring_count=rings, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    return paint(o, material)

def cone(name, r1, r2, depth, loc, material, rot=(0, 0, 0), verts=10):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth,
                                   vertices=verts, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return paint(o, material)

def join_all(name):
    bpy.ops.object.select_all(action='SELECT')
    objs = bpy.context.selected_objects
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    return o

def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)

def finish(model_id):
    """Join, count tris, save .blend, export .glb, record manifest."""
    root = join_all(model_id)
    tris = tri_count(root)
    blend_path = os.path.join(MODELS_DIR, model_id + ".blend")
    glb_path = os.path.join(MODELS_DIR, model_id + ".glb")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB',
                              use_selection=True, export_materials='EXPORT')
    MANIFEST.append({"id": model_id, "tris": tris,
                     "blend": blend_path, "glb": glb_path})
    print(f"MODEL {model_id}: {tris} tris")
    return root

# ---------------------------------------------------------------- palette
DARK   = (0.15, 0.13, 0.11)
METAL  = (0.45, 0.46, 0.48)
WOOD   = (0.45, 0.32, 0.20)
LINEN  = (0.72, 0.66, 0.52)
WHITE  = (0.92, 0.92, 0.90)
BLACK  = (0.08, 0.08, 0.08)
RED    = (0.80, 0.03, 0.03)
YELLOW = (0.92, 0.68, 0.06)
BLUE   = (0.10, 0.25, 0.75)
ORANGE = (0.92, 0.38, 0.03)
PURPLE = (0.42, 0.08, 0.58)
TEAL   = (0.05, 0.58, 0.52)
OLIVE  = (0.36, 0.37, 0.24)
GRAYGR = (0.45, 0.47, 0.40)
DARKGR = (0.30, 0.30, 0.32)
DARKGN = (0.30, 0.36, 0.26)
SAND   = (0.55, 0.48, 0.35)
EARTH  = (0.25, 0.20, 0.14)
GRASS  = (0.35, 0.48, 0.25)
FIELD  = (0.45, 0.35, 0.22)
BRASS  = (0.65, 0.50, 0.20)

# ---------------------------------------------------------------- aircraft
def aircraft(model_id, span=5.0, wings=2, length=5.0, body=OLIVE, wing_col=None,
             accent=RED, livery_fus='solid', livery_wing='solid',
             engines=0, chunky=False, chord=1.0):
    """Nose points +Y. wings = number of stacked wings."""
    clear_scene()
    wing_col = wing_col if wing_col is not None else body
    wm = mat(model_id + "_wing", wing_col)
    bm = mat(model_id + "_body", body)
    am = mat(model_id + "_accent", accent)
    dm = mat(model_id + "_dark", DARK)
    mm = mat(model_id + "_metal", METAL, metallic=0.6, rough=0.5)
    L = length
    fr = 0.38 if chunky else 0.30

    # --- fuselage (segmented for striped livery, else one cylinder + tail cone)
    if livery_fus == 'segmented':
        seg_cols = [accent, body, accent, body]
        seg_len = (L * 0.62) / 4
        y0 = -0.2 - L * 0.31
        for i, c in enumerate(seg_cols):
            sm = mat(f"{model_id}_seg{i}", c)
            cyl(f"seg{i}", fr, seg_len, (0, y0 + seg_len * (i + 0.5), 0),
                sm, rot=(PI / 2, 0, 0))
    else:
        cyl("fus", fr, L * 0.62, (0, -0.2, 0), bm, rot=(PI / 2, 0, 0))
    cone("tailcone", fr, 0.07, L * 0.30,
         (0, -0.2 - L * 0.31 - L * 0.15, 0), bm, rot=(PI / 2, 0, 0))
    nose_y = -0.2 + L * 0.31

    # --- wings, stacked in Z
    if wings == 3:
        zoff = [0.55, 0.05, -0.45]
        yoff = [0.15, 0.0, -0.15]
    elif wings == 2:
        zoff = [0.50, -0.35]
        yoff = [0.25, -0.30]
    else:
        zoff = [0.30]
        yoff = [0.0]
    for wi, (zw, yw) in enumerate(zip(zoff, yoff)):
        if livery_wing == 'checker':
            # 2 rows x 4 cols alternating boxes
            nx, ny = 4, 2
            for ix in range(nx):
                for iy in range(ny):
                    c = am if (ix + iy) % 2 == 0 else wm
                    box(f"wing{wi}_{ix}_{iy}",
                        (span / nx, chord / ny, 0.09),
                        (-span / 2 + span * (ix + 0.5) / nx,
                         yw - chord / 2 + chord * (iy + 0.5) / ny, zw), c)
        elif livery_wing == 'banded':
            box(f"wing{wi}", (span, chord, 0.09), (0, yw, zw), wm)
            for bx in (-span * 0.28, span * 0.28):
                box(f"band{wi}_{bx}", (span * 0.12, chord + 0.02, 0.11),
                    (bx, yw, zw), am)
        elif livery_wing == 'striped':
            nx = 6
            for ix in range(nx):
                c = am if ix % 2 == 0 else wm
                box(f"wing{wi}_{ix}", (span / nx, chord, 0.09),
                    (-span / 2 + span * (ix + 0.5) / nx, yw, zw), c)
        else:
            box(f"wing{wi}", (span, chord, 0.09), (0, yw, zw), wm)
            # simple roundel discs on top wing
            if wi == 0:
                for sx in (-span * 0.32, span * 0.32):
                    cyl(f"rnd{wi}_{sx}", 0.30, 0.03, (sx, yw, zw + 0.06),
                        am, verts=12)
    # interplane struts
    if wings >= 2:
        for sx in (-span * 0.30, span * 0.30):
            gap = zoff[0] - zoff[-1]
            box(f"strut_{sx}", (0.09, 0.30, gap),
                (sx, (yoff[0] + yoff[-1]) / 2, (zoff[0] + zoff[-1]) / 2), dm)

    # --- tail
    y_tail = -0.2 - L * 0.31 - L * 0.22
    box("hstab", (span * 0.42, 0.55, 0.07), (0, y_tail, 0.10), wm)
    box("fin", (0.07, 0.70, 0.80), (0, y_tail - 0.05, 0.45), bm)
    if livery_wing != 'solid':
        box("finacc", (0.09, 0.30, 0.40), (0, y_tail - 0.05, 0.45), am)

    # --- cockpit
    sphere("cockpit", 0.28, (0, -0.65, 0.36), dm, scale=(0.85, 1.25, 0.55))

    # --- propeller(s)
    def propeller(px, py, pz, scale=1.0):
        box("blade1", (1.7 * scale, 0.10, 0.22), (px, py, pz), dm)
        box("blade2", (1.7 * scale, 0.10, 0.22), (px, py, pz), dm,
            rot=(0, PI / 2, 0))
        cone("spinner", 0.16 * scale, 0.02, 0.35 * scale, (px, py + 0.18 * scale, pz),
             mm, rot=(-PI / 2, 0, 0))
    if engines == 0:
        propeller(0, nose_y + 0.12, 0.10)
    else:
        for ex in (-span * 0.22, span * 0.22):
            cyl(f"nac{ex}", 0.28, 1.7, (ex, 0.35, -0.02), bm, rot=(PI / 2, 0, 0))
            propeller(ex, 0.35 + 0.95, -0.02, scale=0.8)

    # --- landing gear
    box("axle", (1.3, 0.09, 0.09), (0, 0.75, -0.55), dm)
    for gx in (-0.65, 0.65):
        cyl(f"wheel{gx}", 0.24, 0.14, (gx, 0.75, -0.55), dm, rot=(0, PI / 2, 0))
        box(f"leg{gx}", (0.09, 0.09, 0.75), (gx * 0.7, 0.72, -0.22), dm)

    return finish(model_id)

# ---------------------------------------------------------------- balloon
def balloon(model_id, envelope_col=(0.62, 0.58, 0.45), accent=RED):
    """Caquot-type observation balloon: elongated envelope + basket + tether."""
    clear_scene()
    em = mat(model_id + "_env", envelope_col, rough=0.9)
    am = mat(model_id + "_accent", accent)
    wm = mat(model_id + "_wood", WOOD)
    dm = mat(model_id + "_dark", DARK)
    # elongated envelope along Y
    sphere("envelope", 1.6, (0, 0, 0), em, segs=14, rings=8, scale=(1.0, 1.9, 1.0))
    # nose/tail accent bands hug the envelope
    cyl("band1", 1.38, 0.35, (0, 1.0, 0), am, rot=(PI / 2, 0, 0), verts=14)
    cyl("band2", 1.38, 0.35, (0, -1.0, 0), am, rot=(PI / 2, 0, 0), verts=14)
    # stabilizing fins at rear
    for i, ang in enumerate((0, 2.09, 4.19)):
        box(f"fin{i}", (0.08, 1.1, 0.9),
            (math.cos(ang) * 0.9, -2.9, math.sin(ang) * 0.9), em,
            rot=(ang, 0, 0))
    # suspension ropes
    for rx in (-0.7, 0.7):
        for ry in (-0.5, 0.5):
            cyl(f"rope{rx}_{ry}", 0.035, 1.6, (rx, ry, -1.9), dm, verts=6)
    # observer basket
    box("basket", (0.95, 0.95, 0.75), (0, 0, -2.85), wm)
    # tether cable going down
    cyl("tether", 0.035, 8.0, (0, 0, -7.0), dm, verts=6)
    return finish(model_id)

# ---------------------------------------------------------------- AA gun
def aagun(model_id):
    clear_scene()
    mm = mat(model_id + "_metal", METAL, metallic=0.55, rough=0.6)
    dm = mat(model_id + "_dark", DARK)
    sm = mat(model_id + "_sand", SAND, rough=0.95)
    em = mat(model_id + "_earth", EARTH)
    # ground pad + sandbag ring
    cyl("pad", 1.5, 0.22, (0, 0, 0.0), em, verts=12)
    for i in range(10):
        ang = i / 10 * 2 * PI
        sphere(f"bag{i}", 0.42, (math.cos(ang) * 1.75, math.sin(ang) * 1.75, 0.18),
               sm, segs=8, rings=5, scale=(1.0, 0.75, 0.6))
    # pedestal + pivot + barrel angled skyward
    cyl("pedestal", 0.32, 1.0, (0, 0, 0.55), dm)
    sphere("pivot", 0.30, (0, 0, 1.15), mm, segs=10, rings=6)
    cyl("barrel", 0.13, 3.4, (0, -0.85, 2.35), mm, rot=(-PI / 3, 0, 0))
    cyl("muzzle", 0.17, 0.35, (0, 0.55, 3.15), dm, rot=(-PI / 3, 0, 0))
    # gun shield
    box("shield", (1.5, 0.09, 1.0), (0, -0.42, 1.05), mm, rot=(0.35, 0, 0))
    # ammo boxes
    box("ammo1", (0.5, 0.35, 0.35), (1.0, 0.5, 0.28),
        mat(model_id + "_wood", WOOD))
    return finish(model_id)

# ---------------------------------------------------------------- railway gun
def railwaygun(model_id):
    clear_scene()
    dm = mat(model_id + "_dark", DARK)
    mm = mat(model_id + "_metal", METAL, metallic=0.55, rough=0.6)
    wm = mat(model_id + "_wood", WOOD)
    em = mat(model_id + "_earth", EARTH)
    # track segment: rails + sleepers
    for sx in (-0.75, 0.75):
        box(f"rail{sx}", (0.18, 11.0, 0.18), (sx, 0, 0.12), mm)
    for i in range(9):
        box(f"sleeper{i}", (2.1, 0.38, 0.12), (0, -4.4 + i * 1.1, 0.03), wm)
    # rail car
    box("carbody", (2.3, 5.6, 0.9), (0, 0, 0.75), dm)
    box("cardeck", (2.3, 5.6, 0.15), (0, 0, 1.25), mm)
    for wx in (-0.85, 0.85):
        for wy in (-1.9, -0.6, 0.6, 1.9):
            cyl(f"wheel{wx}_{wy}", 0.34, 0.18, (wx, wy, 0.35), dm,
                rot=(0, PI / 2, 0))
    # huge cannon: pivot mount + long barrel elevated ~28 deg
    box("mount", (1.6, 1.8, 1.1), (0, -0.6, 1.85), dm)
    cyl("trunnion", 0.42, 1.7, (0, -0.6, 2.35), mm, rot=(0, PI / 2, 0))
    cyl("barrel", 0.34, 7.5, (0, 2.35, 3.55), mm, rot=(-PI / 2 + 0.49, 0, 0),
        verts=12)
    cyl("muzzle", 0.44, 0.6, (0, 5.35, 5.15), dm, rot=(-PI / 2 + 0.49, 0, 0),
        verts=12)
    # breech block
    box("breech", (0.9, 1.0, 0.9), (0, -1.15, 2.30), dm)
    return finish(model_id)

# ---------------------------------------------------------------- items
def item_ammo(model_id):
    clear_scene()
    mm = mat(model_id + "_metal", METAL, metallic=0.55, rough=0.55)
    dm = mat(model_id + "_dark", DARK)
    bm = mat(model_id + "_brass", BRASS, metallic=0.7, rough=0.4)
    cyl("drum", 0.55, 0.9, (0, 0, 0.45), mm, verts=12)
    cyl("band1", 0.58, 0.10, (0, 0, 0.20), dm, verts=12)
    cyl("band2", 0.58, 0.10, (0, 0, 0.70), dm, verts=12)
    cyl("cap", 0.30, 0.12, (0, 0, 0.95), bm, verts=10)
    return finish(model_id)

def item_repair(model_id):
    clear_scene()
    wm = mat(model_id + "_wood", WOOD)
    cm = mat(model_id + "_cross", WHITE)
    box("crate", (1.25, 1.25, 1.25), (0, 0, 0.62), wm)
    # white cross on top face
    box("cross1", (0.36, 1.05, 0.06), (0, 0, 1.28), cm)
    box("cross2", (1.05, 0.36, 0.06), (0, 0, 1.28), cm)
    # cross on front face
    box("cross3", (0.36, 0.06, 1.05), (0, 0.65, 0.62), cm)
    box("cross4", (1.05, 0.06, 0.36), (0, 0.65, 0.62), cm)
    return finish(model_id)

def item_bomb(model_id):
    clear_scene()
    bm = mat(model_id + "_body", BRASS, metallic=0.6, rough=0.45)
    dm = mat(model_id + "_dark", DARK)
    cyl("body", 0.42, 1.15, (0, 0, 0.85), bm, rot=(PI / 2, 0, 0), verts=12)
    cone("nose", 0.42, 0.05, 0.45, (0, 0.80, 0.85), bm, rot=(-PI / 2, 0, 0),
         verts=12)
    # tail fins
    for i, ang in enumerate((0, PI / 2, PI, 3 * PI / 2)):
        box(f"fin{i}", (0.06, 0.55, 0.55),
            (math.cos(ang) * 0.30, -0.45, 0.85 + math.sin(ang) * 0.30), dm,
            rot=(ang, 0, 0))
    cyl("band", 0.44, 0.14, (0, 0.35, 0.85), dm, rot=(PI / 2, 0, 0), verts=12)
    return finish(model_id)

# ---------------------------------------------------------------- set pieces
def set_trench(model_id):
    clear_scene()
    em = mat(model_id + "_earth", EARTH, rough=1.0)
    dm = mat(model_id + "_dark", (0.12, 0.10, 0.07), rough=1.0)
    sm = mat(model_id + "_sand", SAND, rough=0.95)
    # zigzag trench: 5 segments
    segs = [(-3.0, 1.2), (-1.5, -0.6), (0.0, 1.2), (1.5, -0.6), (3.0, 1.2)]
    for i, (sx, sy) in enumerate(segs):
        box(f"cut{i}", (1.7, 2.4, 0.55), (sx, sy, 0.10), dm)
        box(f"lip{i}", (2.1, 2.8, 0.18), (sx, sy, 0.42), em)
        box(f"inner{i}", (1.1, 1.8, 0.60), (sx, sy, 0.12), dm)
    # sandbags along both lips
    n = 0
    for sx, sy in segs:
        for side in (-1, 1):
            for k in range(4):
                sphere(f"bag{n}", 0.34,
                       (sx - 0.9 + k * 0.6, sy + side * 1.55, 0.55), sm,
                       segs=8, rings=5, scale=(1.0, 0.8, 0.6))
                n += 1
    return finish(model_id)

def set_aerodrome(model_id):
    clear_scene()
    cm = mat(model_id + "_canvas", (0.58, 0.50, 0.34), rough=0.95)
    wm = mat(model_id + "_wood", WOOD)
    dm = mat(model_id + "_dark", DARK)
    om = mat(model_id + "_orange", ORANGE)
    gm = mat(model_id + "_grass", GRASS, rough=1.0)
    # grass field
    box("field", (12, 12, 0.15), (0, 0, -0.08), gm)
    # hangar tent: two sloped canvas panels + back wall + ridge beam
    box("roofL", (3.4, 5.0, 0.12), (-1.45, 0, 1.75), cm, rot=(0, 0.62, 0))
    box("roofR", (3.4, 5.0, 0.12), (1.45, 0, 1.75), cm, rot=(0, -0.62, 0))
    box("ridge", (0.20, 5.0, 0.20), (0, 0, 2.70), wm)
    box("back", (3.6, 0.12, 2.6), (0, -2.5, 1.30), cm)
    for px in (-1.5, 1.5):
        for py in (-2.4, 2.4):
            cyl(f"pole{px}_{py}", 0.07, 2.9, (px, py, 1.45), wm, verts=8)
    # windsock: pole + sock cone (kept inside frame)
    cyl("wspole", 0.08, 3.4, (3.1, 2.5, 1.7), wm, verts=8)
    cone("sock", 0.28, 0.10, 1.4, (3.1, 3.35, 3.35), om, rot=(-PI / 2, 0, 0),
         verts=8)
    # fuel drums (kept inside frame)
    for i in range(3):
        cyl(f"drum{i}", 0.35, 0.9, (-2.9 + i * 0.85, 2.9, 0.45), dm, verts=10)
    return finish(model_id)

def set_farm(model_id):
    clear_scene()
    wm = mat(model_id + "_wood", WOOD)
    rm = mat(model_id + "_roof", RED, rough=0.9)
    gm = mat(model_id + "_grass", GRASS, rough=1.0)
    fm = mat(model_id + "_field", FIELD, rough=1.0)
    # fields: alternating crop strips
    for i in range(4):
        c = gm if i % 2 == 0 else fm
        box(f"field{i}", (10, 2.2, 0.12), (0, -4.5 + i * 2.4, -0.06), c)
    # farmhouse
    box("house", (2.6, 2.1, 1.7), (0, 2.5, 0.85), wm)
    box("roofL", (1.75, 2.5, 0.12), (-0.72, 2.5, 2.05), rm, rot=(0, 0.55, 0))
    box("roofR", (1.75, 2.5, 0.12), (0.72, 2.5, 2.05), rm, rot=(0, -0.55, 0))
    box("chimney", (0.35, 0.35, 1.0), (0.6, 2.1, 2.5), wm)
    # barn
    box("barn", (2.0, 1.6, 1.4), (-3.4, 2.8, 0.70), rm)
    box("broof", (2.4, 2.0, 0.14), (-3.4, 2.8, 1.65), wm, rot=(0, 0, 0))
    return finish(model_id)

def set_nomansland(model_id):
    clear_scene()
    em = mat(model_id + "_earth", EARTH, rough=1.0)
    dm = mat(model_id + "_dark", (0.12, 0.10, 0.07), rough=1.0)
    wm = mat(model_id + "_wood", (0.30, 0.22, 0.14), rough=1.0)
    # blasted ground tile
    box("ground", (11, 11, 0.2), (0, 0, -0.10), em)
    # craters: dark discs + raised rims
    craters = [(-3.2, 2.4, 1.1), (1.8, 3.4, 0.9), (3.6, -1.2, 1.3),
               (-1.4, -2.8, 1.0), (0.2, 0.6, 0.7), (-3.8, -0.6, 0.8),
               (2.8, 1.8, 0.6)]
    for i, (cx, cy, cr) in enumerate(craters):
        cyl(f"hole{i}", cr, 0.25, (cx, cy, -0.02), dm, verts=12)
        cyl(f"rim{i}", cr + 0.28, 0.22, (cx, cy, 0.05), em, verts=12)
    # splintered posts / debris
    import random
    random.seed(7)
    for i in range(10):
        box(f"debris{i}", (0.14, 0.14, random.uniform(0.5, 1.3)),
            (random.uniform(-5, 5), random.uniform(-5, 5), 0.35), wm,
            rot=(random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), 0))
    return finish(model_id)

# ---------------------------------------------------------------- build all
def build_all():
    # ENEMIES — muted military colors, original generic designs
    aircraft("enemy-triplane", span=4.6, wings=3, length=4.8,
             body=OLIVE, wing_col=OLIVE, accent=(0.55, 0.50, 0.38))
    aircraft("enemy-scout", span=5.2, wings=2, length=5.6,
             body=GRAYGR, wing_col=LINEN, accent=DARKGR, chord=0.85)
    aircraft("enemy-fighter", span=4.8, wings=2, length=4.6,
             body=DARKGR, wing_col=DARKGR, accent=(0.50, 0.50, 0.52),
             chunky=True)
    aircraft("enemy-bomber", span=7.6, wings=2, length=6.8,
             body=DARKGN, wing_col=DARKGN, accent=METAL, engines=2,
             chunky=True, chord=1.25)
    balloon("enemy-balloon")
    aagun("enemy-aagun")
    railwaygun("enemy-railwaygun")

    # ITEMS
    item_ammo("item-ammo")
    item_repair("item-repair")
    item_bomb("item-bomb")

    # BOSSES — six aces, bold fictional liveries, unique at small size
    aircraft("boss-1-red", span=4.6, wings=3, length=4.8,
             body=RED, wing_col=RED, accent=WHITE)                       # all-red triplane
    aircraft("boss-2-checker", span=4.8, wings=2, length=4.6,
             body=BLACK, wing_col=YELLOW, accent=BLACK,
             livery_wing='checker', chunky=True)                          # checkerboard wings
    aircraft("boss-3-stripes", span=5.2, wings=2, length=5.6,
             body=BLUE, wing_col=WHITE, accent=RED,
             livery_fus='segmented', chord=0.85)                          # striped fuselage
    aircraft("boss-4-tiger", span=5.2, wings=2, length=5.4,
             body=ORANGE, wing_col=ORANGE, accent=BLACK,
             livery_wing='banded', chord=0.9)                            # black-banded wings
    aircraft("boss-5-jester", span=4.6, wings=3, length=4.8,
             body=PURPLE, wing_col=TEAL, accent=WHITE,
             livery_wing='checker')                                      # teal/white checker triplane
    aircraft("boss-6-ghost", span=6.0, wings=2, length=5.8,
             body=WHITE, wing_col=WHITE, accent=RED,
             livery_wing='striped', chunky=True)                         # red-striped wings
    aircraft("boss-7-baron", span=6.2, wings=3, length=5.6,
             body=RED, wing_col=RED, accent=BLACK,
             livery_wing='banded', chunky=True)                          # the Baron's ghost: crimson triplane, black bands

    # SORTIE SET PIECES
    set_trench("setpiece-trench")
    set_aerodrome("setpiece-aerodrome")
    set_farm("setpiece-farm")
    set_nomansland("setpiece-nomansland")

    manifest_path = os.path.join(
        os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender"),
        "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(MANIFEST, f, indent=2)
    total = sum(m["tris"] for m in MANIFEST)
    print(f"BUILT {len(MANIFEST)} models, {total} tris total")
    for m in MANIFEST:
        assert m["tris"] < 5000, f"{m['id']} exceeds 5k tris!"

if __name__ == "__main__":
    build_all()
