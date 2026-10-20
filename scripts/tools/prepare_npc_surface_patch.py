"""Native 3D preparation for bounded colour repair; never changes input GLB."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--height', type=float, default=1.65)
p.add_argument('--name', default='ItemMerchantBody')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
points = [body.matrix_world @ vertex.co for vertex in body.data.vertices]
low = Vector([min(point[axis] for point in points) for axis in range(3)])
high = Vector([max(point[axis] for point in points) for axis in range(3)])
scale = a.height / (high.z-low.z)
for vertex, point in zip(body.data.vertices, points):
    vertex.co = ((point.x-(high.x+low.x)*.5)*scale,
                 (point.y-(high.y+low.y)*.5)*scale, (point.z-low.z)*scale)
body.matrix_world = Matrix.Identity(4)
body.name = a.name
body.data.update()
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.resolution_percentage = 100
scene.render.film_transparent = True
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'
span = a.height * 1.1
camera = bpy.data.objects.new('PatchCamera', bpy.data.cameras.new('PatchCamera'))
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.type = 'ORTHO'
camera.data.ortho_scale = span
materials = []
for material in body.data.materials:
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next(node for node in nodes if node.type == 'BSDF_PRINCIPLED')
    output = next(node for node in nodes if node.type == 'OUTPUT_MATERIAL')
    for node in nodes:
        if node.type == 'NORMAL_MAP': node.inputs['Strength'].default_value = 0
    emission = nodes.new('ShaderNodeEmission')
    links.new(shader.inputs['Base Color'].links[0].from_socket, emission.inputs[0])
    links.new(emission.outputs[0], output.inputs['Surface'])
    materials.append((links, shader, output))
for name, sign in [('front', -1), ('back', 1)]:
    camera.location = (0, sign*a.height*4, a.height*.5)
    camera.rotation_euler = (Vector((0, 0, a.height*.5))-camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str((a.output / ('albedo_' + name + '.png')).resolve())
    bpy.ops.render.render(write_still=True)
for links, shader, output in materials:
    links.new(shader.outputs[0], output.inputs['Surface'])
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output / 'baseline.blend').resolve()))
(a.output / 'projection.json').write_text(json.dumps({'span': span, 'center_z': a.height*.5,
    'height': a.height, 'input': str(a.input), 'input_sha256': hashlib.sha256(a.input.read_bytes()).hexdigest(),
    'method': 'Base colour emission render, orthographic, standard colour transform; unchanged topology',
    'back_horizontal_axis': 'Back camera reverses world X'}, indent=2), encoding='utf8')
print('NPC_SURFACE_PATCH_PREPARED', a.output, flush=True)
