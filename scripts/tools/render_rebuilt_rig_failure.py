"""Render diagnosed poses from this project's owned Ren work copies only."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])
root = Path(__file__).resolve().parents[2]
assert a.input.resolve().is_relative_to(root/'source_assets/character_rebuild_20261020/ren')
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type=='ARMATURE')
for track in rig.animation_data.nla_tracks: track.mute = True
scene.render.engine = 'CYCLES'
scene.cycles.samples = 8
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False
scene.view_settings.view_transform = 'Standard'
scene.world = bpy.data.worlds.new('DiagnosticWorld')
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.13,.17,.20,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .7
camera_data = bpy.data.cameras.new('DiagnosticCamera')
camera = bpy.data.objects.new('DiagnosticCamera',camera_data)
scene.collection.objects.link(camera)
camera_data.type = 'ORTHO'
camera_data.ortho_scale = 2.4
scene.camera = camera
for index,(position,energy,size) in enumerate([((3,-4,5),550,4),((-3,-1,3),250,3)]):
    data = bpy.data.lights.new('DiagnosticLight'+str(index),'AREA')
    data.energy, data.shape, data.size = energy,'DISK',size
    obj = bpy.data.objects.new(data.name,data)
    scene.collection.objects.link(obj)
    obj.location = position
    obj.rotation_euler = (Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
plan = [('run',4,'front'),('run',12,'right'),('cast',8,'front'),('cast',8,'right')]
a.output.mkdir(parents=True)
rows = []
for clip,frame,view in plan:
    action = bpy.data.actions[clip]
    rig.animation_data.action = action
    if action.slots: rig.animation_data.action_slot = action.slots[0]
    scene.frame_set(frame)
    camera.location = (0,-5,.98) if view=='front' else (5,0,.98)
    camera.rotation_euler = (Vector((0,0,.98))-camera.location).to_track_quat('-Z','Y').to_euler()
    path = a.output/f'{clip}_{frame}_{view}.png'
    scene.render.filepath = str(path.resolve())
    bpy.ops.render.render(write_still=True)
    rows.append({'clip':clip,'frame':frame,'view':view,'file':path.name})
(a.output/'render_report.json').write_text(json.dumps({'input':str(a.input),
    'sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'captures':rows,
    'purpose':'Failure evidence only; does not certify animation or production integration'},indent=2),encoding='utf8')
