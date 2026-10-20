"""Anatomical skin isolation and vertical elbow fold on a new owned bat copy.

Geometry, UV, materials and the five established clips remain unchanged. This
produces a review candidate; numeric checks never imply full-fold approval.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Euler, Vector

p = argparse.ArgumentParser()
p.add_argument('--input', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--render', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
expected = '6f2a43b1cb59ebc4b41525bdf1245e3d66eb1e9b79f8111ee0a3312d0c847026'
assert hashlib.sha256(a.input.read_bytes()).hexdigest() == expected
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
body = next(o for o in scene.objects if o.type == 'MESH')
assert len(body.data.polygons) == 8712
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = None
points = np.array([tuple(v.co) for v in body.data.vertices])
original_weights = np.zeros((len(points), len(body.vertex_groups)))
for vertex in body.data.vertices:
    for g in vertex.groups:
        original_weights[vertex.index, g.group] = g.weight
weights = original_weights.copy()


def smooth(low, high, value):
    t = np.clip((value - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


x, y, z = points.T
absx = abs(x)
# Reviewed anatomy: the actual wing ends below z=.831, ears reach 1.085.
# The face projects forward to y=-.599 while the wing attaches behind it.
ear = smooth(.815, .855, z)
head = (1 - smooth(.27, .345, absx)) * smooth(.60, .69, z)
face = (1 - smooth(.30, .355, absx)) * (1 - smooth(-.22, -.15, y)) * smooth(.36, .55, z)
head_mask = np.maximum(ear, np.maximum(head, face))
wing_indices = [g.index for g in body.vertex_groups if g.name.startswith('Wing')]
nonwing_indices = [g.index for g in body.vertex_groups if not g.name.startswith('Wing')]
removed = weights[:, wing_indices].sum(1) * head_mask
weights[:, wing_indices] *= 1 - head_mask[:, None]
nonwing = weights[:, nonwing_indices].sum(1)
for index in nonwing_indices:
    ratio = weights[:, index] / np.maximum(nonwing, 1e-8)
    weights[:, index] += removed * ratio
missing = nonwing < 1e-8
weights[missing, body.vertex_groups['Head'].index] += removed[missing]

# Replace contaminated outer wing skin with a continuous shoulder / wrist
# blend, using identical weights at coincident UV seams. Keep the central
# shoulder attached to the body. No smoothing across ears, crystals or body.
wing_mask = smooth(.225, .345, absx) * (1 - head_mask) * smooth(.18, .27, z)
tip = smooth(.405, .515, absx)
new_wing = np.zeros_like(weights)
for side, positive in [('Left', True), ('Right', False)]:
    selected = (x >= 0) if positive else (x < 0)
    new_wing[selected, body.vertex_groups['Wing' + side].index] = 1 - tip[selected]
    new_wing[selected, body.vertex_groups['WingTip' + side].index] = tip[selected]
weights = weights * (1 - wing_mask[:, None]) + new_wing * wing_mask[:, None]
# The authored glTF contract permits at most four normalized influences.
order = np.argsort(weights, axis=1)[:, :-4]
np.put_along_axis(weights, order, 0, axis=1)
weights /= weights.sum(1)[:, None]
for group in body.vertex_groups:
    group.remove(list(range(len(points))))
for i, row in enumerate(weights):
    for g in np.flatnonzero(row > 1e-8):
        body.vertex_groups[int(g)].add([i], float(row[g]), 'REPLACE')

old_fold = bpy.data.actions['fold_wings']
bpy.data.actions.remove(old_fold)
action = bpy.data.actions.new('fold_wings')
action.use_fake_user = True
rig.animation_data_create()
rig.animation_data.action = action
scene.render.fps = 24


def reset():
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1, 0, 0, 0)
        bone.location = (0, 0, 0)
        bone.scale = (1, 1, 1)


def rotate(name, angles):
    basis = rig.data.bones[name].matrix_local.to_quaternion()
    rig.pose.bones[name].rotation_quaternion = basis.inverted() @ Euler(angles, 'XYZ').to_quaternion() @ basis


for frame in range(61):
    scene.frame_set(frame)
    reset()
    t = frame / 60
    # Deliberate hold makes the complete tuck inspectable before reopening.
    fold = float(smooth(0, .4, t) * (1 - smooth(.6, 1, t)))
    for side, sign in [('Left', 1), ('Right', -1)]:
        rotate('Wing' + side, (0, sign * 1.15 * fold, 0))
        rotate('WingTip' + side, (0, -sign * 2.35 * fold, 0))
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    mesh = evaluated.to_mesh()
    floor = min(v.co.z for v in mesh.vertices)
    evaluated.to_mesh_clear()
    rig.pose.bones['Root'].location = rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0, 0, .147 - floor))
    for bone in rig.pose.bones:
        bone.keyframe_insert(data_path='rotation_quaternion', frame=frame, group=bone.name)
        bone.keyframe_insert(data_path='scale', frame=frame, group=bone.name)
    rig.pose.bones['Root'].keyframe_insert(data_path='location', frame=frame, group='Root')
rig.animation_data.action = None
reset()
scene.frame_set(0)
bpy.context.view_layer.update()
a.output.mkdir(parents=True)
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output / 'bat_fold.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output / 'bat_fold.glb').resolve()), export_format='GLB',
                         use_selection=True, export_animations=True,
                         export_animation_mode='ACTIONS', export_frame_range=False)
report = {'input': str(a.input), 'source_sha256': expected, 'triangles': 8712,
          'bones': len(rig.data.bones), 'head_mask_vertices': int((head_mask > .99).sum()),
          'wing_rebind_vertices': int((wing_mask > .01).sum()),
          'fully_isolated_head_max_wing_weight': float(weights[head_mask > .999][:, wing_indices].sum(1).max()),
          'weight_sum_error': float(abs(weights.sum(1) - 1).max()),
          'geometry_uv_material_edits': False, 'preserved_clips': ['idle', 'walk', 'attack', 'hit', 'death'],
          'fold': {'axis': 'world Y (vertical tuck)', 'root_radians': 1.15, 'tip_radians': -2.35,
                   'frames': 61, 'hold': [24, 36]},
          'full_fold_gate': 'HUMAN_REVIEW', 'formal_integration': 'NOT_STARTED'}
(a.output / 'repair_report.json').write_text(json.dumps(report, indent=2), encoding='utf8', newline='\n')
print('BAT_ANATOMICAL_CANDIDATE', json.dumps(report), flush=True)

if a.render:
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 12
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'Standard'
    scene.world = bpy.data.worlds.new('BatReviewWorld')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.12, .16, .20, 1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .6
    camera_data = bpy.data.cameras.new('BatReviewCamera')
    camera = bpy.data.objects.new(camera_data.name, camera_data)
    scene.collection.objects.link(camera)
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 1.85
    scene.camera = camera
    for i, (pos, energy) in enumerate([((2, -4, 4), 450), ((-3, -1, 2), 250), ((0, 3, 3), 350)]):
        light_data = bpy.data.lights.new('BatReviewLight' + str(i), 'AREA')
        light_data.energy = energy
        light_data.shape, light_data.size = 'DISK', 3
        light = bpy.data.objects.new(light_data.name, light_data)
        scene.collection.objects.link(light)
        light.location = pos
        light.rotation_euler = (Vector((0, 0, .6)) - light.location).to_track_quat('-Z', 'Y').to_euler()
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]
    for frame in [0, 30]:
        scene.frame_set(frame)
        for view, pos in [('front', (0, -4, .65)), ('right', (4, 0, .65)), ('back', (0, 4, .65)), ('left', (-4, 0, .65))]:
            camera.location = pos
            camera.rotation_euler = (Vector((0, 0, .65)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
            scene.render.filepath = str((a.output / f'fold_{frame}_{view}.png').resolve())
            bpy.ops.render.render(write_still=True)
