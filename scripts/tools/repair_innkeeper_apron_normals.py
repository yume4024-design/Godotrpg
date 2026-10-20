"""Reproduce rejected apron repair diagnostics, never a production promotion tool.

Normal-only and flatten variants both failed visual QA; preserve for evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--flatten-apron', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
mesh = body.data
before = [tuple(vertex.co) for vertex in mesh.vertices]
normals = [tuple(normal.vector) for normal in mesh.corner_normals]
displacements = []
if a.flatten_apron:
    # Remove the unwanted deep front-cloth fold that casts a triangular shadow.
    # Restrict this edit to the apron; leave the torso, hands, belt and rear ties.
    def smooth(low, high, value):
        t = max(0., min(1., (value-low)/(high-low)))
        return t*t*(3-2*t)
    for vertex in mesh.vertices:
        point = vertex.co
        if abs(point.x) < .31 and .35 < point.z < .97 and point.y < -.09:
            influence = ((1-smooth(.25, .31, abs(point.x))) *
                         smooth(.35, .42, point.z) * (1-smooth(.91, .97, point.z)))
            target = -.235 + .7*point.x**2
            previous = point.y
            point.y = previous*(1-influence) + target*influence
            if abs(point.y-previous) > 1e-7: displacements.append(abs(point.y-previous))
changed = 0
for loop in mesh.loops:
    point = mesh.vertices[loop.vertex_index].co
    if -.30 < point.x < .30 and .36 < point.z < .96 and point.y < -.09:
        # This is the broad front cloth, not hands, waistband, back ties or hem
        # underside. Imported adjacent corners included almost opposite normals.
        normals[loop.index] = tuple(Vector((point.x*1.7, -1, .03)).normalized())
        changed += 1
assert changed > 100, 'Expected front apron corners; inspect the source instead of guessing'
mesh.normals_split_custom_set(normals)
mesh.update()
for material in mesh.materials:
    shader = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    for name in ['Normal', 'Metallic', 'Roughness']:
        for link in list(shader.inputs[name].links): material.node_tree.links.remove(link)
    shader.inputs['Metallic'].default_value = 0
    shader.inputs['Roughness'].default_value = .8
assert bool(displacements) == a.flatten_apron
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output/'innkeeper_surface.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output/'innkeeper_surface.glb').resolve()),
                         export_format='GLB', use_selection=True, export_animations=False)
(a.output/'surface_report.json').write_text(json.dumps({'source':str(a.input),
    'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(), 'geometry_modified':a.flatten_apron,
    'apron_vertices_adjusted':len(displacements), 'maximum_apron_displacement_m':max(displacements,default=0),
    'uv_or_albedo_modified':False, 'changed_apron_corner_normals':changed,
    'normal_method':'Locally consistent radial front-cloth normals; preserve other imported corner normals',
    'material':'Neutral rough non-metal cloth; broken baked normal disconnected',
    'status':'UNVERIFIED_REQUIRES_VISUAL_REVIEW',
    'unverified':['Topology closure, cloth intersections and animated deformation']},indent=2),encoding='utf8')
print('APRON_REPAIR',changed,'corners;',len(displacements),'apron vertices; UV/albedo preserved',flush=True)
