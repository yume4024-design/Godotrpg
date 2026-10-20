"""Bind the 2026-10-20 Ren surface in a new directory, preserving formal assets.

Landmarks and regional exclusions were inspected on this particular 1.95m mesh.
This is not a general automatic humanoid rigger. Geometry/UVs are never changed.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
if a.output.exists():
    raise FileExistsError(a.output)
expected = 'f94a54b6eec3875f137e6dd87b79d501ef0d90b7a240f09061a80c857f14a0f0'
source_sha = hashlib.sha256(a.input.read_bytes()).hexdigest()
if source_sha != expected:
    raise ValueError('Different surface: inspect the new anatomical landmarks first')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(meshes) == 1 and not any(o.type == 'ARMATURE' for o in bpy.context.scene.objects)
body = meshes[0]
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
body.name = 'RenRebuildBody'
before = np.array([tuple(v.co) for v in body.data.vertices], dtype=np.float32)
assert abs(float(np.ptp(before[:, 2])) - 1.95) < .001
body.data.calc_loop_triangles()
assert len(body.data.loop_triangles) == 12808
uv_before = np.array([tuple(v.uv) for v in body.data.uv_layers.active.data])

spec = {'Root': ((0, 0, 0), (0, 0, 1.02), None),
        'Torso': ((0, 0, 1.02), (0, 0, 1.51), 'Root'),
        'Head': ((0, 0, 1.55), (0, 0, 1.85), 'Torso')}
for side, sign in [('Left', 1), ('Right', -1)]:
    shoulder = Vector((sign*.21, 0, 1.45))
    elbow = Vector((sign*.32, 0, 1.22))
    wrist = Vector((sign*.402, 0, 1.02))
    palm = Vector((sign*.427, 0, .925))
    fingers = Vector((sign*.438, 0, .84))
    spec.update({'Arm'+side: (shoulder, elbow, 'Torso'),
                 'Forearm'+side: (elbow, wrist, 'Arm'+side),
                 'Hand'+side: (wrist, palm, 'Forearm'+side),
                 'Fingers'+side: (palm, fingers, 'Hand'+side),
                 'Leg'+side: ((sign*.145, 0, 1.02), (sign*.18, 0, .56), 'Root'),
                 'Shin'+side: ((sign*.18, 0, .56), (sign*.19, 0, .16), 'Leg'+side),
                 'Foot'+side: ((sign*.19, 0, .16), (sign*.19, -.15, .055), 'Shin'+side),
                 'Coat'+side: ((sign*.13, 0, 1.13), (sign*.18, 0, .89), 'Torso')})
bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = 'RenRebuildRig'
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name, (head, tail, parent) in spec.items():
    bone = rig.data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    bone.use_deform = name != 'Root'
    if parent:
        bone.parent = rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
body.vertex_groups.clear()
for name in spec:
    body.vertex_groups.new(name=name)


def smooth(lo, hi, value):
    t = max(0., min(1., (value-lo)/(hi-lo)))
    return t*t*(3-2*t)


def capsule(point, name):
    head, tail = (Vector(v) for v in spec[name][:2])
    delta = tail-head
    t = max(0., min(1., (point-head).dot(delta)/delta.length_squared))
    return (point-head-delta*t).length


def normalized(values):
    selected = sorted(values.items(), key=lambda pair: pair[1], reverse=True)[:4]
    total = sum(weight for _, weight in selected)
    assert total > 0 and math.isfinite(total)
    return {name: weight/total for name, weight in selected if weight/total > 1e-8}


hands, coat, hips = [], [], []
for vertex in body.data.vertices:
    point = vertex.co
    x, y, z = point
    side = 'Left' if x >= 0 else 'Right'
    arm_names = ['Arm'+side, 'Forearm'+side, 'Hand'+side, 'Fingers'+side]
    # The sleeves, forearms and hanging fingers are separated from the pelvis.
    # A smooth inner-arm blend prevents a hard waist/shoulder seam.
    boundary = max(.245, .21+(1.45-z)*(.402-.21)/(1.45-1.02)-.085)
    # The inner fingers reach x=.34 near z=.92. The old straight arm plane
    # crossed their geometry. Widen only the lower-hand corridor, keeping the
    # front belt pouch out with a continuous depth mask.
    lower_hand = 1-smooth(.98, 1.13, z)
    lower_hand *= smooth(-.14, -.08, y)
    boundary -= .075*lower_hand
    boundary = max(.245+.040*(1-smooth(1.0, 1.10, z)), boundary)
    arm_mix = smooth(boundary-.025, boundary+.035, abs(x)) if .77 < z < 1.51 else 0.
    if .80 < z < 1.10 and abs(x) > .355 and y > -.08:
        hands.append(vertex.index)
    if z > 1.50:
        head_mix = smooth(1.50, 1.60, z)
        weights = {'Head': head_mix, 'Torso': 1-head_mix}
    else:
        if z < 1.11:
            leg_mix = 1-smooth(.98, 1.11, z)
            knee_mix = 1-smooth(.49, .64, z)
            foot_mix = 1-smooth(.16, .27, z)
            weights = {'Torso': 1-leg_mix,
                       'Leg'+side: leg_mix*(1-knee_mix),
                       'Shin'+side: leg_mix*knee_mix*(1-foot_mix),
                       'Foot'+side: leg_mix*knee_mix*foot_mix}
            # Short tabard/coat panels are in front/behind the trousers. Bind
            # their lower edge to coat bones without pulling in outer fingers.
            cloth = smooth(.065, .13, abs(y))*(1-smooth(.98, 1.13, z))
            cloth *= smooth(.84, .91, z)*(1-smooth(.28, .34, abs(x)))
            if cloth > .8:
                coat.append(vertex.index)
            weights = {name: weight*(1-cloth) for name, weight in weights.items()}
            weights['Coat'+side] = cloth
        else:
            weights = {'Torso': 1.}
        if arm_mix > 0:
            arm_weights = {name: 1/(capsule(point, name)+.025)**4 for name in arm_names}
            total = sum(arm_weights.values())
            weights = {name: weight*(1-arm_mix) for name, weight in weights.items()}
            for name, weight in arm_weights.items():
                weights[name] = weight/total*arm_mix
        if .84 < z < 1.01 and abs(x) < .26:
            hips.append(vertex.index)
    for name, weight in normalized(weights).items():
        body.vertex_groups[name].add([vertex.index], weight, 'REPLACE')
assert len(hands) > 100
for index in hands:
    assert all(body.vertex_groups[g.group].name.startswith(('Arm', 'Forearm', 'Hand', 'Fingers'))
               for g in body.data.vertices[index].groups)
for index in hips:
    assert not any(body.vertex_groups[g.group].name.startswith(('Arm', 'Forearm', 'Hand', 'Fingers'))
                   for g in body.data.vertices[index].groups)
error = max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices)
assert error < 1e-5
assert max(len(v.groups) for v in body.data.vertices) <= 4
assert np.array_equal(before, np.array([tuple(v.co) for v in body.data.vertices], dtype=np.float32))
assert np.array_equal(uv_before, np.array([tuple(v.uv) for v in body.data.uv_layers.active.data]))
body.parent = rig
body.modifiers.new('RenRebuildSkin', 'ARMATURE').object = rig
scene = bpy.context.scene
scene.render.fps = 24
rig.animation_data_create()
recipes = {'attack': {'ArmRight': (-.35, .1, 0), 'ForearmRight': (-.3, 0, 0), 'Torso': (0, .08, 0)},
           'cast': {'ArmLeft': (-.35, 0, .12), 'ArmRight': (-.22, 0, -.12),
                    'ForearmLeft': (-.65, 0, 0), 'ForearmRight': (-.45, 0, 0), 'Head': (-.04, 0, 0)},
           'guard': {'ArmLeft': (-.16, 0, .08), 'ArmRight': (-.16, 0, -.08),
                     'ForearmLeft': (-.32, 0, 0), 'ForearmRight': (-.32, 0, 0)},
           'hit': {'Torso': (-.09, 0, 0), 'Head': (.06, 0, 0),
                   'ShinLeft': (.08, 0, 0), 'ShinRight': (.08, 0, 0)},
           'potion': {'ArmLeft': (-.2, 0, 0), 'ForearmLeft': (-.45, 0, 0)}}


def floor_height():
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    value = min(v.co.z for v in mesh.vertices)
    evaluated.to_mesh_clear()
    return value


def reset():
    for bone in rig.pose.bones:
        bone.rotation_mode = 'XYZ'
        bone.rotation_euler = (0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)


def keyframe(frame):
    bpy.context.view_layer.update()
    rig.pose.bones['Root'].location = rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0, 0, .002-floor_height()))
    for bone in rig.pose.bones:
        bone.keyframe_insert(data_path='rotation_euler', frame=frame, group=bone.name)
    rig.pose.bones['Root'].keyframe_insert(data_path='location', frame=frame, group='Root')


for clip, recipe in recipes.items():
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(17):
        scene.frame_set(frame)
        reset()
        pulse = math.sin(math.pi*frame/16)
        for bone in rig.pose.bones:
            bone.rotation_euler = Vector(recipe.get(bone.name, (0, 0, 0)))*pulse
        keyframe(frame)
distances, soles = {}, {}
for clip, amplitude, length in [('walk', .45, 24), ('run', .75, 16)]:
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    forward, floor = [], []
    for frame in range(length+1):
        scene.frame_set(frame)
        reset()
        for side, sign in [('Left', 1), ('Right', -1)]:
            stride = math.sin(frame/length*math.tau)*sign
            poses = {'Leg'+side: (stride*amplitude, 0, 0),
                     'Shin'+side: (max(0, -stride)*amplitude, 0, 0),
                     'Arm'+side: (-stride*amplitude*.4, 0, 0),
                     'Forearm'+side: (-.08-max(0, stride)*.08, 0, 0),
                     'Coat'+side: (.045*stride, 0, 0)}
            for name, pose in poses.items():
                rig.pose.bones[name].rotation_euler = pose
        bpy.context.view_layer.update()
        forward.append(rig.pose.bones['FootLeft'].matrix.translation.y)
        # Hold each sole orientation level; no terrain IK is claimed.
        for side in ['Left', 'Right']:
            foot = rig.pose.bones['Foot'+side]
            foot.matrix = Matrix.Translation(foot.matrix.translation) @ foot.bone.matrix_local.to_3x3().to_4x4()
        keyframe(frame)
        bpy.context.view_layer.update()
        floor.append(floor_height())
    distances[clip] = 2*(max(forward)-min(forward))
    soles[clip] = [min(floor), max(floor)]
rig.animation_data.action = None
reset()
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
a.output.mkdir(parents=True)
bpy.ops.file.pack_all()
native = a.output/'ren_rigged.blend'
glb = a.output/'ren_rigged.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()), export_format='GLB', use_selection=True,
                         export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
report = {'source': str(a.input), 'source_sha256': source_sha,
          'geometry_and_uv_exact': True, 'triangles': 12808, 'bones': len(spec),
          'clips': list(recipes)+['walk', 'run'], 'cycle_distances': distances, 'floor_samples': soles,
          'weight_sum_max_error': error, 'maximum_vertex_weights': max(len(v.groups) for v in body.data.vertices),
          'hand_weight_check_vertices': len(hands), 'coat_check_vertices': len(coat),
          'hip_weight_check_vertices': len(hips),
          'outputs': {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in [native, glb]},
          'limitations': ['Single finger group per hand; not independent fingers or a validated sword grip',
                          'No eyelid/mouth morphs, terrain IK, gameplay integration or performance acceptance',
                          'Regional weights and cloth require evaluated motion and actual visual acceptance']}
(a.output/'rig_recipe.json').write_text(json.dumps(report, indent=2), encoding='utf8')
profile = ('[gd_resource type="Resource" script_class="CharacterMotionProfile" format=3]\n'
           '[ext_resource type="Script" path="res://scripts/characters/character_motion_profile.gd" id="1"]\n'
           '[resource]\nscript = ExtResource("1")\nwalk_cycle_distance = %.9f\nrun_cycle_distance = %.9f\n'
           % (distances['walk'], distances['run']))
(a.output/'ren_motion_profile.tres').write_text(profile, encoding='utf8')
print('REN_REBUILD_RIG', json.dumps(report), flush=True)
