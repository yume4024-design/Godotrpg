"""Check source surfaces, original albedo and all action poses on Ren retopology.

The optional fan diagnostic mutates only this isolated process's memory. It
never saves a candidate, and cannot change the actual candidate's FAIL result.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Vector

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--candidate', type=Path, required=True)
parser.add_argument('--plan', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--diagnose-sharp-fans', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
assert hashlib.sha256(args.source.read_bytes()).hexdigest() == '93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'


def snapshot(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    scene = bpy.context.scene
    rig = next(o for o in scene.objects if o.type == 'ARMATURE')
    for track in rig.animation_data.nla_tracks: track.mute = True
    rest = {bone.name: np.array(bone.matrix_local) for bone in rig.data.bones}
    poses = {}
    for action in bpy.data.actions:
        rig.animation_data.action = action
        if action.slots: rig.animation_data.action_slot = action.slots[0]
        poses[action.name] = []
        for frame in range(int(action.frame_range[0]), int(action.frame_range[1])+1):
            scene.frame_set(frame); bpy.context.view_layer.update()
            poses[action.name].append({bone.name: np.array(bone.matrix) for bone in rig.pose.bones})
    images = sorted(hashlib.sha256(bytes(image.packed_file.data)).hexdigest() for image in bpy.data.images if image.packed_file)
    rig.animation_data.action = None
    for bone in rig.pose.bones: bone.matrix_basis.identity()
    scene.frame_set(0); bpy.context.view_layer.update()
    return rest, poses, images


rest, poses, images = snapshot(args.source)
original = next(o for o in bpy.context.scene.objects if o.type == 'MESH').data
original_faces = []
for face in original.polygons:
    original_faces.append({'points': [original.vertices[v].co.copy() for v in face.vertices],
                           'uv': [original.uv_layers.active.data[i].uv.copy() for i in face.loop_indices],
                           'normal': [original.corner_normals[i].vector.copy() for i in face.loop_indices]})
new_rest, new_poses, new_images = snapshot(args.candidate)
plan = json.loads(args.plan.read_text(encoding='utf-8'))
failures = []
rest_error = max(float(np.abs(rest[name]-new_rest[name]).max()) for name in rest) if set(rest) == set(new_rest) else float('inf')
pose_error = 0.
if set(poses) != set(new_poses): failures.append('CLIP_NAMES_CHANGED')
else:
    for name, frames in poses.items():
        if len(frames) != len(new_poses[name]): failures.append(name+':FRAME_COUNT_CHANGED'); continue
        for frame, other in zip(frames, new_poses[name]):
            for bone in frame: pose_error = max(pose_error, float(np.abs(frame[bone]-other[bone]).max()))
if rest_error > 1e-7: failures.append('BONE_REST_CHANGED')
if pose_error > 1e-7: failures.append('ACTION_POSES_CHANGED')
if not set(images).issubset(new_images): failures.append('ORIGINAL_ALBEDO_CHANGED')
body = bpy.context.scene.objects['RenRetainedSource']
mesh = body.data
ids = mesh.attributes['OriginalSourceFace']
source_ids = {int(item.value) for item in ids.data}
if not set(plan['protected_pouch_faces']).issubset(source_ids): failures.append('PROTECTED_POUCH_FACE_MISSING')
if not set(range(len(original_faces)))-set(plan['replace_faces']) <= source_ids: failures.append('UNAPPROVED_SOURCE_FACE_MISSING')
uv_error, position_error, normal_error = 0., 0., 0.
desired = [None]*len(mesh.loops)
bad = []
for face in mesh.polygons:
    source_index = int(ids.data[face.index].value)
    original = original_faces[source_index]
    for loop_id in face.loop_indices:
        point = mesh.vertices[mesh.loops[loop_id].vertex_index].co
        exact = next((i for i, source in enumerate(original['points']) if point == source), None)
        if exact is not None:
            uv, normal = original['uv'][exact], original['normal'][exact]
        else:
            origin = np.asarray(original['points'][0], dtype=np.float64)
            matrix = np.asarray([original['points'][1]-original['points'][0], original['points'][2]-original['points'][0]], dtype=np.float64).T
            factors = np.linalg.lstsq(matrix, np.asarray(point, dtype=np.float64)-origin, rcond=None)[0]
            bary = (1-factors.sum(), factors[0], factors[1])
            if min(bary) < -2e-4 or max(bary) > 1.0002: failures.append('CORNER_OUTSIDE_ORIGINAL_FACE')
            projected = sum((original['points'][i]*bary[i] for i in range(3)), Vector())
            position_error = max(position_error, (projected-point).length)
            uv = sum((original['uv'][i]*bary[i] for i in range(3)), Vector((0, 0)))
            normal = sum((original['normal'][i]*bary[i] for i in range(3)), Vector()).normalized()
        uv_error = max(uv_error, (uv-mesh.uv_layers.active.data[loop_id].uv).length)
        error = (normal-mesh.corner_normals[loop_id].vector).length
        normal_error = max(normal_error, error); desired[loop_id] = normal.copy()
        if error > .002:
            bad.append({'loop': loop_id, 'vertex': mesh.loops[loop_id].vertex_index, 'source_face': source_index,
                        'position': list(point), 'expected': list(normal),
                        'actual': list(mesh.corner_normals[loop_id].vector), 'error': error})
if uv_error > 2e-5: failures.append('RETAINED_UV_CHANGED')
if position_error > 2e-6: failures.append('RETAINED_POSITION_CHANGED')
if normal_error > .002: failures.append('RETAINED_CORNER_NORMAL_CHANGED')
diagnostic = None
if args.diagnose_sharp_fans and bad:
    vertices = {row['vertex'] for row in bad}
    changed = []
    for edge in mesh.edges:
        if vertices.intersection(edge.vertices): edge.use_edge_sharp = True; changed.append(edge.index)
    mesh.update(); mesh.normals_split_custom_set(desired)
    after = [(normal.vector-expected).length for normal, expected in zip(mesh.corner_normals, desired)]
    diagnostic = {'not_saved': True, 'changed_sharp_edges': changed, 'maximum_error': max(after),
                  'bad_loops': sum(value > .002 for value in after)}
    trial = [normal.copy() for normal in desired]
    correction_trace = []
    for unused in range(8):
        actual = [normal.vector.copy() for normal in mesh.corner_normals]
        for index, (expected, normal) in enumerate(zip(desired, actual)):
            if (expected-normal).length > .0002:
                trial[index] = (trial[index]+expected-normal).normalized()
        mesh.normals_split_custom_set(trial)
        errors = [(normal.vector-expected).length for normal, expected in zip(mesh.corner_normals, desired)]
        correction_trace.append({'maximum_error': max(errors), 'bad_loops': sum(value > .002 for value in errors)})
    diagnostic['encoding_correction_trace'] = correction_trace
report = {'source_sha256': hashlib.sha256(args.source.read_bytes()).hexdigest(),
          'candidate_sha256': hashlib.sha256(args.candidate.read_bytes()).hexdigest(),
          'status': 'FAIL' if failures else 'PASS', 'failures': sorted(set(failures)),
          'original_source_faces_retained': len(source_ids), 'retained_triangles': len(mesh.polygons),
          'protected_pouch_faces_retained': len(set(plan['protected_pouch_faces']) & source_ids),
          'maximum_bone_rest_error': rest_error, 'maximum_all_frame_pose_error': pose_error,
          'sampled_pose_frames': sum(len(frames) for frames in poses.values()),
          'original_packed_albedo_preserved': set(images).issubset(new_images),
          'maximum_retained_position_error': position_error, 'maximum_retained_uv_error': uv_error,
          'maximum_retained_corner_normal_error': normal_error, 'bad_normal_loops': bad,
          'sharp_fan_diagnostic': diagnostic,
          'limits': ['New trouser/coat/strap topology and its atlas intentionally differ',
                     'This does not certify visual fidelity, collisions or formal gameplay']}
args.output.write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('REN_AUTHORED_PRESERVATION', report['status'], 'bad loops', len(bad), 'diagnostic', diagnostic, flush=True)
if failures: raise RuntimeError(sorted(set(failures)))
