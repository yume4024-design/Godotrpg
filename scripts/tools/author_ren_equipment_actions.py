"""Add real idle, sword idle/attack/guard and death clips to the validated copy.

The original seven actions, body topology, materials and skin weights remain.
Weapon geometry stays a separate asset. No production references are changed.
"""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector,Matrix,Euler

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--input',type=Path,required=True)
p.add_argument('--sword',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--recipe',choices=['world-v1','local-v2','hinge-v3'],default='hinge-v3')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
assert hashlib.sha256(a.input.read_bytes()).hexdigest()=='e42d45233fc8a1e8d598a29cd95a2def37b131c7a23926bba0f72bb90fcf5301'
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene;scene.render.fps=24
rig=next(o for o in scene.objects if o.type=='ARMATURE')
meshes=[o for o in scene.objects if o.type=='MESH']
assert len(meshes)==5
for track in rig.animation_data.nla_tracks:track.mute=True
old_actions={action.name:action for action in bpy.data.actions}
assert set(old_actions)=={'attack','cast','guard','hit','potion','run','walk'}
with bpy.data.libraries.load(str(a.sword.resolve()),link=False) as (src,dst):
    dst.meshes=['BronzeBlade']
sword_mesh=dst.meshes[0]
sword_points=[v.co.copy() for v in sword_mesh.vertices]
bpy.data.meshes.remove(sword_mesh)
blade_axis=Vector((-.65,-.25,-.70)).normalized()
sword_rest=Matrix.Translation(Vector((-.43,.01,.94))) @ Vector((0,0,1)).rotation_difference(blade_axis).to_matrix().to_4x4()
hand_rest_inverse=rig.data.bones['HandRight'].matrix_local.inverted()
floor_rows={}

def reset():
    for bone in rig.pose.bones:
        bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)

def rotate(name,angles):
    basis=rig.data.bones[name].matrix_local.to_3x3()
    rotation=basis.inverted() @ Euler(angles,'XYZ').to_matrix() @ basis
    rig.pose.bones[name].rotation_euler=rotation.to_euler('XYZ')

def sample_floor():
    minimum=float('inf')
    bpy.context.view_layer.update()
    for obj in meshes:
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
        minimum=min(minimum,min(v.co.z for v in mesh.vertices));evaluated.to_mesh_clear()
    transform=rig.pose.bones['HandRight'].matrix @ hand_rest_inverse @ sword_rest
    minimum=min(minimum,min((transform@v).z for v in sword_points))
    return minimum

def frame_key():
    rig.pose.bones['Root'].location=rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0,0,.002-sample_floor()))
    for bone in rig.pose.bones:bone.keyframe_insert(data_path='rotation_euler',group=bone.name)
    rig.pose.bones['Torso'].keyframe_insert(data_path='location',group='Torso')
    rig.pose.bones['Root'].keyframe_insert(data_path='location',group='Root')
    bpy.context.view_layer.update()
    return sample_floor()

idle={'ArmLeft':(0,.08,0),'ArmRight':(0,-.08,0),'ForearmLeft':(-.04,0,0),'ForearmRight':(-.04,0,0)}
sword_idle={**idle,'ForearmRight':(-.12,0,0),'HandRight':(-.10,0,0)}
def from_local(poses):
    # The isolated v1 failed at the armpit (retained vertices 783/785), not
    # the sword. Keep upper-arm poses in the proven original action envelope;
    # articulate the new blade arc with elbow/wrist rather than world abduction.
    result={}
    for name,angles in poses.items():
        basis=rig.data.bones[name].matrix_local.to_3x3()
        result[name]=tuple((basis @ Euler(angles,'XYZ').to_matrix() @ basis.inverted()).to_euler('XYZ'))
    return result
def forward_bend(name,angle):
    # Anatomical hinge: bend the rest arm toward the character's forward -Y.
    # v2 passed numeric gates but its local-X elbow barely lifted the blade.
    direction=rig.data.bones[name].matrix_local.to_3x3().col[1].normalized()
    axis=direction.cross(Vector((0,-1,0))).normalized()
    from mathutils import Quaternion
    return tuple(Quaternion(axis,angle).to_euler('XYZ'))
windup={**sword_idle,'ArmRight':forward_bend('ArmRight',.15),
        'ForearmRight':forward_bend('ForearmRight',1.10),'HandRight':forward_bend('HandRight',.50),
        **from_local({'Torso':(0,.10,0),'ArmLeft':(-.12,0,-.10)})}
impact={**sword_idle,'ArmRight':forward_bend('ArmRight',.12),
        'ForearmRight':forward_bend('ForearmRight',.35),'HandRight':forward_bend('HandRight',-.10),
        **from_local({'Torso':(0,-.10,0)})}
follow={**sword_idle,'ArmRight':forward_bend('ArmRight',-.05),
        'ForearmRight':forward_bend('ForearmRight',.08),'HandRight':forward_bend('HandRight',-.10),
        **from_local({'Torso':(0,-.12,0)})}
guard={**sword_idle,'ArmRight':forward_bend('ArmRight',.12),
       'ForearmRight':forward_bend('ForearmRight',1.10),'HandRight':forward_bend('HandRight',.60),
       **from_local({'Torso':(0,.02,0),'ArmLeft':(-.16,0,.08),'ForearmLeft':(-.45,0,0)})}
if a.recipe=='world-v1':
    windup={**sword_idle,'ArmRight':(-.60,.10,.40),'ForearmRight':(-.60,0,0),'HandRight':(-.30,0,0),'Torso':(0,0,.12),'ArmLeft':(-.12,0,-.10)}
    impact={**sword_idle,'ArmRight':(-.28,-.10,-.38),'ForearmRight':(-.42,0,0),'HandRight':(-.32,0,0),'Torso':(.025,0,-.10)}
    follow={**sword_idle,'ArmRight':(.08,-.10,-.25),'ForearmRight':(-.25,0,0),'HandRight':(0,0,0),'Torso':(0,0,-.12)}
    guard={**sword_idle,'ArmRight':(-.50,.02,.08),'ForearmRight':(-.65,0,0),'HandRight':(-.60,0,0),'Torso':(0,0,.02),'ArmLeft':(-.30,0,0),'ForearmLeft':(-.45,0,0)}
elif a.recipe=='local-v2':
    windup={**sword_idle,**from_local({'ArmRight':(-.35,.10,0),'ForearmRight':(-.55,0,0),'HandRight':(0,0,-.20),'Torso':(0,.10,0),'ArmLeft':(-.12,0,-.10)})}
    impact={**sword_idle,**from_local({'ArmRight':(-.10,-.10,0),'ForearmRight':(-.25,0,0),'HandRight':(0,0,.20),'Torso':(0,-.10,0)})}
    follow={**sword_idle,**from_local({'ArmRight':(.08,-.10,0),'ForearmRight':(-.08,0,0),'HandRight':(0,0,.10),'Torso':(0,-.12,0)})}
    guard={**sword_idle,**from_local({'ArmRight':(-.16,0,-.08),'ForearmRight':(-.55,0,0),'HandRight':(0,0,-.20),'Torso':(0,.02,0),'ArmLeft':(-.16,0,.08),'ForearmLeft':(-.45,0,0)})}

def interpolate_pose(keys,frame):
    first,second=keys[0],keys[-1]
    for lo,hi in zip(keys,keys[1:]):
        if lo[0]<=frame<=hi[0]:first,second=lo,hi;break
    t=(frame-first[0])/max(1,second[0]-first[0]);t=t*t*(3-2*t)
    return {name:tuple(first[1].get(name,(0,0,0))[i]*(1-t)+second[1].get(name,(0,0,0))[i]*t for i in range(3))
            for name in set(first[1])|set(second[1])}

for clip,length in [('idle',24),('sword_idle',24),('sword_attack',12),('sword_guard',12),('death',24)]:
    action=bpy.data.actions.new(clip);action.use_fake_user=True;rig.animation_data.action=action
    floor_rows[clip]=[]
    for frame in range(length+1):
        scene.frame_set(frame);reset()
        if clip in ['idle','sword_idle']:
            pose=idle if clip=='idle' else sword_idle
            for name,angles in pose.items():rotate(name,angles)
            phase=frame/length*math.tau
            rotate('Head',(0,0,.008*math.sin(phase)))
            rig.pose.bones['Torso'].location.y=.002*math.sin(phase)
        elif clip=='death':
            t=frame/length;t=t*t*(3-2*t)
            rotate('Root',(math.pi/2*t,0,0))
            rotate('Head',(.03*t,0,0))
        else:
            keys=[(0,sword_idle),(3,windup),(6,impact),(9,follow),(12,sword_idle)] if clip=='sword_attack' else [(0,sword_idle),(4,guard),(8,guard),(12,sword_idle)]
            for name,angles in interpolate_pose(keys,frame).items():rotate(name,angles)
        floor_rows[clip].append(frame_key())
rig.animation_data.action=None;reset();scene.frame_set(0);bpy.context.view_layer.update()
assert set(old_actions).issubset(bpy.data.actions.keys())
triangles=0
for obj in meshes:obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
assert triangles==10655
a.output.mkdir(parents=True)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
native=a.output/'ren_runtime.blend';glb=a.output/'ren_runtime.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
report={'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'recipe':a.recipe,'triangles':triangles,'bones':19,
        'original_clips':sorted(old_actions),'added_clips':['idle','sword_idle','sword_attack','sword_guard','death'],
        'fps':24,'floor_samples':floor_rows,'sword_in_body_budget':False,
        'grip_rest_blender':[-.43,.01,.94],'blade_axis_blender':list(blade_axis),
        'geometry_or_weights_changed':False,'original_action_curves_changed':False,
        'gates':{'motion':'NOT_TESTED','visual':'NOT_TESTED','formal_game':'NOT_STARTED'},
        'outputs':{path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in [native,glb]}}
(a.output/'build_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('REN_EQUIPMENT_ACTIONS',len(bpy.data.actions),'clips',triangles,'triangles',flush=True)
