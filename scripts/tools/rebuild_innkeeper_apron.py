"""Local manual-topology recipe: replace the diagnosed crossed front cloth, not flatten it.

Input is the preserved 1.72 m innkeeper baseline. The bounded apron region,
surface colour and exact source SHA are checked before any face is removed.
All retained corners keep their positions, UVs and split normals. A continuous
curved cloth panel gets new topology, thickness and a source-albedo UV transfer.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
if a.output.exists():
    raise FileExistsError(a.output)
a.output.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
assert hashlib.sha256(a.input.read_bytes()).hexdigest() == 'f76443c999aea4840547992042c6929a001dbcf24a066734ea07ae12431c4ae0', 'Unreviewed baseline'
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
mesh = body.data
assert len(mesh.polygons) == 13642, 'Source mesh differs; inspect before editing'
positions = [v.co.copy() for v in mesh.vertices]
height = max(v.z for v in positions) - min(v.z for v in positions)
print('SOURCE_DIMENSIONS', height, list(body.dimensions), list(body.scale), flush=True)
assert abs(height - 1.72) < .001
material = mesh.materials[0]
shader = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
image = shader.inputs['Base Color'].links[0].from_node.image
pixels = np.empty(len(image.pixels), dtype=np.float32)
image.pixels.foreach_get(pixels)
pixels = pixels.reshape(image.size[1], image.size[0], 4)
uvs = [uv.uv.copy() for uv in mesh.uv_layers.active.data]
normals = [n.vector.copy() for n in mesh.corner_normals]

def color(uv):
    x = min(image.size[0] - 1, max(0, int(uv.x * image.size[0])))
    y = min(image.size[1] - 1, max(0, int(uv.y * image.size[1])))
    return pixels[y, x]

def cream(rgb):
    return rgb[0] > .28 and rgb[1] > .23 and rgb[2] > .14 and max(rgb[:3]) - min(rgb[:3]) < .32

# Artist-inspected front apron, below the vest, inside the hanging hands.
# The entire crossed layer is removed, rather than pressing many layers flat.
removed, kept, sample_faces = [], [], []
for f in mesh.polygons:
    point = f.center
    rgb = np.mean([color(uvs[i]) for i in f.loop_indices], axis=0)
    # Source ray/UV inspection locates the actual vest seam at z=.85-.885,
    # not .975. Preserve the vest; remove the whole crossed cloth below it.
    waist = .85 + .035 * min(1, (point.x / .265) ** 2)
    in_panel = abs(point.x) < .335 and .355 < point.z < waist + .002 and point.y < .025
    # Do not remove the original hem/pants by colour: mixed UV corners belong
    # to the trouser surface too. The curved new hem is correctly visible
    # through the gap between the legs when viewed from behind.
    if in_panel:
        removed.append(f.index)
        if in_panel and cream(rgb): sample_faces.append(f)
    else:
        kept.append(f)
assert 1000 < len(removed) < 6500, ('Unexpected selection', len(removed))
source_triangles = [tuple(f.vertices) for f in sample_faces]
tree = BVHTree.FromPolygons(positions, source_triangles, all_triangles=True)
used = sorted({i for f in kept for i in f.vertices})
remap = {old: new for new, old in enumerate(used)}
body_points = [positions[i] for i in used]
body_faces = [[remap[i] for i in f.vertices] for f in kept]
corner_data = [[(uvs[l].copy(), normals[l].copy()) for l in f.loop_indices] for f in kept]
materials = [f.material_index for f in kept]
smooth_faces = [f.use_smooth for f in kept]
fragments = 0
for index in removed:
    f = mesh.polygons[index]
    # A source triangle can straddle cloth and trousers. Preserve its lower
    # part instead of deleting a complete triangle and leaving a sawtooth hole.
    if min(positions[v].z for v in f.vertices) >= .37: continue
    polygon = [(positions[mesh.loops[l].vertex_index].copy(), uvs[l].copy(), normals[l].copy()) for l in f.loop_indices]
    clipped = []
    for previous, current in zip(polygon[-1:] + polygon[:-1], polygon):
        previous_inside, current_inside = previous[0].z <= .37, current[0].z <= .37
        if previous_inside != current_inside:
            weight = (.37 - previous[0].z) / (current[0].z - previous[0].z)
            clipped.append((previous[0].lerp(current[0], weight), previous[1].lerp(current[1], weight), previous[2].lerp(current[2], weight).normalized()))
        if current_inside: clipped.append(current)
    if len(clipped) < 3: continue
    first = len(body_points)
    body_points.extend(row[0] for row in clipped)
    body_faces.append(list(range(first, first + len(clipped))))
    corner_data.append([(row[1], row[2]) for row in clipped])
    materials.append(f.material_index)
    smooth_faces.append(f.use_smooth)
    fragments += 1
clean = bpy.data.meshes.new('InnkeeperRetainedBody')
clean.from_pydata(body_points, [], body_faces)
for mat in mesh.materials:
    clean.materials.append(mat)
clean.uv_layers.new(name=mesh.uv_layers.active.name)
kept_normals = []
for index, target in enumerate(clean.polygons):
    target.material_index = materials[index]
    target.use_smooth = smooth_faces[index]
    for dst, (uv, normal) in zip(target.loop_indices, corner_data[index]):
        clean.uv_layers.active.data[dst].uv = uv
        kept_normals.append(normal)
clean.normals_split_custom_set(kept_normals)
body.data = clean

def panel(u, v, inside=False):
    theta = (u - .5) * math.pi
    hem = .355 + .009 * math.cos(theta)
    waist = .85 + .035 * math.sin(theta) ** 2
    z = hem * (1 - v) + waist * v
    radius_x = .337 - .072 * v
    radius_y = .247 - .014 * v
    # Broad shallow folds, no inverted layers or deep triangular cut.
    crease = .0035 * math.cos(theta * 5) * (1 - v)
    return Vector((math.sin(theta) * radius_x,
                   .012 - math.cos(theta) * (radius_y + crease) + (.004 if inside else 0), z))

columns, rows = 24, 16
points = [panel(col / columns, row / rows) for row in range(rows + 1) for col in range(columns + 1)]
faces = []
for row in range(rows):
    for col in range(columns):
        start = row * (columns + 1) + col
        faces.append((start, start + 1, start + columns + 2, start + columns + 1))
cloth_mesh = bpy.data.meshes.new('ContinuousApronPanel')
cloth_mesh.from_pydata(points, [], faces)
cloth_mesh.uv_layers.new(name=mesh.uv_layers.active.name)
for f in cloth_mesh.polygons:
    for loop in f.loop_indices:
        vertex = cloth_mesh.loops[loop].vertex_index
        cloth_mesh.uv_layers.active.data[loop].uv = ((vertex % (columns + 1)) / columns,
                                                  (vertex // (columns + 1)) / rows)
cloth = bpy.data.objects.new('InnkeeperApron', cloth_mesh)
bpy.context.scene.collection.objects.link(cloth)

# Bake the original front cloth colour into a single new atlas. New triangles
# never interpolate between unrelated original UV islands.
size = 512
atlas = np.zeros((size, size, 4), dtype=np.float32)
fallbacks = 0
for y in range(size):
    for x in range(size):
        position = panel((x + .5) / size, (y + .5) / size)
        origin = Vector((position.x, -1, position.z))
        hit, _, index, _ = tree.ray_cast(origin, Vector((0, 1, 0)), 2)
        if hit is None:
            hit, _, index, _ = tree.find_nearest(position)
            fallbacks += 1
        f = sample_faces[index]
        vertex_uvs = [uvs[i] for i in f.loop_indices]
        triangle = [positions[i] for i in f.vertices]
        uv = barycentric_transform(hit, *triangle, *[Vector((p.x, p.y, 0)) for p in vertex_uvs])
        atlas[y, x] = color(uv)
atlas[:, :, 3] = 1
texture = bpy.data.images.new('InnkeeperApronAlbedo', width=size, height=size, alpha=True)
texture.pixels.foreach_set(atlas.ravel())
texture.filepath_raw = str((a.output / 'apron_albedo.png').resolve())
texture.file_format = 'PNG'
texture.save()
texture.pack()
cloth_material = bpy.data.materials.new('InnkeeperApronCloth')
cloth_material.use_nodes = True
principled = next(n for n in cloth_material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
tex = cloth_material.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = texture
cloth_material.node_tree.links.new(tex.outputs['Color'], principled.inputs['Base Color'])
principled.inputs['Roughness'].default_value = .85
cloth_mesh.materials.append(cloth_material)
for mat in body.data.materials:
    principled = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    for socket in ['Normal', 'Metallic', 'Roughness']:
        for link in list(principled.inputs[socket].links):
            mat.node_tree.links.remove(link)
    principled.inputs['Metallic'].default_value = 0
    principled.inputs['Roughness'].default_value = .8
bpy.ops.object.select_all(action='DESELECT')
cloth.select_set(True)
bpy.context.view_layer.objects.active = cloth
thickness = cloth.modifiers.new('ActualClothThickness', 'SOLIDIFY')
thickness.thickness = .004
thickness.offset = 0
bpy.ops.object.modifier_apply(modifier=thickness.name)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'InnkeeperBody'
assert len(body.data.uv_layers) == 1, 'Joined cloth must use the same active UV layer as the retained body'
triangles = sum(len(f.vertices) - 2 for f in body.data.polygons)
assert triangles <= 15000
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output / 'innkeeper_retopology.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output / 'innkeeper_retopology.glb').resolve()), export_format='GLB', use_selection=True, export_animations=False)
report = {'status': 'REQUIRES_VISUAL_REVIEW', 'source': str(a.input), 'source_sha256': hashlib.sha256(a.input.read_bytes()).hexdigest(),
          'source_triangles': 13642, 'removed_crossed_panel_faces': len(removed), 'removed_face_indices': removed,
          'retained_faces': len(kept), 'clipped_pants_boundary_fragments': fragments,
          'retained_corner_positions_uv_preserved': True,
          'retained_normals': 'Copied original custom normals; Blender re-encodes them; inspect preservation audit error separately', 'new_panel_rows': rows,
          'new_panel_columns': columns, 'real_thickness_m': .004, 'source_albedo_transfer_nearest_samples': fallbacks,
          'atlas_size': size, 'triangles': triangles, 'uv_rebuilt_only_on_new_panel': True,
          'limitations': ['Not rigged or gameplay accepted', 'Existing non-apron topology warnings retained']}
(a.output / 'manual_topology_report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('APRON_TOPOLOGY', triangles, 'triangles;', len(removed), 'source faces replaced; visual review required', flush=True)
