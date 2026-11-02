"""Rebuild Lia's damaged coat, belt and single pouch from measured sections."""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--selection',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);sha=hashlib.sha256(a.input.read_bytes()).hexdigest();assert sha=='d657861cc239bc5b1750a43196f0e63f5b5d8af124e694a53b67f7e4cdb3c2b4'
if a.output.exists():raise FileExistsError('Keep earlier candidates')
spec=json.loads(a.selection.read_text());assert spec['source_sha256']==sha;selected=set(spec['faces']);assert len(selected)==7106
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()));body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];m=body.data
protected={o.name:([tuple(v.co) for v in o.data.vertices],[tuple(x.uv) for x in o.data.uv_layers.active.data]) for o in bpy.context.scene.objects if o.type=='MESH' and o!=body}
normals=[v.vector.copy() for v in m.corner_normals];kept={f.index:[(tuple(m.vertices[m.loops[i].vertex_index].co),tuple(m.uv_layers.active.data[i].uv),normals[i].copy()) for i in f.loop_indices] for f in m.polygons if f.index not in selected}
bm=bmesh.new();bm.from_mesh(m);bm.faces.ensure_lookup_table();ids=bm.faces.layers.int.new('CoatSourceFace');nl=bm.loops.layers.float_vector.new('CoatSourceNormal')
for f in bm.faces:
 f[ids]=f.index
 for loop,i in zip(f.loops,m.polygons[f.index].loop_indices):loop[nl]=normals[i]
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in sorted(selected)],context='FACES_ONLY');bm.to_mesh(m);bm.free();m.update()
desired=[v.vector.copy() for v in m.attributes['CoatSourceNormal'].data];m.normals_split_custom_set(desired);normal_result=calibrate(m,desired);m.attributes.remove(m.attributes['CoatSourceNormal'])
max_error=0
for f in m.polygons:
 for li,(co,uv,n) in zip(f.loop_indices,kept[m.attributes['CoatSourceFace'].data[f.index].value]):
  assert (m.vertices[m.loops[li].vertex_index].co-Vector(co)).length<1e-7
  assert (m.uv_layers.active.data[li].uv-Vector(uv)).length<1e-7
  error=(m.corner_normals[li].vector-n).length;max_error=max(max_error,error);assert error<.002
purple=bpy.data.materials['LiaMatchedSleeve'];cream=bpy.data.materials['LiaForearmCuff'];lining=bpy.data.materials['LiaCollarLining']
def material(name,color,metal=0):
 mat=bpy.data.materials.new(name);mat.use_nodes=True;mat.diffuse_color=(*color,1);bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.72;bs.inputs['Metallic'].default_value=metal;return mat
leather=material('LiaCoatLeather',(.17,.085,.045));gold=material('LiaCoatGold',(.65,.39,.10),.25);pants=material('LiaCoatUnderlayer',(.035,.028,.032));lace=material('LiaCoatLaces',(.09,.038,.02))
created=[];checks=[]
def finish(obj,solid=False,smooth=False):
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 if solid:
  mod=obj.modifiers.new('TailThickness','SOLIDIFY');mod.thickness=.004;mod.offset=-1;mod.material_offset=2;mod.material_offset_rim=1;bpy.ops.object.modifier_apply(modifier=mod.name)
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));assert all(e.is_manifold for e in bm.edges),obj.name;assert all(f.calc_area()>1e-10 for f in bm.faces),obj.name
 bm.to_mesh(obj.data);bm.free();obj.data.update()
 for f in obj.data.polygons:f.use_smooth=smooth
 checks.append({'mesh':obj.name,'triangles':len(obj.data.polygons),'closed':True});created.append(obj)
 return obj
def mesh_object(name,points,faces,slots,mats,solid=False,smooth=False):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(points,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.scene.collection.objects.link(o)
 for mat in mats:mesh.materials.append(mat)
 uv=mesh.uv_layers.new(name='UVMap')
 for f,slot in zip(mesh.polygons,slots):
  f.material_index=slot
  # Stable independent polygon UVs; these materials use no image textures.
  for j,i in enumerate(f.loop_indices):uv.data[i].uv=(.5+.45*math.cos(j*2*math.pi/len(f.vertices)),.5+.45*math.sin(j*2*math.pi/len(f.vertices)))
 return finish(o,solid,smooth)
# Continuous shaped bodice, central ivory shirt, narrow piping and inner layer.
degrees=sorted(set([0,20,24,32,45,60,75,90,105,120,135,150,165,180]+[-v for v in [20,24,32,45,60,75,90,105,120,135,150,165]]));angles=[math.radians(v) for v in degrees];n=len(angles)
sections=[(1.05,.155,-.143,.095),(1.13,.15,-.145,.09),(1.17,.14,-.14,.08),(1.22,.13,-.13,.06),(1.29,.115,-.13,.055),(1.37,.13,-.14,.055),(1.44,.145,-.156,.06),(1.49,.14,-.145,.055),(1.535,.105,-.115,.045)]
points=[]
for z,rx,front,back in sections:
 cy=(front+back)/2;ry=(back-front)/2
 for theta in angles:points.append((rx*math.sin(theta),cy-ry*math.cos(theta),z))
faces=[];slots=[]
for row in range(len(sections)-1):
 for col in range(n):
  nxt=(col+1)%n;faces.append((row*n+col,row*n+nxt,(row+1)*n+nxt,(row+1)*n+col))
  midpoint=(degrees[col]+(degrees[nxt] if nxt else degrees[0]+360))/2
  slot=1 if abs(midpoint)<24 else (2 if sections[row][0]<1.17 else 0);slots.append(slot)
faces.extend([tuple(reversed(range(n))),tuple(range((len(sections)-1)*n,len(sections)*n))]);slots.extend([2,1])
mesh_object('LiaTailoredBodice',points,faces,slots,[purple,cream,pants],smooth=True)
# Two continuous side panels: front opening, back vent and pointed cream hem.
cols=[0,.018,.065,.15,.25,.36,.5,.64,.75,.85,.935,.982,1];rows=[0,.15,.32,.52,.72,.94,1]
for sign,label in [(1,'Right'),(-1,'Left')]:
 points=[];faces=[];slots=[]
 for t in rows:
  for u in cols:
   gap_front=.07+(.34-.07)*t;gap_back=.30*max(0,(t-.3)/.7);theta=gap_front+(math.pi-gap_back-gap_front)*u
   hem=.90+.065*math.sin(theta)**2;z=1.21*(1-t)+hem*t
   rx=.145+(.245-.145)*t;front=-.145+(-.20+.145)*t;back=.08+(.18-.08)*t
   points.append((sign*rx*math.sin(theta),(front+back)/2-(back-front)/2*math.cos(theta),z))
 width=len(cols)
 for row in range(len(rows)-1):
  for col in range(width-1):
   face=(row*width+col,(row+1)*width+col,(row+1)*width+col+1,row*width+col+1)
   if sign<0:face=tuple(reversed(face))
   faces.append(face);slots.append(1 if row==len(rows)-2 or col in [0,width-2] else 0)
 mesh_object('LiaCoatTail'+label,points,faces,slots,[purple,cream,lining],solid=True,smooth=True)
# Closed elliptical belt with actual thickness.
count=32;points=[]
for z,rx,ry in [(1.235,.145,.107),(1.17,.172,.133),(1.235,.139,.101),(1.17,.166,.127)]:
 for k in range(count):
  t=k*2*math.pi/count;points.append((rx*math.sin(t),-.035-ry*math.cos(t),z))
faces=[]
for k in range(count):
 j=(k+1)%count;faces.extend([(k,j,count+j,count+k),(2*count+k,3*count+k,3*count+j,2*count+j),(k,2*count+k,2*count+j,j),(count+k,count+j,3*count+j,3*count+k)])
mesh_object('LiaWaistBelt',points,faces,[0]*len(faces),[leather],smooth=True)
def box(name,center,scale,mat,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=center);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 if bevel:
  mod=o.modifiers.new('SoftEdges','BEVEL');mod.width=min(bevel,min(scale)*.24);mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
 # Apply transforms for consistent rig coordinates and geometry assertions.
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 if name.startswith('LiaBuckle'):
  for v in o.data.vertices:v.co.y += .4*(v.co.z-1.204)-.012
 if name=='LiaBeltLoop':
  for v in o.data.vertices:v.co.y += .4*(v.co.z-1.204)-.020
 return finish(o,smooth=False)
# Rectangular buckle frame leaves leather visible through its opening.
for name,center,size in [('Top',(0,-.154,1.232),(.095,.014,.009)),('Bottom',(0,-.154,1.176),(.095,.014,.009)),('Left',(-.043,-.154,1.204),(.009,.014,.056)),('Right',(.043,-.154,1.204),(.009,.014,.056)),('Tongue',(-.013,-.165,1.204),(.043,.008,.006))]:box('LiaBuckle'+name,center,size,gold,.002)
box('LiaSinglePouch',(.18,-.065,1.12),(.085,.075,.14),leather,.009)
box('LiaPouchFlap',(.18,-.106,1.16),(.087,.012,.055),leather,.006)
box('LiaPouchClasp',(.18,-.116,1.145),(.022,.008,.013),gold,.002)
for x in [-.085,.085]:box('LiaBeltLoop', (x,-.122,1.202),(.014,.01,.078),leather,.002)
# Gold cape fasteners and three visible crossed leather laces.
for x in [-.053,.053]:
 o=box('LiaCapeFastener',(x,-.133,1.525),(.027,.013,.027),gold,.002)
 # diamond outline, rotated in the frontal plane about its center
 for v in o.data.vertices:
  dx=v.co.x-x;dz=v.co.z-1.525;v.co.x=x+(dx-dz)/math.sqrt(2);v.co.z=1.525+(dx+dz)/math.sqrt(2)
def cord(name,start,end):
 start,end=Vector(start),Vector(end)
 for point in [start,end]:
  ok,hit,_,_=bpy.data.objects['LiaTailoredBodice'].ray_cast(Vector((point.x,-2,point.z)),Vector((0,1,0)));assert ok;point.y=hit.y-.0035
 delta=end-start
 bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.003,depth=delta.length,location=(start+end)/2);o=bpy.context.object;o.name=name;o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.data.materials.append(lace);finish(o)
for row in range(3):
 high=1.518-row*.018;low=high-.016;half=.040-row*.008
 # Face lies on the measured front profile, with a small visible clearance.
 y=-.123-(1.53-high)*.75
 cord('LiaLaceA',(-half,y,high),(half-.006,y-.010,low));cord('LiaLaceB',(half,y-.003,high),(-half+.006,y-.013,low))
# Consolidate only the new outfit: shared materials and named vertex regions.
bpy.ops.object.select_all(action='DESELECT')
for obj in created:
 group=obj.vertex_groups.new(name=obj.name);group.add(list(range(len(obj.data.vertices))),1,'REPLACE');obj.select_set(True)
bpy.context.view_layer.objects.active=created[0];bpy.ops.object.join();bpy.context.object.name='LiaTailoredOutfit'
# Stabilize the last-bit UV noise produced by bevel interpolation on solid materials.
for corner in bpy.context.object.data.uv_layers.active.data:corner.uv=tuple(round(float(c),6) for c in corner.uv)
# All pre-existing mesh objects except selected body faces must be untouched.
for name,(coords,uv) in protected.items():
 old=bpy.data.objects[name].data;assert [tuple(v.co) for v in old.vertices]==coords;assert [tuple(d.uv) for d in old.uv_layers.active.data]==uv
objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in objects);assert triangles<=15000
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_tailored_coat.blend';glb=out/'lia_tailored_coat.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==sha
report={'source_sha256':sha,'selection_sha256':hashlib.sha256(a.selection.read_bytes()).hexdigest(),'removed_faces':len(selected),'retained_faces':len(kept),'retained_coordinate_uv_unchanged':True,'maximum_retained_normal_error':max_error,'normal_calibration':normal_result,'protected_meshes':list(protected),'new_meshes':checks,'triangles':triangles,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'rigged':False,'visual_gate':'PENDING','formal_integrated':False}
(out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('COAT_RESULT',json.dumps(report))