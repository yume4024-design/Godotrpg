"""Prove a diagnosed weight repair does not edit geometry, UV or clip poses."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
import numpy as np

p = argparse.ArgumentParser()
p.add_argument('--before',type=Path,required=True)
p.add_argument('--after',type=Path,required=True)
p.add_argument('--repair',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])


def capture(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    body = next(o for o in bpy.context.scene.objects if o.type=='MESH')
    rig = next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks: track.mute=True
    result={'vertices':np.array([tuple(v.co) for v in body.data.vertices]),
            'uv':np.array([tuple(v.uv) for v in body.data.uv_layers.active.data]),
            'faces':[tuple(f.vertices) for f in body.data.polygons],
            'weights':[{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in body.data.vertices],
            'bones':[(b.name,b.parent.name if b.parent else None,tuple(b.head_local),tuple(b.tail_local)) for b in rig.data.bones],
            'albedo':[],'clips':{}}
    for material in body.data.materials:
        shader=next(n for n in material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        image=shader.inputs['Base Color'].links[0].from_node.image
        result['albedo'].append(hashlib.sha256(image.packed_file.data).hexdigest())
    for action in bpy.data.actions:
        rig.animation_data.action=action
        rig.animation_data.action_slot=action.slots[0]
        poses=[]
        for frame in range(int(action.frame_range[0]),int(action.frame_range[1])+1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            poses.append(np.array([tuple(row) for bone in rig.pose.bones for row in bone.matrix]))
        result['clips'][action.name]=np.stack(poses)
    return result


before,after=capture(a.before),capture(a.after)
listed={row['vertex'] for row in json.loads(a.repair.read_text(encoding='utf8'))['edits']}
changed={i for i,(old,new) in enumerate(zip(before['weights'],after['weights'])) if old!=new}
checks={'vertices_exact':np.array_equal(before['vertices'],after['vertices']),
        'uv_exact':np.array_equal(before['uv'],after['uv']),
        'face_indices_exact':before['faces']==after['faces'],
        'bones_exact':before['bones']==after['bones'],
        'packed_albedo_exact':before['albedo']==after['albedo'],
        'weights_only_within_listed_vertices':bool(changed) and changed.issubset(listed),
        'clip_names_exact':before['clips'].keys()==after['clips'].keys()}
differences={name:float(np.abs(before['clips'][name]-after['clips'][name]).max()) for name in before['clips']}
checks['all_127_frame_bone_poses_exact']=sum(len(v) for v in before['clips'].values())==127 and all(v==0 for v in differences.values())
report={'before':str(a.before),'after':str(a.after),'checks':checks,'changed_vertices':len(changed),
        'listed_vertices':len(listed),'clip_pose_max_difference':differences,
        'status':'PASS' if all(checks.values()) else 'FAIL',
        'scope':'Bounded repair preservation only; overall motion remains FAIL until separate quality gate passes'}
a.output.write_text(json.dumps(report,indent=2),encoding='utf8')
print('REN_BOUNDED_REPAIR_AUDIT',report['status'],flush=True)
if not all(checks.values()):raise RuntimeError(checks)
