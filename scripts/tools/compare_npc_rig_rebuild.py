"""Blender read-only semantic comparison against a previously accepted native rig."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
import numpy as np

p = argparse.ArgumentParser()
p.add_argument('--expected', type=Path, required=True)
p.add_argument('--actual', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])

def capture(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    body = next(obj for obj in bpy.context.scene.objects if obj.type == 'MESH')
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE')
    result = {'vertices':np.array([tuple(vertex.co) for vertex in body.data.vertices], dtype=np.float32),
              'uv':np.array([tuple(loop.uv) for loop in body.data.uv_layers.active.data], dtype=np.float32),
              'weights': [[(body.vertex_groups[group.group].name, group.weight) for group in vertex.groups]
                          for vertex in body.data.vertices],
              'bones':[(bone.name, bone.parent.name if bone.parent else None, tuple(bone.head_local), tuple(bone.tail_local))
                       for bone in rig.data.bones], 'poses':{}, 'albedo':[]}
    for material in body.data.materials:
        shader = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
        image = shader.inputs['Base Color'].links[0].from_node.image
        if not image.packed_file: raise ValueError('Comparison requires packed albedo')
        result['albedo'].append(hashlib.sha256(image.packed_file.data).hexdigest())
    for action in bpy.data.actions:
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        points = []
        for frame in [0, 12, 24, 36, 48]:
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            mesh = body.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
            points.append(np.array([tuple(vertex.co) for vertex in mesh.vertices], dtype=np.float32))
            body.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
        result['poses'][action.name] = np.stack(points)
    return result

expected, actual = capture(a.expected), capture(a.actual)
checks = {'rest_vertices_equal':np.array_equal(expected['vertices'], actual['vertices']),
          'uv_equal':np.array_equal(expected['uv'], actual['uv']),
          'weights_equal':expected['weights'] == actual['weights'],
          'bones_equal':expected['bones'] == actual['bones'],
          'albedo_equal':expected['albedo'] == actual['albedo'],
          'clip_names_equal':set(expected['poses']) == set(actual['poses'])}
difference = {}
for name in expected['poses'].keys() & actual['poses'].keys():
    old, new = expected['poses'][name], actual['poses'][name]
    difference[name] = float(np.abs(old-new).max()) if old.shape == new.shape else None
checks['sampled_poses_equal'] = bool(difference) and all(value == 0 for value in difference.values())
report = {'expected':str(a.expected), 'actual':str(a.actual), 'checks':checks,
          'pose_maximum_difference':difference, 'status':'PASS' if all(checks.values()) else 'FAIL',
          'scope':'Default-profile rebuild equality, not new visual/gameplay acceptance'}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('NPC_REBUILD_COMPARISON',report['status'],difference,flush=True)
if not all(checks.values()): raise RuntimeError(checks)
