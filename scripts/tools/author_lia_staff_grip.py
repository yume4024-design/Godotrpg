"""Add an authored right-hand grip to Lia's preserved rig candidate.
Only finger weights and ten new digit bones change; source geometry/UVs remain.
"""
import argparse,sys,hashlib,json,math
from pathlib import Path
import bpy
from mathutils import Vector,Quaternion,Matrix
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert sha=='b7ce42fd57e55945a5ccd3ac4f4c81722c3604dbd02c250422271ce8ed0d0107','Inspect a different hand before applying index-specific bindings'
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
rig=bpy.data.objects['LiaRebuildRig'];hand=bpy.data.objects['LiaHandRight'];mesh=hand.data
before=[tuple(v.co) for v in mesh.vertices];uvs=[[tuple(v.uv) for v in uv.data] for uv in mesh.uv_layers]
rig.animation_data.action=None
for bone in rig.pose.bones:bone.matrix_basis.identity()
def centroid(ids):return sum((mesh.vertices[i].co for i in ids),Vector())/len(ids)
scale=1.0182767
wrist=Vector((-.42,.06,1.06))*scale
down=Vector((-.48,0,-.877268)).normalized();across=Vector((-.877268,0,.48)).normalized();depth=Vector((0,1,0))
# Original authored indices are still present after sleeve extension.
assert (centroid([40,41,42,43])-wrist).dot(down)>.08
parts=[]
for k,name in enumerate(['Index','Middle','Ring','Pinky']):
 parts.append((name+'Right',list(range(40+2*k,44+2*k)),50+k*16))
parts.append(('ThumbRight',[10,11,20,21],114))
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for name,base_ids,start in parts:
 base=centroid(base_ids);joint=centroid(range(start,start+4));tip=centroid(range(start+12,start+16))
 assert .015<(joint-base).length<.04 and .05<(tip-base).length<.09
 for bn,head,tail,parent in [(name,base,joint,'HandRight'),(name.replace('Right','TipRight'),joint,tip,name)]:
  b=rig.data.edit_bones.new(bn);b.head=head;b.tail=tail;b.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
for name,_,_ in parts:
 for bn in [name,name.replace('Right','TipRight')]:hand.vertex_groups.new(name=bn)
# Preserve wrist/sleeve blend, bind the lower palm rigidly to the actual hand.
for v in mesh.vertices:
 if not 10<=v.index<130:continue
 for group in hand.vertex_groups:group.remove([v.index])
 if v.index<50:hand.vertex_groups['HandRight'].add([v.index],1,'REPLACE')
for name,_,start in parts:
 for ring,blend in enumerate([0.,.75,1.,1.]):
  for idx in range(start+4*ring,start+4*ring+4):
   if blend<1:hand.vertex_groups[name].add([idx],1-blend,'REPLACE')
   if blend>0:hand.vertex_groups[name.replace('Right','TipRight')].add([idx],blend,'REPLACE')
# Fit a real 5.8cm-diameter grip with per-digit angular search. No mesh shrinking.
center=wrist+down*(.088*scale)-depth*(.040*scale)
shaft_radius=.029*.7
measurements={};rotations={}
for name,base_ids,start in parts:
 base=centroid(base_ids);joint=centroid(range(start,start+4));tip=centroid(range(start+12,start+16))
 direction=(tip-base).normalized();axis=Vector((direction.z,0,-direction.x)).normalized()
 indices=list(range(start,start+16))
 opposition=Quaternion(Vector((0,1,0)),math.radians(50 if name.startswith("Thumb") else 0))
 def transformed(idx,p_angle,t_angle):
  q=opposition@Quaternion(axis,p_angle);r=Quaternion(axis,t_angle)
  v=mesh.vertices[idx].co
  blend=[0.,.75,1.,1.][(idx-start)//4]
  one=base+q@(v-base);two=base+q@(joint-base)+q@r@(v-joint)
  return one.lerp(two,blend)
 def radial(v):
  off=v-center;return (off-across*off.dot(across)).length
 best=None
 for pdeg in range(0,96,3):
  for tdeg in range(0,121,3):
   if pdeg+tdeg>170:continue
   pa,ta=map(math.radians,[pdeg,tdeg]);points={i:transformed(i,pa,ta) for i in indices}
   radii=[radial(v) for v in points.values()]
   # Add edge midpoints and face centers: corner-only tests miss shaft penetration.
   for face in mesh.polygons:
    if all(i in points for i in face.vertices):
     vs=[points[i] for i in face.vertices];radii.append(radial(sum(vs,Vector())/len(vs)))
     radii.extend(radial((vs[k]+vs[(k+1)%len(vs)])/2) for k in range(len(vs)))
   tip_center=sum((points[i] for i in range(start+12,start+16)),Vector())/4
   distance=radial(tip_center)
   # Keep the distal pad outside the shaft and close to its surface.
   score=2000*sum(max(0,shaft_radius-r)**2 for r in radii)+20*(distance-(shaft_radius+.005))**2
   score+=max(0,(tip_center-center).y+.004)**2*50
   score+=1e-9*(pdeg*pdeg+tdeg*tdeg)
   if best is None or score<best[0]:best=(score,pdeg,tdeg,min(radii),distance,tuple(tip_center))
 _,pdeg,tdeg,mindist,tipdist,_=best
 rotations[name]=opposition@Quaternion(axis,math.radians(pdeg));rotations[name.replace('Right','TipRight')]=Quaternion(axis,math.radians(tdeg))
 measurements[name]={'opposition_degrees':50 if name.startswith('Thumb') else 0,'proximal_degrees':pdeg,'distal_degrees':tdeg,'minimum_sampled_shaft_clearance_m':mindist-shaft_radius,'tip_center_radius_m':tipdist,'samples':'vertices, internal edge midpoints and face centers; not continuous collision proof'}
# Align the held shaft upright through the hand; this is a wrist pose, not a mesh edit.
rotations['HandRight']=Quaternion(Vector((0,1,0)),math.atan2(-across.x,across.z))
act=bpy.data.actions.new('staff_grip');act.use_fake_user=True;rig.animation_data.action=act
for frame in [0,1]:
 bpy.context.scene.frame_set(frame)
 for bone in rig.pose.bones:bone.matrix_basis.identity();bone.rotation_mode='XYZ'
 for name,q in rotations.items():
  rest=rig.data.bones[name].matrix_local.to_3x3().to_quaternion()
  rig.pose.bones[name].rotation_euler=(rest.inverted()@q@rest).to_euler('XYZ')
 for bone in rig.pose.bones:bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
rig.animation_data.action=None
for bone in rig.pose.bones:bone.matrix_basis.identity()
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
assert before==[tuple(v.co) for v in mesh.vertices]
assert uvs==[[tuple(v.uv) for v in uv.data] for uv in mesh.uv_layers]
err=max(abs(sum(g.weight for g in v.groups)-1) for v in mesh.vertices);assert err<1e-5
bpy.ops.object.select_all(action='DESELECT')
for o in bpy.context.scene.objects:
 if o.type in ['MESH','ARMATURE']:o.select_set(True)
a.output.mkdir(parents=True)
blend=a.output/'lia_rigged.blend';glb=a.output/'lia_rigged.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
import shutil
shutil.copy2(a.input.parent/'lia_motion_profile.tres',a.output/'lia_motion_profile.tres')
report={'source_sha256':sha,'geometry_uv_unchanged':True,'bones':len(rig.data.bones),'new_bones':[name for name in rotations if name!='HandRight'],'grip_pose_bones':list(rotations),'grip_measurements':measurements,'staff_thickness_scale':.7,'staff_rest_origin_godot':[center.x,center.z,-center.y],'staff_rest_direction_godot':[across.x,across.z,-across.y],'weight_error':err,'sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in [blend,glb]},'limitations':['Sparse shaft sample fitting; visual inspection and runtime tests still required','Candidate only; original gameplay and character remain unchanged']}
(a.output/'grip_receipt.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('LIA_GRIP',json.dumps(report),flush=True)
