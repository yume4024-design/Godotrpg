"""Inspect full-detail generated GLBs without changing topology (isolated Blender)."""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', required=True)
p.add_argument('--output', required=True)
p.add_argument('--name', required=True)
p.add_argument('--audit-only', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
out = Path(a.output)
out.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.input)
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == 'MESH']
assert meshes, 'No mesh imported'
corners = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector([min(v[i] for v in corners) for i in range(3)])
hi = Vector([max(v[i] for v in corners) for i in range(3)])
report = {'input': a.input, 'topology_modified': False, 'rigged': any(o.type == 'ARMATURE' for o in scene.objects), 'objects': [], 'images': []}
for o in meshes:
    # glTF triangulates faces. Do not allocate millions of loop-triangle wrappers.
    import numpy as np
    sizes = np.empty(len(o.data.polygons), dtype=np.int32)
    o.data.polygons.foreach_get('loop_total', sizes)
    loop_edges = np.empty(len(o.data.loops), dtype=np.int32)
    o.data.loops.foreach_get('edge_index', loop_edges)
    edge_uses = np.bincount(loop_edges, minlength=len(o.data.edges))
    areas = np.empty(len(o.data.polygons), dtype=np.float32)
    o.data.polygons.foreach_get('area', areas)
    report['objects'].append({'name': o.name, 'vertices': len(o.data.vertices), 'triangles': int(np.maximum(sizes-2, 0).sum()), 'uv_layers': len(o.data.uv_layers), 'boundary_edges': int((edge_uses==1).sum()), 'nonmanifold_edges_more_than_two_faces': int((edge_uses>2).sum()), 'zero_area_faces_epsilon_1e_16': int((areas<=1e-16).sum()), 'materials': [m.name if m else None for m in o.data.materials]})
    del loop_edges, edge_uses, areas, sizes
report['triangles'] = sum(o['triangles'] for o in report['objects'])
report['bounds_min'] = list(lo)
report['bounds_max'] = list(hi)
for im in bpy.data.images:
    report['images'].append({'name': im.name, 'size': list(im.size)})
assert all(o['uv_layers'] for o in report['objects']), 'Missing UV'
assert report['images'], 'Missing texture images'
(out/'inspection.json').write_text(json.dumps(report, indent=2), encoding='utf8')
if a.audit_only:
    print('QUALITY_AUDIT_COMPLETE', report['triangles'], flush=True)
    sys.exit(0)
# Keep original positions, scale and geometry in the work file.
bpy.ops.file.pack_all()
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 8
scene.render.resolution_x = 600
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new('InspectionWorld')
scene.world.use_nodes = True
bg = scene.world.node_tree.nodes.get('Background')
bg.inputs[0].default_value = (.16, .18, .23, 1)
bg.inputs[1].default_value = .65
center = (lo+hi)*.5
height = hi.z-lo.z
for offset, energy in [((2,-3,3), 180), ((-2,1,2), 120)]:
    light = bpy.data.lights.new('InspectionSoftbox', 'AREA')
    light.energy = energy*height*height
    light.size = height*2
    obj = bpy.data.objects.new(light.name, light)
    scene.collection.objects.link(obj)
    obj.location = center+Vector(offset)*height
    obj.rotation_euler = (center-obj.location).to_track_quat('-Z','Y').to_euler()
camera = bpy.data.objects.new('InspectionCamera', bpy.data.cameras.new('InspectionCamera'))
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.type = 'ORTHO'
camera.data.ortho_scale = height*1.18
camera.data.clip_end = max(100, height*20)
for label, angle in [('front',0), ('side',math.pi/2), ('back',math.pi)]:
    camera.location = center+Vector((math.sin(angle)*height*3, -math.cos(angle)*height*3, height*.03))
    camera.rotation_euler = (center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str(out/(label+'.png'))
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/(a.name+'_full.blend')))
print('QUALITY_INSPECTION_COMPLETE', report['triangles'], flush=True)
