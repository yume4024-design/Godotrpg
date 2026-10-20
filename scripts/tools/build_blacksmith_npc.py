"""Reuse the inspected blacksmith rig for a static dialogue NPC, in a new copy."""
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
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
a.output.mkdir(parents=True, exist_ok=False)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
rig.animation_data.action = None
for track in list(rig.animation_data.nla_tracks): rig.animation_data.nla_tracks.remove(track)
# The current gameplay blacksmith only provides dialogue. Work/weapon gestures
# remain in the untouched original; do not imply a validated hammer grip.
for action in list(bpy.data.actions):
    if action.name != 'idle': bpy.data.actions.remove(action, do_unlink=True)
for material in body.data.materials:
    nodes, links = material.node_tree.nodes, material.node_tree.links
    shader = next(node for node in nodes if node.type == 'BSDF_PRINCIPLED')
    for link in list(shader.inputs['Normal'].links): links.remove(link)
    shader.inputs['Roughness'].default_value = .8
action = bpy.data.actions.new('talk')
action.use_fake_user = True
rig.animation_data.action = action
scene = bpy.context.scene
scene.render.fps = 24
for frame in range(49):
    scene.frame_set(frame)
    t = frame / 48
    phase = t * math.tau
    pulse = math.sin(math.pi*t)**2
    poses = {'Chest': (.005*math.sin(phase), 0, .007*math.sin(phase)),
             'Head': (.025*math.sin(phase*2)*pulse, 0, .018*math.sin(phase)),
             'ArmRight': (-.07*pulse, 0, .025*pulse),
             'ForearmRight': (-.12*pulse, 0, 0),
             'HandRight': (0, .05*math.sin(phase)*pulse, 0),
             'ArmLeft': (-.03*pulse, 0, 0)}
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
    bone.scale = (1, 1, 1)
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output / 'blacksmith_npc.blend').resolve()))
bpy.ops.export_scene.gltf(filepath=str((a.output / 'blacksmith_npc.glb').resolve()), export_format='GLB',
                         use_selection=True, export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
(a.output / 'npc_recipe.json').write_text(json.dumps({'source': str(a.input),
    'source_sha256': hashlib.sha256(a.input.read_bytes()).hexdigest(), 'geometry_or_weight_changes': False,
    'material': 'Baked normal disconnected after controlled comparison; original source retained',
    'clips': ['idle', 'talk'], 'scope': 'Static dialogue NPC; no walking, hammer grip or work acceptance',
    'original_ten_actions': 'Preserved in the untouched source Blend, not exported as unverified NPC actions'}, indent=2), encoding='utf8')
print('BLACKSMITH_DIALOGUE_NPC_READY', len(rig.data.bones), 'bones', flush=True)
