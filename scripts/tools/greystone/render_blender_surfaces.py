"""Render the saved procedural master, without editing the user's live scene."""
import bpy
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[3]
out = root / 'artifacts/greystone_surface_20261023'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(root / 'source_assets/greystone_blender_20261023/greystone_master.blend'))
scene = bpy.context.scene
scene.cycles.samples = 12
scene.render.resolution_x = 1400; scene.render.resolution_y = 1200
scene.render.filepath = str(out / 'blender_overview.png')
bpy.ops.render.render(write_still=True)
scene.camera.location = (55, -4, 42)
scene.camera.rotation_euler = (Vector((25,16,3)) - scene.camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera.data.ortho_scale = 32
scene.render.resolution_x = 1280; scene.render.resolution_y = 900
scene.render.filepath = str(out / 'blender_water.png')
bpy.ops.render.render(write_still=True)
