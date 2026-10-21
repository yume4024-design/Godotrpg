"""Bake explicit narrower foot tracks as additive clips, preserving all 12 inputs.

This is a measured gait correction on a new work copy, not another sword recipe.
Only the copied leg/foot curves and per-frame floor compensation are authored.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
rig=next(o for o in scene.objects if o.type=='ARMATURE')
meshes=[o for o in scene.objects if o.type=='MESH']
for track in rig.animation_data.nla_tracks:track.mute=True
rows={}
for name in ['walk','run']:
    source=bpy.data.actions[name]
    # Snapshot the full source before selecting the destination action. Switching
    # actions after writing a pose lets the destination's existing F-curves
    # overwrite that pose at depsgraph evaluation (the rejected first copy).
    source_frames=[]
    rig.animation_data.action=source
    if source.slots:rig.animation_data.action_slot=source.slots[0]
    for frame in range(int(source.frame_range[0]),int(source.frame_range[1])+1):
        scene.frame_set(frame);bpy.context.view_layer.update()
        basis={bone.name:bone.matrix_basis.copy() for bone in rig.pose.bones}
        source_frames.append((frame,basis))
    target=bpy.data.actions.new(name+'_narrow');target.use_fake_user=True
    rig.animation_data.action=target
    samples=[];forward=[]
    for frame,basis in source_frames:
        scene.frame_set(frame);bpy.context.view_layer.update()
        for bone in rig.pose.bones:bone.matrix_basis=basis[bone.name]
        bpy.context.view_layer.update()
        for side,sign in [('Left',1),('Right',-1)]:
            leg=rig.pose.bones['Leg'+side];foot=rig.pose.bones['Foot'+side]
            hip=leg.matrix.translation.copy();foot_basis=foot.matrix.to_3x3().copy()
            vector=foot.matrix.translation-hip
            desired=sign*.135-hip.x
            angle=0.
            for unused in range(5):
                value=vector.x*math.cos(angle)+vector.z*math.sin(angle)-desired
                derivative=-vector.x*math.sin(angle)+vector.z*math.cos(angle)
                assert abs(derivative)>.1
                angle-=value/derivative
            assert abs(angle)<.15
            leg.matrix=Matrix.Translation(hip) @ Matrix.Rotation(angle,4,'Y') @ Matrix.Translation(-hip) @ leg.matrix
            bpy.context.view_layer.update()
            foot.matrix=Matrix.Translation(foot.matrix.translation) @ foot_basis.to_4x4()
            bpy.context.view_layer.update()
        minimum=float('inf')
        for obj in meshes:
            evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=evaluated.to_mesh()
            minimum=min(minimum,min(v.co.z for v in mesh.vertices));evaluated.to_mesh_clear()
        root=rig.pose.bones['Root']
        root.location+=rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0,0,.002-minimum))
        for bone in rig.pose.bones:
            bone.keyframe_insert(data_path='rotation_euler',frame=frame,group=bone.name)
        root.keyframe_insert(data_path='location',frame=frame,group='Root')
        bpy.context.view_layer.update()
        samples.append(abs(rig.pose.bones['FootLeft'].matrix.translation.x-rig.pose.bones['FootRight'].matrix.translation.x))
        forward.append(rig.pose.bones['FootLeft'].matrix.translation.y)
    assert max(forward)-min(forward)>(.3 if name=='walk' else .6)
    rows[name+'_narrow']={'foot_span_min_m':min(samples),'foot_span_max_m':max(samples),
                         'forward_stride_m':max(forward)-min(forward),'samples':samples}
rig.animation_data.action=None
for bone in rig.pose.bones:bone.matrix_basis.identity()
scene.frame_set(0);bpy.context.view_layer.update()
a.output.mkdir(parents=True)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
native=a.output/'ren_runtime.blend';glb=a.output/'ren_runtime.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
report={'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'added_clips':rows,
        'original_twelve_clips_retained':True,'source_geometry_uv_weights_unchanged':True,
        'target_foot_track_m':.27,'limits':['Numeric authored track; real game input and collision tests remain necessary'],
        'outputs':{path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in [native,glb]}}
(a.output/'build_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('REN_NARROW_GAIT',rows.keys(),flush=True)
