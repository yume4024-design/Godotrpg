"""Original reusable bronze short sword, with a real grip origin and tip marker."""
import argparse, hashlib, json, sys
from pathlib import Path
import bpy

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
assert not bpy.data.filepath, 'Run in a fresh background factory process'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
a.output.mkdir(parents=True)

def material(name,color,metallic,roughness):
    m=bpy.data.materials.new(name);m.use_nodes=True
    shader=m.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Metallic'].default_value=metallic
    shader.inputs['Roughness'].default_value=roughness
    return m

bronze=material('Bronze',(.34,.20,.075),.7,.38)
edge=material('BronzeEdge',(.52,.34,.15),.75,.30)
leather=material('BrownLeather',(.065,.028,.012),0,.88)
parts=[]
points=[]
for z,w,d in [(.05,.040,.009),(.12,.037,.009),(.43,.026,.007)]:
    points.extend([(w,0,z),(0,d,z),(-w,0,z),(0,-d,z)])
points.append((0,0,.535))
faces=[(3,2,1,0)]
zones=[0]
for level in range(2):
    for i in range(4):
        j=(i+1)%4
        faces.append((level*4+i,level*4+j,(level+1)*4+j,(level+1)*4+i))
        zones.append(1 if level==1 else 0)
for i in range(4):
    faces.append((8+i,8+(i+1)%4,12));zones.append(1)
mesh=bpy.data.meshes.new('BronzeBlade');mesh.from_pydata(points,[],faces);mesh.update()
blade=bpy.data.objects.new('BronzeBlade',mesh);bpy.context.scene.collection.objects.link(blade)
mesh.materials.append(bronze);mesh.materials.append(edge)
zone=mesh.attributes.new('DistalBlade','INT','FACE')
for f,value in zip(mesh.polygons,zones):
    f.material_index=f.index%2;zone.data[f.index].value=value
parts.append(blade)

def cube(name,location,size,mat,bevel):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('SmallCraftedBevel','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.append(mat);parts.append(o);return o

cube('Guard',(0,0,.025),(.155,.035,.028),bronze,.006)
bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.017,depth=.12,location=(0,0,-.045))
handle=bpy.context.object;handle.name='Grip';handle.data.materials.append(leather);parts.append(handle)
for z in [-.09,-.063,-.036,-.009]:
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.019,depth=.007,location=(0,0,z))
    wrap=bpy.context.object;wrap.data.materials.append(leather);parts.append(wrap)
cube('Pommel',(0,0,-.119),(.046,.036,.035),bronze,.007)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=blade
bpy.ops.object.join()
body=bpy.context.object;body.name='BronzeSwordMesh'
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(island_margin=.02)
bpy.ops.object.mode_set(mode='OBJECT')
root=bpy.data.objects.new('BronzeSword',None);bpy.context.scene.collection.objects.link(root);body.parent=root
for name,z in [('GripOrigin',0),('BladeRoot',.12),('Tip',.535)]:
    marker=bpy.data.objects.new(name,None);marker.location=(0,0,z);marker.parent=root
    bpy.context.scene.collection.objects.link(marker)
body.data.calc_loop_triangles();triangles=len(body.data.loop_triangles)
assert triangles<=1000
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=root
native=a.output/'bronze_sword.blend';glb=a.output/'bronze_sword.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,export_animations=False)
report={'source':'Original project Blender geometry; no third-party asset',
        'triangles':triangles,'explicit_budget':1000,'units':'metres','godot_up_axis':'Y',
        'grip_origin':[0,0,0],'tip_blender':[0,0,.535],'textures':0,
        'uv_present':bool(body.data.uv_layers),'distal_blade_face_attribute':'DistalBlade',
        'outputs':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in [native,glb]}}
(a.output/'build_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('BRONZE_SWORD',triangles,'triangles',flush=True)
