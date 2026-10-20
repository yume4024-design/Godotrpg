"""Read-only face/edge inventory and close-up renders of the owned Ren source.

This does not classify clothing by texture thresholds or change skin weights.
"""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
expected = '93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'
assert hashlib.sha256(a.input.read_bytes()).hexdigest() == expected
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene = bpy.context.scene
body = next(o for o in scene.objects if o.type == 'MESH')
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.matrix_basis.identity()
scene.frame_set(0)
bpy.context.view_layer.update()
mesh = body.data
canonical = {}
position_ids = {}
for vertex in mesh.vertices:
    # glTF splits the same geometric point at UV seams. Inspect connectivity
    # using exact coincident coordinates without welding or changing the mesh.
    key = tuple(vertex.co)
    canonical[vertex.index] = position_ids.setdefault(key, vertex.index)
adjacency = defaultdict(set)
incidence = defaultdict(list)
for face in mesh.polygons:
    for edge in face.edge_keys:
        incidence[tuple(sorted(canonical[v] for v in edge))].append(face.index)
for edge, faces in incidence.items():
    for face in faces:
        adjacency[face].update(set(faces) - {face})
unvisited = set(range(len(mesh.polygons)))
components = []
while unvisited:
    todo = [next(iter(unvisited))]
    found = set()
    while todo:
        face = todo.pop()
        if face not in unvisited:
            continue
        unvisited.remove(face)
        found.add(face)
        todo.extend(adjacency[face] & unvisited)
    vertices = sorted({v for f in found for v in mesh.polygons[f].vertices})
    points = [mesh.vertices[v].co for v in vertices]
    components.append({'faces': sorted(found), 'face_count': len(found),
                       'bounds': [[min(p[i] for p in points), max(p[i] for p in points)] for i in range(3)]})
boundary = []
for edge, faces in incidence.items():
    if len(faces) != 1:
        continue
    points = [mesh.vertices[v].co for v in edge]
    if any(.75 < point.z < 1.16 and abs(point.x) < .34 for point in points):
        boundary.append({'vertices': list(edge), 'points': [list(v) for v in points], 'face': faces[0]})
roi = []
for face in mesh.polygons:
    center = face.center
    if .78 < center.z < 1.13 and abs(center.x) < .34:
        roi.append({'face': face.index, 'vertices': list(face.vertices),
                    'center': list(center), 'normal': list(face.normal),
                    'adjacent': sorted(adjacency[face.index])})
a.output.mkdir(parents=True)
report = {'source_sha256': expected, 'mesh_vertices': len(mesh.vertices),
          'exact_geometric_positions': len(position_ids),
          'connectivity_method': 'Exact coincident position identity; no mesh welding',
          'components': sorted(components, key=lambda r: -r['face_count']),
          'garment_region_boundary_edges': boundary, 'region_faces': roi,
          'limitations': ['Connected components and boundaries do not identify garment semantics automatically']}
(a.output / 'topology.json').write_text(json.dumps(report, indent=2), encoding='utf8')
summary = {key:value for key,value in report.items() if key not in ['components','region_faces']}
summary['components'] = [{key:value for key,value in row.items() if key!='faces'}
                         for row in report['components']]
summary['region_face_count'] = len(roi)
summary['full_face_inventory'] = 'topology.json (local, reproducible; not required in Git)'
(a.output / 'topology_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf8')
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.view_settings.view_transform = 'Standard'
scene.world = bpy.data.worlds.new('TopologyReviewWorld')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.16,.18,.20,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .8
camera_data = bpy.data.cameras.new('TopologyReviewCamera')
camera = bpy.data.objects.new(camera_data.name, camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'
camera_data.ortho_scale = .74
for index, position in enumerate([(2,-3,4),(-2,3,4)]):
    data = bpy.data.lights.new('TopologyReviewLight'+str(index),'AREA')
    data.energy, data.size = 180, 3
    light = bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(light)
    light.location = position
    light.rotation_euler = (Vector((0,0,.98))-light.location).to_track_quat('-Z','Y').to_euler()
for name, position in [('front',(0,-3,.98)),('back',(0,3,.98)),('left',(3,0,.98))]:
    camera.location = position
    camera.rotation_euler = (Vector((0,0,.98))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath = str((a.output / (name+'.png')).resolve())
    bpy.ops.render.render(write_still=True)
print('REN_TOPOLOGY', len(components), 'components;', len(boundary), 'region boundary edges;',len(roi),'region faces',flush=True)
