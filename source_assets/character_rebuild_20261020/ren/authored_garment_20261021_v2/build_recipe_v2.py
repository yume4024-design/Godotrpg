"""Author a clean trouser/crotch volume and two split coat panels on a copy.

Uses the reviewed full-trouser face receipt. Keeps the source, all seven action
curves, rest bones, upper body, hands, boots and protected leather accessories.
No gameplay assets are installed by this tool. Output must be a new directory.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--plan', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
assert not args.output.exists(), 'Preserve all previous attempts'
source_sha = hashlib.sha256(args.input.read_bytes()).hexdigest()
assert source_sha == '93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'
plan = json.loads(args.plan.read_text(encoding='utf-8'))
assert plan['source_sha256'] == source_sha and plan['whole_trousers']
assert plan['replace_face_count'] == 4142 and plan['protected_pouch_face_count'] == 964
args.output.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(args.input.resolve()))
scene = bpy.context.scene
source = next(o for o in scene.objects if o.type == 'MESH')
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks: track.mute = True
for bone in rig.pose.bones: bone.matrix_basis.identity()
scene.frame_set(0); bpy.context.view_layer.update()
mesh = source.data
group_names = [g.name for g in source.vertex_groups]
positions = [v.co.copy() for v in mesh.vertices]
normals = [n.vector.copy() for n in mesh.corner_normals]
uvs = [uv.uv.copy() for uv in mesh.uv_layers.active.data]
replace = set(plan['replace_faces'])
protected = set(plan['protected_pouch_faces'])
lower, upper = plan['patch_z_bounds']


def smooth(lo, hi, value):
    t = max(0., min(1., (value-lo)/(hi-lo)))
    return t*t*(3-2*t)


def weights(point, side=None):
    x, y, z = point
    leg = 1-smooth(.97, 1.10, z)
    shin = 1-smooth(.49, .64, z)
    left = smooth(-.075, .075, x) if side is None else (1. if side > 0 else 0.)
    row = {'Torso': 1-leg, 'LegLeft': leg*(1-shin)*left,
           'LegRight': leg*(1-shin)*(1-left), 'ShinLeft': leg*shin*left,
           'ShinRight': leg*shin*(1-left)}
    row = {name: value for name, value in row.items() if value > 1e-8}
    assert len(row) <= 4
    total = sum(row.values())
    return {name: value/total for name, value in row.items()}


def blend(a, b, t):
    row = {name: a['weights'].get(name, 0)*(1-t)+b['weights'].get(name, 0)*t
           for name in set(a['weights']) | set(b['weights'])}
    row = dict(sorted(row.items(), key=lambda item: -item[1])[:4])
    total = sum(row.values())
    return {'point': a['point'].lerp(b['point'], t), 'uv': a['uv'].lerp(b['uv'], t),
            'normal': a['normal'].lerp(b['normal'], t).normalized(),
            'weights': {name: value/total for name, value in row.items()}}


def clip(poly, plane, below):
    result = []
    for first, second in zip(poly, poly[1:]+poly[:1]):
        inside_a = first['point'].z <= plane if below else first['point'].z >= plane
        inside_b = second['point'].z <= plane if below else second['point'].z >= plane
        if inside_a: result.append(first)
        if inside_a != inside_b:
            result.append(blend(first, second, (plane-first['point'].z)/(second['point'].z-first['point'].z)))
    return result


# Keep the original mesh topology where possible, instead of rebuilding every
# original face as an isolated triangle (which changes its normal fan basis).
body = source.copy(); body.data = mesh.copy(); body.name = 'RenRetainedSource'
scene.collection.objects.link(body)
bm = bmesh.new(); bm.from_mesh(body.data); bm.faces.ensure_lookup_table()
normal_layer = bm.loops.layers.float_vector.new('RetainedNormal')
face_layer = bm.faces.layers.int.new('OriginalSourceFace')
for face in bm.faces:
    face[face_layer] = face.index
    for loop, index in zip(face.loops, mesh.polygons[face.index].loop_indices):
        loop[normal_layer] = normals[index]
uv_layer = bm.loops.layers.uv.active
deform_layer = bm.verts.layers.deform.verify()
fragments = []
for index in sorted(replace):
    face = mesh.polygons[index]
    poly = [{'point': positions[mesh.loops[i].vertex_index].copy(), 'uv': uvs[i].copy(),
             'normal': normals[i].copy(),
             'weights': {group_names[g.group]: g.weight for g in mesh.vertices[mesh.loops[i].vertex_index].groups}}
            for i in face.loop_indices]
    for plane, below in [(lower, True), (upper, False)]:
        retained = clip(poly, plane, below)
        if len(retained) >= 3: fragments.append((index, face.material_index, face.use_smooth, retained))
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in sorted(replace)], context='FACES_ONLY')
for source_index, material, smooth_face, poly in fragments:
    for index in range(1, len(poly)-1):
        corners = [poly[0], poly[index], poly[index+1]]
        if (corners[1]['point']-corners[0]['point']).cross(corners[2]['point']-corners[0]['point']).length < 1e-10: continue
        vertices = [bm.verts.new(corner['point']) for corner in corners]
        face = bm.faces.new(vertices); face.material_index = material; face.smooth = smooth_face
        face[face_layer] = source_index
        for vertex, loop, corner in zip(vertices, face.loops, corners):
            loop[uv_layer].uv = corner['uv']; loop[normal_layer] = corner['normal']
            for name, weight in corner['weights'].items(): vertex[deform_layer][group_names.index(name)] = weight
unused = [v for v in bm.verts if not v.link_faces]
if unused: bmesh.ops.delete(bm, geom=unused, context='VERTS')
bm.to_mesh(body.data); bm.free(); body.data.update()
desired = [d.vector.copy() for d in body.data.attributes['RetainedNormal'].data]
body.data.normals_split_custom_set(desired)
normal_errors = [(actual.vector-target).length for actual, target in zip(body.data.corner_normals, desired)]
body.data.attributes.remove(body.data.attributes['RetainedNormal'])

# The fused waist pouch follows the belt; the thigh pouch follows its leg.
# Original source geometry/UV is retained, only accessory presentation weights
# are corrected where the old cloth mask assigned a hanging pouch to coat bones.
waist_pouch_vertices = {v for face in body.data.polygons
                        if int(body.data.attributes['OriginalSourceFace'].data[face.index].value) in protected
                        and mesh.polygons[int(body.data.attributes['OriginalSourceFace'].data[face.index].value)].center.z > .98
                        for v in face.vertices}
thigh_pouch_vertices = {v for face in body.data.polygons
                        if int(body.data.attributes['OriginalSourceFace'].data[face.index].value) in protected
                        and mesh.polygons[int(body.data.attributes['OriginalSourceFace'].data[face.index].value)].center.z <= .98
                        for v in face.vertices}
for index in waist_pouch_vertices:
    for group in body.vertex_groups: group.remove([index])
    body.vertex_groups['Torso'].add([index], 1., 'REPLACE')
for index in thigh_pouch_vertices:
    for group in body.vertex_groups: group.remove([index])
    body.vertex_groups['LegRight'].add([index], 1., 'REPLACE')


def make_skinned(name, points, faces, coordinates, rows, materials, material_ids=None, smooth_faces=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(points, [], faces); data.update()
    obj = bpy.data.objects.new(name, data); scene.collection.objects.link(obj)
    for material in materials: data.materials.append(material)
    data.uv_layers.new(name='UVMap')
    for face in data.polygons:
        face.use_smooth = smooth_faces
        if material_ids is not None: face.material_index = material_ids[face.index]
        for loop in face.loop_indices: data.uv_layers.active.data[loop].uv = coordinates[data.loops[loop].vertex_index]
    for name in group_names: obj.vertex_groups.new(name=name)
    for index, row in enumerate(rows):
        for name, value in row.items(): obj.vertex_groups[name].add([index], value, 'REPLACE')
    obj.parent = rig
    obj.modifiers.new('AuthoredSkin', 'ARMATURE').object = rig
    return obj


def solid_material(name, color):
    material = bpy.data.materials.new(name); material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Roughness'].default_value = .92
    return material


dark = solid_material('RenAuthoredTrouserFabric', (.022, .025, .030))
trim = solid_material('RenAuthoredHemBinding', (.39, .29, .235))
# Each leg joins a shared crotch seam to form a real pair-of-trousers volume.
# Sixteen radial segments retain the reference's broad faceted silhouette.
points, faces, coordinates, rows = [], [], [], []
ring_spec = [(.395, .190, .074, .078), (.44, .188, .085, .090),
             (.52, .183, .105, .110), (.60, .175, .115, .122),
             (.70, .165, .120, .126), (.82, .150, .120, .126),
             (.94, .125, .118, .122)]
seam_cache = {}
for sign in [-1, 1]:
    rings = []
    for level, (z, center, rx, ry) in enumerate(ring_spec + [(upper, 0, .215, .130)]):
        ring = []
        for col in range(16):
            theta = col/16*math.tau
            if level == len(ring_spec):
                point = Vector((sign*rx*max(0., math.cos(theta)), ry*math.sin(theta),
                                upper + min(0., math.cos(theta))*.155))
            else:
                point = Vector((sign*(center+rx*math.cos(theta)), ry*math.sin(theta), z))
            key = tuple(round(float(v), 7) for v in point)
            if level == len(ring_spec) and abs(point.x) < 1e-6 and key in seam_cache:
                vertex = seam_cache[key]
            else:
                vertex = len(points); points.append(point)
                coordinates.append((col/16, level/len(ring_spec)))
                rows.append(weights(point))
                if level == len(ring_spec) and abs(point.x) < 1e-6: seam_cache[key] = vertex
            ring.append(vertex)
        rings.append(ring)
    for low_ring, high_ring in zip(rings, rings[1:]):
        for col in range(16):
            nxt = (col+1)%16
            face = (low_ring[col], low_ring[nxt], high_ring[nxt], high_ring[col])
            faces.append(face if sign > 0 else tuple(reversed(face)))
pants = make_skinned('RenAuthoredTrousers', points, faces, coordinates, rows, [dark], smooth_faces=False)

# Replace the buried, duplicate strap sheets with one closed band. Its visible
# left-thigh pouch remains original geometry and follows the same leg.
leather = solid_material('RenAuthoredThighStrapLeather', (.10, .047, .022))
points, faces, coordinates, rows = [], [], [], []
for row, z in enumerate([.759, .800]):
    for col in range(16):
        theta = col/16*math.tau
        point = Vector((-.154+.126*math.cos(theta), .134*math.sin(theta), z))
        points.append(point); coordinates.append((col/16, row)); rows.append({'LegRight': 1.})
for col in range(16):
    nxt = (col+1)%16
    faces.append((col, nxt, nxt+16, col+16))
strap = make_skinned('RenAuthoredThighStrap', points, faces, coordinates, rows, [leather])
skin = strap.modifiers.get('AuthoredSkin'); strap.modifiers.remove(skin)
bpy.context.view_layer.objects.active = strap
thickness = strap.modifiers.new('LeatherThickness', 'SOLIDIFY'); thickness.thickness = .0025
bpy.ops.object.modifier_apply(modifier=thickness.name)
strap.modifiers.new('AuthoredSkin', 'ARMATURE').object = rig


def panel(sign, u, v):
    theta = -math.pi/2+.025 + u*(math.pi-.05)
    hem = .925 + .135*math.exp(-(math.cos(theta)/.18)**2)
    z = hem*(1-v) + (upper+.003)*v
    rx, ry = .248*(1-v)+.215*v, .174*(1-v)+.137*v
    return Vector((sign*rx*math.cos(theta), ry*math.sin(theta), z))


# Transfer only the inspected old coat surface into new, contiguous UVs.
# New triangles never interpolate through unrelated original atlas islands.
sample_faces = [face for face in mesh.polygons if face.index in replace and .89 < face.center.z < upper+.01]
tree = BVHTree.FromPolygons(positions, [tuple(f.vertices) for f in sample_faces], all_triangles=True)
source_material = mesh.materials[0]
source_shader = source_material.node_tree.nodes.get('Principled BSDF')
source_image = source_shader.inputs['Base Color'].links[0].from_node.image
pixels = np.empty(len(source_image.pixels), dtype=np.float32); source_image.pixels.foreach_get(pixels)
pixels = pixels.reshape(source_image.size[1], source_image.size[0], 4)
width, height = 1024, 512
atlas = np.ones((height, width, 4), dtype=np.float32)
fallbacks = 0
old_hem_pixels_replaced = 0
for y in range(height):
    for x in range(width):
        sign = -1 if x < width//2 else 1
        u, v = ((x % (width//2))+.5)/(width//2), (y+.5)/height
        point = panel(sign, u, v)
        hit, _, index, _ = tree.find_nearest(point)
        if hit is None:
            fallbacks += 1; atlas[y, x, :3] = (.16, .17, .18); continue
        face = sample_faces[index]
        original_uv = [Vector((*uvs[i], 0)) for i in face.loop_indices]
        uv = barycentric_transform(hit, *[positions[i] for i in face.vertices], *original_uv)
        ix = min(source_image.size[0]-1, max(0, int(uv.x*source_image.size[0])))
        iy = min(source_image.size[1]-1, max(0, int(uv.y*source_image.size[1])))
        atlas[y, x] = pixels[iy, ix]
        # The new hem has its own physical binding. Do not project the old
        # folded cream strips into the middle of a clean black cloth panel.
        if float(atlas[y, x, :3].mean()) > .44:
            atlas[y, x, :3] = (.18, .176, .18)
            old_hem_pixels_replaced += 1
        atlas[y, x, 3] = 1
texture = bpy.data.images.new('RenAuthoredCoatAlbedo', width=width, height=height, alpha=True)
texture.colorspace_settings.name = source_image.colorspace_settings.name
texture.pixels.foreach_set(atlas.ravel())
texture.filepath_raw = str((args.output/'coat_albedo.png').resolve()); texture.file_format = 'PNG'
texture.save(); texture.pack()
cloth = solid_material('RenAuthoredCoatFabric', (.02, .023, .028))
cloth_shader = cloth.node_tree.nodes.get('Principled BSDF')
tex = cloth.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = texture
cloth.node_tree.links.new(tex.outputs['Color'], cloth_shader.inputs['Base Color'])
panels = []
column_values = [0., .025] + [i/16 for i in range(1, 16)] + [.975, 1.]
row_values = [0., .06, .24, .45, .65, .84, 1.]
for sign in [-1, 1]:
    points, faces, coordinates, rows, material_ids = [], [], [], [], []
    for v in row_values:
        for u in column_values:
            point = panel(sign, u, v)
            points.append(point); coordinates.append(((u+(1 if sign > 0 else 0))/2, v))
            rows.append(weights(point, sign))
    columns = len(column_values)
    for row in range(len(row_values)-1):
        for col in range(columns-1):
            i = row*columns+col
            face = (i, i+1, i+1+columns, i+columns)
            faces.append(tuple(reversed(face)) if sign < 0 else face)
            material_ids.append(int(row == 0 or col in [0, columns-2]))
    obj = make_skinned('RenAuthoredCoat'+('Left' if sign > 0 else 'Right'), points, faces, coordinates, rows, [cloth, trim], material_ids)
    # Apply real cloth thickness before the skin modifier, preserving weights.
    skin = obj.modifiers.get('AuthoredSkin'); obj.modifiers.remove(skin)
    bpy.context.view_layer.objects.active = obj
    solidify = obj.modifiers.new('HemThickness', 'SOLIDIFY'); solidify.thickness = .003; solidify.offset = 0
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    obj.modifiers.new('AuthoredSkin', 'ARMATURE').object = rig
    panels.append(obj)
bpy.data.objects.remove(source, do_unlink=True)
objects = [body, pants, strap]+panels
triangles = 0
for obj in objects:
    obj.data.calc_loop_triangles(); triangles += len(obj.data.loop_triangles)
assert triangles <= 15000, triangles
assert all(len(v.groups) <= 4 for obj in objects for v in obj.data.vertices)
weight_error = max(abs(sum(g.weight for g in v.groups)-1) for obj in objects for v in obj.data.vertices)
assert weight_error < 1e-5, weight_error
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
for obj in objects: obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.file.pack_all()
native = args.output/'ren_rigged.blend'; glb = args.output/'ren_rigged.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()), export_format='GLB', use_selection=True,
                         export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
report = {'source_sha256': source_sha, 'plan_sha256': hashlib.sha256(args.plan.read_bytes()).hexdigest(),
          'recipe_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
          'method': 'Authored continuous trousers with shared crotch seam, two split side-wrap panels and true thickness',
          'triangles': triangles, 'bones': len(rig.data.bones), 'clips': [action.name for action in bpy.data.actions],
          'retained_original_face_count': len(mesh.polygons)-len(replace), 'replaced_source_faces': len(replace),
          'protected_pouch_faces': len(protected), 'retained_boundary_fragments': len(fragments),
          'retained_normal_reencoding_max_error': max(normal_errors),
          'retained_normal_reencoding_over_002': sum(error > .002 for error in normal_errors),
          'maximum_weight_sum_error': weight_error, 'waist_pouch_weight_vertices': len(waist_pouch_vertices),
          'thigh_pouch_weight_vertices': len(thigh_pouch_vertices),
          'new_coat_atlas': [width, height], 'nearest_sample_fallbacks': fallbacks,
          'old_hem_atlas_pixels_replaced': old_hem_pixels_replaced,
          'source_albedo_changed': False, 'action_keyframes_changed': False,
          'gates': {'motion': 'NOT_TESTED', 'visual': 'NOT_TESTED', 'formal_gameplay': 'NOT_STARTED'},
          'outputs': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [native, glb]}}
(args.output/'build_report.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf-8')
print('REN_AUTHORED_GARMENT', triangles, 'triangles; normal max error', max(normal_errors), flush=True)
