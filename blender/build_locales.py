"""New locale models for 1918: U-boat flotilla, sub pens, zeppelin sheds,
munitions depot, rail yard, artillery. Top-down readable, low-poly originals.
Run headless: blender --background --python build_locales.py"""
import os
import sys

sys.path.insert(0, os.path.expanduser("~/workspace/1918-ace-of-aces-assets/blender"))
import build_models as B


def uboat():
    B.clear_scene()
    hull = B.mat("uboat_hull", (0.28, 0.31, 0.29), rough=0.65)
    dark = B.mat("uboat_dark", (0.12, 0.13, 0.12))
    # pressure hull along Y
    B.cyl("hull", 0.55, 5.6, (0, 0, 0), hull, rot=(B.PI / 2, 0, 0), verts=12)
    B.cone("bow", 0.55, 0.06, 1.1, (0, 3.35, 0), hull, rot=(B.PI / 2, 0, 0), verts=12)
    B.cone("stern", 0.55, 0.10, 0.9, (0, -3.25, 0), hull, rot=(-B.PI / 2, 0, 0), verts=12)
    # conning tower
    B.box("tower", (0.72, 1.5, 0.72), (0, 0.4, 0.72), dark)
    B.box("bridge", (0.5, 0.6, 0.3), (0, 0.4, 1.2), dark)
    # deck gun forward of tower
    B.cyl("gun", 0.09, 1.2, (0, 2.0, 0.42), dark, rot=(B.PI / 2, 0, 0), verts=8)
    # wake hint: pale stern trail
    wake = B.mat("uboat_wake", (0.75, 0.82, 0.85), rough=1.0)
    B.box("wake", (1.5, 1.6, 0.02), (0, -4.3, 0.02), wake)
    return B.finish("uboat")


def subpen():
    B.clear_scene()
    conc = B.mat("subpen_conc", (0.48, 0.48, 0.50), rough=0.95)
    dark = B.mat("subpen_dark", (0.07, 0.08, 0.09))
    # massive concrete bunker
    B.box("pen", (5.2, 3.8, 1.7), (0, 0, 0.85), conc)
    B.box("roof", (5.6, 4.2, 0.28), (0, 0, 1.82), conc)
    # two dark pen mouths (water channels)
    B.box("mouthL", (1.4, 0.7, 1.1), (-1.3, 1.95, 0.55), dark)
    B.box("mouthR", (1.4, 0.7, 1.1), (1.3, 1.95, 0.55), dark)
    # AA tub on the roof
    B.cyl("aamnt", 0.5, 0.25, (0, -1.0, 2.05), dark, verts=10)
    B.cyl("aabar", 0.07, 1.4, (0, -1.0, 2.6), dark, rot=(0.5, 0, 0), verts=8)
    return B.finish("subpen")


def zeppelin():
    B.clear_scene()
    env = B.mat("zep_env", (0.58, 0.55, 0.45), rough=0.8)
    dark = B.mat("zep_dark", (0.22, 0.20, 0.16))
    # gas envelope stretched along Y
    B.sphere("env", 1.5, (0, 0, 0), env, segs=16, rings=10, scale=(0.55, 2.7, 0.55))
    # control gondola
    B.box("gond", (0.55, 2.0, 0.45), (0, 0.4, -1.05), dark)
    B.box("gond2", (0.4, 0.9, 0.35), (0, -1.9, -0.95), dark)
    # tail fins
    B.box("finL", (1.2, 1.0, 0.12), (-1.2, -3.6, 0), env, rot=(0, 0, 0.5))
    B.box("finR", (1.2, 1.0, 0.12), (1.2, -3.6, 0), env, rot=(0, 0, -0.5))
    return B.finish("zeppelin")


def ammodepot():
    B.clear_scene()
    wood = B.mat("depot_wood", (0.52, 0.40, 0.24), rough=0.95)
    canvas = B.mat("depot_canvas", (0.62, 0.57, 0.44), rough=0.95)
    # crate stacks
    for ix in (-0.95, 0.0, 0.95):
        for iy in (-0.75, 0.75):
            B.box(f"crate_{ix}_{iy}", (0.85, 0.65, 0.62), (ix, iy, 0.31), wood)
    B.box("crate_top", (0.85, 0.65, 0.58), (0.0, 0.0, 0.9), wood)
    # tarp over the pile
    B.box("tarp", (3.4, 2.4, 0.12), (0, 0, 1.25), canvas)
    # sandbag ring hint: low dark boxes around
    sand = B.mat("depot_sand", (0.55, 0.50, 0.36), rough=1.0)
    for sx, sy in [(-2.0, 0), (2.0, 0), (0, -1.7), (0, 1.7)]:
        B.box(f"sand_{sx}_{sy}", (0.9, 0.9, 0.35), (sx, sy, 0.17), sand)
    return B.finish("ammodepot")


def train():
    B.clear_scene()
    eng = B.mat("train_eng", (0.13, 0.13, 0.15), rough=0.55)
    carm = B.mat("train_car", (0.38, 0.24, 0.13), rough=0.85)
    metal = B.mat("train_met", (0.42, 0.42, 0.44), rough=0.45)
    # locomotive
    B.box("loco", (1.1, 2.4, 1.0), (0, 2.3, 0.5), eng)
    B.cyl("stack", 0.22, 0.9, (0, 3.1, 1.35), eng, verts=10)
    B.box("cab", (1.1, 1.0, 1.35), (0, 1.3, 0.68), eng)
    # two freight cars (kept short to fit the sprite frame)
    for i in range(2):
        y = -0.5 - i * 1.75
        B.box(f"car{i}", (1.0, 1.55, 0.95), (0, y, 0.48), carm)
    # rails
    B.box("railL", (0.12, 7.6, 0.08), (-0.75, 0.6, 0.04), metal)
    B.box("railR", (0.12, 7.6, 0.08), (0.75, 0.6, 0.04), metal)
    return B.finish("train")


def arty():
    B.clear_scene()
    gunm = B.mat("arty_gun", (0.27, 0.30, 0.24), rough=0.55)
    wood = B.mat("arty_wood", (0.44, 0.32, 0.20), rough=0.9)
    # long barrel toward +Y
    B.cyl("barrel", 0.15, 2.8, (0, 1.0, 0.6), gunm, rot=(B.PI / 2, 0, 0), verts=10)
    # gun shield
    B.box("shield", (1.6, 0.12, 0.95), (0, 0.15, 0.48), gunm)
    # spoked wheels
    B.cyl("wheelL", 0.58, 0.15, (-0.9, -0.25, 0.58), wood, rot=(0, B.PI / 2, 0), verts=12)
    B.cyl("wheelR", 0.58, 0.15, (0.9, -0.25, 0.58), wood, rot=(0, B.PI / 2, 0), verts=12)
    # split trails
    B.box("trailL", (0.15, 2.1, 0.15), (-0.42, -1.7, 0.2), wood, rot=(0, 0, 0.28))
    B.box("trailR", (0.15, 2.1, 0.15), (0.42, -1.7, 0.2), wood, rot=(0, 0, -0.28))
    # ready shell stack
    for i in range(3):
        B.sphere(f"shell{i}", 0.17, (1.45, -0.7 + i * 0.38, 0.17), gunm, segs=8, rings=5)
    return B.finish("arty")


if __name__ == "__main__":
    for fn in (uboat, subpen, zeppelin, ammodepot, train, arty):
        fn()
    print("LOCALE MODELS DONE")
