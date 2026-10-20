"""Build an original modular wheel in a fresh Blender process, no source edits."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--output', required=True, type=Path)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
if a.output.exists():
    raise FileExistsError('Output must be a new directory')
bpy.ops.wm.read_factory_settings(use_empty=True)
materials = {}
palette = {'wood': (.43, .29, .16), 'iron': (.27, .31, .33), 'stone': (.60, .59, .51)}
for name, rgb in palette.items():
    mat = bpy.data.materials.new('G04_' + name)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = (*[c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb], 1)
    shader.inputs['Roughness'].default_value = .9
    materials[name] = mat
moving, fixed = [], []


def finish(obj, name, material, moving_part=True):
    obj.name = name
    obj.data.materials.append(materials[material])
    (moving if moving_part else fixed).append(obj)
    return obj


def box(name, center, dimensions, material, angle=0., moving_part=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.x = angle
    return finish(obj, name, material, moving_part)


def cylinder(name, center, radius, depth, material, segments=12, moving_part=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=segments, radius=radius, depth=depth, location=center,
                                      rotation=(0, math.pi / 2, 0))
    return finish(bpy.context.object, name, material, moving_part)


def ring(name, x):
    vertices, faces = [], []
    for axial in [x - .07, x + .07]:
        for radius in [2.02, 2.35]:
            vertices.extend((axial, radius * math.cos(i * math.tau / 24), radius * math.sin(i * math.tau / 24)) for i in range(24))
    for i in range(24):
        j = (i + 1) % 24
        faces.extend([(i, j, 24 + j, 24 + i), (48 + i, 72 + i, 72 + j, 48 + j),
                      (i, 48 + i, 48 + j, j), (24 + i, 24 + j, 72 + j, 72 + i)])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return finish(obj, name, 'wood')


for side in [-1, 1]:
    ring('Rim' + str(side), side * .48)
    cylinder('Hub' + str(side), (side * .56, 0, 0), .34, .18, 'wood')
    for i in range(8):
        angle = i * math.tau / 8
        box('Spoke', (side * .48, 1.18 * math.cos(angle), 1.18 * math.sin(angle)),
            (.10, 1.96, .16), 'wood', angle)
        cylinder('RimBolt', (side * .57, 2.16 * math.cos(angle), 2.16 * math.sin(angle)),
                 .065, .05, 'iron', segments=6)
for i in range(12):
    angle = i * math.tau / 12
    box('Paddle', (0, 2.17 * math.cos(angle), 2.17 * math.sin(angle)), (1.15, .22, .46), 'wood', angle)
cylinder('FixedAxle', (0, 0, 0), .16, 2.05, 'iron', segments=16, moving_part=False)
for side in [-1, 1]:
    box('Bearing', (side * .88, 0, -.28), (.25, .56, .56), 'stone', moving_part=False)


def join_parts(parts, name):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return obj


wheel = join_parts(moving, 'Wheel')
axle = join_parts(fixed, 'FixedAxle')
assembly = bpy.data.objects.new('WaterwheelAssembly', None)
bpy.context.scene.collection.objects.link(assembly)
for obj in [wheel, axle]:
    obj.parent = assembly
    obj.data.calc_loop_triangles()
triangles = sum(len(obj.data.loop_triangles) for obj in [wheel, axle])
if triangles > 2500:
    raise ValueError('Waterwheel explicit 2500-triangle budget exceeded')
all_points = [obj.matrix_world @ v.co for obj in [wheel, axle] for v in obj.data.vertices]
report = {'status': 'IN_PROGRESS', 'method': 'Original Blender mesh construction; no Comfy submission or third-party assets',
          'triangles': triangles, 'budget': 2500, 'dimensions_blender': [max(v[i] for v in all_points) - min(v[i] for v in all_points) for i in range(3)],
          'origin': 'Axle centre; matches original Godot placeholder origin, rotation axis X',
          'parts': {'Wheel': len(wheel.data.loop_triangles), 'FixedAxle': len(axle.data.loop_triangles)},
          'palette': palette, 'uv': 'Not required: texture-free shared colour materials, not a UV PASS claim',
          'collisions': 'None: decorative riverside wheel; traversal/collision integration not yet tested',
          'formal_scene_replacement': False}
a.output.mkdir(parents=True)
bpy.ops.object.select_all(action='SELECT')
native, glb = a.output / 'waterwheel.blend', a.output / 'waterwheel.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()), export_format='GLB', use_selection=True, export_animations=False)
report['outputs'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [native, glb]}
(a.output / 'model_report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print('WATERWHEEL_BUILT', triangles, 'of 2500 triangles', flush=True)
