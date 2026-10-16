"""Refine the delivered mesh without another reduction; export reusable joint clips."""
import bpy, json, math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/female/lia_user.blend'))
rig=bpy.data.objects['LiaRig']
body=bpy.data.objects['LiaBody']
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for side,sign in [('Left',1),('Right',-1)]:
 upper=rig.data.edit_bones['Arm'+side]
 upper.head=(sign*.29,0,1.43); upper.tail=(sign*.42,0,1.22)
 upper.parent=rig.data.edit_bones['Torso']
 fore=rig.data.edit_bones.new('Forearm'+side)
 fore.head=upper.tail; fore.tail=(sign*.66,0,.88); fore.parent=upper; fore.use_connect=True
 thigh=rig.data.edit_bones['Leg'+side]
 thigh.head=(sign*.16,0,.95); thigh.tail=(sign*.19,0,.55)
 shin=rig.data.edit_bones.new('Shin'+side)
 shin.head=thigh.tail; shin.tail=(sign*.23,0,.12); shin.parent=thigh; shin.use_connect=True
 coat=rig.data.edit_bones.new('Coat'+side)
 coat.head=(sign*.15,0,1.05); coat.tail=(sign*.2,0,.8); coat.parent=rig.data.edit_bones['Root']
rig.data.edit_bones['Head'].parent=rig.data.edit_bones['Torso']
bpy.ops.object.mode_set(mode='OBJECT')
for name in ['ForearmLeft','ForearmRight','ShinLeft','ShinRight','CoatLeft','CoatRight']:
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
 elif name.startswith('Leg'):
  lower='Shin'+name[3:]; w=1-smooth(.47,.63,z)
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

# Every clip contains explicit zero endpoints for all joints.
recipes={
 'cast':{'ArmLeft':(-.22,0,.12),'ArmRight':(-.22,0,-.12),'ForearmLeft':(-.38,0,0),'ForearmRight':(-.38,0,0),'Head':(-.04,0,0)},
 'hit':{'Torso':(-.09,0,0),'Head':(.06,0,0),'ShinLeft':(.08,0,0),'ShinRight':(.08,0,0)},
 'guard':{'ArmLeft':(-.16,0,.08),'ArmRight':(-.16,0,-.08),'ForearmLeft':(-.32,0,0),'ForearmRight':(-.32,0,0)},
 'attack':{'ArmRight':(-.3,.1,0),'ForearmRight':(-.25,0,0),'Torso':(0,.06,0)},
 'potion':{'ArmLeft':(-.2,0,0),'ForearmLeft':(-.45,0,0)}
}
rig.animation_data_clear()
for name,recipe in recipes.items():
 action=bpy.data.actions.new(name); action.use_fake_user=True
 rig.animation_data_create(); rig.animation_data.action=action
 for frame in [1,5,9,13,17]:
  amount=math.sin(math.pi*(frame-1)/16)
  for bone in rig.pose.bones:
   bone.rotation_mode='XYZ'
   bone.rotation_euler=Vector(recipe.get(bone.name,(0,0,0)))*amount
   bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
for name,amplitude,length in [('walk',.17,24),('run',.27,16)]:
 action=bpy.data.actions.new(name); action.use_fake_user=True
 rig.animation_data.action=action
 for frame in range(1,length+2,2):
  phase=(frame-1)/length*math.tau
  pose={}
  for side,sign in [('Left',1),('Right',-1)]:
   stride=math.sin(phase)*sign
   pose['Leg'+side]=(stride*amplitude,0,0)
   pose['Shin'+side]=(max(0,-stride)*amplitude,0,0)
   pose['Arm'+side]=(-stride*amplitude*.65,0,0)
   pose['Forearm'+side]=(-.08-max(0,stride)*.08,0,0)
   pose['Coat'+side]=(-stride*amplitude*.4,0,0)
  for bone in rig.pose.bones:
   bone.rotation_euler=pose.get(bone.name,(0,0,0))
   bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
rig.animation_data.action=None
for bone in rig.pose.bones: bone.rotation_euler=(0,0,0)
bpy.context.scene.render.fps=24
bpy.context.scene.frame_start=1; bpy.context.scene.frame_end=17
bpy.context.scene.frame_set(1)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.parent==rig]
bpy.ops.object.select_all(action='DESELECT'); rig.select_set(True)
for o in meshes: o.select_set(True)
out=ROOT/'assets/models/female/lia_rigged.glb'
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/source/female/lia_rigged.blend'))
tris=0
for o in meshes: o.data.calc_loop_triangles(); tris+=len(o.data.loop_triangles)
assert tris<=5000
(ROOT/'assets/models/female/rigged_report.json').write_text(json.dumps({'triangles':tris,'bones':list(rig.data.bones.keys()),'clips':list(recipes)+['walk','run'],'duration_seconds':{'battle':16/24,'walk':1,'run':16/24},'mixed_joint_vertices':mixed,'weights':'smooth elbow/knee/shoulder/hip blending with separate coat tails; no new reduction'},indent=2))
