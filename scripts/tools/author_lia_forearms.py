"""Author continuous cuff, forearm, bracer and hand surfaces in a static copy.

Cuts a measured local cuff/forearm region and extends the existing hand root
into a single connected surface. Visual/rig approval is not implied.
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
 wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();plane=wrist+down*(-.255)
 across=Vector((sign*.877268,0,.48)).normalized()
 fs=[f for f in bm.faces if sign*f.calc_center_median().x>.18 and .85<f.calc_center_median().z<1.4 and -.05<f.calc_center_median().y<.17 and abs((f.calc_center_median()-wrist).dot(across))<.18 and max((v.co-plane).dot(down) for v in f.verts)>-.00001]
 counts[str(sign)]=len(fs);selected.update(f[ids] for f in fs)
 # Isolate the cut region so bisect clear_outer cannot delete adjacent source faces.
 region=set(fs);boundary=[e for e in bm.edges if any(f in region for f in e.link_faces) and any(f not in region for f in e.link_faces)]
 if boundary:bmesh.ops.split_edges(bm,edges=boundary)
 bm.verts.index_update();bm.edges.index_update();bm.faces.index_update()
 es={e for f in fs for e in f.edges};vs={v for f in fs for v in f.verts}
 result=bmesh.ops.bisect_plane(bm,geom=sorted(vs,key=lambda v:v.index)+sorted(es,key=lambda e:e.index)+sorted(fs,key=lambda f:f.index),dist=.000001,plane_co=plane,plane_no=down,clear_outer=True)
 cut_counts[str(sign)]=len(result['geom_cut'])
assert all(100<n<700 for n in counts.values()),counts
assert all(n>10 for n in cut_counts.values()),cut_counts
original_unselected=set(before)-selected
present={f[ids] for f in bm.faces if f[ids] in original_unselected}
assert present==original_unselected,'Unexpected changes outside local selection'
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(mesh);bm.free();mesh.update()
for f in mesh.polygons:
 if mesh.attributes['BracerSourceFace'].data[f.index].value in selected:f.use_smooth=False
mesh.update()
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
# Rebuild from the existing hand root: shared vertices, not overlapping parts.
def material(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1)
 node=m.node_tree.nodes.get('Principled BSDF');node.inputs['Base Color'].default_value=m.diffuse_color;node.inputs['Roughness'].default_value=.8
 return m
leather=material('LiaForearmLeather',(.12,.065,.043))
trim=material('LiaForearmTrim',(.34,.22,.10))
cuff=material('LiaForearmCuff',(.72,.65,.52))
checks=[]
for sign,label in [(-1,'Right'),(1,'Left')]:
 hand=bpy.data.objects['LiaHand'+label];data=hand.data
 wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();across=Vector((sign*.877268,0,.48)).normalized();depth=Vector((0,1,0))
 points=[tuple(v.co) for v in data.vertices]
 # Original hand generator stores five pairs along the wrist root.
 root=[0,2,4,6,8,9,7,5,3,1]
 assert all(abs((Vector(points[i])-wrist).dot(down)+.026)<1e-6 for i in root)
 removed=[f for f in data.polygons if all(i in root for i in f.vertices)]
 assert len(removed)==4
 faces=[tuple(f.vertices) for f in data.polygons if f not in removed]
 mats=[0]*len(faces)
 # Slightly round the existing palm without changing the finger tips.
 for i in range(50):
  r=i//10;k=(i%10)//2;side=-1 if i%2==0 else 1
  v=Vector(points[i]);y=(v-wrist).dot(depth)
  factor=.60+.40*math.sqrt(max(0,1-((k-2)/2)**2))
  points[i]=tuple(v+depth*(y*(factor-1)))
 previous=root
 # Rows proceed upward from wrist. A small skin interval separates bracer/cuff.
 rows=[(-.034,-.002,0,.024,.022,2),(-.043,-.003,0,.025,.023,2),
       (-.050,-.004,-.001,.026,.024,1),(-.090,-.012,-.002,.032,.030,1),
       (-.135,-.019,-.003,.037,.033,1),(-.162,-.020,-.004,.038,.035,1),
       (-.174,-.019,-.004,.034,.033,0),(-.188,-.018,-.005,.035,.034,0),
       (-.195,-.018,-.006,.049,.052,3),(-.238,-.019,-.008,.050,.053,3),
       (-.257,-.020,-.010,.042,.054,3)]
 for distance,offset,yoff,width,thickness,slot in rows:
  pair=[]
  for k in range(5):
   u=(k-2)/2;radius=(.60+.40*math.sqrt(max(0,1-u*u)))
   for side in [-1,1]:
    pair.append(len(points));points.append(tuple(wrist+down*distance+across*(offset+width*u)+depth*(yoff+side*thickness*radius)))
  ring=[pair[i] for i in root]
  for k in range(10):faces.append((previous[k],previous[(k+1)%10],ring[(k+1)%10],ring[k]));mats.append(slot)
  previous=ring
 faces.append(tuple(reversed(previous)));mats.append(3)
 new=bpy.data.meshes.new('LiaForearmHand'+label);new.from_pydata(points,[],faces);new.update()
 for m in [bpy.data.materials['LiaAuthoredSkin'],leather,trim,cuff]:new.materials.append(m)
 uvnew=new.uv_layers.new(name='UVMap')
 for f,slot in zip(new.polygons,mats):
  f.material_index=slot;f.use_smooth=slot==0
  for i in f.loop_indices:
   v=new.vertices[new.loops[i].vertex_index].co
   uvnew.data[i].uv=(.5+(v-wrist).dot(across)*5,.5+(v-wrist).dot(down)*2)
 check=bmesh.new();check.from_mesh(new);bmesh.ops.recalc_face_normals(check,faces=list(check.faces))
 assert all(e.is_manifold for e in check.edges),'Disconnected forearm/hand'
 assert all(f.calc_area()>1e-10 for f in check.faces),'Degenerate surface'
 # Flood every face, not merely checking manifold edge count.
 visited=set();pending=[next(iter(check.faces))]
 while pending:
  f=pending.pop()
  if f in visited:continue
  visited.add(f);pending.extend(other for e in f.edges for other in e.link_faces if other not in visited)
 assert len(visited)==len(check.faces),'Separate surface components'
 checks.append({'side':label,'faces':len(check.faces),'single_connected_component':True,'nonmanifold_edges':0,'degenerate_faces':0})
 check.to_mesh(new);check.free();new.update();hand.data=new
objects=[o for o in scene.objects if o.type=='MESH'];assert len(objects)==4
triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects);assert triangles<=15000
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==source_sha
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_forearm_trial.blend';glb=out/'lia_forearm_trial.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
receipt={'source_sha256':source_sha,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'selected_faces':counts,'cut_geometry_elements':cut_counts,'unselected_faces_verified':len(original_unselected),'maximum_normal_error':max_error,'normal_calibration':calibration,'triangles':triangles,'forearm_hand_checks':checks,'status':'static manual retopology trial; forearm and hand are connected, proximal cuff is separate from original sleeve; no rig'}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print('BRACER_TRIAL',json.dumps(receipt),flush=True)
