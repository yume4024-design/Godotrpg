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
rig.data.edit_bones['Head'].parent=rig.data.edit_bones['Torso']
bpy.ops.object.mode_set(mode='OBJECT')
for name in ['ForearmLeft','ForearmRight','ShinLeft','ShinRight']:
 body.vertex_groups.new(name=name)
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)))
 return t*t*(3-2*t)
for v in body.data.vertices:
 old=[body.vertex_groups[g.group].name for g in v.groups if g.weight>.5]
 if not old: continue
 name=old[0]; x,y,z=v.co
 if name.startswith('Arm'):
  lower='Forearm'+name[3:]; w=1-smooth(1.13,1.29,z)
 elif name.startswith('Leg'):
  lower='Shin'+name[3:]; w=1-smooth(.47,.63,z)
 else: continue
 body.vertex_groups[name].add([v.index],1-w,'REPLACE')
 body.vertex_groups[lower].add([v.index],w,'REPLACE')
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
(ROOT/'assets/models/female/rigged_report.json').write_text(json.dumps({'triangles':tris,'bones':list(rig.data.bones.keys()),'clips':list(recipes),'duration_seconds':16/24,'mixed_joint_vertices':mixed,'weights':'smooth elbow and knee regional blending; no new reduction'},indent=2))
