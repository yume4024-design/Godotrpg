"""Bind the approved male villager on a new copy; no RPG or original asset edits."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
assert len(meshes) == 1
body = meshes[0]
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
low = Vector([min(vertex.co[i] for vertex in body.data.vertices) for i in range(3)])
high = Vector([max(vertex.co[i] for vertex in body.data.vertices) for i in range(3)])
factor = 1.75/(high.z-low.z)
for vertex in body.data.vertices:
    point = vertex.co.copy()
    vertex.co = ((point.x-(low.x+high.x)*.5)*factor,
                 (point.y-(low.y+high.y)*.5)*factor, (point.z-low.z)*factor)
body.data.update()
body.name = 'VillagerMaleBody'
for material in body.data.materials:
    shader = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    for name in ['Normal', 'Metallic', 'Roughness']:
        for link in list(shader.inputs[name].links): material.node_tree.links.remove(link)
    shader.inputs['Metallic'].default_value = 0
    shader.inputs['Roughness'].default_value = .8
spec = {'Root': ((0, 0, 0), (0, 0, .96), None),
        'Hips': ((0, 0, .96), (0, 0, 1.06), 'Root'),
        'Spine': ((0, 0, 1.06), (0, 0, 1.19), 'Hips'),
        'Chest': ((0, 0, 1.19), (0, 0, 1.34), 'Spine'),
        'Neck': ((0, 0, 1.34), (0, 0, 1.43), 'Chest'),
        'Head': ((0, 0, 1.43), (0, 0, 1.72), 'Neck')}
for side, sign in [('Left', 1), ('Right', -1)]:
    spec.update({'Arm'+side: ((sign*.23, 0, 1.32), (sign*.36, .01, 1.10), 'Chest'),
                 'Forearm'+side: ((sign*.36, .01, 1.10), (sign*.47, .03, .87), 'Arm'+side),
                 'Hand'+side: ((sign*.47, .03, .87), (sign*.51, .05, .74), 'Forearm'+side),
                 'Leg'+side: ((sign*.13, 0, .96), (sign*.17, 0, .52), 'Hips'),
                 'Shin'+side: ((sign*.17, 0, .52), (sign*.18, 0, .13), 'Leg'+side),
                 'Foot'+side: ((sign*.18, 0, .13), (sign*.18, -.15, .05), 'Shin'+side)})
bpy.ops.object.armature_add()
rig = bpy.context.object
rig.name = 'VillagerMaleRig'
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
def distance(point, head, tail):
    head, tail = Vector(head), Vector(tail)
    delta = tail-head
    return (point-head-delta*max(0., min(1., (point-head).dot(delta)/delta.length_squared))).length
hands = []
for vertex in body.data.vertices:
    point = vertex.co
    if point.z > 1.40:
        weights = {'Head': 1.}
    else:
        names = [name for name in spec if name != 'Root']
        if point.z < .98 and point.z > .65 and abs(point.x) > .40:
            side = 'Left' if point.x > 0 else 'Right'
            names = ['Arm'+side, 'Forearm'+side, 'Hand'+side]
            hands.append(vertex.index)
        weights = {name: 1/(distance(point, *spec[name][:2])+.025)**4 for name in names}
        weights = dict(sorted(weights.items(), key=lambda pair: pair[1], reverse=True)[:4])
    total = sum(weights.values())
    for name, weight in weights.items():body.vertex_groups[name].add([vertex.index], weight/total, 'REPLACE')
assert len(hands) > 20
for index in hands:
    assert all(not body.vertex_groups[group.group].name.startswith(('Hips','Leg','Shin','Foot'))
               for group in body.data.vertices[index].groups)
error = max(abs(sum(group.weight for group in vertex.groups)-1) for vertex in body.data.vertices)
assert error < 1e-5
body.parent = rig
body.modifiers.new('VillagerSkin', 'ARMATURE').object = rig
rig.animation_data_create()
scene = bpy.context.scene
scene.render.fps = 24
for clip in ['idle', 'talk']:
    action = bpy.data.actions.new(clip)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in range(49):
        scene.frame_set(frame)
        phase = frame/48*math.tau
        pulse = math.sin(math.pi*frame/48)**2
        poses = {'Chest': (.008*math.sin(phase), 0, 0), 'Head': (0, .008*math.sin(phase), 0)}
        if clip == 'talk':
            poses.update({'Head': (.022*math.sin(phase*2)*pulse, 0, .016*math.sin(phase)),
                          'ArmRight': (-.07*pulse, 0, .02*pulse), 'ForearmRight': (-.11*pulse, 0, 0),
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
        for bone in rig.pose.bones:bone.keyframe_insert(data_path='rotation_euler', frame=frame, group=bone.name)
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
bpy.ops.wm.save_as_mainfile(filepath=str((a.output/'villager_male_npc.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output/'villager_male_npc.glb').resolve()), export_format='GLB',
                         use_selection=True, export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
(a.output/'npc_recipe.json').write_text(json.dumps({'source':str(a.input),
    'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(), 'height_m':1.75,
    'geometry':'Uniform normalization only; no decimation or topology repair',
    'material':'Baked normal disconnected after paired CPU review; neutral rough non-metal material',
    'bones':len(spec), 'clips':['idle','talk'], 'hand_weight_check_vertices':len(hands),
    'weight_sum_max_error':error, 'limitations':['Stationary dialogue only; no walk/patrol or finger rig',
    'No formal NPC/story/save integration']},indent=2),encoding='utf8')
print('VILLAGER_MALE_READY',len(spec),'bones',flush=True)
