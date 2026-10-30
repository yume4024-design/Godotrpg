"""Experimental Lia skirt repair: remove supported overlapping fragments on a copy.

Exact source hash and local region are required; original faces, UV and normals
outside the selected fragments are verified. Output is a static candidate only.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate

p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--thorough',action='store_true',help='Remove locally overlapping fragments on both sides of the identified backing surface')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
source_sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
if source_sha!='1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e':raise ValueError('Unexpected source: do not apply selection to a different mesh')
if a.output.exists():raise FileExistsError('Output directory exists')
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
body=bpy.data.objects['LiaRetainedAuthoredNeckSurface']; neck=bpy.data.objects['LiaContinuousNeckClavicle'];mesh=body.data
assert len(mesh.polygons)==12078 and len(mesh.materials)==1
assert not any(o.type=='ARMATURE' for o in scene.objects)
assert len([o for o in scene.objects if o.type=='MESH'])==2
# Identify larger outward-facing fabric near each fragment. Four interior
# samples are a local safeguard, not proof of a continuous surface or closure.
large=[f for f in mesh.polygons if f.area>.003 and f.normal.y>.45 and .86<f.center.z<1.18]
bvh=BVHTree.FromPolygons([v.co for v in mesh.vertices],[tuple(f.vertices) for f in large])
removed=[];supports=[]
for f in mesh.polygons:
 c=f.center
 if a.thorough:
  if not (.052<abs(c.x)<.115 and .980<c.z<1.05 and .08<c.y<.16 and f.area<.001):continue
 else:
  if not (.057<abs(c.x)<.106 and .987<c.z<1.04 and .08<c.y<.16 and f.area<.001):continue
 samples=[c*.8+mesh.vertices[i].co*.2 for i in f.vertices]+[c]
 if a.thorough:
  hits=[bvh.ray_cast(Vector((pt.x,.25,pt.z)),Vector((0,-1,0)),.25) for pt in samples]
  valid=all(h[0] is not None and abs(h[0].y-pt.y)<.025 for h,pt in zip(hits,samples))
 else:
  hits=[bvh.ray_cast(pt+Vector((0,.0001,0)),Vector((0,-1,0)),.025) for pt in samples]
  valid=all(h[0] is not None for h in hits)
 if valid:
  removed.append(f.index);supports.append({'face':f.index,'support_face_ids':[large[h[2]].index for h in hits], 'signed_offsets_m':[float(h[0].y-pt.y) for h,pt in zip(hits,samples)]})
assert len(removed)==(280 if a.thorough else 66), 'Selection changed; stop for review'
original_normals=[n.vector.copy() for n in mesh.corner_normals]
uv=mesh.uv_layers.active
kept={f.index:[(tuple(mesh.vertices[mesh.loops[i].vertex_index].co),tuple(uv.data[i].uv),tuple(original_normals[i])) for i in f.loop_indices] for f in mesh.polygons if f.index not in removed}
bm=bmesh.new();bm.from_mesh(mesh);bm.faces.ensure_lookup_table()
face_ids=bm.faces.layers.int.new('SkirtRepairSourceFace');normal_layer=bm.loops.layers.float_vector.new('SkirtRepairSourceNormal')
for f in bm.faces:
 f[face_ids]=f.index
 for loop,index in zip(f.loops,mesh.polygons[f.index].loop_indices): loop[normal_layer]=original_normals[index]
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in removed],context='FACES_ONLY')
loose=[v for v in bm.verts if not v.link_faces]
if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(mesh);bm.free();mesh.update()
desired=[x.vector.copy() for x in mesh.attributes['SkirtRepairSourceNormal'].data]
mesh.normals_split_custom_set(desired)
calibration=calibrate(mesh,desired)
mesh.attributes.remove(mesh.attributes['SkirtRepairSourceNormal'])
max_error=0.0
for f in mesh.polygons:
 source_id=mesh.attributes['SkirtRepairSourceFace'].data[f.index].value
 expected=kept[source_id]
 for loop,(point,coord,normal) in zip(f.loop_indices,expected):
  assert (mesh.vertices[mesh.loops[loop].vertex_index].co-Vector(point)).length<1e-7
  assert (mesh.uv_layers.active.data[loop].uv-Vector(coord)).length<1e-7
  err=(mesh.corner_normals[loop].vector-Vector(normal)).length;max_error=max(max_error,err)
  assert err<=.002,(source_id,loop,err)
assert len(mesh.polygons)==(11798 if a.thorough else 12012)
triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in [body,neck]);assert triangles==(12274 if a.thorough else 12488)
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==source_sha
out=a.output.resolve();out.mkdir(parents=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in [body,neck]:obj.select_set(True)
bpy.context.view_layer.objects.active=body
bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=out/'lia_skirt_repair.blend';glb=out/'lia_skirt_repair.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
receipt={'method':('thorough' if a.thorough else 'front'),'source_sha256':source_sha,'blend_sha256':hashlib.sha256(blend.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'removed_face_ids':removed,'support':supports,'retained_faces_verified':len(kept),'maximum_normal_error':max_error,'calibration':calibration,'triangles':triangles,'status':'experimental static candidate; visual and rig not accepted'}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
# Native Blender render. Camera matches the baseline close-up exactly.
for o in list(scene.objects):
 if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
scene.render.resolution_x=scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.film_transparent=False
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
scene.world=bpy.data.worlds.new('SkirtRepairReviewWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.16,.2,1);scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
camera=bpy.data.objects.new('SkirtRepairCamera',bpy.data.cameras.new('SkirtRepairCamera'));scene.collection.objects.link(camera);scene.camera=camera;camera.data.type='ORTHO'
for idx,(position,power) in enumerate([((2,-3,4),350),((-2,1,3),160)]):
 d=bpy.data.lights.new('ReviewLight'+str(idx),'AREA');d.energy=power;d.size=3;o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=position;o.rotation_euler=(Vector((0,0,1.0))-o.location).to_track_quat('-Z','Y').to_euler()
for name,center,angle,scale in [('skirt_back',(0,0,.98),180,.75),('skirt_front',(0,0,.98),0,.75),('skirt_side',(0,0,.98),90,.75),('skirt_quarter',(0,0,.98),135,.75)]:
 center=Vector(center);t=math.radians(angle);camera.location=center+Vector((math.sin(t)*4,-math.cos(t)*4,0));camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=scale
 scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
print('SKIRT_REPAIR_RESULT',json.dumps({'removed_faces':len(removed),'triangles':triangles,'retained_faces_verified':len(kept)}),flush=True)
