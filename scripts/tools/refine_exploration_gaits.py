"""Re-author only locomotion on preserved Pixal rigs; keep source meshes/battle clips."""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--character', choices=['ren', 'lia'], required=True)
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
name = args.character
source = ROOT / f'assets/source/pixal3d/{name}_rigged.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
body = bpy.data.objects['RenBody' if name == 'ren' else 'LiaBody']
report = {'character': name, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'clips': {}}
for clip, amplitude, length in [('walk', .32, 24), ('run', .75, 16)]:
    old = bpy.data.actions.get(clip)
    if rig.animation_data.action == old:
        rig.animation_data.action = None
    if old:
        bpy.data.actions.remove(old)
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    sole_samples, forward_samples, lateral_samples = [], [], []
    for frame in range(length + 1):
        bpy.context.scene.frame_set(frame)
        for bone in rig.pose.bones:
            bone.rotation_mode = 'XYZ'
            bone.rotation_euler = (0, 0, 0)
            bone.location = Vector((0, 0, 0))
        for side, sign in [('Left', 1), ('Right', -1)]:
            stride = math.sin(frame / length * math.tau) * sign
            leg = rig.pose.bones['Leg' + side]
            # Inward correction in model space, converted to this bone's rest axes.
            axis = leg.bone.matrix_local.to_3x3().inverted() @ Vector((0, 1, 0))
            leg.rotation_euler = (Quaternion(axis, sign * .055) @ Euler((stride * amplitude, 0, 0)).to_quaternion()).to_euler('XYZ')
            rig.pose.bones['Shin' + side].rotation_euler = (max(0, -stride) * amplitude, 0, 0)
            rig.pose.bones['Arm' + side].rotation_euler = (-stride * amplitude * .45, 0, 0)
            rig.pose.bones['Forearm' + side].rotation_euler = (-.65 if clip == 'run' else -.12, 0, 0)
        bpy.context.view_layer.update()
        forward_samples.append(rig.pose.bones['FootLeft'].matrix.translation.y)
        lateral_samples.append(abs(rig.pose.bones['FootLeft'].matrix.translation.x - rig.pose.bones['FootRight'].matrix.translation.x))
        for side in ['Left', 'Right']:
            foot = rig.pose.bones['Foot' + side]
            foot.matrix = Matrix.Translation(foot.matrix.translation) @ foot.bone.matrix_local.to_3x3().to_4x4()
        bpy.context.view_layer.update()
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        lowest = min(vertex.co.z for vertex in evaluated.data.vertices)
        rig.pose.bones['Root'].location = rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0, 0, .002 - lowest))
        bpy.context.view_layer.update()
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        sole_samples.append(min(vertex.co.z for vertex in evaluated.data.vertices))
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='rotation_euler', frame=frame, group=bone.name)
        rig.pose.bones['Root'].keyframe_insert(data_path='location', frame=frame, group='Root')
    distance = 2 * (max(forward_samples) - min(forward_samples))
    report['clips'][clip] = {'cycle_distance_m': distance, 'duration_s': length / 24, 'foot_lateral_span_m': [min(lateral_samples), max(lateral_samples)], 'floor_m': [min(sole_samples), max(sole_samples)]}
rig.animation_data.action = None
for bone in rig.pose.bones:
    # Existing battle actions animate Euler tracks; restore that mode on export.
    bone.rotation_mode = 'XYZ'
    bone.rotation_euler = (0, 0, 0)
    bone.location = (0, 0, 0)
bpy.context.scene.frame_set(0)
bpy.context.scene.render.fps = 24
output = ROOT / 'assets/models/pixal3d' / f'{name}_locomotion.glb'
blend = ROOT / 'assets/source/pixal3d/locomotion' / f'{name}.blend'
blend.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
report['output_sha256'] = hashlib.sha256(output.read_bytes()).hexdigest()
evidence = ROOT / 'source_assets/exploration_locomotion_20261021'
evidence.mkdir(parents=True, exist_ok=True)
(evidence / f'{name}_authoring.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
profile = ROOT / f'assets/models/pixal3d/{name}_locomotion_profile.tres'
profile.write_text('[gd_resource type="Resource" script_class="CharacterMotionProfile" format=3]\n[ext_resource type="Script" path="res://scripts/characters/character_motion_profile.gd" id="1"]\n[resource]\nscript = ExtResource("1")\nwalk_cycle_distance = %.9f\nrun_cycle_distance = %.9f\n' % (report['clips']['walk']['cycle_distance_m'], report['clips']['run']['cycle_distance_m']), encoding='utf-8')
print('EXPLORATION_GAIT', json.dumps(report))
