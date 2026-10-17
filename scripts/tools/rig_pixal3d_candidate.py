"""Build a fresh proportioned humanoid rig on a preserved Pixal3D candidate."""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector, Matrix

parser = argparse.ArgumentParser()
parser.add_argument("--character", choices=["ren", "lia"], required=True)
args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
root = Path(__file__).resolve().parents[2]
name = args.character
bpy.ops.wm.open_mainfile(filepath=str(root / f"artifacts/pixal3d/{name}/face.blend"))
for image in bpy.data.images:
    largest = max(image.size)
    if largest>1024:
        image.scale(round(image.size[0]*1024/largest),round(image.size[1]*1024/largest))
        image.pack()
body = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH" and not obj.get("pixal_head_attachment"))
body.name = "LiaBody" if name == "lia" else "RenBody"
points = [vertex.co for vertex in body.data.vertices]
outer = sorted(abs(point.x) for point in points if .91<point.z<1.00 and abs(point.x)>.28)
assert outer, "Hand landmark not found"
wrist_x = outer[int(len(outer)*.75)]-.012
wrist_z = .96
spec = {"Root": ((0,0,0),(0,0,1),None), "Torso": ((0,0,1),(0,0,1.5),"Root"), "Head": ((0,0,1.54),(0,0,1.82),"Torso")}
for side, sign in [("Left",1),("Right",-1)]:
    shoulder = Vector((sign*.21,0,1.45))
    wrist = Vector((sign*wrist_x,0,wrist_z))
    elbow = shoulder.lerp(wrist,.52)
    hand_end = wrist+(wrist-elbow).normalized()*.10
    finger_end = hand_end+(wrist-elbow).normalized()*.075
    spec.update({"Arm"+side:(shoulder,elbow,"Torso"), "Forearm"+side:(elbow,wrist,"Arm"+side), "Hand"+side:(wrist,hand_end,"Forearm"+side), "Fingers"+side:(hand_end,finger_end,"Hand"+side), "Leg"+side:((sign*.14,0,.99),(sign*.17,0,.55),"Root"), "Shin"+side:((sign*.17,0,.55),(sign*.18,0,.14),"Leg"+side), "Foot"+side:((sign*.18,0,.14),(sign*.18,-.16,.05),"Shin"+side), "Coat"+side:((sign*.14,0,1.03),(sign*.20,0,.83),"Root")})
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = ("Lia" if name=="lia" else "Ren")+"PixalRig"
bpy.ops.object.mode_set(mode="EDIT")
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for bone_name,(head,tail,parent) in spec.items():
    bone = rig.data.edit_bones.new(bone_name)
    bone.head = head
    bone.tail = tail
    if parent: bone.parent = rig.data.edit_bones[parent]
    bone.use_deform = bone_name!="Root" and not bone_name.startswith("Coat")
bpy.ops.object.mode_set(mode="OBJECT")
# Smooth distance weights restricted by body region; no reuse of old mesh geometry.
for bone_name in spec: body.vertex_groups.new(name=bone_name)
def smooth(low,high,value):
    t = max(0,min(1,(value-low)/(high-low)))
    return t*t*(3-2*t)
def assign(vertex,weights):
    total = sum(weights.values())
    for bone_name,weight in weights.items():
        if weight>.00001: body.vertex_groups[bone_name].add([vertex.index],weight/total,"REPLACE")
for vertex in body.data.vertices:
    x,y,z = vertex.co
    side = "Left" if x>=0 else "Right"
    arm_boundary = max(.23,.21+(1.45-z)*(wrist_x-.21)/(1.45-wrist_z)-.11)
    if z>1.50:
        head_weight = smooth(1.50,1.62,z)
        assign(vertex,{"Head":head_weight,"Torso":1-head_weight})
    elif abs(x)>arm_boundary and z>.70:
        attachment = smooth(.21,.30,abs(x))
        lower = 1-smooth(elbow.z-.07,elbow.z+.07,z)
        hand = 1-smooth(wrist_z-.02,wrist_z+.06,z)
        fingers = 1-smooth(.80,.88,z)
        assign(vertex,{"Arm"+side:attachment*(1-lower),"Forearm"+side:attachment*lower*(1-hand),"Hand"+side:attachment*lower*hand*(1-fingers),"Fingers"+side:attachment*lower*hand*fingers,"Torso":1-attachment})
    elif z<1.05:
        leg_weight = 1-smooth(.93,1.05,z)
        lower = 1-smooth(.49,.61,z)
        foot = 1-smooth(.14,.25,z)
        assign(vertex,{"Leg"+side:leg_weight*(1-lower),"Shin"+side:leg_weight*lower*(1-foot),"Foot"+side:leg_weight*lower*foot,"Torso":1-leg_weight})
    else:
        assign(vertex,{"Torso":1})
for vertex in body.data.vertices:
    if .78<vertex.co.z<.99 and abs(vertex.co.x)<.30:
        arm_weight = sum(group.weight for group in vertex.groups if body.vertex_groups[group.group].name.startswith(("Arm","Forearm","Hand","Fingers")))
        assert arm_weight<.01, "Hip accidentally bound to an arm"
    if .72<vertex.co.z<1.02 and abs(vertex.co.x)>wrist_x-.02:
        leg_weight = sum(group.weight for group in vertex.groups if body.vertex_groups[group.group].name.startswith(("Leg","Shin","Foot")))
        assert leg_weight<.01, "Outer hand accidentally bound to a leg"
body.parent = rig
modifier = body.modifiers.new("PixalSkin","ARMATURE")
modifier.object = rig
face_objects = [obj for obj in bpy.context.scene.objects if obj.get("pixal_head_attachment")]
for obj in face_objects:
    obj.parent = rig
    obj.vertex_groups.new(name="Head").add(list(range(len(obj.data.vertices))),1,"REPLACE")
    face_skin = obj.modifiers.new("FaceSkin","ARMATURE")
    face_skin.object = rig
error = max(abs(sum(group.weight for group in vertex.groups)-1) for vertex in body.data.vertices)
assert error<.00001
recipes = {"attack":{"ArmRight":(-.35,.1,0),"ForearmRight":(-.3,0,0),"Torso":(0,.08,0)}, "cast":{"ArmLeft":(-.35,0,.12),"ArmRight":(-.22,0,-.12),"ForearmLeft":(-.65,0,0),"ForearmRight":(-.45,0,0),"Head":(-.04,0,0)}, "guard":{"ArmLeft":(-.16,0,.08),"ArmRight":(-.16,0,-.08),"ForearmLeft":(-.32,0,0),"ForearmRight":(-.32,0,0)}, "hit":{"Torso":(-.09,0,0),"Head":(.06,0,0),"ShinLeft":(.08,0,0),"ShinRight":(.08,0,0)}, "potion":{"ArmLeft":(-.2,0,0),"ForearmLeft":(-.45,0,0)}}
rig.animation_data_create()
for clip,recipe in recipes.items():
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in [0,4,8,12,16]:
        for bone in rig.pose.bones:
            bone.rotation_mode = "XYZ"
            bone.rotation_euler = Vector(recipe.get(bone.name,(0,0,0)))*math.sin(math.pi*frame/16)
            bone.keyframe_insert(data_path="rotation_euler",frame=frame,group=bone.name)
distances = {}
floor_samples = {}
for clip,amplitude,length in [("walk",.45,24),("run",.75,16)]:
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    sole_samples,forward_samples = [],[]
    for frame in range(length+1):
        bpy.context.scene.frame_set(frame)
        rig.pose.bones["Root"].location = (0,0,0)
        pose = {}
        for side,sign in [("Left",1),("Right",-1)]:
            stride = math.sin(frame/length*math.tau)*sign
            pose.update({"Leg"+side:(stride*amplitude,0,0),"Shin"+side:(max(0,-stride)*amplitude,0,0),"Arm"+side:(-stride*amplitude*.4,0,0),"Forearm"+side:(-.08-max(0,stride)*.08,0,0)})
        for bone in rig.pose.bones: bone.rotation_euler = pose.get(bone.name,(0,0,0))
        bpy.context.view_layer.update()
        forward_samples.append(rig.pose.bones["FootLeft"].matrix.translation.y)
        for side in ["Left","Right"]:
            foot = rig.pose.bones["Foot"+side]
            foot.matrix = Matrix.Translation(foot.matrix.translation) @ foot.bone.matrix_local.to_3x3().to_4x4()
        bpy.context.view_layer.update()
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        lowest = min(vertex.co.z for vertex in evaluated.data.vertices)
        rig.pose.bones["Root"].location = rig.data.bones["Root"].matrix_local.to_3x3().inverted() @ Vector((0,0,.002-lowest))
        bpy.context.view_layer.update()
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        sole_samples.append(min(vertex.co.z for vertex in evaluated.data.vertices))
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path="rotation_euler",frame=frame,group=bone.name)
        rig.pose.bones["Root"].keyframe_insert(data_path="location",frame=frame,group="Root")
    distances[clip] = 2*(max(forward_samples)-min(forward_samples))
    floor_samples[clip] = [min(sole_samples),max(sole_samples)]
rig.animation_data.action = None
for bone in rig.pose.bones:
    bone.rotation_euler = (0,0,0)
    bone.location = (0,0,0)
bpy.context.scene.render.fps = 24
bpy.context.scene.frame_set(0)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
for obj in face_objects: obj.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.wm.save_as_mainfile(filepath=str(root/f"assets/source/pixal3d/{name}_rigged.blend"))
bpy.ops.export_scene.gltf(filepath=str(root/f"assets/models/pixal3d/{name}_rigged.glb"),export_format="GLB",use_selection=True,export_animations=True,export_animation_mode="ACTIONS",export_frame_range=False)
report = {"bones":len(rig.data.bones),"wrist_x":wrist_x,"wrist_z":wrist_z,"weight_sum_max_error":error,"clips":list(recipes)+["walk","run"],"cycle_distances":distances,"floor_samples":floor_samples,"limitations":"single group fingers; region weights require visual deformation acceptance; eyes have Blink morphs, no mouth morph"}
(root/f"artifacts/pixal3d/{name}/rig_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print("PIXAL_RIG",json.dumps(report))
profile = '[gd_resource type="Resource" script_class="CharacterMotionProfile" format=3]\n[ext_resource type="Script" path="res://scripts/characters/character_motion_profile.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nwalk_cycle_distance = %.9f\nrun_cycle_distance = %.9f\n' % (distances['walk'],distances['run'])
(root/f"assets/models/pixal3d/{name}_motion_profile.tres").write_text(profile,encoding="utf-8")
