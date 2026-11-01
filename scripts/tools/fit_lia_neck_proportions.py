"""Shorten Lia's measured neck transition without reshaping the face."""
import argparse,hashlib,json,sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--normalize-height',action='store_true');a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
sha=hashlib.sha256(a.input.read_bytes()).hexdigest();assert sha=='b9820e6db0f18892fbd703febd6ae6176c485ccdee78406e9bfaf0d6dbff3586'
if a.output.exists():raise FileExistsError('Preserve existing candidates')
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()));assert not any(o.type=='ARMATURE' for o in bpy.context.scene.objects)
start,end,offset=1.515,1.635,.035
objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];unchanged={o.name:[tuple(v.co) for v in o.data.vertices] for o in objects if o.name not in ['LiaRetainedAuthoredNeckSurface','LiaContinuousNeckClavicle']};results=[]
for name in ['LiaRetainedAuthoredNeckSurface','LiaContinuousNeckClavicle']:
 m=bpy.data.objects[name].data;coords=[v.co.copy() for v in m.vertices];uvs=[[tuple(d.uv) for d in layer.data] for layer in m.uv_layers];normals=[v.vector.copy() for v in m.corner_normals];scales=[];moved=0;rigid=0;fixed=0
 for v,co in zip(m.vertices,coords):
  t=max(0,min(1,(co.z-start)/(end-start)));falloff=t*t*(3-2*t);jac=1-offset*6*t*(1-t)/(end-start);assert jac>.5;scales.append(jac)
  v.co.z=co.z-offset*falloff
  if co.z<=start:assert (v.co-co).length<1e-7;fixed+=1
  elif co.z>=end:assert (v.co-(co-Vector((0,0,offset)))).length<2e-7;rigid+=1
  if falloff>0:moved+=1
 m.update();desired=[]
 for loop,n in zip(m.loops,normals):desired.append(Vector((n.x,n.y,n.z/scales[loop.vertex_index])).normalized())
 m.normals_split_custom_set(desired);calibration=calibrate(m,desired)
 assert all(tuple(d.uv)==prior for layer,old in zip(m.uv_layers,uvs) for d,prior in zip(layer.data,old))
 max_rigid_error=0
 for f in m.polygons:
  if all(coords[i].z>=end for i in f.vertices):
   for i,j in zip(f.vertices,list(f.vertices[1:])+[f.vertices[0]]):max_rigid_error=max(max_rigid_error,abs((coords[i]-coords[j]).length-(m.vertices[i].co-m.vertices[j].co).length))
 assert max_rigid_error<1e-6
 results.append({'object':name,'fixed_vertices':fixed,'rigidly_translated_vertices':rigid,'moved_vertices':moved,'face_edge_length_max_error':max_rigid_error,'uv_unchanged':True,'normal_calibration':calibration})
for name,coords in unchanged.items():assert [tuple(v.co) for v in bpy.data.objects[name].data.vertices]==coords
normalization={'applied':False}
if a.normalize_height:
 highest=max(v.co.z for o in objects for v in o.data.vertices);lowest=min(v.co.z for o in objects for v in o.data.vertices);assert abs(lowest)<1e-7
 factor=1.95/highest;calibrations={}
 for obj in objects:
  m=obj.data;before=[v.co.copy() for v in m.vertices];normals=[v.vector.copy() for v in m.corner_normals]
  for v in m.vertices:v.co*=factor
  m.update();m.normals_split_custom_set(normals);calibrations[obj.name]=calibrate(m,normals)
  assert all((v.co/factor-co).length<2e-7 for v,co in zip(m.vertices,before))
 assert abs(max(v.co.z for o in objects for v in o.data.vertices)-1.95)<2e-7
 normalization={'applied':True,'original_height':highest,'target_height':1.95,'uniform_scale':factor,'normal_calibrations':calibrations}
triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects);assert triangles==11492
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_neck_fit.blend';glb=out/'lia_neck_fit.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==sha
report={'source_sha256':sha,'transition_z':[start,end],'head_down_m':offset,'minimum_jacobian':1-offset*1.5/(end-start),'objects':results,'unchanged_before_uniform_normalization':list(unchanged),'normalization':normalization,'triangles':triangles,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'status':'static neck proportion candidate; no rig or formal integration'}
(out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('NECK_FIT',json.dumps(report))
