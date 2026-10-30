"""Render an isolated static Lia candidate at reproducible inspection views."""
import argparse, bpy, math, sys
from pathlib import Path
from mathutils import Vector
parser=argparse.ArgumentParser()
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
p=args.output.resolve()
if p.exists(): raise FileExistsError('Output directory must be new')
p.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(args.input.resolve()))
s=bpy.context.scene
for o in list(s.objects):
 if o.type!='MESH': bpy.data.objects.remove(o,do_unlink=True)
s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=16
s.render.resolution_x=s.render.resolution_y=900;s.render.resolution_percentage=100;s.render.film_transparent=False
s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX'
s.world=bpy.data.worlds.new('ExamineWorld');s.world.use_nodes=True
s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.16,.2,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
cam=bpy.data.objects.new('ExamineCamera',bpy.data.cameras.new('ExamineCamera'));s.collection.objects.link(cam);s.camera=cam;cam.data.type='ORTHO'
for idx,(position,power) in enumerate([((2,-3,4),350),((-2,1,3),160)]):
 d=bpy.data.lights.new('L'+str(idx),'AREA');d.energy=power;d.size=3;o=bpy.data.objects.new(d.name,d);s.collection.objects.link(o);o.location=position;o.rotation_euler=(Vector((0,0,1.0))-o.location).to_track_quat('-Z','Y').to_euler()
for name,center,angle,scale in [('sleeve_left_front',(-.27,0,1.21),0,.55),('sleeve_right_front',(.27,0,1.21),0,.55),('skirt_back',(0,0,.98),180,.75),('neck_front',(0,0,1.59),0,.4),('neck_back',(0,0,1.59),180,.4)]:
 center=Vector(center);t=math.radians(angle);cam.location=center+Vector((math.sin(t)*4,-math.cos(t)*4,0));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale;s.render.filepath=str(p/(name+'.png'));bpy.ops.render.render(write_still=True)
print('RENDER_DONE')
