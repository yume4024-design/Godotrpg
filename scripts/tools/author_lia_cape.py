"""Rebuild Lia's capelet and extend the measured upper sleeve loops in a copy."""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--selection',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--fit-shoulders',action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);sha=hashlib.sha256(a.input.read_bytes()).hexdigest();assert sha=='e77b8e89d132740209a12e5e64d2441592ff95d4cea58f4c5be2446e5350ce71'
selection_sha=hashlib.sha256(a.selection.read_bytes()).hexdigest();assert selection_sha in ['e38d484ad1a9de78690116e2104b87a34864e3c78555ffb13513f3c66968aaa8','83bd01f1f92de6eb587e3ec6516ab8e42c7b5135e9cc8287d19f5a7a6333d0d4','377c445a6a64c2ae627ea400e125870f4bba7506d676d247a9e85af01a500eaa']
if a.output.exists():raise FileExistsError('Preserve candidates')
selected=set(json.loads(a.selection.read_text())['faces']);assert len(selected) in [1264,1278,1279]
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];m=body.data;normals=[v.vector.copy() for v in m.corner_normals];uv=m.uv_layers.active
kept={f.index:[(tuple(m.vertices[m.loops[i].vertex_index].co),tuple(uv.data[i].uv),tuple(normals[i])) for i in f.loop_indices] for f in m.polygons if f.index not in selected}
bm=bmesh.new();bm.from_mesh(m);bm.faces.ensure_lookup_table();ids=bm.faces.layers.int.new('CapeSourceFace');nl=bm.loops.layers.float_vector.new('CapeSourceNormal')
for f in bm.faces:
 f[ids]=f.index
 for l,i in zip(f.loops,m.polygons[f.index].loop_indices):l[nl]=normals[i]
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in sorted(selected)],context='FACES_ONLY');bm.to_mesh(m);bm.free();m.update()
desired=[v.vector.copy() for v in m.attributes['CapeSourceNormal'].data];m.normals_split_custom_set(desired);calibration=calibrate(m,desired);m.attributes.remove(m.attributes['CapeSourceNormal'])
error=0
for f in m.polygons:
 expected=kept[m.attributes['CapeSourceFace'].data[f.index].value];assert len(expected)==len(f.loop_indices)
 for i,(co,tex,n) in zip(f.loop_indices,expected):
  assert (m.vertices[m.loops[i].vertex_index].co-Vector(co)).length<1e-7
  assert (m.uv_layers.active.data[i].uv-Vector(tex)).length<1e-7
  d=(m.corner_normals[i].vector-Vector(n)).length;error=max(error,d);assert d<.002
# Extend each existing measured forearm ring instead of approximating its seam.
sleeves=[]
for label,sign in [('Left',-1),('Right',1)]:
 hand=bpy.data.objects['LiaHand'+label];old=hand.data
 # Names follow authored hand labels; use the geometry to determine its side.
 sign=-1 if sum(v.co.x for v in old.vertices)<0 else 1
 wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();base_center=wrist+down*(-.32)
 cap=old.polygons[-1];ring=list(reversed(cap.vertices));assert len(ring) in [11,13]
 assert all(abs((old.vertices[i].co-base_center).dot(down))<2e-6 for i in ring)
 points=[tuple(v.co) for v in old.vertices];faces=[tuple(f.vertices) for f in old.polygons[:-1]];slots=[f.material_index for f in old.polygons[:-1]];smooth=[f.use_smooth for f in old.polygons[:-1]]
 textures=[[tuple(old.uv_layers.active.data[i].uv) for i in f.loop_indices] for f in old.polygons[:-1]]
 base=[Vector(points[i]) for i in ring];previous=ring
 rows=[(-.38,.95),(-.43,.95),(-.48,.70)] if a.fit_shoulders else [(-.38,.95),(-.46,1.0),(-.54,.90)]
 for distance,scale in rows:
  current=[]
  for v in base:current.append(len(points));points.append(tuple(wrist+down*distance+(v-base_center)*scale))
  for k in range(len(ring)):
   faces.append((previous[k],previous[(k+1)%len(ring)],current[(k+1)%len(ring)],current[k]));slots.append(4);smooth.append(False);textures.append([(k/len(ring),0),((k+1)/len(ring),0),((k+1)/len(ring),1),(k/len(ring),1)])
  previous=current
 faces.append(tuple(reversed(previous)));slots.append(4);smooth.append(False);textures.append([(i/len(previous),.5) for i in range(len(previous))])
 mesh=bpy.data.meshes.new('LiaCompleteSleeveHand'+label);mesh.from_pydata(points,[],faces);mesh.update()
 for mat in old.materials:mesh.materials.append(mat)
 tex=mesh.uv_layers.new(name='UVMap')
 for f,slot,sh,uvs in zip(mesh.polygons,slots,smooth,textures):
  f.material_index=slot;f.use_smooth=sh
  for i,v in zip(f.loop_indices,uvs):tex.data[i].uv=v
 check=bmesh.new();check.from_mesh(mesh);bmesh.ops.recalc_face_normals(check,faces=list(check.faces));assert all(e.is_manifold for e in check.edges);assert all(f.calc_area()>1e-10 for f in check.faces);check.to_mesh(mesh);check.free();mesh.update()
 assert all((mesh.vertices[i].co-old.vertices[i].co).length<1e-7 for i in range(len(old.vertices)))
 hand.data=mesh;sleeves.append({'object':hand.name,'ring_vertices':len(ring),'old_vertices_preserved':len(old.vertices),'closed':True})
# Open-front capelet. Inner ring meets the existing authored collar's base.
collar=bpy.data.objects['LiaAuthoredCollar'].data
top=[collar.vertices[i*6].co.copy() for i in range(11)]
bottom=[Vector(v) for v in [(-.13,-.14,1.345),(-.245,-.13,1.35),(-.32,-.04,1.35),(-.29,.10,1.345),(-.18,.16,1.32),(0,.165,1.32)]]
bottom += [Vector((-v.x,v.y,v.z)) for v in reversed(bottom[:-1])]
# Narrow front-edge strips retain the approved cream piping.
for array in [top,bottom]:
 array.insert(1,array[0].lerp(array[1],.08));array.insert(len(array)-1,array[-1].lerp(array[-2],.08))
rows=[0,.32,.65,.94,1.0];n=len(top);points=[];faces=[];slots=[]
for t in rows:
 for upper,lower in zip(top,bottom):
  v=upper.lerp(lower,t);v.z+=.055*math.sin(math.pi*t);points.append(tuple(v))
for r in range(len(rows)-1):
 for c in range(n-1):faces.append((r*n+c,r*n+c+1,(r+1)*n+c+1,(r+1)*n+c));slots.append(1 if r==len(rows)-2 or c in [0,n-2] else 0)
mesh=bpy.data.meshes.new('LiaContinuousCapelet');mesh.from_pydata(points,[],faces);mesh.update();cape=bpy.data.objects.new(mesh.name,mesh);bpy.context.scene.collection.objects.link(cape)
for name in ['LiaMatchedSleeve','LiaForearmCuff','LiaCollarLining']:mesh.materials.append(bpy.data.materials[name])
uv=mesh.uv_layers.new(name='UVMap')
for f,slot in zip(mesh.polygons,slots):
 f.material_index=slot
 for i in f.loop_indices:
  v=mesh.loops[i].vertex_index;uv.data[i].uv=(v%n/(n-1),rows[v//n])
bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
bpy.ops.object.select_all(action='DESELECT');cape.select_set(True);bpy.context.view_layer.objects.active=cape
mod=cape.modifiers.new('ClothThickness','SOLIDIFY');mod.thickness=.004;mod.offset=-1;mod.material_offset=2;mod.material_offset_rim=1;bpy.ops.object.modifier_apply(modifier=mod.name)
bm=bmesh.new();bm.from_mesh(cape.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);assert all(f.calc_area()>1e-10 for f in bm.faces);bm.to_mesh(cape.data);bm.free()
objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects);assert triangles<=15000
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_cape_trial.blend';glb=out/'lia_cape_trial.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==sha
report={'source_sha256':sha,'selection_sha256':selection_sha,'removed_faces':sorted(selected),'unselected_faces_verified':len(kept),'maximum_normal_error':error,'normal_calibration':calibration,'sleeves':sleeves,'fit_shoulders':a.fit_shoulders,'cape_triangles':len(cape.data.polygons),'triangles':triangles,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'status':'static candidate; visual and animation gates pending'}
(out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('CAPE_TRIAL',triangles,json.dumps(sleeves))
