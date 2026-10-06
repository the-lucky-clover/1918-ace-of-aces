"""v22 photorealism directive — particle sprite set for the FX layer.

Layered photorealistic sprites (the v20 4-layer tracer is the template):
the Blender-rendered texture sits UNDER the readable canvas core in each
effect. All geometry/materials are original procedural work — game sprites,
never claimed photographic.

Renders (transparent PNG, top-down ortho):
  fx-explosion-0/1/2.png  128px  3-frame emissive fireball (noise-displaced)
  fx-smoke.png            128px  dark smoke puff (noise alpha)
  fx-muzzle.png            64px  hot muzzle flash (emission, noise breakup)
  fx-flak.png             128px  flak burst: dark shell + hot core

Run headless:
  blender-softwaregl --background --python render_fx.py
"""
import bpy
import math
import os

OUT = os.path.expanduser("~/workspace/1918-godot/assets/sprites/fx")
os.makedirs(OUT, exist_ok=True)


def setup_scene(res):
    # Cycles CPU: no EGL needed headless. 128px emission materials converge
    # in very few samples.
    bpy.context.scene.render.engine = "CYCLES"
    bpy.context.scene.cycles.device = "CPU"
    bpy.context.scene.cycles.samples = 32
    bpy.context.scene.cycles.use_denoising = False
    r = bpy.context.scene.render
    r.resolution_x = r.resolution_y = res
    r.resolution_percentage = 100
    r.film_transparent = True
    r.image_settings.file_format = "PNG"
    r.image_settings.color_mode = "RGBA"
    # top-down ortho camera
    cam_data = bpy.data.cameras.new("FXCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.7
    cam = bpy.data.objects.new("FXCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (0, 0, 6)
    bpy.context.scene.camera = cam


def clear_meshes():
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)


def displace(obj, strength, seed, noise_scale=0.55):
    sub = obj.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2
    tex = bpy.data.textures.new("Cloud%d" % seed, type="CLOUDS")
    tex.noise_scale = noise_scale
    tex.noise_depth = 4
    d = obj.modifiers.new("Dis", "DISPLACE")
    d.texture = tex
    d.strength = strength
    d.mid_level = 0.5
    # per-frame variation: shift the texture space
    d.texture_coords = "OBJECT"
    return tex


def emission_mat(name, ramp_stops, strength, noise_scale, seed,
                 alpha_feather=0.35):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    n = mat.node_tree.nodes
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    texc = n.new("ShaderNodeTexCoord")
    mapping = n.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 1.7, seed * 0.9, 0.0)
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 4.0
    ramp = n.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = ramp_stops[0]
    for pos, col in ramp_stops[1:]:
        e = els.new(pos)
        e.color = col
    emis = n.new("ShaderNodeEmission")
    emis.inputs["Strength"].default_value = strength
    trans = n.new("ShaderNodeBsdfTransparent")
    lw = n.new("ShaderNodeLayerWeight")
    aramp = n.new("ShaderNodeValToRGB")
    ae = aramp.color_ramp.elements
    ae[0].position, ae[0].color = (0.0, (0, 0, 0, 1))
    e2 = ae.new(alpha_feather)
    e2.color = (1, 1, 1, 1)
    mix = n.new("ShaderNodeMixShader")
    L = mat.node_tree.links
    L.new(texc.outputs["Object"], mapping.inputs["Vector"])
    L.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    L.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], emis.inputs["Color"])
    L.new(lw.outputs["Facing"], aramp.inputs["Fac"])
    L.new(aramp.outputs["Color"], mix.inputs["Fac"])
    L.new(trans.outputs["BSDF"], mix.inputs[1])
    L.new(emis.outputs["Emission"], mix.inputs[2])
    L.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def smoke_mat(name, color, noise_scale, seed, alpha_feather=0.45):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    n = mat.node_tree.nodes
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    texc = n.new("ShaderNodeTexCoord")
    mapping = n.new("ShaderNodeMapping")
    mapping.inputs["Location"].default_value = (seed * 2.3, seed * 1.1, 0.0)
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 5.0
    ramp = n.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = (0.30, (0, 0, 0, 1))
    e = els.new(0.72)
    e.color = (1, 1, 1, 1)
    lw = n.new("ShaderNodeLayerWeight")
    aramp = n.new("ShaderNodeValToRGB")
    ae = aramp.color_ramp.elements
    ae[0].position, ae[0].color = (0.0, (0, 0, 0, 1))
    e2 = ae.new(alpha_feather)
    e2.color = (1, 1, 1, 1)
    mathn = n.new("ShaderNodeMath")
    mathn.operation = "MULTIPLY"
    diff = n.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = color
    diff.inputs["Roughness"].default_value = 1.0
    trans = n.new("ShaderNodeBsdfTransparent")
    mix = n.new("ShaderNodeMixShader")
    L = mat.node_tree.links
    L.new(texc.outputs["Object"], mapping.inputs["Vector"])
    L.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    L.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    L.new(ramp.outputs["Color"], mathn.inputs[0])
    L.new(lw.outputs["Facing"], aramp.inputs["Fac"])
    L.new(aramp.outputs["Color"], mathn.inputs[1])
    L.new(trans.outputs["BSDF"], mix.inputs[1])
    L.new(diff.outputs["BSDF"], mix.inputs[2])
    L.new(mathn.outputs["Value"], mix.inputs["Fac"])
    L.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def render_to(name):
    bpy.context.scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", name)


FIRE_RAMP = [
    (0.00, (1.0, 0.98, 0.92, 1)),
    (0.35, (1.0, 0.82, 0.38, 1)),
    (0.60, (1.0, 0.42, 0.08, 1)),
    (0.85, (0.55, 0.10, 0.02, 1)),
    (1.00, (0.04, 0.01, 0.01, 1)),
]

setup_scene(128)

# --- explosion fireball: 3 frames, same ball, noise drifting through it
for frame in range(3):
    clear_meshes()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16,
                                         radius=1.0)
    ball = bpy.context.active_object
    # per-frame silhouette: different noise scale per frame (Cloud textures
    # have no seed; object-space rotation would rotate with the mesh)
    displace(ball, 0.38, 100 + frame, noise_scale=0.45 + frame * 0.18)
    ball.data.materials.append(
        emission_mat("Fire%d" % frame, FIRE_RAMP, 3.2, 4.0, frame,
                     alpha_feather=0.38))
    render_to("fx-explosion-%d.png" % frame)

# --- smoke puff
clear_meshes()
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0)
sm = bpy.context.active_object
displace(sm, 0.30, 210)
sm.data.materials.append(
    smoke_mat("Smoke", (0.085, 0.08, 0.078, 1), 5.0, 3))
render_to("fx-smoke.png")

# --- flak burst: dark shell + hot core
clear_meshes()
bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1.0)
shell = bpy.context.active_object
displace(shell, 0.28, 310)
shell.data.materials.append(
    smoke_mat("FlakShell", (0.03, 0.03, 0.035, 1), 5.5, 5))
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.34)
core = bpy.context.active_object
core.data.materials.append(
    emission_mat("FlakCore",
                 [(0.0, (1.0, 0.95, 0.75, 1)),
                  (0.5, (1.0, 0.55, 0.15, 1)),
                  (1.0, (0.4, 0.08, 0.02, 1))],
                 4.5, 6.0, 7, alpha_feather=0.5))
render_to("fx-flak.png")

# --- muzzle flash (64px)
setup_scene(64)
clear_meshes()
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0)
mz = bpy.context.active_object
mz.scale = (1.0, 1.0, 0.35)
bpy.context.view_layer.update()
mz.data.materials.append(
    emission_mat("Muzzle",
                 [(0.0, (1.0, 1.0, 0.95, 1)),
                  (0.45, (1.0, 0.80, 0.30, 1)),
                  (1.0, (1.0, 0.45, 0.08, 1))],
                 5.0, 7.0, 11, alpha_feather=0.55))
render_to("fx-muzzle.png")

print("FX RENDER SET DONE")
