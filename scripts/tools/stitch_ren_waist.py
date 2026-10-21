"""Stitch the inspected top-edge vertices directly to the existing belt surface.

This edits only the new coat's three upper rows and the new trouser waist rim.
The original retained mesh, UVs, skins, textures and action curves are untouched.
Every moved vertex and its displacement is recorded. No source is overwritten.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--plan', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:])
assert hashlib.sha256(args.input.read_bytes()).hexdigest() == '340c1bd2cfc3990aacc1820b04db835f454e0e5ba08d9d95a0000c1a7cf5a804'
assert not args.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(args.input.resolve()))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = True
for bone in rig.pose.bones: bone.matrix_basis.identity()
scene.frame_set(0); bpy.context.view_layer.update()
body = scene.objects['RenRetainedSource']
plan = json.loads(args.plan.read_text(encoding='utf-8'))
pouches = set(plan['protected_pouch_faces'])
ids = body.data.attributes['OriginalSourceFace']
belt_faces = [face.index for face in body.data.polygons if 1.105 <= face.center.z <= 1.185
              and abs(face.center.x) < .27 and int(ids.data[face.index].value) not in pouches]
tree = BVHTree.FromPolygons([v.co for v in body.data.vertices],
                            [tuple(body.data.polygons[i].vertices) for i in belt_faces])
assert len(belt_faces) > 30
moves = {}
for name in ['RenAuthoredCoatLeft', 'RenAuthoredCoatRight']:
    obj = scene.objects[name]
    assert len(obj.data.vertices) == 266
    original = [vertex.co.copy() for vertex in obj.data.vertices]
    rows = []
    for column in range(19):
        top = 6*19+column
        middle = (original[top]+original[top+133])*.5
        point, _, _, _ = tree.find_nearest(middle)
        radial = Vector((point.x, point.y, 0)).normalized()
        delta = point-radial*.002-middle
        # Explicit authored row IDs: top is fixed beneath the belt; the next
        # two rows spread the seam correction without pulling the moving hem.
        for row, influence in [(6, 1.), (5, .55), (4, .20)]:
            for offset in [0, 133]:
                index = row*19+column+offset
                obj.data.vertices[index].co = original[index]+delta*influence
                rows.append({'vertex': index, 'before': list(original[index]),
                             'after': list(obj.data.vertices[index].co), 'delta_m': list(delta*influence)})
    if obj.data.attributes.get('custom_normal'):
        obj.data.attributes.remove(obj.data.attributes['custom_normal'])
    obj.data.update()
    moves[name] = rows
obj = scene.objects['RenAuthoredTrousers']
top = {obj.data.loops[loop].vertex_index for face in obj.data.polygons for loop in face.loop_indices
       if obj.data.uv_layers.active.data[loop].uv.y > .9999
       and obj.data.vertices[obj.data.loops[loop].vertex_index].co.z >= 1.099}
rows = []
for index in sorted(top):
    vertex = obj.data.vertices[index]
    before = vertex.co.copy()
    point, _, _, _ = tree.find_nearest(before)
    radial = Vector((point.x, point.y, 0)).normalized()
    vertex.co = point-radial*.004
    rows.append({'vertex': index, 'before': list(before), 'after': list(vertex.co), 'delta_m': list(vertex.co-before)})
obj.data.update(); moves[obj.name] = rows
assert len(top) == 16, len(top)
args.output.mkdir(parents=True)
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in scene.objects:
    if obj.type == 'MESH': obj.select_set(True)
bpy.context.view_layer.objects.active = rig
native, glb = args.output/'ren_rigged.blend', args.output/'ren_rigged.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()), export_format='GLB', use_selection=True,
                         export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
report = {'input_sha256': hashlib.sha256(args.input.read_bytes()).hexdigest(),
          'method': 'Inspected vertex rows stitched to closest original belt surface, with hidden overlap',
          'new_coat_hidden_overlap_m': .002, 'new_trouser_hidden_overlap_m': .004,
          'original_belt_face_indices': belt_faces, 'moved_vertices': moves,
          'original_retained_mesh_modified': False, 'uvs_modified': False,
          'weights_or_actions_modified': False, 'triangles_expected': 10655,
          'gates': {'preservation': 'NOT_TESTED', 'motion': 'NOT_TESTED', 'attachment': 'NOT_TESTED', 'visual': 'NOT_TESTED'},
          'outputs': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [native, glb]}}
(args.output/'stitch_report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('REN_WAIST_STITCH', {name: len(rows) for name, rows in moves.items()}, flush=True)
