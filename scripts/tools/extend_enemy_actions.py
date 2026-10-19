"""Blender: add species-specific clips to a new copy, preserving mesh/weights."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Euler, Vector
from mathutils.kdtree import KDTree

p = argparse.ArgumentParser()
p.add_argument('--asset', required=True, choices=['thorn_boar', 'crystal_bat', 'corrupted_guardian'])
p.add_argument('--input', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--smooth-wing-weights', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
scene = bpy.context.scene
scene.render.fps = 24
created = []
weight_edits = False
if a.smooth_wing_weights:
    if a.asset != 'crystal_bat':
        raise ValueError('Wing smoothing is specific to the inspected bat seam')
    vertices = list(body.data.vertices)
    weights = np.zeros((len(vertices), len(body.vertex_groups)))
    for vertex in vertices:
        for group in vertex.groups:
            weights[vertex.index, group.group] = group.weight
    points = np.array([tuple(v.co) for v in vertices])
    width, height = np.ptp(points[:, 0]), np.ptp(points[:, 2])
    wing_indices = [g.index for g in body.vertex_groups if g.name.startswith('Wing')]
    wing_strength = weights[:, wing_indices].sum(axis=1)
    def ramp(low, high, values):
        t = np.clip((values-low)/(high-low), 0, 1)
        return t*t*(3-2*t)
    factor = .85 * ramp(.2, .6, wing_strength) * ramp(.10, .18, np.abs(points[:, 0])/width)
    factor *= ramp(.25, .35, points[:, 2]/height) * (1-ramp(.82, .9, points[:, 2]/height))
    tree = KDTree(len(vertices))
    for index, point in enumerate(points): tree.insert(Vector(point), index)
    tree.balance()
    # The inspected seam joins separately sampled front/back membrane strips.
    # Geodesic adjacency alone widened it; use a bounded spatial Gaussian so
    # vertices only millimetres apart receive continuous influence weights.
    sigma = height * .035
    neighborhoods = []
    for point in points:
        found = tree.find_range(Vector(point), sigma * 3)
        indices = np.array([value[1] for value in found])
        influence = np.exp(-np.square([value[2] / sigma for value in found]) * .5)
        neighborhoods.append((indices, influence / influence.sum()))
    for iteration in range(3):
        adjacent = np.array([(weights[indices] * influence[:, None]).sum(axis=0)
                             for indices, influence in neighborhoods])
        weights = weights*(1-factor[:, None]) + adjacent*factor[:, None]
        # Retain the engine's maximum four skin influences.
        order = np.argsort(weights, axis=1)[:, :-4]
        np.put_along_axis(weights, order, 0, axis=1)
        weights /= weights.sum(axis=1)[:, None]
    for group in body.vertex_groups:
        group.remove(list(range(len(vertices))))
    for index, row in enumerate(weights):
        for group in np.flatnonzero(row > 1e-8):
            body.vertex_groups[int(group)].add([index], float(row[group]), 'REPLACE')
    weight_edits = True


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


clips = ({'run': 18, 'charge': 32} if a.asset == 'thorn_boar' else
         {'fold_wings': 36} if a.asset == 'crystal_bat' else
         {'heavy_attack': 42, 'special_attack': 48, 'stagger': 30})
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
        elif a.asset == 'crystal_bat':
            # A separate forward tuck; unlike flap, this rotates about Z-up.
            # Return to the full span at the end for transition inspection.
            for side, sign in [('Left', 1), ('Right', -1)]:
                rotation('Wing' + side, (0, 0, -sign * .55 * pulse))
                rotation('WingTip' + side, (0, 0, -sign * .35 * pulse))
        else:
            if name == 'heavy_attack':
                windup = smooth(0, .4, t) * (1 - smooth(.45, .62, t))
                slam = smooth(.45, .60, t) * (1 - smooth(.66, 1, t))
                rotation('Chest', (-.035 * windup + .085 * slam, 0, 0))
                for side in ['Left', 'Right']:
                    rotation('Arm' + side, (-.38 * windup + .23 * slam, 0, 0))
                    rotation('Forearm' + side, (-.16 * windup + .12 * slam, 0, 0))
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
        shift = .004 + (.143 if a.asset == 'crystal_bat' else 0) + bob - floor()
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
    'added_clips': created, 'mesh_geometry_edits': False, 'wing_weight_smoothing': weight_edits, 'fps': 24,
    'root_translation': 'Floor compensated; charge visual offset <= 0.18m, no gameplay movement'}, indent=2), encoding='utf8')
print('SPECIES_ACTIONS_ADDED', a.asset, created, flush=True)
