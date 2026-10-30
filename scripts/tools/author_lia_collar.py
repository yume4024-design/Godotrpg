"""Re-author Lia's inspected collar faces in a separate static candidate."""
import argparse,hashlib,json,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--selection',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--fit-base',action='store_true')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert sha=='8525d65ff7c88fb8357de723598a551e6de9b94ae3644df403fcb85bed045e2b'
selection=json.loads(a.selection.read_text(encoding='utf-8'));assert selection['source_sha256']==sha
assert hashlib.sha256(a.selection.read_bytes()).hexdigest() in ['e0ecb9785ef76a2142bdb313f9401eee8bdcefe8fca8742639e477e227655e94','72976361d94fbade99bd9be5a624e091410e91034fe23197d844d04300f4cc4c']
assert len(selection['faces']) in [238,265] and len(set(selection['faces']))==len(selection['faces'])
if a.output.exists():raise FileExistsError('Preserve earlier candidates')
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];m=body.data
assert len(m.polygons)==11028
cut=set(selection['faces']);normals=[v.vector.copy() for v in m.corner_normals];uv=m.uv_layers.active
kept={f.index:[(tuple(m.vertices[m.loops[i].vertex_index].co),tuple(uv.data[i].uv),tuple(normals[i])) for i in f.loop_indices] for f in m.polygons if f.index not in cut}
bm=bmesh.new();bm.from_mesh(m);bm.faces.ensure_lookup_table();ids=bm.faces.layers.int.new('CollarSourceFace');nl=bm.loops.layers.float_vector.new('CollarSourceNormal')
for f in bm.faces:
 f[ids]=f.index
 for loop,i in zip(f.loops,m.polygons[f.index].loop_indices):loop[nl]=normals[i]
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in sorted(cut)],context='FACES_ONLY')
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(m);bm.free();m.update()
desired=[v.vector.copy() for v in m.attributes['CollarSourceNormal'].data];m.normals_split_custom_set(desired);calibration=calibrate(m,desired);m.attributes.remove(m.attributes['CollarSourceNormal'])
max_error=0.
for f in m.polygons:
 old=kept[m.attributes['CollarSourceFace'].data[f.index].value]
 assert len(old)==len(f.loop_indices)
 for i,(co,uvco,n) in zip(f.loop_indices,old):
  assert (m.vertices[m.loops[i].vertex_index].co-Vector(co)).length<1e-7
  assert (m.uv_layers.active.data[i].uv-Vector(uvco)).length<1e-7
  err=(m.corner_normals[i].vector-Vector(n)).length;max_error=max(max_error,err);assert err<.002
# Preserve the established design: open purple stand collar, cream piping.
cloth=bpy.data.materials['LiaMatchedSleeve'];trim=bpy.data.materials['LiaForearmCuff']
liner=cloth.copy();liner.name='LiaCollarLining';color=tuple(cloth.diffuse_color[i]*.70 for i in range(3))+(1,);liner.diffuse_color=color;liner.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
controls=[((-.060,-.120,1.502),(-.055,-.125,1.495)),((-.085,-.100,1.550),(-.095,-.110,1.505)),((-.115,-.060,1.605),(-.125,-.060,1.512)),((-.100,0,1.620),(-.130,0,1.520)),((-.075,.060,1.625),(-.115,.070,1.520)),((0,.080,1.625),(0,.110,1.520))]
controls+= [((-top[0],top[1],top[2]),(-base[0],base[1],base[2])) for top,base in reversed(controls[:-1])]
base_fit=[]
if a.fit_base:
 support=[list(f.vertices) for f in m.polygons if 1.45<f.center.z<1.515 and abs(f.center.x)<.19 and -.16<f.center.y<.15]
 assert len(support)>10
 tree=BVHTree.FromPolygons([v.co for v in m.vertices],support,all_triangles=False)
 adjusted=[]
 for i,(top,base) in enumerate(controls):
  if i in [0,len(controls)-1]:adjusted.append((top,base));continue
  point,normal,index,distance=tree.find_nearest(Vector(base),.045)
  if point is None:raise ValueError('No body surface near collar base')
  if point.z>1.535 or point.z<1.45:raise ValueError('Collar anchor outside shoulder band')
  base_fit.append({'control':i,'original':base,'anchored':tuple(point),'distance_m':distance})
  adjusted.append((top,tuple(point)))
 controls=adjusted
verts=[];faces=[];slots=[]
for top,base in controls:
 top=Vector(top);base=Vector(base);direction=Vector((top.x,top.y+.015,0)).normalized();inner_top=top-direction*.004;inner_base=base-direction*.004
 fraction=min(.45,.008/(top-base).length)
 for v in [base,top.lerp(base,fraction),top,inner_top,inner_top.lerp(inner_base,fraction),inner_base]:verts.append(tuple(v))
for r in range(len(controls)-1):
 for k in range(6):
  faces.append((r*6+k,r*6+(k+1)%6,(r+1)*6+(k+1)%6,(r+1)*6+k));slots.append([0,1,1,1,2,2][k])
# Center fans avoid zero-area triangles when the exporter tessellates
# the collinear piping vertices on a thin six-sided end cap.
for ring in [list(reversed(range(6))),[(len(controls)-1)*6+k for k in range(6)]]:
 center=sum((Vector(verts[i]) for i in ring),Vector())/len(ring);ci=len(verts);verts.append(tuple(center))
 for k in range(len(ring)):faces.append((ring[k],ring[(k+1)%len(ring)],ci));slots.append(1)
data=bpy.data.meshes.new('LiaAuthoredCollar');data.from_pydata(verts,[],faces);data.update();collar=bpy.data.objects.new(data.name,data);bpy.context.scene.collection.objects.link(collar)
for mat in [cloth,trim,liner]:data.materials.append(mat)
layer=data.uv_layers.new(name='UVMap')
for f,slot in zip(data.polygons,slots):
 f.material_index=slot
 for i in f.loop_indices:
  v=data.vertices[data.loops[i].vertex_index].co;layer.data[i].uv=(.5+v.x*3,(v.z-1.49)*6)
bm=bmesh.new();bm.from_mesh(data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);assert all(f.calc_area()>1e-10 for f in bm.faces);bm.to_mesh(data);bm.free();data.update()
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(meshes)==5
triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes);assert triangles<=15000
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==sha
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_collar_trial.blend';glb=out/'lia_collar_trial.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
receipt={'source_sha256':sha,'selection_sha256':hashlib.sha256(a.selection.read_bytes()).hexdigest(),'removed_face_ids':sorted(cut),'unselected_faces_verified':len(kept),'maximum_normal_error':max_error,'calibration':calibration,'triangles':triangles,'collar_triangles':sum(len(f.vertices)-2 for f in data.polygons),'base_fit':base_fit,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'status':'static independent collar candidate; not rigged or visually accepted'}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print('COLLAR_TRIAL',json.dumps(receipt))
