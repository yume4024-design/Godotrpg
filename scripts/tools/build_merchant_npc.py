"""Bind reviewed skirted NPC copies with per-profile cloth masks; preserve geometry."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--profile', choices=['item_merchant', 'villager_female'], default='item_merchant')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
assert not any(obj.type == 'ARMATURE' for obj in bpy.context.scene.objects)
before = np.array([tuple(v.co) for v in body.data.vertices], dtype=np.float32)
assert abs(float(np.ptp(before[:, 2])) - 1.65) < .001
body.name = 'ItemMerchantBody' if a.profile == 'item_merchant' else 'VillagerFemaleBody'

spec = {'Root': ((0, 0, 0), (0, 0, .9), None),
        'Hips': ((0, 0, .91), (0, 0, 1.02), 'Root'),
        'Spine': ((0, 0, 1.02), (0, 0, 1.15), 'Hips'),
        'Chest': ((0, 0, 1.15), (0, 0, 1.27), 'Spine'),
        'Neck': ((0, 0, 1.27), (0, 0, 1.36), 'Chest'),
        'Head': ((0, 0, 1.36), (0, 0, 1.62), 'Neck'),
        'SkirtFront': ((0, -.04, .94), (0, -.12, .28), 'Hips'),
        'SkirtBack': ((0, .04, .94), (0, .12, .28), 'Hips')}
for side, sign in [('Left', 1), ('Right', -1)]:
    spec.update({'Arm' + side: ((sign*.18, 0, 1.25), (sign*.31, .03, 1.02), 'Chest'),
                 'Forearm' + side: ((sign*.31, .03, 1.02), (sign*.40, .08, .80), 'Arm' + side),
                 'Hand' + side: ((sign*.40, .08, .80), (sign*.45, .11, .67), 'Forearm' + side),
                 'Leg' + side: ((sign*.10, 0, .92), (sign*.12, 0, .48), 'Hips'),
                 'Shin' + side: ((sign*.12, 0, .48), (sign*.12, 0, .12), 'Leg' + side),
                 'Foot' + side: ((sign*.12, 0, .12), (sign*.12, -.14, .06), 'Shin' + side)})
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = 'ItemMerchantRig' if a.profile == 'item_merchant' else 'VillagerFemaleRig'
bpy.ops.object.mode_set(mode='EDIT')
rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name, (head, tail, parent) in spec.items():
    bone = rig.data.edit_bones.new(name)
    bone.head, bone.tail = head, tail
    bone.use_deform = name != 'Root'
    if parent: bone.parent = rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
body.vertex_groups.clear()
for name in spec: body.vertex_groups.new(name=name)

# Distinguish each profile's cloth from skin, boots and the belt; proximity
# fills small texture seams without assigning the hanging hands to the skirt.
image = next(node.image for node in body.data.materials[0].node_tree.nodes
             if node.type == 'TEX_IMAGE' and node.image)
pixels = np.empty(len(image.pixels), dtype=np.float32)
image.pixels.foreach_get(pixels)
pixels = pixels.reshape((image.size[1], image.size[0], 4))
seeds = set()
for loop in body.data.loops:
    vertex = body.data.vertices[loop.vertex_index]
    lower = .19 if a.profile == 'item_merchant' else .36
    if not (lower < vertex.co.z < .99 and abs(vertex.co.x) < .40): continue
    uv = body.data.uv_layers.active.data[loop.index].uv
    color = pixels[max(0, min(image.size[1]-1, int(uv.y*image.size[1]))),
                   max(0, min(image.size[0]-1, int(uv.x*image.size[0])))][:3]
    cloth_color = (color[2] > color[0]*1.15 and color[2] > color[1]*1.03) if a.profile == 'item_merchant' else (
        .04 < color[0] < .6 and color[1] < .18 and color[2] < .18 and
        color[0] > color[1]*1.5 and color[0] > color[2]*1.5)
    if cloth_color: seeds.add(vertex.index)
assert len(seeds) > 500, 'No reliable skirt colour region; inspect material before binding'
cloth = KDTree(len(seeds))
for index in seeds: cloth.insert(body.data.vertices[index].co, index)
cloth.balance()
del pixels

def smooth(low, high, value):
    t = max(0., min(1., (value-low)/(high-low)))
    return t*t*(3-2*t)

def distance(point, head, tail):
    head, tail = Vector(head), Vector(tail)
    delta = tail-head
    t = max(0., min(1., (point-head).dot(delta)/delta.length_squared))
    return (point-head-delta*t).length

hand_vertices, skirt_vertices = [], []
for vertex in body.data.vertices:
    point = vertex.co
    side = 'Left' if point.x >= 0 else 'Right'
    arm_names = ['Arm'+side, 'Forearm'+side, 'Hand'+side]
    arm_distance = min(distance(point, *spec[name][:2]) for name in arm_names)
    # The generated hands sit behind the torso plane. Include their complete
    # silhouette; a strict capsule cut previously left fingertips on Hips.
    hand_region = .62 < point.z < .90 and abs(point.x) > .34
    arm = .62 < point.z < 1.30 and abs(point.x) > .20 and (arm_distance < .16 or hand_region)
    if point.z > 1.36:
        weights = {'Head': 1.}
    elif arm:
        names = arm_names if point.z < 1.17 else arm_names + ['Chest']
        weights = {name: 1/(distance(point, *spec[name][:2])+.025)**4 for name in names}
        if a.profile == 'villager_female':
            # Her narrower waist approaches the inner sleeve. A hard arm/body
            # cutoff tore adjacent waist vertices; blend across that boundary.
            influence = smooth(.23, .30, abs(point.x)) if point.z < 1.14 else smooth(.18, .25, abs(point.x))
            if hand_region: influence = 1.
            core = {'Hips': 1.} if point.z < .99 else {
                name: 1/(distance(point, *spec[name][:2])+.025)**4
                for name in ['Hips', 'Spine', 'Chest', 'Neck', 'Head']}
            arm_total, core_total = sum(weights.values()), sum(core.values())
            blend = {name: weight/core_total*(1-influence) for name, weight in core.items()}
            for name, weight in weights.items(): blend[name] = blend.get(name, 0) + weight/arm_total*influence
            weights = blend
        if point.z < .86 and abs(point.x) > .34: hand_vertices.append(vertex.index)
    elif point.z < .20:
        weights = {'Foot'+side: 1.}
    elif a.profile == 'villager_female' and point.z < .36 and abs(point.x) < .20:
        weights = {'Shin'+side: 1.}
    elif point.z < .99:
        _, _, nearest = cloth.find(point)
        influence = (1-smooth(.018, .045, nearest)) * (1-smooth(.88, .98, point.z))
        front = 1-smooth(-.07, .07, point.y)
        weights = {'Hips': 1-influence, 'SkirtFront': influence*front, 'SkirtBack': influence*(1-front)}
        if influence > .95: skirt_vertices.append(vertex.index)
    else:
        names = ['Hips', 'Spine', 'Chest', 'Neck', 'Head']
        weights = {name: 1/(distance(point, *spec[name][:2])+.025)**4 for name in names}
    weights = dict(sorted(weights.items(), key=lambda pair: pair[1], reverse=True)[:4])
    total = sum(weights.values())
    for name, weight in weights.items():
        if weight > 0: body.vertex_groups[name].add([vertex.index], weight/total, 'REPLACE')
assert len(hand_vertices) > 10 and len(skirt_vertices) > 500
for index in hand_vertices:
    assert all(body.vertex_groups[group.group].name not in ['SkirtFront', 'SkirtBack', 'Hips']
               for group in body.data.vertices[index].groups), 'Hand bound to skirt/pelvis'
error = max(abs(sum(group.weight for group in vertex.groups)-1) for vertex in body.data.vertices)
assert error < 1e-5
assert np.array_equal(before, np.array([tuple(v.co) for v in body.data.vertices], dtype=np.float32))
body.parent = rig
body.modifiers.new('MerchantSkin', 'ARMATURE').object = rig
scene = bpy.context.scene
scene.render.fps = 24
rig.animation_data_create()
for clip in ['idle', 'talk']:
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(49):
        scene.frame_set(frame)
        phase = frame/48*math.tau
        pulse = math.sin(math.pi*frame/48)**2
        poses = {'Chest': (.009*math.sin(phase), 0, 0),
                 'Head': (0, .008*math.sin(phase), 0),
                 'SkirtFront': (.004*math.sin(phase), 0, 0),
                 'SkirtBack': (-.004*math.sin(phase), 0, 0)}
        if clip == 'talk':
            poses.update({'Head': (.022*math.sin(phase*2)*pulse, .008*math.sin(phase), .015*math.sin(phase)),
                          'ArmRight': (-.07*pulse, 0, .018*pulse),
                          'ForearmRight': (-.11*pulse, 0, 0),
                          'HandRight': (0, .04*math.sin(phase)*pulse, 0)})
        for bone in rig.pose.bones:
            bone.rotation_mode = 'XYZ'
            bone.rotation_euler = poses.get(bone.name, (0, 0, 0))
            bone.location = (0, 0, 0)
            bone.scale = (1, 1, 1)
        bpy.context.view_layer.update()
        evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
        lowest = min(vertex.co.z for vertex in evaluated.data.vertices)
        rig.pose.bones['Root'].location = rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0, 0, .002-lowest))
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='rotation_euler', frame=frame, group=bone.name)
        rig.pose.bones['Root'].keyframe_insert(data_path='location', frame=frame, group='Root')
rig.animation_data.action = None
for bone in rig.pose.bones:
    bone.rotation_euler = (0, 0, 0)
    bone.location = (0, 0, 0)
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output/(a.profile+'_npc.blend')).resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output/(a.profile+'_npc.glb')).resolve()), export_format='GLB',
                         use_selection=True, export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
(a.output/'npc_recipe.json').write_text(json.dumps({'source': str(a.input), 'profile': a.profile,
    'source_sha256': hashlib.sha256(a.input.read_bytes()).hexdigest(), 'geometry_modified': False,
    'height_m': 1.65, 'bones': len(spec), 'clips': ['idle', 'talk'], 'weight_sum_max_error': error,
    'skirt_color_seed_vertices': len(seeds), 'skirt_weight_check_vertices': len(skirt_vertices),
    'hand_weight_check_vertices': len(hand_vertices), 'weight_method': 'Four nearest permitted bone capsules; profile-specific cloth colour proximity and dedicated front/back skirt bones',
    'limitations': ['Stationary NPC, no walking or finger rig', 'No cloth physics or item handoff animation',
                    'Material/geometry limitations of reviewed static source remain; formal gameplay integration not tested']}, indent=2), encoding='utf8')
print('SKIRTED_NPC_READY', a.profile, len(spec), 'bones; source geometry unchanged', flush=True)
