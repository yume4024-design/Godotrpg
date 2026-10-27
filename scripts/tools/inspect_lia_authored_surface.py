"""Render neutral material diagnostics without changing the owned work file."""
import argparse, math, sys
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
a.output.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
for obj in list(scene.objects):
    if obj.type!='MESH': bpy.data.objects.remove(obj,do_unlink=True)
    else:
        mat=bpy.data.materials.new('Neutral_'+obj.name)
        mat.use_nodes=True
        bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value=(.62,.42,.25,1) if obj.name=='LiaContinuousNeckClavicle' else (.47,.56,.65,1)
        bsdf.inputs['Roughness'].default_value=.8
        obj.data.materials.clear();obj.data.materials.append(mat)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=16
scene.render.resolution_x=scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world=bpy.data.worlds.new('NeutralWorld');scene.world.use_nodes=True
background=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
background.inputs['Color'].default_value=(.14,.18,.22,1);background.inputs['Strength'].default_value=.7
camera=bpy.data.objects.new('NeutralCamera',bpy.data.cameras.new('NeutralCamera'));scene.collection.objects.link(camera)
scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=.36
for index,(point,power) in enumerate([((2,-3,4),350),((-2,1,3),160)]):
    light=bpy.data.lights.new('NeutralLight'+str(index),'AREA');light.energy=power;light.size=3
    obj=bpy.data.objects.new(light.name,light);scene.collection.objects.link(obj);obj.location=point
    obj.rotation_euler=(Vector((0,0,1.6))-obj.location).to_track_quat('-Z','Y').to_euler()
for name,angle in [('front',0),('quarter',math.pi/4),('right',math.pi/2)]:
    camera.location=(math.sin(angle)*3,-math.cos(angle)*3,1.59)
    camera.rotation_euler=(Vector((0,0,1.59))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(name+'.png')).resolve());bpy.ops.render.render(write_still=True)
