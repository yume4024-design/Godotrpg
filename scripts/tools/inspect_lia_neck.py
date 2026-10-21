"""Read-only neck/collar face inventory and labelled native views of the new Lia.

Only in-memory diagnostic materials/cameras are changed. The source is never saved.
"""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--expected-sha',default='935c47d37706c711cafbb8f1156b6efb6fba1cdbc1edd341fcb3b7da4ec01281')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==a.expected_sha
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
body=scene.objects.get('LiaRetainedSurface') or next(o for o in scene.objects if o.type=='MESH')
mesh=body.data
shader=next(n for n in body.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
image=shader.inputs['Base Color'].links[0].from_node.image
pixels=np.asarray(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)
rows=[];sections={}
for face in mesh.polygons:
    if not(1.43<face.center.z<1.71 and abs(face.center.x)<.16):continue
    uv=sum((mesh.uv_layers.active.data[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
    color=pixels[min(image.size[1]-1,max(0,int(uv.y*image.size[1]))),min(image.size[0]-1,max(0,int(uv.x*image.size[0]))),:3]
    rows.append({'face':face.index,'center':list(face.center),'normal':list(face.normal),
                 'points':[list(mesh.vertices[i].co)for i in face.vertices],'rgb_linear':color.tolist()})
for height in [1.48,1.50,1.52,1.54,1.56,1.58,1.60,1.62,1.64,1.66]:
    segments=[]
    for row in rows:
        points=[Vector(point)for point in row['points']];cross=[]
        for lo,hi in zip(points,points[1:]+points[:1]):
            if (lo.z<height)!=(hi.z<height):cross.append(lo.lerp(hi,(height-lo.z)/(hi.z-lo.z)))
        if len(cross)==2:segments.append({'face':row['face'],'points':[list(v)for v in cross]})
    sections[str(height)]=segments
a.output.mkdir(parents=True)
(a.output/'neck_inventory.json').write_text(json.dumps({'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),
    'rows':rows,'sections':sections,'source_modified':False},indent=2)+'\n',encoding='utf8')
for obj in list(scene.objects):
    if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8
scene.render.resolution_x=scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.world=bpy.data.worlds.new('NeckDiagnosticWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.16,.20,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
camera=bpy.data.objects.new('NeckCamera',bpy.data.cameras.new('NeckCamera'));scene.collection.objects.link(camera)
scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=.36
for index,(point,power)in enumerate([((2,-3,4),350),((-2,1,3),160)]):
    data=bpy.data.lights.new('NeckLight'+str(index),'AREA');data.energy=power;data.size=3
    obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=point
    obj.rotation_euler=(Vector((0,0,1.6))-obj.location).to_track_quat('-Z','Y').to_euler()
for name,angle in [('front',0),('right',math.pi/2),('three_quarter',math.pi/4),('back',math.pi)]:
    camera.location=(math.sin(angle)*3,-math.cos(angle)*3,1.59)
    camera.rotation_euler=(Vector((0,0,1.59))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(name+'.png')).resolve());bpy.ops.render.render(write_still=True)
print('LIA_NECK_INVENTORY',len(rows),'faces',flush=True)
