"""Read-only preservation audit; never upgrades the candidate's visual gate."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

p=argparse.ArgumentParser()
p.add_argument('--source',type=Path,required=True)
p.add_argument('--candidate',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert hashlib.sha256(a.source.read_bytes()).hexdigest()=='93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'

def snapshot(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    scene=bpy.context.scene
    rig=next(o for o in scene.objects if o.type=='ARMATURE')
    for track in rig.animation_data.nla_tracks:track.mute=True
    bones={bone.name:[value for row in bone.matrix_local for value in row] for bone in rig.data.bones}
    poses={}
    for action in bpy.data.actions:
        rig.animation_data.action=action
        if action.slots:rig.animation_data.action_slot=action.slots[0]
        frames=[]
        for frame in range(int(action.frame_range[0]),int(action.frame_range[1])+1):
            scene.frame_set(frame);bpy.context.view_layer.update()
            frames.append({bone.name:[value for row in bone.matrix for value in row] for bone in rig.pose.bones})
        poses[action.name]=frames
    images=sorted((list(image.size),hashlib.sha256(bytes(image.packed_file.data)).hexdigest())
                  for image in bpy.data.images if image.packed_file)
    rig.animation_data.action=None
    for bone in rig.pose.bones:bone.matrix_basis.identity()
    scene.frame_set(0);bpy.context.view_layer.update()
    return bones,poses,images

bones,poses,images=snapshot(a.source)
source=next(o for o in bpy.context.scene.objects if o.type=='MESH')
points=[vertex.co.copy() for vertex in source.data.vertices]
polygons=[tuple(face.vertices) for face in source.data.polygons]
uvs=[[source.data.uv_layers.active.data[i].uv.copy() for i in face.loop_indices] for face in source.data.polygons]
normals=[[source.data.corner_normals[i].vector.copy() for i in face.loop_indices] for face in source.data.polygons]
area=sum(face.area for face in source.data.polygons)
tree=BVHTree.FromPolygons(points,polygons,all_triangles=True)
new_bones,new_poses,new_images=snapshot(a.candidate)
failures=[]
if bones!=new_bones:failures.append('BONE_REST_CHANGED')
if set(poses)!=set(new_poses):failures.append('CLIP_NAMES_CHANGED')
pose_error=0.
if set(poses)==set(new_poses):
    for name,frames in poses.items():
        if len(frames)!=len(new_poses[name]):failures.append(name+':FRAME_COUNT_CHANGED');continue
        for frame,new_frame in zip(frames,new_poses[name]):
            for bone,values in frame.items():
                pose_error=max(pose_error,max(abs(v-n) for v,n in zip(values,new_frame[bone])))
if pose_error>1e-7:failures.append('BONE_ANIMATION_CHANGED')
if images!=new_images:failures.append('PACKED_ALBEDO_CHANGED')
meshes={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
assert set(meshes)=={'RenRetainedBody','RenSeparatedCoat','RenInnerTrousers'}
new_area=0.;bad_faces=[];max_uv=0.;max_normal=0.;checked=0
for name in ['RenRetainedBody','RenSeparatedCoat']:
    body=meshes[name]
    for face in body.data.polygons:
        new_area+=face.area
        corners=[body.data.vertices[v].co for v in face.vertices]
        centroid=sum(corners,Vector())/3
        candidates=tree.find_nearest_range(centroid,2e-6)
        best=None
        for _,_,index,_ in candidates:
            original=[points[v] for v in polygons[index]]
            uv_error,normal_error=0.,0.
            for corner,loop_id in zip(corners,face.loop_indices):
                # Coplanar overlapping triangles can share a centroid. Require
                # the candidate to contain all corners before accepting UVs.
                # float64 avoids Blender's float32 barycentric projection
                # falsely moving points on long, very thin source triangles.
                origin=np.asarray(original[0],dtype=np.float64)
                edges=np.asarray([original[1]-original[0],original[2]-original[0]],dtype=np.float64).T
                delta=np.asarray(corner,dtype=np.float64)-origin
                factors=np.linalg.lstsq(edges,delta,rcond=None)[0]
                bary=(1-factors.sum(),factors[0],factors[1])
                if min(bary)<-2e-4 or max(bary)>1.0002:uv_error=float('inf');break
                projected=sum((original[i]*bary[i] for i in range(3)),Vector())
                if (projected-corner).length>2e-6:uv_error=float('inf');break
                expected_uv=sum((uvs[index][i]*bary[i] for i in range(3)),Vector((0,0)))
                expected_normal=sum((normals[index][i]*bary[i] for i in range(3)),Vector()).normalized()
                uv_error=max(uv_error,(expected_uv-body.data.uv_layers.active.data[loop_id].uv).length)
                normal_error=max(normal_error,(expected_normal-body.data.corner_normals[loop_id].vector).length)
            row=(uv_error,normal_error)
            if best is None or row<best:best=row
        if best is not None:
            max_uv=max(max_uv,best[0]);max_normal=max(max_normal,best[1])
        if best is None or best[0]>2e-5 or best[1]>2e-3:
            bad_faces.append({'mesh':name,'face':face.index,'best':
                [float(v) if np.isfinite(v) else None for v in best] if best else None})
        checked+=1
if max_uv>2e-5:failures.append('OUTER_UV_MISMATCH')
if max_normal>2e-3:failures.append('CORNER_NORMAL_MISMATCH')
area_error=abs(new_area-area)
if area_error>1e-6:failures.append('OUTER_SURFACE_AREA_CHANGED')
error=max(abs(sum(g.weight for g in vertex.groups)-1) for body in meshes.values() for vertex in body.data.vertices)
maximum=max(len(vertex.groups) for body in meshes.values() for vertex in body.data.vertices)
if error>1e-5 or maximum>4:failures.append('WEIGHT_CONTRACT')
report={'source_sha256':hashlib.sha256(a.source.read_bytes()).hexdigest(),
        'candidate_sha256':hashlib.sha256(a.candidate.read_bytes()).hexdigest(),
        'status':'FAIL' if failures else 'PASS','failures':failures,
        'bones':len(bones),'clips':len(poses),'sampled_frames':sum(len(frames) for frames in poses.values()),
        'maximum_bone_pose_error':pose_error,'packed_images':images,
        'outer_triangles_checked':checked,'outer_surface_area_error':area_error,
        'maximum_uv_error':max_uv,'maximum_corner_normal_error':max_normal,
        'bad_faces':sorted(bad_faces,key=lambda row:-(row['best'][1] if row['best'] and row['best'][1] is not None else float('inf')))[:20],
        'bad_face_count':len(bad_faces),
        'maximum_weight_sum_error':error,'maximum_influences':maximum,
        'checks':{'bone_rest':bones==new_bones,'clip_names':set(poses)==set(new_poses),
                  'all_frame_bone_poses':pose_error<=1e-7,'packed_images':images==new_images,
                  'outer_surface_area':area_error<=1e-6,'outer_uv':max_uv<=2e-5,
                  'corner_normals':max_normal<=2e-3,'weight_contract':error<=1e-5 and maximum<=4},
        'limitations':['Surface/UV/action preservation does not certify deformation or intersections',
                       'New inner trouser shell uses a separate plain fabric material',
                       'Old coat bones are preserved in actions but no longer weight this layer']}
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(report,indent=2),encoding='utf8')
print('REN_LAYER_PRESERVATION',report['status'],checked,'outer triangles',flush=True)
if failures:raise RuntimeError(failures)
