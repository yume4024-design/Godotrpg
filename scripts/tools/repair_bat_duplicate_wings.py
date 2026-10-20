"""Blender: remove the three visually diagnosed duplicate rear-wing islands.

This is a topology-only work copy, NOT full-fold acceptance. Import the owned
GLB in a fresh process; preserve its source, main wing mesh, UVs and skinning.
Do not use this spatial selection on a different model without a new review.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import sys

import bmesh
import bpy

p = argparse.ArgumentParser()
p.add_argument('--input', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
if a.output.exists():
    raise FileExistsError(a.output)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
# Importer-only display spheres can be linked to this fresh scene. Remove only
# the exact objects referenced by bone.custom_shape in glTF_not_exported.
helpers = {bone.custom_shape for bone in rig.pose.bones if bone.custom_shape is not None}
removed_helpers = []
for helper in helpers:
    if any(c.name.startswith('glTF_not_exported') for c in helper.users_collection):
        removed_helpers.append(helper.name)
        for bone in rig.pose.bones:
            if bone.custom_shape == helper:
                bone.custom_shape = None
        bpy.data.objects.remove(helper, do_unlink=True)
meshes = [o for o in scene.objects if o.type == 'MESH' and o.parent == rig]
if len(meshes) != 1:
    raise ValueError('Expected the reviewed single skinned bat body')
body = meshes[0]
mesh = body.data
if len(mesh.polygons) != 9686 or any(len(f.vertices) != 3 for f in mesh.polygons):
    raise ValueError('Source differs from the reviewed 9686-triangle bat')
parent = list(range(len(mesh.vertices)))


def root(index):
    while parent[index] != index:
        parent[index] = parent[parent[index]]
        index = parent[index]
    return index


def join(left, right):
    left, right = root(left), root(right)
    if left != right:
        parent[right] = left


positions = {}
for vertex in mesh.vertices:
    key = tuple(round(v, 5) for v in vertex.co)
    if key in positions:
        join(vertex.index, positions[key])
    else:
        positions[key] = vertex.index
for face in mesh.polygons:
    for index in face.vertices[1:]:
        join(face.vertices[0], index)
components = defaultdict(list)
for face in mesh.polygons:
    components[root(face.vertices[0])].append(face.index)
selected, details = [], []
for faces in components.values():
    ids = {index for face in faces for index in mesh.polygons[face].vertices}
    points = [mesh.vertices[i].co for i in ids]
    bounds = [[min(v[axis] for v in points), max(v[axis] for v in points)] for axis in range(3)]
    duplicate = bounds[1][0] > .18 and bounds[2][0] > .5 and max(abs(v.x) for v in points) < .38
    if duplicate:
        selected.extend(faces)
        details.append({'faces': len(faces), 'bounds': bounds, 'source_face_indices': sorted(faces)})
if sorted(row['faces'] for row in details) != [74, 422, 478] or len(selected) != 974:
    raise ValueError('Selection differs from the three visually diagnosed duplicate islands')

# An analysis-only coincidence union above does not weld UV seams or crystals.
# Save every retained face's loop attributes to prove the deletion is bounded.
selected_set = set(selected)
normals, preserved = {}, {}
for face in mesh.polygons:
    normals[face.index] = {tuple(round(v, 6) for v in mesh.vertices[mesh.loops[li].vertex_index].co):
                           tuple(mesh.corner_normals[li].vector) for li in face.loop_indices}
    if face.index not in selected_set:
        preserved[face.index] = [(tuple(mesh.vertices[mesh.loops[li].vertex_index].co),
                                 tuple(mesh.uv_layers.active.data[li].uv)) for li in face.loop_indices]
attr = mesh.attributes.new('SourceFaceIndex', 'INT', 'FACE')
for i, item in enumerate(attr.data):
    item.value = i
bm = bmesh.new()
bm.from_mesh(mesh)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in selected], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(mesh)
bm.free()
mesh.update()
restored = []
for face in mesh.polygons:
    old = mesh.attributes['SourceFaceIndex'].data[face.index].value
    actual = [(tuple(mesh.vertices[mesh.loops[li].vertex_index].co),
               tuple(mesh.uv_layers.active.data[li].uv)) for li in face.loop_indices]
    if actual != preserved[old]:
        raise ValueError('Retained geometry or UV changed')
    for li in face.loop_indices:
        co = tuple(round(v, 6) for v in mesh.vertices[mesh.loops[li].vertex_index].co)
        restored.append(normals[old][co])
mesh.normals_split_custom_set(restored)
mesh.attributes.remove(mesh.attributes['SourceFaceIndex'])
assert len(mesh.polygons) == 8712

for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = None
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = (1, 0, 0, 0)
    bone.location = (0, 0, 0)
    bone.scale = (1, 1, 1)
scene.frame_set(0)
scene.render.fps = 24
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
a.output.mkdir(parents=True)
bpy.ops.file.pack_all()
native = a.output / 'crystal_bat_topology.blend'
glb = a.output / 'crystal_bat_topology.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()), export_format='GLB', use_selection=True,
                         export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
report = {'source': str(a.input), 'source_sha256': hashlib.sha256(a.input.read_bytes()).hexdigest(),
          'method': 'Codex-directed Blender component inspection and bounded face deletion; no third-party artist',
          'source_triangles': 9686, 'removed_triangles': 974, 'remaining_triangles': 8712,
          'removed_components': details, 'retained_geometry_and_uv_exact': True,
          'corner_normals_restored': True, 'weights_edited': False, 'animations_edited': False,
          'removed_importer_display_helpers': removed_helpers,
          'bones': len(rig.data.bones), 'clips': [action.name for action in bpy.data.actions],
          'outputs': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [native, glb]},
          'gates': {'duplicate_rear_wing_cleanup': 'PASS', 'full_fold': 'FAIL', 'formal_integration': 'NOT_STARTED'},
          'limitations': ['Old fold is partial; stronger hinge diagnostic poses reveal ear weight contamination and membrane overlap',
                          'This copy must not be selected as a qualified A03/A04 replacement']}
(a.output / 'topology_report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
print('BAT_TOPOLOGY_COPY', len(mesh.polygons), 'triangles; full fold remains FAIL', flush=True)
