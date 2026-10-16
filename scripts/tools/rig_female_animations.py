"""Refine the delivered mesh without another reduction; export reusable joint clips."""
import bpy, json, math, bmesh
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/female/lia_user.blend'))
rig=bpy.data.objects['LiaRig']
body=bpy.data.objects['LiaBody']
# Remove isolated triangle debris and the coarse distal hand geometry on a copy.
bm=bmesh.new(); bm.from_mesh(body.data)
remaining=set(bm.verts); debris=set()
while remaining:
 seed=remaining.pop(); group={seed}; frontier=[seed]
 while frontier:
  current=frontier.pop()
  for edge in current.link_edges:
   other=edge.other_vert(current)
   if other in remaining: remaining.remove(other); group.add(other); frontier.append(other)
 if len(group)<=3: debris.update(group)
cut={v for v in bm.verts if v.co.z<1.01 and abs(v.co.x)>.58}
removed_debris=len(debris)
bmesh.ops.delete(bm,geom=list(debris|cut),context='VERTS')
bm.to_mesh(body.data); bm.free()

def hand_layout(sign):
 wrist=Vector((sign*.59,-.035,1.04))
 down=Vector((sign*.55,0,-.835)).normalized()
 across=Vector((sign*.835,0,.55)).normalized()
 depth=Vector((0,1,0))
 fingers=[]
 for name,offset,length in [('Index',-.025,.105),('Middle',-.008,.115),('Ring',.009,.105),('Pinky',.026,.09)]:
  start=wrist+down*.12+across*offset
  direction=(down+across*(offset/.026)*.07).normalized()
  fingers.append((name,[start,start+direction*length*.55-depth*.004,start+direction*length-depth*.012]))
 start=wrist+down*.052-across*.024
 thumb_direction=(down*.5-across*.85).normalized()
 fingers.append(('Thumb',[start,start+thumb_direction*.04-depth*.004,start+thumb_direction*.08-depth*.012]))
 return wrist,down,across,depth,fingers
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for side,sign in [('Left',1),('Right',-1)]:
 upper=rig.data.edit_bones['Arm'+side]
 upper.head=(sign*.29,0,1.43); upper.tail=(sign*.42,0,1.22)
 upper.parent=rig.data.edit_bones['Torso']
 fore=rig.data.edit_bones.new('Forearm'+side)
 fore.head=upper.tail; fore.tail=(sign*.61,0,1.0); fore.parent=upper; fore.use_connect=True
 hand=rig.data.edit_bones.new('Hand'+side)
 hand.head=fore.tail; hand.tail=hand_layout(sign)[0]+hand_layout(sign)[1]*.12; hand.parent=fore; hand.use_connect=True
 fingers=rig.data.edit_bones.new('Fingers'+side)
 fingers.head=hand.tail; fingers.tail=(sign*.735,0,.84); fingers.parent=hand; fingers.use_connect=True
 for name,points in hand_layout(sign)[4]:
  finger=rig.data.edit_bones.new(name+side)
  finger.head=points[0]; finger.tail=points[-1]; finger.parent=hand if name=='Thumb' else fingers
 thigh=rig.data.edit_bones['Leg'+side]
 thigh.head=(sign*.16,0,.95); thigh.tail=(sign*.19,0,.55)
 shin=rig.data.edit_bones.new('Shin'+side)
 shin.head=thigh.tail; shin.tail=(sign*.23,0,.16); shin.parent=thigh; shin.use_connect=True
 foot=rig.data.edit_bones.new('Foot'+side)
 foot.head=shin.tail; foot.tail=(sign*.23,-.16,.08); foot.parent=shin; foot.use_connect=True
 coat=rig.data.edit_bones.new('Coat'+side)
 coat.head=(sign*.15,0,1.05); coat.tail=(sign*.2,0,.8); coat.parent=rig.data.edit_bones['Root']
rig.data.edit_bones['Head'].parent=rig.data.edit_bones['Torso']
bpy.ops.object.mode_set(mode='OBJECT')
for name in ['ForearmLeft','ForearmRight','ShinLeft','ShinRight','FootLeft','FootRight','CoatLeft','CoatRight','HandLeft','HandRight','FingersLeft','FingersRight']:
 body.vertex_groups.new(name=name)
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)))
 return t*t*(3-2*t)
for v in body.data.vertices:
 old=[body.vertex_groups[g.group].name for g in v.groups if g.weight>.5]
 if not old: continue
 name=old[0]; x,y,z=v.co
 color=body.data.color_attributes['HeroColor'].data[v.index].color
 if .78<z<1.055 and color[2]>color[0]*1.15 and color[0]>.1:
  for group in body.vertex_groups: group.remove([v.index])
  coat_weight=1-smooth(.94,1.055,z)
  body.vertex_groups['CoatLeft' if x>0 else 'CoatRight'].add([v.index],coat_weight,'REPLACE')
  body.vertex_groups['Torso'].add([v.index],1-coat_weight,'REPLACE')
  continue
 if name.startswith('Arm'):
  lower='Forearm'+name[3:]; w=1-smooth(1.13,1.29,z)
  if z<1.045 and abs(x)>.55:
   hand_weight=1-smooth(.97,1.045,z)
   finger_weight=1-smooth(.87,.945,z)
   body.vertex_groups[name].add([v.index],0,'REPLACE')
   body.vertex_groups[lower].add([v.index],1-hand_weight,'REPLACE')
   body.vertex_groups['Hand'+name[3:]].add([v.index],hand_weight*(1-finger_weight),'REPLACE')
   body.vertex_groups['Fingers'+name[3:]].add([v.index],hand_weight*finger_weight,'REPLACE')
   continue
 elif name.startswith('Leg'):
  lower='Shin'+name[3:]; w=1-smooth(.47,.63,z)
  if z<.25:
   foot_weight=1-smooth(.12,.25,z)
   body.vertex_groups[name].add([v.index],0,'REPLACE')
   body.vertex_groups[lower].add([v.index],1-foot_weight,'REPLACE')
   body.vertex_groups['Foot'+name[3:]].add([v.index],foot_weight,'REPLACE')
   continue
 else: continue
 attachment=smooth(.27,.4,abs(x)) if name.startswith('Arm') else 1-smooth(.86,1.01,z)
 body.vertex_groups[name].add([v.index],(1-w)*attachment,'REPLACE')
 body.vertex_groups[lower].add([v.index],w*attachment,'REPLACE')
 body.vertex_groups['Torso'].add([v.index],1-attachment,'REPLACE')
mixed={name:0 for name in ['ForearmLeft','ForearmRight','ShinLeft','ShinRight']}
for v in body.data.vertices:
 assert abs(sum(g.weight for g in v.groups)-1)<.0001, 'Unnormalized vertex weights'
 for g in v.groups:
  name=body.vertex_groups[g.group].name
  if name in mixed and .001<g.weight<.999: mixed[name]+=1
assert all(mixed.values()), mixed
print('JOINT_WEIGHT_AUDIT',mixed)

# Small facial accents from the supplied front reference; no new body topology.
def face_material(name,color):
 mat=bpy.data.materials.new(name); mat.diffuse_color=(*color,1); mat.use_nodes=True
 mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
 mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
 return mat
pupil_mat=face_material('Pupil',(.008,.018,.035))
glint_mat=face_material('EyeGlint',(.95,.95,.95))
mouth_mat=face_material('LipLine',(.17,.065,.045))
def skinned_face(name,vertices,faces,mat):
 mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
 uv=mesh.uv_layers.new(name='UVMap')
 xs=[v.co.x for v in mesh.vertices]; zs=[v.co.z for v in mesh.vertices]
 for loop in mesh.loops:
  co=mesh.vertices[loop.vertex_index].co
  uv.data[loop.index].uv=((co.x-min(xs))/max(.00001,max(xs)-min(xs)),(co.z-min(zs))/max(.00001,max(zs)-min(zs)))
 obj=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(obj)
 obj.data.materials.append(mat); obj.parent=rig
 obj.vertex_groups.new(name='Head').add(list(range(len(vertices))),1,'REPLACE')
 modifier=obj.modifiers.new('Skin','ARMATURE'); modifier.object=rig
 return obj
skin_mat=face_material('HandSkin',(.88,.63,.43))
for side,sign in [('Left',1),('Right',-1)]:
 wrist,down,across,depth,fingers=hand_layout(sign)
 vertices=[]; faces=[]; assignments={}
 def tube(centers,radii,segments,bone):
  base=len(vertices)
  for center,(width,thickness) in zip(centers,radii):
   for segment in range(segments):
    angle=segment/segments*math.tau
    vertices.append(tuple(center+across*width*math.cos(angle)+depth*thickness*math.sin(angle)))
  for ring in range(len(centers)-1):
   for segment in range(segments):
    a=base+ring*segments+segment; b=base+ring*segments+(segment+1)%segments
    faces.append((a,b,b+segments,a+segments))
  faces.append(tuple(base+i for i in reversed(range(segments))))
  faces.append(tuple(base+(len(centers)-1)*segments+i for i in range(segments)))
  assignments[bone]=list(range(base,len(vertices)))
 tube([wrist,wrist+down*.05,wrist+down*.12],[(.025,.02),(.028,.018),(.035,.017)],8,'Hand'+side)
 for name,points in fingers:
  tube(points,[(.0095,.010),(.007,.008),(.006,.007)],4,name+side)
 obj=skinned_face('DetailedHand'+side,vertices,faces,skin_mat)
 obj.vertex_groups.clear()
 for name,indices in assignments.items(): obj.vertex_groups.new(name=name).add(indices,1,'REPLACE')
 hand_mesh=bmesh.new(); hand_mesh.from_mesh(obj.data)
 bmesh.ops.recalc_face_normals(hand_mesh,faces=list(hand_mesh.faces)); hand_mesh.to_mesh(obj.data); hand_mesh.free()
for iris in [o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.name.startswith('Iris')]:
 for name,rx,rz,dx,dz,dy,segments,mat in [('Pupil',.006,.012,0,0,-.010,8,pupil_mat),('EyeGlint',.003,.004,-.003,.007,-.011,6,glint_mat)]:
  center=iris.location+Vector((dx,dy,dz))
  points=[(0,0,0)]+[(rx*math.cos(i/segments*math.tau),0,rz*math.sin(i/segments*math.tau)) for i in range(segments)]
  obj=skinned_face(name,points,[(0,i+1,(i+1)%segments+1) for i in range(segments)],mat)
  obj.location=center
points=[]
for x in [-.03,-.015,0,.015,.03]:
 z=1.625+abs(x)*.2
 hit,p,_,_=body.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
 if hit: points.extend([tuple(p+Vector((0,-.002,-.002))),tuple(p+Vector((0,-.002,.002)))])
if len(points)==10:
 skinned_face('SmileLine',points,[(i+2,i+3,i+1,i) for i in range(0,8,2)],mouth_mat)
for obj in [o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(('EyeWhite','Iris','Pupil','EyeGlint'))]:
 obj.shape_key_add(name='Basis')
 blink=obj.shape_key_add(name='Blink')
 for point in blink.data:
  center=1.715-obj.location.z
  point.co.z=center+(point.co.z-center)*.08

# Every clip contains explicit zero endpoints for all joints.
recipes={
 'cast':{'ArmLeft':(-.35,0,.12),'ArmRight':(-.22,0,-.12),'ForearmLeft':(-.65,0,0),'ForearmRight':(-.45,0,0),'HandLeft':(.12,0,0),'Head':(-.04,0,0)},
 'hit':{'Torso':(-.09,0,0),'Head':(.06,0,0),'ShinLeft':(.08,0,0),'ShinRight':(.08,0,0)},
 'guard':{'ArmLeft':(-.16,0,.08),'ArmRight':(-.16,0,-.08),'ForearmLeft':(-.32,0,0),'ForearmRight':(-.32,0,0)},
 'attack':{'ArmRight':(-.3,.1,0),'ForearmRight':(-.25,0,0),'Torso':(0,.06,0)},
 'potion':{'ArmLeft':(-.2,0,0),'ForearmLeft':(-.45,0,0)}
}
rig.animation_data_clear()
for name,recipe in recipes.items():
 action=bpy.data.actions.new(name); action.use_fake_user=True
 rig.animation_data_create(); rig.animation_data.action=action
 for frame in [0,4,8,12,16]:
  amount=math.sin(math.pi*frame/16)
  for bone in rig.pose.bones:
   bone.rotation_mode='XYZ'
   bone.rotation_euler=Vector(recipe.get(bone.name,(0,0,0)))*amount
   bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
grounding={}
cycle_distances={}
for name,amplitude,length in [('walk',.45,24),('run',.75,16)]:
 action=bpy.data.actions.new(name); action.use_fake_user=True
 rig.animation_data.action=action
 samples=[]; forward_samples=[]
 for frame in range(length+1):
  bpy.context.scene.frame_set(frame)
  rig.pose.bones['Root'].location=(0,0,0)
  phase=frame/length*math.tau
  pose={}
  for side,sign in [('Left',1),('Right',-1)]:
   stride=math.sin(phase)*sign
   pose['Leg'+side]=(stride*amplitude,0,0)
   pose['Shin'+side]=(max(0,-stride)*amplitude,0,0)
   pose['Arm'+side]=(-stride*amplitude*.65,0,0)
   pose['Forearm'+side]=(-.08-max(0,stride)*.08,0,0)
   pose['Coat'+side]=(-stride*min(.14,amplitude*.4),0,0)
  for bone in rig.pose.bones:
   bone.rotation_euler=pose.get(bone.name,(0,0,0))
  bpy.context.view_layer.update()
  forward_samples.append(rig.pose.bones['FootLeft'].matrix.translation.y)
  for side in ['Left','Right']:
   foot=rig.pose.bones['Foot'+side]
   # Keep boots oriented to the floor while the thigh and knee cycle.
   foot.matrix=Matrix.Translation(foot.matrix.translation) @ foot.bone.matrix_local.to_3x3().to_4x4()
  bpy.context.view_layer.update()
  deps=bpy.context.evaluated_depsgraph_get(); evaluated=body.evaluated_get(deps)
  lowest=min(v.co.z for v in evaluated.data.vertices)
  rig.pose.bones['Root'].location=rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0,0,.002-lowest))
  bpy.context.view_layer.update()
  evaluated=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
  samples.append(min(v.co.z for v in evaluated.data.vertices))
  for bone in rig.pose.bones:
   bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
  rig.pose.bones['Root'].keyframe_insert(data_path='location',frame=frame,group='Root')
 assert min(samples)>-.001 and max(samples)<.006, samples
 grounding[name]={'minimum_sole_m':min(samples),'maximum_sole_m':max(samples),'sampled_frames':len(samples)}
 cycle_distances[name]=2*(max(forward_samples)-min(forward_samples))
rig.animation_data.action=None
for bone in rig.pose.bones: bone.rotation_euler=(0,0,0); bone.location=(0,0,0)
bpy.context.scene.render.fps=24
bpy.context.scene.frame_start=0; bpy.context.scene.frame_end=16
bpy.context.scene.frame_set(0)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==rig]
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
for o in meshes: o.select_set(True)
out=ROOT/'assets/models/female/lia_rigged.glb'
tris=0
for o in meshes: o.data.calc_loop_triangles(); tris+=len(o.data.loop_triangles)
assert tris+140<=5000, 'Character plus willow staff exceeds the shared visual budget'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/source/female/lia_rigged.blend'))
(ROOT/'assets/models/female/rigged_report.json').write_text(json.dumps({'triangles':tris,'bones':list(rig.data.bones.keys()),'clips':list(recipes)+['walk','run'],'duration_seconds':{'battle':16/24,'walk':1,'run':16/24},'mixed_joint_vertices':mixed,'flat_floor_samples':grounding,'removed_debris_vertices':removed_debris,'weights':'smooth joints, separate five-finger hands, coat tails and feet; no new reduction'},indent=2))
(ROOT/'assets/models/female/lia_motion_profile.tres').write_text('[gd_resource type="Resource" script_class="CharacterMotionProfile" format=3]\n[ext_resource type="Script" path="res://scripts/characters/character_motion_profile.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nwalk_cycle_distance = %.8f\nrun_cycle_distance = %.8f\n' % (cycle_distances['walk'],cycle_distances['run']))
print('LOCOMOTION_CYCLE_DISTANCES',cycle_distances)
