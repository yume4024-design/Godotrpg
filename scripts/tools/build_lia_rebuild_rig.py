"""Rig the inspected Lia coat candidate without editing the formal game asset.

Anatomical regions and authored garment groups are specific to this source.
The seven clip names reuse female_actor.gd's existing contract.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector, Matrix, Euler

p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
source_sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
if source_sha!='2254aeb44c49422d9d2ef098f4037a4ffc077044631dc25fb5ed90261efbbdde':
 raise ValueError('Inspect landmarks before binding a different source')
if a.output.exists():raise FileExistsError(a.output)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(meshes)==7 and not any(o.type=='ARMATURE' for o in bpy.context.scene.objects)
# Keep exact positions, normals, UVs, materials and source region membership.
before={o.name:([tuple(v.co) for v in o.data.vertices],[[tuple(t.uv) for t in uv.data] for uv in o.data.uv_layers]) for o in meshes}
regions={o.name:{v.index:[o.vertex_groups[g.group].name for g in v.groups] for v in o.data.vertices} for o in meshes}
spec={'Root':((0,0,0),(0,0,1.10),None),'Torso':((0,.015,1.10),(0,.015,1.53),'Root'),'Head':((0,.015,1.61),(0,.015,1.86),'Torso')}
for side,s in [('Left',1),('Right',-1)]:
 spec.update({'Arm'+side:((s*.19,.046,1.47),(s*.32,.057,1.27),'Torso'),
 'Forearm'+side:((s*.32,.057,1.27),(s*.428,.061,1.079),'Arm'+side),
 'Hand'+side:((s*.428,.061,1.079),(s*.463,.061,1.015),'Forearm'+side),
 'Fingers'+side:((s*.463,.061,1.015),(s*.505,.061,.94),'Hand'+side),
 'Leg'+side:((s*.13,.04,1.10),(s*.16,.04,.60),'Root'),
 'Shin'+side:((s*.16,.04,.60),(s*.18,.04,.18),'Leg'+side),
 'Foot'+side:((s*.18,.04,.18),(s*.18,-.13,.055),'Shin'+side),
 'Coat'+side:((s*.14,-.01,1.21),(s*.20,-.01,.93),'Torso')})
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add()
rig=bpy.context.object;rig.name='LiaRebuildRig'
bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name,(head,tail,parent) in spec.items():
 b=rig.data.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')

def smooth(lo,hi,x):
 t=max(0.,min(1.,(x-lo)/(hi-lo)));return t*t*(3-2*t)
def arm_weights(z,side):
 # Identical rule on the inner sleeve, outer sleeve and cape prevents separation.
 shoulder=1-smooth(1.43,1.52,z)
 forearm=1-smooth(1.22,1.32,z)
 hand=1-smooth(1.06,1.10,z)
 finger=1-smooth(.997,1.025,z)
 return {'Torso':1-shoulder,'Arm'+side:shoulder*(1-forearm),
 'Forearm'+side:shoulder*forearm*(1-hand),'Hand'+side:shoulder*forearm*hand*(1-finger),'Fingers'+side:shoulder*forearm*hand*finger}
def weights(o,v):
 x,y,z=v.co;side='Left' if x>=0 else 'Right';names=regions[o.name][v.index]
 if o.name.startswith('LiaHand'):return arm_weights(z,side)
 if o.name=='LiaAuthoredCollar':return {'Torso':1}
 if o.name=='LiaContinuousNeckClavicle':
  h=smooth(1.54,1.63,z);return {'Head':h,'Torso':1-h}
 if o.name=='LiaContinuousCapelet':
  arm=smooth(.14,.26,abs(x))*(1-smooth(1.44,1.53,z))
  return {'Torso':1-arm,'Arm'+side:arm}
 if o.name=='LiaTailoredOutfit':
  if any(n.startswith('LiaCoatTail') for n in names):
   cloth=1-smooth(1.02,1.20,z);return {'Torso':1-cloth,'Coat'+side:cloth}
  return {'Torso':1}
 if z>1.57:return {'Head':1}
 # Retained mesh contains original outer sleeve panels; use the same weights.
 if z>1.29 and abs(x)>.17:return arm_weights(z,side)
 if z>1.13:return {'Torso':1}
 leg=1-smooth(1.02,1.13,z);shin=1-smooth(.54,.66,z);foot=1-smooth(.16,.28,z)
 return {'Torso':1-leg,'Leg'+side:leg*(1-shin),'Shin'+side:leg*shin*(1-foot),'Foot'+side:leg*shin*foot}
errors=[]
for o in meshes:
 o.vertex_groups.clear()
 for name in spec:o.vertex_groups.new(name=name)
 for v in o.data.vertices:
  w=sorted(((n,w) for n,w in weights(o,v).items() if w>1e-8),key=lambda x:-x[1])[:4]
  total=sum(x[1] for x in w);assert total>0
  for name,value in w:o.vertex_groups[name].add([v.index],value/total,'REPLACE')
  errors.append(abs(sum(g.weight for g in v.groups)-1))
 o.parent=rig;o.modifiers.new('LiaRebuildSkin','ARMATURE').object=rig
 assert before[o.name]==([tuple(v.co) for v in o.data.vertices],[[tuple(t.uv) for t in uv.data] for uv in o.data.uv_layers])
assert max(errors)<1e-5
scene=bpy.context.scene;scene.render.fps=24
rig.animation_data_create()

def reset():
 for bone in rig.pose.bones:
  bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)
def bounds():
 dg=bpy.context.evaluated_depsgraph_get();points=[]
 for o in meshes:
  ob=o.evaluated_get(dg);me=ob.to_mesh()
  # Only vertices referenced by faces count; retained source has unused vertices.
  used={i for p in me.polygons for i in p.vertices}
  points.extend(ob.matrix_world@me.vertices[i].co for i in used);ob.to_mesh_clear()
 return [(min(v[i] for v in points),max(v[i] for v in points)) for i in range(3)]
def key(frame):
 bpy.context.view_layer.update()
 low=bounds()[2][0]
 rig.pose.bones['Root'].location=rig.data.bones['Root'].matrix_local.to_3x3().inverted()@Vector((0,0,.002-low))
 for bone in rig.pose.bones:bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
 rig.pose.bones['Root'].keyframe_insert(data_path='location',frame=frame,group='Root')

def set_pose(name, angles):
 # Author anatomical rotations in Blender world axes, then convert to bone-local.
 rest=rig.data.bones[name].matrix_local.to_3x3().to_quaternion()
 q=Euler(angles, "XYZ").to_quaternion()
 rig.pose.bones[name].rotation_euler=(rest.inverted()@q@rest).to_euler("XYZ")

def action(name):
 act=bpy.data.actions.new(name);act.use_fake_user=True;rig.animation_data.action=act;return act
recipes={'attack':{'ArmRight':(-.35,.1,0),'ForearmRight':(-.3,0,0),'Torso':(0,.08,0)},
 'cast':{'ArmLeft':(-.35,0,.12),'ArmRight':(-.22,0,-.12),'ForearmLeft':(-.65,0,0),'ForearmRight':(-.45,0,0),'Head':(-.04,0,0)},
 'guard':{'ArmLeft':(-.16,0,.08),'ArmRight':(-.16,0,-.08),'ForearmLeft':(-.32,0,0),'ForearmRight':(-.32,0,0)},
 'hit':{'Torso':(-.09,0,0),'Head':(.06,0,0),'ShinLeft':(.08,0,0),'ShinRight':(.08,0,0)},
 'potion':{'ArmLeft':(-.2,0,0),'ForearmLeft':(-.45,0,0)}}
for clip,recipe in recipes.items():
 action(clip)
 for frame in range(17):
  scene.frame_set(frame);reset();pulse=math.sin(math.pi*frame/16)
  for name,angles in recipe.items():set_pose(name,Vector(angles)*pulse)
  key(frame)
cycle={}
for clip,amp,length in [('walk',.35,24),('run',.6,16)]:
 action(clip);travel=[]
 for frame in range(length+1):
  scene.frame_set(frame);reset()
  for side,s in [('Left',1),('Right',-1)]:
   stride=math.sin(frame/length*math.tau)*s
   for name,pose in {'Leg'+side:(amp*stride,0,0),'Shin'+side:(max(0,-stride)*amp,0,0),
    'Arm'+side:(-stride*amp*.4,0,0),'Forearm'+side:(-.08-max(0,stride)*.08,0,0),
    'Coat'+side:(amp*stride*.65,0,0)}.items():set_pose(name,pose)
  bpy.context.view_layer.update();travel.append(rig.pose.bones['FootLeft'].matrix.translation.y)
  for side in ['Left','Right']:
   foot=rig.pose.bones['Foot'+side];foot.matrix=Matrix.Translation(foot.matrix.translation)@foot.bone.matrix_local.to_3x3().to_4x4()
  key(frame)
 cycle[clip]=2*(max(travel)-min(travel))
# Evaluate all keyed poses, not just rest shape; record limits without claiming no intersections.
samples={}
for act in bpy.data.actions:
 rig.animation_data.action=act
 if act.slots:rig.animation_data.action_slot=act.slots[0]
 result=[]
 for frame in range(int(act.frame_range[1])+1):
  scene.frame_set(frame);bpy.context.view_layer.update();bb=bounds()
  assert all(math.isfinite(v) for pair in bb for v in pair)
  assert bb[2][0]>-.015 and bb[2][1]<2.2 and bb[0][1]-bb[0][0]<1.8
  result.append(bb)
 samples[act.name]=result
rig.animation_data.action=None;reset();scene.frame_set(0);bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
rig.select_set(True);bpy.context.view_layer.objects.active=rig
a.output.mkdir(parents=True);bpy.ops.file.pack_all()
blend=a.output/'lia_rigged.blend';glb=a.output/'lia_rigged.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
triangles=0
for o in meshes:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
report={'source':str(a.input),'source_sha256':source_sha,'triangles':triangles,'bones':len(spec),'geometry_uv_unchanged':True,'weight_max_error':max(errors),'max_influences':max(len(v.groups) for o in meshes for v in o.data.vertices),'cycle_distances':cycle,'evaluated_bounds':samples,'sha256':{f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in [blend,glb]},'limitations':['Candidate only; no formal game replacement','Single aggregate finger bone; staff grip not individually authored','No terrain IK or collision-free cloth claim','Gameplay, transitions and visual deformation require separate tests']}
(a.output/'receipt.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(a.output/'lia_motion_profile.tres').write_text('[gd_resource type="Resource" script_class="CharacterMotionProfile" format=3]\n[ext_resource type="Script" path="res://scripts/characters/character_motion_profile.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nwalk_cycle_distance = %.9f\nrun_cycle_distance = %.9f\n'%(cycle['walk'],cycle['run']),encoding='utf-8')
print('LIA_RIG_RESULT',triangles,len(spec),'bounds samples',sum(map(len,samples.values())),flush=True)
