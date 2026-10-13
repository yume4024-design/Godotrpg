"""Local Blender script for an isolated review scene. MCP safe mode instead uses
the equivalent inline import/model commands with explicit manifest data.
Does not remove anything from the user's existing scenes or change the open file.
"""
from pathlib import Path
import json
import bpy
from mathutils import Vector, Quaternion

ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'source_assets/greystone_g02'
scene=bpy.data.scenes.get('Crystal_G02_Review')
if scene is not None and not scene.get('crystal_owned'):
    raise RuntimeError('Scene name belongs to another author; refusing to overwrite')
if scene is None:
    scene=bpy.data.scenes.new('Crystal_G02_Review')
    scene['crystal_owned']=True
else:
    for obj in list(scene.objects):
        if obj.get('crystal_owned'):
            bpy.data.objects.remove(obj,do_unlink=True)
bpy.context.window.scene=scene
def coordinate(v):return (v[0],-v[2],v[1])
def mark(obj):obj['crystal_owned']=True
palette={}
def material(rgb):
    key=tuple(rgb)
    if key not in palette:
        mat=bpy.data.materials.new('G02_review_color')
        mat.use_nodes=True
        linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
        next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=(*linear,1)
        mat.diffuse_color=(*linear,1)
        palette[key]=mat
    return palette[key]
def box(entry):
    bpy.ops.mesh.primitive_cube_add(size=1,location=coordinate(entry['position']))
    obj=bpy.context.object
    obj.name='G02_'+entry['name']
    w,h,d=entry['size']
    obj.scale=(w,d,h)
    obj.data.materials.append(material(entry['color']))
    mark(obj)
for entry in json.loads((SOURCE/'manifest.json').read_text()):
    before=set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/greystone/terrain'/Path(entry['file']).with_suffix('.glb')))
    for obj in set(scene.objects)-before:
        mark(obj)
        if obj.parent is None:obj.location+=Vector(coordinate(entry.get('position',(0,0,0))))
layout=json.loads((SOURCE/'layout.json').read_text())
for entry in layout['boxes']:box(entry)
for ident,title,pos,size,roof in layout['buildings']:
    x,y,z=pos;w,h,d=size
    box({'name':ident,'position':(x,y+h*.34,z),'size':(w,h*.68,d),'color':(.80,.73,.57)})
    # Six-vertex gable, preserving the same blockout footprint.
    vertices=[coordinate((x+dx,y+dy,z+dz)) for dx,dy,dz in [(-w/2,h*.68,-d/2),(w/2,h*.68,-d/2),(0,h,-d/2),(-w/2,h*.68,d/2),(w/2,h*.68,d/2),(0,h,d/2)]]
    mesh=bpy.data.meshes.new(ident+'_roof')
    mesh.from_pydata(vertices,[],[(0,2,1),(3,4,5),(0,3,5,2),(2,5,4,1),(0,1,4,3)])
    obj=bpy.data.objects.new(ident+'_roof',mesh);scene.collection.objects.link(obj);mark(obj)
    obj.data.materials.append(material([float(c) for c in roof.split(',')]))
pine=next(o for o in scene.objects if o.type=='MESH' and o.name.startswith('pinecontext'))
for n,pos in enumerate(layout['trees'][1:]):
    obj=bpy.data.objects.new('G02_Pine_%02d'%n,pine.data)
    scene.collection.objects.link(obj)
    obj.location=coordinate(pos);mark(obj)
scene.world=bpy.data.worlds.new('G02_ReviewWorld')
scene.world.color=(.3,.4,.5)
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.shading.type='MATERIAL'
        area.spaces.active.region_3d.view_location=(0,0,0)
        area.spaces.active.region_3d.view_distance=135
        area.spaces.active.region_3d.view_rotation=Quaternion((0.853553,0.353553,0.146447,0.353553))
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'greystone_g02_review.blend'),copy=True)
print('Review scene objects',len(scene.objects),'saved copy; other scenes retained.')
