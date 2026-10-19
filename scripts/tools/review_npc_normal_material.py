"""CPU-only diagnostic render: same source mesh with/without baked normal map."""
import argparse
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 8
scene.render.threads_mode = 'FIXED'
scene.render.threads = 2
scene.render.resolution_x = 1000
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('DiagnosticWorld')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.30, .35, .40, 1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .65
for index, x in enumerate([-.57, .57]):
    previous = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
    added = set(bpy.data.objects) - previous
    meshes = [obj for obj in added if obj.type == 'MESH' and not obj.hide_render]
    bounds = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low, high = min(point.z for point in bounds), max(point.z for point in bounds)
    scale = 1.85 / (high-low)
    for obj in added:
        if obj.parent is None:
            obj.scale *= scale
            obj.location = obj.location*scale + Vector((x, 0, -low*scale))
    if index == 1:
        for obj in added:
            if obj.type != 'MESH': continue
            for slot in obj.material_slots:
                if not slot.material or not slot.material.use_nodes: continue
                slot.material = slot.material.copy()
                for node in slot.material.node_tree.nodes:
                    if node.type == 'NORMAL_MAP': node.inputs['Strength'].default_value = 0
for y in [-3, 3]:
    bpy.ops.object.light_add(type='AREA', location=(-2, y, 4))
    bpy.context.object.data.energy = 280
    bpy.context.object.data.shape = 'DISK'
    bpy.context.object.data.size = 4
    bpy.context.object.rotation_euler = (Vector((0, 0, 1)) - bpy.context.object.location).to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.camera_add()
camera = bpy.context.object
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 2.55
scene.camera = camera
for view, y in [('front', -4), ('back', 4)]:
    camera.location = (0, y, 1.0)
    camera.rotation_euler = (Vector((0, 0, 1.0)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str((a.output / (view + '.png')).resolve())
    bpy.ops.render.render(write_still=True)
print('NORMAL_DIAGNOSTIC_DONE', a.output, flush=True)
