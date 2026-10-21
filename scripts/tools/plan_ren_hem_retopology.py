"""Read-only authored patch plan, with explicit source faces and protected pouch.

This is not another variation of the rejected angular hem slicing recipe.
The whole contaminated waist-to-thigh band is scheduled for reconstruction.
No candidate or runtime asset is exported by this planner.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
from collections import defaultdict

import bpy
from mathutils import Vector

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--whole-trousers', action='store_true')
parser.add_argument('--topology', type=Path, help='Read-only inventory from inspect_ren_garment_topology.py')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
expected = '93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'
assert hashlib.sha256(args.input.read_bytes()).hexdigest() == expected
assert not args.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(args.input.resolve()))
scene = bpy.context.scene
source = next(o for o in scene.objects if o.type == 'MESH')
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = True
for bone in rig.pose.bones: bone.matrix_basis.identity()
scene.frame_set(0)
bpy.context.view_layer.update()
root = Path(__file__).resolve().parents[2]
topology_path = args.topology or root / 'source_assets/character_rebuild_20261020/ren/garment_topology_geometric/topology.json'
if not topology_path.is_file():
    raise FileNotFoundError('Generate the read-only topology inventory first, then pass --topology <topology.json>')
topology = json.loads(topology_path.read_text())
assert topology['source_sha256'] == expected
component_by_face = {face: index for index, component in enumerate(topology['components']) for face in component['faces']}

# Anatomical bounds inspected against the original front/back/side close-ups.
# Top is below the original belt; bottom is below all contaminated white hem.
lower, upper = (.405 if args.whole_trousers else .855), 1.105
planned, protected = [], []
for face in source.data.polygons:
    arm = max(sum(g.weight for g in source.data.vertices[v].groups
                  if source.vertex_groups[g.group].name.startswith(('Arm', 'Forearm', 'Hand', 'Fingers')))
              for v in face.vertices)
    center = face.center
    pouch = .155 < center.x < .30 and -.19 < center.y < .075 and .985 < center.z < 1.17
    # Retain the complete disconnected pouch surface as well as the pouch's
    # fused body-facing section. Old floating white hem details are replaced.
    # Components 1/21/23 are old inner cloth/trim; 12/14/26 are buried strap
    # layers revealed by the new trousers. They are not the visible pouches.
    # Their material and isolated visibility were inspected separately.
    pouch = pouch or component_by_face[face.index] in [4, 10, 13, 20, 22, 28, 29]
    if args.whole_trousers:
        # Inspected left-thigh pouch wraps the leg; preserve its fused section
        # in addition to its disconnected leather faces. Never touch the hand.
        pouch = pouch or (-.27 < center.x < -.16 and -.175 < center.y < .105 and .69 < center.z < .88)
        if component_by_face[face.index] in [1, 12, 14, 21, 23, 26]: pouch = False
    if pouch and arm < .15:
        protected.append(face.index)
    elif arm < .15 and abs(center.x) < .30 and any(lower < source.data.vertices[v].co.z < upper for v in face.vertices):
        planned.append(face.index)
assert 300 < len(planned) < 7500, len(planned)
assert len(set(planned) & set(protected)) == 0
segments = []
graph = defaultdict(set)
for face in source.data.polygons:
    if component_by_face[face.index] != 0: continue
    if any(abs(source.data.vertices[v].co.x) > .30 for v in face.vertices): continue
    points = [source.data.vertices[v].co for v in face.vertices]
    intersections = []
    for first, second in zip(points, points[1:] + points[:1]):
        if (first.z - lower) * (second.z - lower) < 0:
            point = first.lerp(second, (lower - first.z) / (second.z - first.z))
            intersections.append(tuple(round(c, 6) for c in point))
    if len(intersections) == 2 and intersections[0] != intersections[1]:
        first, second = intersections
        graph[first].add(second); graph[second].add(first)
        segments.append(intersections)
loops = []
remaining = set(graph)
while remaining:
    start = min(remaining)
    todo, found = [start], set()
    while todo:
        point = todo.pop()
        if point in found: continue
        found.add(point)
        todo.extend(graph[point] - found)
    remaining -= found
    loops.append({'points': sorted(found), 'degrees': {str(n): sum(len(graph[v]) == n for v in found) for n in sorted({len(graph[v]) for v in found})}})
args.output.mkdir(parents=True)
report = {'source_sha256': expected, 'mesh': source.name,
          'method': 'Complete waist-to-thigh replacement with an authored two-leg inner volume and two side wrap panels',
          'patch_z_bounds': [lower, upper], 'replace_faces': planned, 'protected_pouch_faces': protected,
          'whole_trousers': args.whole_trousers,
          'replace_face_count': len(planned), 'protected_pouch_face_count': len(protected),
          'lower_plane_cross_sections': loops,
          'status': 'VISUAL_REVIEW_REQUIRED',
          'limits': ['Plan only; boundary stitching, weights, normal encoding, UV/materials and deformation not validated']}
(args.output / 'plan.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
gray = bpy.data.materials.new('Retained_Source'); gray.diffuse_color = (.34, .38, .42, 1)
red = bpy.data.materials.new('Replace_Hem_And_Inner_Band'); red.diffuse_color = (.85, .055, .025, 1)
green = bpy.data.materials.new('Protected_Belt_Pouch'); green.diffuse_color = (.12, .72, .20, 1)
source.data.materials.clear()
for material in [gray, red, green]: source.data.materials.append(material)
planned, protected = set(planned), set(protected)
for face in source.data.polygons: face.material_index = 2 if face.index in protected else 1 if face.index in planned else 0
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.light = 'STUDIO'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.show_cavity = True
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
camera_data = bpy.data.cameras.new('PatchPlanCamera')
camera = bpy.data.objects.new(camera_data.name, camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.type = 'ORTHO'; camera_data.ortho_scale = .74
for name, position in [('front', (0, -3, .98)), ('back', (0, 3, .98)), ('right', (3, 0, .98))]:
    camera.location = position
    camera.rotation_euler = (Vector((0, 0, .98)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str((args.output / (name + '.png')).resolve())
    bpy.ops.render.render(write_still=True)
print('REN_AUTHORED_PATCH_PLAN', report['replace_face_count'], report['protected_pouch_face_count'], flush=True)
