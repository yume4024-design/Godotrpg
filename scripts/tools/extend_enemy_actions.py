"""Blender: add species-specific clips to a new copy, preserving mesh/weights."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Euler, Vector

p = argparse.ArgumentParser()
p.add_argument('--asset', required=True, choices=['thorn_boar', 'corrupted_guardian'])
p.add_argument('--input', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
scene = bpy.context.scene
scene.render.fps = 24
created = []


def smooth(low, high, value):
    t = max(0, min(1, (value - low) / (high - low)))
    return t * t * (3 - 2 * t)


def rotation(name, angles):
    basis = rig.data.bones[name].matrix_local.to_quaternion()
    rig.pose.bones[name].rotation_quaternion = basis.inverted() @ Euler(angles, 'XYZ').to_quaternion() @ basis


def floor():
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    minimum = min(v.co.z for v in mesh.vertices)
    evaluated.to_mesh_clear()
    return minimum


clips = {'run': 18, 'charge': 32} if a.asset == 'thorn_boar' else {'heavy_attack': 42, 'special_attack': 48, 'stagger': 30}
for name, length in clips.items():
    if name in bpy.data.actions:
        raise ValueError('Do not replace an existing action: ' + name)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    for frame in range(length + 1):
        scene.frame_set(frame)
        t = frame / length
        phase = t * math.tau
        pulse = math.sin(math.pi * t) ** 2
        forward = 0.0
        bob = 0.0
        for bone in rig.pose.bones:
            bone.rotation_mode = 'QUATERNION'
            bone.rotation_quaternion = (1, 0, 0, 0)
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
        if a.asset == 'thorn_boar':
            strength = 1.0 if name == 'run' else smooth(.18, .4, t) * (1 - smooth(.66, .98, t))
            gait = phase if name == 'run' else phase * 2.0
            for side, sign in [('Left', 1), ('Right', -1)]:
                for station, offset in [('Front', 0), ('Back', math.pi)]:
                    stride = math.sin(gait + offset) * sign * strength
                    stride_angle = .30 if name == 'run' else .18
                    knee_angle = .17 if name == 'run' else .10
                    rotation('Leg' + station + side, (stride_angle * stride, 0, .025 * stride))
                    rotation('Foot' + station + side, (-knee_angle * max(0, -stride), 0, 0))
            rotation('Tail', (0, .10 * math.sin(gait) * strength, 0))
            if name == 'run':
                rotation('Body', (.025 * math.sin(phase * 2), 0, 0))
                bob = .012 * (1 - math.cos(phase * 2))
            else:
                windup = smooth(0, .24, t) * (1 - smooth(.24, .42, t))
                rotation('Body', (-.04 * windup + .035 * strength, 0, 0))
                rotation('Head', (-.08 * windup + .16 * strength, 0, 0))
                forward = -.18 * strength
        else:
            if name == 'heavy_attack':
                windup = smooth(0, .4, t) * (1 - smooth(.45, .62, t))
                slam = smooth(.45, .60, t) * (1 - smooth(.66, 1, t))
                rotation('Chest', (-.045 * windup + .11 * slam, 0, 0))
                for side in ['Left', 'Right']:
                    rotation('Arm' + side, (-.46 * windup + .23 * slam, 0, 0))
                    rotation('Forearm' + side, (-.17 * windup + .12 * slam, 0, 0))
            elif name == 'special_attack':
                rotation('Chest', (-.04 * pulse, 0, .035 * pulse * math.sin(phase)))
                for side, sign in [('Left', 1), ('Right', -1)]:
                    rotation('Arm' + side, (-.34 * pulse, sign * .08 * pulse, -sign * .10 * pulse))
                    rotation('Forearm' + side, (-.18 * pulse, 0, 0))
                rotation('Head', (.07 * pulse, 0, 0))
            else:
                sway = math.sin(phase * 2) * pulse
                rotation('Chest', (-.14 * pulse, 0, .065 * sway))
                rotation('Head', (.07 * pulse, 0, -.035 * sway))
                for side, sign in [('Left', 1), ('Right', -1)]:
                    rotation('Arm' + side, (.08 * pulse, 0, sign * .04 * pulse))
                    rotation('Shin' + side, (-.045 * pulse, 0, 0))
        bpy.context.view_layer.update()
        shift = .004 + bob - floor()
        rig.pose.bones['Root'].location = rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0, forward, shift))
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='rotation_quaternion', frame=frame, group=bone.name)
            bone.keyframe_insert(data_path='scale', frame=frame, group=bone.name)
        rig.pose.bones['Root'].keyframe_insert(data_path='location', frame=frame, group='Root')
    created.append(name)
rig.animation_data.action = None
for bone in rig.pose.bones:
    bone.rotation_quaternion = (1, 0, 0, 0)
    bone.location = (0, 0, 0)
    bone.scale = (1, 1, 1)
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output / 'extended.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output / 'extended.glb').resolve()), export_format='GLB', use_selection=True,
                         export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
(a.output / 'extension.json').write_text(json.dumps({'asset': a.asset, 'input': str(a.input),
    'added_clips': created, 'mesh_or_weight_edits': False, 'fps': 24,
    'root_translation': 'Floor compensated; charge visual offset <= 0.18m, no gameplay movement'}, indent=2), encoding='utf8')
print('SPECIES_ACTIONS_ADDED', a.asset, created, flush=True)
