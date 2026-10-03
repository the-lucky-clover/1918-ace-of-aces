"""Tiny headless Cycles CPU smoke test."""
import bpy
s = bpy.context.scene
s.render.engine = 'CYCLES'
s.cycles.device = 'CPU'
s.cycles.samples = 8
s.render.resolution_x = 128
s.render.resolution_y = 128
s.render.filepath = '/tmp/cycles_test.png'
s.render.image_settings.file_format = 'PNG'
bpy.ops.render.render(write_still=True)
print("CYCLES_CPU_TEST_OK")
