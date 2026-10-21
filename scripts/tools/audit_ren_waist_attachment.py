"""Measure the authored coat's top edge against the actual original belt.

Positive outward separation is an attachment defect, not a motion/triangle
failure. This is a separate gate; it never edits models or hides samples.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--plan', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(args.input.resolve()))
plan = json.loads(args.plan.read_text(encoding='utf-8'))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
for track in rig.animation_data.nla_tracks: track.mute = True
body = scene.objects['RenRetainedSource']
ids = body.data.attributes['OriginalSourceFace']
pouches = set(plan['protected_pouch_faces'])
belt_faces = [face.index for face in body.data.polygons if 1.105 <= face.center.z <= 1.185
              and abs(face.center.x) < .27 and int(ids.data[face.index].value) not in pouches]
assert len(belt_faces) > 30
tops = {}
for name in ['RenAuthoredCoatLeft', 'RenAuthoredCoatRight']:
    obj = scene.objects[name]
    tops[name] = sorted({obj.data.loops[loop].vertex_index for face in obj.data.polygons
                         for loop in face.loop_indices if obj.data.uv_layers.active.data[loop].uv.y > .9999})
rows = []
for clip, frame in [(None, 0), ('run', 4), ('run', 12), ('walk', 6), ('walk', 18), ('cast', 8)]:
    rig.animation_data.action = bpy.data.actions[clip] if clip else None
    if clip and rig.animation_data.action.slots: rig.animation_data.action_slot = rig.animation_data.action.slots[0]
    if clip is None:
        for bone in rig.pose.bones: bone.matrix_basis.identity()
    scene.frame_set(frame); bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get()); mesh = evaluated.to_mesh()
    positions = [v.co.copy() for v in mesh.vertices]
    polygons = [tuple(mesh.polygons[index].vertices) for index in belt_faces]
    tree = BVHTree.FromPolygons(positions, polygons)
    evaluated.to_mesh_clear()
    samples = []
    for name, indices in tops.items():
        evaluated = scene.objects[name].evaluated_get(bpy.context.evaluated_depsgraph_get()); mesh = evaluated.to_mesh()
        for index in indices:
            point = mesh.vertices[index].co
            closest, _, _, distance = tree.find_nearest(point)
            radial = Vector((closest.x, closest.y, 0)).normalized()
            outward = max(0., (point-closest).dot(radial))
            samples.append({'mesh': name, 'vertex': index, 'outward_m': outward,
                            'distance_m': distance, 'point': list(point), 'closest_belt': list(closest)})
        evaluated.to_mesh_clear()
    rows.append({'clip': clip or 'rest', 'frame': frame, 'samples': samples,
                 'maximum_outward_m': max(s['outward_m'] for s in samples)})
maximum = max(row['maximum_outward_m'] for row in rows)
report = {'input_sha256': hashlib.sha256(args.input.read_bytes()).hexdigest(),
          'status': 'PASS' if maximum <= .005 else 'FAIL', 'tolerance_m': .005,
          'maximum_outward_separation_m': maximum, 'original_belt_faces': len(belt_faces),
          'top_vertices': tops, 'rows': rows,
          'limits': ['Outward top-edge attachment only; not whole-garment intersection or gameplay acceptance']}
args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('REN_WAIST_ATTACHMENT', report['status'], maximum, flush=True)
if report['status'] == 'FAIL': raise RuntimeError('Coat edge needs manual attachment to the original belt')
