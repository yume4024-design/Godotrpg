"""Blender background fallback: export original G02 terrain components as GLB.

blender --background --python scripts/tools/greystone/export_terrain.py
Authoring OBJ is generated locally, never downloaded; no external assets or addon.
"""
from pathlib import Path
import json
import bpy

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'source_assets/greystone_g02'
OUT = ROOT / 'assets/models/greystone/terrain'
OUT.mkdir(parents=True, exist_ok=True)
materials = {}
metrics = []
for entry in json.loads((SOURCE/'manifest.json').read_text(encoding='utf-8')):
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    vertices, faces = [], []
    for line in (SOURCE/entry['file']).read_text(encoding='utf-8').splitlines():
        if line.startswith('v '):
            x,y,z = map(float,line.split()[1:])
            vertices.append((x,-z,y))  # Godot Y up -> Blender Z up; exporter reverses it.
        elif line.startswith('f '):
            faces.append(tuple(int(i)-1 for i in line.split()[1:]))
    mesh = bpy.data.meshes.new(Path(entry['file']).stem)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj = bpy.data.objects.new(mesh.name,mesh)
    bpy.context.collection.objects.link(obj)
    key=tuple(entry['color'])
    if key not in materials:
        material=bpy.data.materials.new('Greystone_%02d' % len(materials))
        material.use_nodes=True
        material.use_backface_culling=True
        shader=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        linear=tuple(v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in key)
        shader.inputs['Base Color'].default_value=(*linear,1)
        shader.inputs['Roughness'].default_value=1
        material.diffuse_color=(*linear,1)
        materials[key]=material
    mesh.materials.append(materials[key])
    bpy.ops.export_scene.gltf(filepath=str(OUT/(mesh.name+'.glb')),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    metrics.append({'file':mesh.name+'.glb','triangles':len(faces)})
(SOURCE/'metrics.json').write_text(json.dumps(metrics,indent=2),encoding='utf-8')
print('GREYSTONE_GLBS',len(metrics),'TRIANGLES',sum(m['triangles'] for m in metrics))
