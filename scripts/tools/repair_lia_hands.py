"""Experimental, separate five-finger hands for Lia's static skirt candidate.

Source is hash-locked; hands replace a local cut only in a new output directory.
This is a static visual trial, not an animated or production-ready character.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate

p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--continuous',action='store_true');p.add_argument('--bands',action='store_true');p.add_argument('--fit-wrist',action='store_true');p.add_argument('--source-receipt',type=Path)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
if sha!='b05ac1dd01f0347aa7ab1f73a96f9af73b6ca939349184d5463c20d282c1a7f7':
 if a.source_receipt is None:raise ValueError('Unexpected candidate blend; provide matching source receipt')
 prior=json.loads(a.source_receipt.read_text(encoding='utf-8'))
 if prior.get('blend_sha256')!=sha or prior.get('source_sha256')!='1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e' or prior.get('method')!='thorough' or len(prior.get('removed_face_ids',[]))!=280:raise ValueError('Source receipt does not describe the expected skirt repair')
if (a.bands or a.fit_wrist) and not a.continuous:raise ValueError('Bands and wrist fitting require continuous hand')
if a.output.exists():raise FileExistsError('Use a new output directory')
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene;body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];neck=bpy.data.objects['LiaContinuousNeckClavicle'];mesh=body.data
assert len(mesh.polygons)==11798 and not any(o.type=='ARMATURE' for o in scene.objects)
assert len([o for o in scene.objects if o.type=='MESH'])==2
# Cut only the two distal hand areas, in the plane perpendicular to the arm.
cut=[]; side_counts={}
for sign in [-1,1]:
 wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();side=[]
 for f in mesh.polygons:
  c=f.center
  if sign*c.x<.365 or not (.80<c.z<1.13):continue
  if max((mesh.vertices[i].co-wrist).dot(down) for i in f.vertices)>.012:side.append(f.index)
 side_counts[str(sign)]=len(side);cut.extend(side)
assert side_counts=={'-1':172,'1':82} and len(set(cut))==254,side_counts
normals=[n.vector.copy() for n in mesh.corner_normals];uv=mesh.uv_layers.active
kept={f.index:[(tuple(mesh.vertices[mesh.loops[i].vertex_index].co),tuple(uv.data[i].uv),tuple(normals[i])) for i in f.loop_indices] for f in mesh.polygons if f.index not in cut}
bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table();ids=bm.faces.layers.int.new('HandSourceFace');nl=bm.loops.layers.float_vector.new('HandSourceNormal')
for f in bm.faces:
 f[ids]=f.index
 for loop,i in zip(f.loops,mesh.polygons[f.index].loop_indices):loop[nl]=normals[i]
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in cut],context='FACES_ONLY')
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(mesh);bm.free();mesh.update()
desired=[x.vector.copy() for x in mesh.attributes['HandSourceNormal'].data];mesh.normals_split_custom_set(desired)
calibration=calibrate(mesh,desired);mesh.attributes.remove(mesh.attributes['HandSourceNormal']);max_error=0
for f in mesh.polygons:
 source=mesh.attributes['HandSourceFace'].data[f.index].value
 for loop,(point,coord,normal) in zip(f.loop_indices,kept[source]):
  assert (mesh.vertices[mesh.loops[loop].vertex_index].co-Vector(point)).length<1e-7
  assert (mesh.uv_layers.active.data[loop].uv-Vector(coord)).length<1e-7
  err=(mesh.corner_normals[loop].vector-Vector(normal)).length;max_error=max(max_error,err);assert err<.002
assert len(mesh.polygons)==11544
# Reuse the previously authored skin shade. Discrete fingers are deliberately
# kept editable; overlapping closed parts do not imply a welded rigged hand.
skin=bpy.data.materials['LiaAuthoredSkin'];hands=[]
for sign,label in [(-1,'Right'),(1,'Left')]:
 wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();across=Vector((sign*.877268,0,.48)).normalized();depth=Vector((0,1,0))
 vertices=[];faces=[]
 if not a.continuous:
  vertices=[];faces=[]
  def tube(centers,widths,thicknesses,segments=8):
   base=len(vertices)
   for c,w,t in zip(centers,widths,thicknesses):
    for k in range(segments):
     angle=math.tau*k/segments;vertices.append(tuple(c+across*w*math.cos(angle)+depth*t*math.sin(angle)))
   for row in range(len(centers)-1):
    for k in range(segments):
     i=base+row*segments+k;j=base+row*segments+(k+1)%segments;faces.append((i,j,j+segments,i+segments))
   faces.append(tuple(base+k for k in reversed(range(segments))))
   faces.append(tuple(base+(len(centers)-1)*segments+k for k in range(segments)))
  tube([wrist-down*.026,wrist+down*.025,wrist+down*.084], [.022,.027,.033],[.019,.019,.015])
  for offset,length in [(-.0255,.069),(-.0085,.078),(.0085,.072),(.0255,.061)]:
   start=wrist+down*.079+across*offset;direction=(down+across*(offset/.0255)*.045).normalized()
   tube([start,start+direction*(length*.52),start+direction*length],[.0085,.0075,.005],[.009,.008,.006])
  thumb_start=wrist+down*.033-across*.022
  thumb_direction=(down*.62-across*.78).normalized()
  tube([thumb_start,thumb_start+thumb_direction*.035,thumb_start+thumb_direction*.068],[.010,.009,.006],[.011,.009,.007])
 else:
  # One connected palm surface, with four digit openings and a thumb opening.
  # The first finger rings share their boundary vertices with the palm.
  rows=[(-.026,.022,.019),(.016,.026,.019),(.045,.030,.018),(.075,.032,.016),(.084,.033,.015)]
  grid=[]
  for row_index,(distance,width,thickness) in enumerate(rows):
   row=[]
   # The first ring matches the measured bracer cross-section at t=-.026m.
   # Subsequent rings gradually return to the original palm dimensions.
   center_offset = -.015 if a.fit_wrist and row_index == 0 else 0.0
   if a.fit_wrist and row_index == 0:
    width=.032;thickness=.035
   for k in range(5):
    pair=[]
    for side in [-1,1]:
     pair.append(len(vertices));vertices.append(tuple(wrist+down*distance+across*(center_offset+width*(k/2-1))+depth*thickness*side))
    row.append(pair)
   grid.append(row)
  for r in range(len(rows)-1):
   for k in range(4):
    faces.append((grid[r][k][0],grid[r][k+1][0],grid[r+1][k+1][0],grid[r+1][k][0]))
    faces.append((grid[r+1][k][1],grid[r+1][k+1][1],grid[r][k+1][1],grid[r][k][1]))
   faces.append((grid[r][4][0],grid[r][4][1],grid[r+1][4][1],grid[r+1][4][0]))
   if r!=1:faces.append((grid[r+1][0][0],grid[r+1][0][1],grid[r][0][1],grid[r][0][0]))
  for k in range(4):faces.append((grid[0][k][1],grid[0][k+1][1],grid[0][k+1][0],grid[0][k][0]))
  def extend_quad(start, centers, axes, radii):
   previous=start
   for center,axis,(width,thickness) in zip(centers,axes,radii):
    ring=[]
    for u,v in [(-1,-1),(1,-1),(1,1),(-1,1)]:
     ring.append(len(vertices));vertices.append(tuple(center+axis*width*u+depth*thickness*v))
    for k in range(4):faces.append((previous[k],previous[(k+1)%4],ring[(k+1)%4],ring[k]))
    previous=ring
   faces.append(tuple(previous))
  for k,length in enumerate([.069,.078,.072,.061]):
   offset=(k-1.5)*.0165
   start=[grid[-1][k][0],grid[-1][k+1][0],grid[-1][k+1][1],grid[-1][k][1]]
   base=wrist+down*.084+across*offset
   direction=(down+across*(offset/.025)*.05).normalized()
   centers=[base+direction*length*f for f in [.40,.78,.96,1.0]]
   extend_quad(start,centers,[across]*4,[(.008,.012),(.0075,.010),(.006,.008),(.003,.004)])
  start=[grid[1][0][0],grid[2][0][0],grid[2][0][1],grid[1][0][1]]
  base=sum((Vector(vertices[i]) for i in start),Vector())*.25
  direction=(down*.62-across*.78).normalized();axis=(down*.78+across*.62).normalized()
  centers=[base+direction*d for d in [.018,.038,.055,.061]]
  extend_quad(start,centers,[axis]*4,[(.012,.014),(.010,.012),(.007,.009),(.003,.004)])
 data=bpy.data.meshes.new('LiaHand'+label);data.from_pydata(vertices,[],faces);data.update();obj=bpy.data.objects.new('LiaHand'+label,data);scene.collection.objects.link(obj);data.materials.append(skin)
 layer=data.uv_layers.new(name='UVMap')
 for poly in data.polygons:
  poly.use_smooth=len(poly.vertices)==4
  for loop in poly.loop_indices:
   v=data.vertices[data.loops[loop].vertex_index].co;layer.data[loop].uv=(.5+(v-wrist).dot(across)*5,.5+(v-wrist).dot(down)*4)
 bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free();data.update()
 if a.continuous:
  check=bmesh.new();check.from_mesh(data)
  if not all(e.is_manifold for e in check.edges):raise ValueError('Hand surface is not closed')
  check.free()
 hands.append(obj)
bands=[]
if a.bands:
 trim=bpy.data.materials.new('LiaWristTrim');trim.use_nodes=True
 trim.diffuse_color=(.30,.18,.09,1);shader=trim.node_tree.nodes.get('Principled BSDF');shader.inputs['Base Color'].default_value=trim.diffuse_color;shader.inputs['Roughness'].default_value=.8
 for sign,label in [(-1,'Right'),(1,'Left')]:
  wrist=Vector((sign*.42,.06,1.06));down=Vector((sign*.48,0,-.877268)).normalized();across=Vector((sign*.877268,0,.48)).normalized();depth=Vector((0,1,0))
  points=[];faces=[];n=12
  for distance in [-.04,.012]:
   for k in range(n):
    t=math.tau*k/n;points.append(tuple(wrist+down*distance+across*.037*math.cos(t)+depth*.046*math.sin(t)))
  for k in range(n):faces.append((k,(k+1)%n,(k+1)%n+n,k+n))
  faces.append(tuple(reversed(range(n))));faces.append(tuple(range(n,n*2)))
  data=bpy.data.meshes.new('LiaWristTrim'+label);data.from_pydata(points,[],faces);data.update()
  obj=bpy.data.objects.new('LiaWristTrim'+label,data);scene.collection.objects.link(obj);data.materials.append(trim);uv=data.uv_layers.new(name='UVMap')
  for loop in data.loops:
   point=data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(.5+(point-wrist).dot(across)*5,.5+(point-wrist).dot(down)*5)
  bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free();data.update();bands.append(obj)
objects=[body,neck]+hands+bands
triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects)
assert triangles<=15000,triangles
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==sha
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_hands_trial.blend';glb=out/'lia_hands_trial.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
receipt={'source_sha256':sha,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'removed_face_ids':cut,'cut_face_counts':side_counts,'remaining_faces_verified':len(kept),'maximum_normal_error':max_error,'calibration':calibration,'triangles':triangles,'hand_geometry':('two closed connected palm-and-five-finger meshes' if a.continuous else 'two separate editable meshes; palm and five overlapping fingers per hand'),'bands_added':a.bands,'wrist_fitted_to_measured_section':a.fit_wrist,'status':'static trial; no weld, animation or production acceptance'}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print('LIA_HAND_TRIAL',json.dumps({k:receipt[k] for k in ['cut_face_counts','remaining_faces_verified','maximum_normal_error','triangles','status']}),flush=True)
