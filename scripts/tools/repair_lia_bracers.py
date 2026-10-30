"""Rebuild only Lia's two damaged distal bracer sections in a static copy.

Bisects the existing damaged section and constructs a tapered leather surface
using measured cross-sections. Visual/rig approval is not implied.
"""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--source-receipt',type=Path)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);source_sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
if source_sha!='e8ad4df994e4eb63daf6068a5a9a331a043c1c26d6ba9cd8b07bc9af2101a19a':
 if a.source_receipt is None:raise ValueError('Unexpected blend; provide matching hand-generation receipt')
 prior=json.loads(a.source_receipt.read_text(encoding='utf-8'))
 if prior.get('blend_sha256')!=source_sha or prior.get('glb_sha256')!='5bc7dc7106a698c6312c66a6f26cd042eb4c54dd3ff1bc787c7b3d998c6f3568' or prior.get('hand_geometry')!='two closed connected palm-and-five-finger meshes':raise ValueError('Source receipt does not match the expected hand candidate')
if a.output.exists():raise FileExistsError('Output must be new')
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()));scene=bpy.context.scene
body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];mesh=body.data
assert len(mesh.polygons)==11544 and not any(o.type=='ARMATURE' for o in scene.objects)
normals=[n.vector.copy() for n in mesh.corner_normals];uv=mesh.uv_layers.active
before={f.index:[(tuple(mesh.vertices[mesh.loops[i].vertex_index].co),tuple(uv.data[i].uv),tuple(normals[i])) for i in f.loop_indices] for f in mesh.polygons}
bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table();ids=bm.faces.layers.int.new('BracerSourceFace');nl=bm.loops.layers.float_vector.new('BracerSourceNormal')
for f in bm.faces:
 f[ids]=f.index
 for loop,i in zip(f.loops,mesh.polygons[f.index].loop_indices):loop[nl]=normals[i]
selected=set();counts={};cut_counts={}
for sign in [-1,1]:
 wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();plane=wrist+down*(-.06)
 fs=[f for f in bm.faces if sign*f.calc_center_median().x>.33 and .85<f.calc_center_median().z<1.2 and max((v.co-plane).dot(down) for v in f.verts)>-.00001]
 counts[str(sign)]=len(fs);selected.update(f[ids] for f in fs)
 es={e for f in fs for e in f.edges};vs={v for f in fs for v in f.verts}
 result=bmesh.ops.bisect_plane(bm,geom=list(vs)+list(es)+fs,dist=.000001,plane_co=plane,plane_no=down,clear_outer=True)
 cut_counts[str(sign)]=len(result['geom_cut'])
assert counts=={'-1':45,'1':40} and cut_counts=={'-1':58,'1':63},(counts,cut_counts)
original_unselected=set(before)-selected
present={f[ids] for f in bm.faces if f[ids] in original_unselected}
assert present==original_unselected,'Unexpected changes outside local selection'
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(mesh);bm.free();mesh.update()
desired=[x.vector.copy() for x in mesh.attributes['BracerSourceNormal'].data]
# Some newly cut corners can lack interpolated normals; fall back only there.
for f in mesh.polygons:
 for i in f.loop_indices:
  if mesh.attributes['BracerSourceFace'].data[f.index].value in selected:
   desired[i]=f.normal.copy()
  elif desired[i].length<.5:
   raise ValueError('Undefined normal outside local cut')
mesh.normals_split_custom_set(desired)
errors=[(i,(n.vector-desired[i]).length) for i,n in enumerate(mesh.corner_normals) if (n.vector-desired[i]).length>.002]
print('NORMAL_MISMATCHES',len(errors),errors[:8],flush=True)
calibration=calibrate(mesh,desired);mesh.attributes.remove(mesh.attributes['BracerSourceNormal'])
max_error=0
for f in mesh.polygons:
 fid=mesh.attributes['BracerSourceFace'].data[f.index].value
 if fid not in original_unselected:continue
 expected=before[fid];assert len(f.loop_indices)==len(expected)
 for loop,(point,coord,normal) in zip(f.loop_indices,expected):
  assert (mesh.vertices[mesh.loops[loop].vertex_index].co-Vector(point)).length<1e-7
  assert (mesh.uv_layers.active.data[loop].uv-Vector(coord)).length<1e-7
  err=(mesh.corner_normals[loop].vector-Vector(normal)).length;max_error=max(max_error,err);assert err<.002
# Median texture swatches from the two actual bracers: encoded RGB ~(.327,.213,.199).
def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
leather=bpy.data.materials.new('LiaBracerRepairLeather');leather.use_nodes=True
leather.diffuse_color=tuple(linear(v) for v in (.327,.213,.199))+(1,)
shader=leather.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=leather.diffuse_color;shader.inputs['Roughness'].default_value=.85
bracers=[]
for sign,label in [(-1,'Right'),(1,'Left')]:
 wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();across=Vector((sign*.877268,0,.48)).normalized();depth=Vector((0,1,0))
 # From the observed outer bracer section to a narrow end above the hand.
 rows=[(-.063,-.016,-.003,.035,.038),(-.042,-.013,-.003,.033,.034),(-.020,-.007,-.001,.028,.027),(-.003,-.002,0,.024,.021)]
 n=16;points=[];faces=[]
 for distance,offset,yoff,width,thickness in rows:
  center=wrist+down*distance+across*offset+depth*yoff
  for k in range(n):
   angle=math.tau*k/n;points.append(tuple(center+across*width*math.cos(angle)+depth*thickness*math.sin(angle)))
 for r in range(len(rows)-1):
  for k in range(n):
   i=r*n+k;j=r*n+(k+1)%n;faces.append((i,j,j+n,i+n))
 faces.append(tuple(reversed(range(n))));faces.append(tuple(range((len(rows)-1)*n,len(rows)*n)))
 data=bpy.data.meshes.new('LiaBracerRepair'+label);data.from_pydata(points,[],faces);data.update();obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);data.materials.append(leather)
 layer=data.uv_layers.new(name='UVMap')
 for loop in data.loops:
  v=data.vertices[loop.vertex_index].co;layer.data[loop.index].uv=(.5+(v-wrist).dot(across)*5,.5+(v-wrist).dot(down)*4)
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges);bm.to_mesh(data);bm.free();data.update();bracers.append(obj)
objects=[o for o in scene.objects if o.type=='MESH'];assert len(objects)==6
triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects);assert triangles<=15000
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==source_sha
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_bracer_trial.blend';glb=out/'lia_bracer_trial.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
receipt={'source_sha256':source_sha,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'selected_faces':counts,'cut_geometry_elements':cut_counts,'unselected_faces_verified':len(original_unselected),'maximum_normal_error':max_error,'normal_calibration':calibration,'triangles':triangles,'leather_encoded_rgb':[.327,.213,.199],'status':'static trial only; sleeve parts overlap hand and are not welded or rigged'}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print('BRACER_TRIAL',json.dumps(receipt),flush=True)
