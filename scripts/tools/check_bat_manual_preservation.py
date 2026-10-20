"""Read-only retained anatomy, old-bone motion and complete-fold measurements."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import bpy
import numpy as np

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--candidate', type=Path, required=True)
p.add_argument('--recipe', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])
recipe = json.loads(a.recipe.read_text(encoding='utf-8-sig'))
assert hashlib.sha256(a.source.read_bytes()).hexdigest() == recipe['source_sha256']
removed = set(recipe['removed_generated_wing_faces'])
clips = ['idle','walk','attack','hit','death']


def capture(path, source):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    body = bpy.data.objects['crystal_bat_body']
    mesh = body.data
    faces, normals = [], {}
    for f in mesh.polygons:
        if source and f.index in removed:
            continue
        corners = []
        for li in f.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv = mesh.uv_layers.active.data[li].uv
            corners.append((tuple(round(value,6) for value in [*co,*uv]),tuple(mesh.corner_normals[li].vector)))
        corners.sort()
        key = tuple(row[0] for row in corners)
        faces.append(key)
        normals[key] = tuple(row[1] for row in corners)
    material = mesh.materials[0]
    texture_hashes = sorted(hashlib.sha256(n.image.packed_file.data).hexdigest()
                            for n in material.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image)
    old_bones = [bone.name for bone in rig.data.bones if not bone.name.startswith('WingPanel')]
    poses = {}
    for name in clips:
        action = bpy.data.actions[name]
        rig.animation_data.action = action
        if action.slots: rig.animation_data.action_slot = action.slots[0]
        samples = []
        for frame in range(int(action.frame_range[0]),int(action.frame_range[1])+1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            samples.append([[list(row) for row in rig.pose.bones[bone].matrix] for bone in old_bones])
        poses[name] = np.array(samples)
    return faces,normals,texture_hashes,poses


old_faces,old_normals,old_textures,old_poses = capture(a.source,True)
new_faces,new_normals,new_textures,new_poses = capture(a.candidate,False)
missing = Counter(old_faces)-Counter(new_faces)
extra = Counter(new_faces)-Counter(old_faces)
normal_error = max(abs(x-y) for key in old_normals.keys() & new_normals.keys()
                   for a,b in zip(old_normals[key],new_normals[key]) for x,y in zip(a,b))
pose_error = {name:float(abs(old_poses[name]-new_poses[name]).max()) for name in clips}
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
wing = bpy.data.objects['BatManualWings']
body = bpy.data.objects['crystal_bat_body']
action = bpy.data.actions['fold_wings']
rig.animation_data.action = action
if action.slots: rig.animation_data.action_slot = action.slots[0]
samples = []
body_first,body_last = None,None
max_scale_error = 0.
for frame in range(61):
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()
    meshes = {}
    for obj in [body,wing]:
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        meshes[obj.name] = np.array([tuple(v.co) for v in mesh.vertices])
        evaluated.to_mesh_clear()
    if frame == 0:
        body_first = meshes[body.name].copy()
        open_wing = meshes[wing.name].copy()
    body_last = meshes[body.name]
    max_scale_error = max(max_scale_error,max(abs(value-1) for bone in rig.pose.bones for value in bone.scale))
    points = meshes[wing.name]
    samples.append({'frame':frame,'wing_bounds':[points.min(0).tolist(),points.max(0).tolist()],
                    'wing_span':float(np.ptp(points[:,0])),
                    'body_max_vertex_difference_from_open':float(abs(meshes[body.name]-body_first).max())})
    if frame == 30:
        full_wing = points.copy()
full_body_motion = max(row['body_max_vertex_difference_from_open'] for row in samples)
checks = {'retained_face_corner_geometry_uv_equal':not missing and not extra,
          'retained_normals_reencoding_under_0_001':normal_error < .001,
          'original_body_images_exact':old_textures == new_textures,
          'five_original_clip_old_bone_matrices_exact':all(error == 0 for error in pose_error.values()),
          'fold_rotates_without_scale':max_scale_error == 0,
          'fold_keeps_whole_body_ears_feet_static':full_body_motion < 1e-6,
          'fold_span_below_0_80m':np.ptp(full_wing[:,0]) < .8,
          'fold_retains_open_span_above_1_45m':np.ptp(open_wing[:,0]) > 1.45,
          'fold_no_rear_spike_beyond_0_40m':full_wing[:,1].max() < .4,
          'fold_reopens_exactly':samples[0]['wing_bounds'] == samples[-1]['wing_bounds']}
checks = {name:bool(value) for name,value in checks.items()}
report = {'source':str(a.source),'candidate':str(a.candidate), 'checks':checks,
          'status':'PASS' if all(checks.values()) else 'FAIL',
          'preserved_anatomy_faces':len(new_faces),'missing_faces':sum(missing.values()),'extra_body_faces':sum(extra.values()),
          'retained_normal_max_component_error':normal_error,'old_bone_clip_matrix_max_difference':pose_error,
          'body_image_sha256':new_textures,'fold_samples':samples,
          'scope':'Numeric anatomy/pose preservation and full-fold dimensions; visual and gameplay gates are separate'}
a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8',newline='\n')
print('BAT_MANUAL_PRESERVATION',report['status'],checks,flush=True)
if not all(checks.values()): raise RuntimeError(checks)
