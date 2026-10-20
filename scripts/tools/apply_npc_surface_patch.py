"""Project bounded, reviewed front/back repairs and rebake the existing UV atlas."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--name', default='item_merchant')
p.add_argument('--regions', type=Path)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
default_regions = [(275, 230, 750, 480), (405, 830, 620, 910)]
view_regions = {'front': default_regions, 'back': default_regions}
if a.regions:
    view_regions = json.loads(a.regions.read_text(encoding='utf8'))
    if set(view_regions) != {'front', 'back'}: raise ValueError('Specify both view regions')
    for rectangles in view_regions.values():
        if not rectangles: raise ValueError('Missing bounded repair region')
        for rectangle in rectangles:
            if (len(rectangle) != 4 or not all(isinstance(value, int) for value in rectangle) or
                not 0 <= rectangle[0] < rectangle[2] <= 1024 or not 0 <= rectangle[1] < rectangle[3] <= 1024):
                raise ValueError('Repair rectangles must be bounded in the source 1024 canvas')
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str((a.source / 'baseline.blend').resolve()))
body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
projection = json.loads((a.source / 'projection.json').read_text(encoding='utf8'))
span, height, center = projection['span'], projection['height'], projection['center_z']
main_uv = body.data.uv_layers.active.name
bm = bmesh.new()
bm.from_mesh(body.data)
tree = BVHTree.FromBMesh(bm)
patches = []
for view, sign in [('front', -1), ('back', 1)]:
    regions = view_regions[view]
    path = a.source / (view + '_repair.png')
    image = bpy.data.images.load(str(path.resolve()))
    uv = body.data.uv_layers.new(name='Patch_' + view)
    mask = body.data.color_attributes.new(name='Repair_' + view, type='FLOAT_COLOR', domain='CORNER')
    selected = 0
    for polygon in body.data.polygons:
        point = polygon.center
        hit, normal, index, distance = tree.ray_cast(Vector((point.x, sign*height*4, point.z)), Vector((0, -sign, 0)))
        visible = hit is not None and abs(hit.y-point.y) < height*.003
        touched = False
        for loop in polygon.loop_indices:
            vertex = body.data.vertices[body.data.loops[loop].vertex_index].co
            u = .5 + (-sign)*vertex.x/span
            v = .5 + (vertex.z-center)/span
            uv.data[loop].uv = (u, v)
            px, py = u*1024, (1-v)*1024
            factor = max(max(0, min(1, min(px-x0, x1-px, py-y0, y1-py)/8)) for x0, y0, x1, y1 in regions)
            factor = factor if visible else 0
            mask.data[loop].color = (factor, factor, factor, 1)
            touched = touched or factor > 0
        selected += int(touched)
    patches.append((view, uv.name, mask.name, image, selected, path))
bm.free()
body.data.uv_layers.active = body.data.uv_layers[main_uv]
body.data.uv_layers[main_uv].active_render = True
target_image = bpy.data.images.new(a.name + '_RepairedAlbedo', width=4096, height=4096, alpha=False)
target_image.colorspace_settings.name = 'sRGB'
saved = []
for material in body.data.materials:
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next(node for node in nodes if node.type == 'BSDF_PRINCIPLED')
    output = next(node for node in nodes if node.type == 'OUTPUT_MATERIAL')
    color = shader.inputs['Base Color'].links[0].from_socket
    for view, uv_name, mask_name, image, selected, path in patches:
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = image
        uv_node = nodes.new('ShaderNodeUVMap')
        uv_node.uv_map = uv_name
        links.new(uv_node.outputs[0], texture.inputs['Vector'])
        attribute = nodes.new('ShaderNodeVertexColor')
        attribute.layer_name = mask_name
        multiply = nodes.new('ShaderNodeMath')
        multiply.operation = 'MULTIPLY'
        links.new(attribute.outputs['Color'], multiply.inputs[0])
        links.new(texture.outputs['Alpha'], multiply.inputs[1])
        mix = nodes.new('ShaderNodeMixRGB')
        links.new(multiply.outputs[0], mix.inputs[0])
        links.new(color, mix.inputs[1])
        links.new(texture.outputs['Color'], mix.inputs[2])
        color = mix.outputs[0]
    emission = nodes.new('ShaderNodeEmission')
    links.new(color, emission.inputs[0])
    links.new(emission.outputs[0], output.inputs['Surface'])
    target = nodes.new('ShaderNodeTexImage')
    target.image = target_image
    nodes.active = target
    saved.append((material, shader, output, target))
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
scene.render.bake.margin = 24
scene.render.bake.margin_type = 'EXTEND'
bpy.ops.object.bake(type='EMIT', use_clear=True)
target_image.filepath_raw = str((a.output / 'albedo.png').resolve())
target_image.file_format = 'PNG'
target_image.save()
for material, shader, output, target in saved:
    nodes, links = material.node_tree.nodes, material.node_tree.links
    links.new(target.outputs['Color'], shader.inputs['Base Color'])
    links.new(shader.outputs[0], output.inputs['Surface'])
    for node in list(nodes):
        if node not in [shader, output, target]: nodes.remove(node)
    shader.inputs['Metallic'].default_value = 0
    shader.inputs['Roughness'].default_value = .8
for view, uv_name, mask_name, image, selected, path in patches:
    body.data.uv_layers.remove(body.data.uv_layers[uv_name])
    body.data.color_attributes.remove(body.data.color_attributes[mask_name])
for image in list(bpy.data.images):
    if image.users == 0 and image.type != 'RENDER_RESULT': bpy.data.images.remove(image)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output / (a.name + '_surface.blend')).resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output / (a.name + '_surface.glb')).resolve()), export_format='GLB',
                         use_selection=True, export_animations=False)
(a.output / 'surface_report.json').write_text(json.dumps({'source': str(a.source), 'projection': projection,
    'method': 'Reviewed imagegen colour repair, bounded visible-surface UV projection and emission-only bake',
    'regions_at_1024': view_regions, 'topology_modified': False, 'rigged': False,
    'material_change': 'Baked normal map disabled after controlled diagnostic showed false black tears',
    'patches': [{'view': view, 'selected_polygons': selected, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                for view, uv, mask, image, selected, path in patches]}, indent=2), encoding='utf8')
print('NPC_SURFACE_PATCH_APPLIED', a.output, flush=True)
