"""Original texture-free crop model, sized to the existing 0.7m-wide placeholder."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
if a.output.exists():
    raise FileExistsError(a.output)
bpy.ops.wm.read_factory_settings(use_empty=True)
materials = {}
for name, rgb in {'leaf': (.24, .43, .24), 'leaf_light': (.42, .57, .28)}.items():
    material = bpy.data.materials.new('G04_' + name)
    material.use_nodes = True
    shader = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*[c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb], 1)
    shader.inputs['Roughness'].default_value = .9
    materials[name] = material
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1, location=(0, 0, .32))
head = bpy.context.object
head.name = 'LeafyCropCore'
head.scale = (.25, .25, .27)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
head.data.materials.append(materials['leaf_light'])
parts = [head]
for index in range(8):
    angle = index * math.tau / 8
    forward = Vector((math.cos(angle), math.sin(angle), 0))
    tangent = Vector((-math.sin(angle), math.cos(angle), 0))
    base = forward * .07 + Vector((0, 0, .025))
    tip = forward * .35 + Vector((0, 0, .33 + .025 * (index % 2)))
    middle = forward * .245 + Vector((0, 0, .155))
    boundary = [base, middle - tangent * .11, tip, middle + tangent * .11]
    vertices = boundary + [middle + Vector((0, 0, .045)), middle - Vector((0, 0, .02))]
    faces = []
    for side in range(4):
        next_side = (side + 1) % 4
        faces.extend([(side, next_side, 4), (next_side, side, 5)])
    mesh = bpy.data.meshes.new('FoldedLeaf')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new('Leaf' + str(index), mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(materials['leaf' if index % 2 else 'leaf_light'])
    parts.append(obj)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = head
bpy.ops.object.join()
crop = bpy.context.object
crop.name = 'LeafyCrop'
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
crop.data.calc_loop_triangles()
triangles = len(crop.data.loop_triangles)
if triangles > 300:
    raise ValueError('Explicit crop budget exceeded')
points = [crop.matrix_world @ v.co for v in crop.data.vertices]
a.output.mkdir(parents=True)
native, glb = a.output / 'leafy_crop.blend', a.output / 'leafy_crop.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()), export_format='GLB', use_selection=True, export_animations=False)
report = {'status': 'IN_PROGRESS', 'method': 'Original Blender mesh construction; no generative API or third-party model',
          'triangles': triangles, 'budget': 300, '28_instance_triangles': triangles * 28,
          'bounds_blender': [[min(v[i] for v in points), max(v[i] for v in points)] for i in range(3)],
          'origin': 'Ground centre, Godot Y up after glTF conversion',
          'materials': ['G04_leaf', 'G04_leaf_light'], 'textures': 0,
          'uv': 'No texture UV requirement; not certified UV-unwrapped',
          'collisions': 'None; decorative farmland plant, no new pickup or economy logic',
          'formal_scene_replacement': False,
          'outputs': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [native, glb]}}
(a.output / 'model_report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print('LEAFY_CROP_BUILT', triangles, 'of 300 triangles', flush=True)
