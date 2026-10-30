"""Clip measured old cloth intersections against the authored collar inner wall."""
import argparse,hashlib,json,sys
from pathlib import Path
import bpy,bmesh
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert sha=='0409ee2d7c447df2717e71a506d908ccd5cdab5193fa0e1b11459ba7fef50d9b'
if a.output.exists():raise FileExistsError('Preserve previous candidates')
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];m=body.data; collar=bpy.data.objects['LiaAuthoredCollar'].data
selected={1714,1715,1717,1960,2160,2161,2162,2163,2164,2504,3257,3476}
planes=[]
for face_id in [16,94]:
 c=[collar.vertices[i].co.copy() for i in collar.polygons[face_id].vertices];normal=(c[1]-c[0]).cross(c[2]-c[0]).normalized()
 if normal.x<0:normal=-normal
 # Cut 1 mm into each measured wall segment; preserve the shoulder side.
 planes.append((c[0]-normal*.001,normal))
bm=bmesh.new();bm.from_mesh(m);bm.faces.ensure_lookup_table();ids=bm.faces.layers.int.get('CollarSourceFace');uv=bm.loops.layers.uv.active;nl=bm.loops.layers.float_vector.new('ClipNormal')
original={}
for f in bm.faces:
 for l,i in zip(f.loops,m.polygons[f.index].loop_indices):l[nl]=m.corner_normals[i].vector
 if f[ids] not in selected:original[f[ids]]=[(tuple(l.vert.co),tuple(l[uv].uv),tuple(l[nl])) for l in f.loops]
changes=[];edge_cuts={}
for f in list(bm.faces):
 if f[ids] not in selected:continue
 source=f[ids];material=f.material_index;smooth=f.smooth
 poly=[(l.vert,l.vert.co.copy(),l[uv].uv.copy(),l[nl].copy()) for l in f.loops];before=len(poly);changed=False
 for plane_id,(origin,normal) in enumerate(planes):
  out=[]
  for current,following in zip(poly,poly[1:]+poly[:1]):
   d0=(current[1]-origin).dot(normal);d1=(following[1]-origin).dot(normal)
   if d0<=0:out.append(current)
   else:changed=True
   if (d0<=0)!=(d1<=0):
    t=d0/(d0-d1);co=current[1].lerp(following[1],t);key=(plane_id,frozenset((current[0],following[0])))
    if key not in edge_cuts:edge_cuts[key]=bm.verts.new(co)
    out.append((edge_cuts[key],co,current[2].lerp(following[2],t),current[3].lerp(following[3],t).normalized()))
  poly=out
 if not changed:continue
 changes.append({'source_face':source,'before':before,'after':len(poly)})
 bm.faces.remove(f)
 if len(poly)>=3:
  face=bm.faces.new([v[0] for v in poly]);face[ids]=source;face.material_index=material;face.smooth=smooth
  for l,v in zip(face.loops,poly):l[uv].uv=v[2];l[nl]=v[3]
assert changes
# Preserve the original topology of all other faces. Triangulate only clipped polygons.
new_faces=[f for f in bm.faces if f[ids] in {c['source_face'] for c in changes}]
bmesh.ops.triangulate(bm,faces=new_faces)
bm.to_mesh(m);bm.free();m.update();desired=[v.vector.copy() for v in m.attributes['ClipNormal'].data]
m.normals_split_custom_set(desired);calibration=calibrate(m,desired);m.attributes.remove(m.attributes['ClipNormal'])
verified=0;max_error=0
for f in m.polygons:
 source=m.attributes['CollarSourceFace'].data[f.index].value
 if source not in original:continue
 expected=original[source];assert len(expected)==len(f.loop_indices)
 for i,(co,tex,n) in zip(f.loop_indices,expected):
  assert (m.vertices[m.loops[i].vertex_index].co-Vector(co)).length<1e-7
  assert (m.uv_layers.active.data[i].uv-Vector(tex)).length<1e-7
  error=(m.corner_normals[i].vector-Vector(n)).length;max_error=max(max_error,error);assert error<.002
 verified+=1
assert verified==len(original)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes);assert triangles<=15000
out=a.output.resolve();out.mkdir(parents=True);bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=body;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_collar_clipped.blend';glb=out/'lia_collar_clipped.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==sha
report={'source_sha256':sha,'changes':changes,'planes':[{'origin':list(o),'normal':list(n)} for o,n in planes],'shared_cut_vertices':len(edge_cuts),'unselected_faces_verified':verified,'maximum_normal_error':max_error,'calibration':calibration,'triangles':triangles,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'status':'static candidate, visual and animation acceptance required'}
(out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('COLLAR_CLIP',json.dumps(report))
