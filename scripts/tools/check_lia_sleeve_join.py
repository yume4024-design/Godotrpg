"""Check the exact static outer-sleeve join after GLB export, not rig quality."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree

p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
if a.output.exists():raise FileExistsError('Use a new report path')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(objects)==4, 'Unexpected character structure'
body=next(o for o in objects if o.data.name.startswith('Mesh_0'))
points=[body.matrix_world@v.co for v in body.data.vertices]
kd=KDTree(len(points))
for i,v in enumerate(points):kd.insert(v,i)
kd.balance()
rows=[]
for sign,label,count in [(-1,'Right',11),(1,'Left',13)]:
 hand=next(o for o in objects if o.data.name.startswith('LiaForearmHand'+label))
 wrist=Vector((sign*.42,.06,1.06));axis=Vector((sign*.48,0,-.877268)).normalized()
 seam={tuple(round(c,7) for c in hand.matrix_world@v.co) for v in hand.data.vertices if abs(((hand.matrix_world@v.co)-wrist).dot(axis)+.32)<1e-5}
 assert len(seam)==count,(label,len(seam))
 distances=[kd.find(Vector(v))[2] for v in seam]
 assert max(distances)<1e-5,(label,max(distances))
 rows.append({'side':label,'outer_seam_vertices':len(seam),'maximum_body_vertex_distance_m':max(distances)})
report={'input_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'blender_version':bpy.app.version_string,'static_outer_seam_gate':'PASS','tolerance_m':1e-5,'rows':rows,'limitations':['Checks coincident outer seam vertices only; separate mesh objects are not welded','Does not test normals, whole sleeve intersections, weights or animation']}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('STATIC_SLEEVE_SEAM_PASS',json.dumps(report))
