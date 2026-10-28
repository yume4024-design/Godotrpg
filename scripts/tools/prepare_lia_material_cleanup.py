"""Render unlit orthographic cleanup references; preserve model geometry and UV."""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);assert not a.output.exists();a.output.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
for o in list(scene.objects):
    if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
meshes=[o for o in scene.objects if o.type=='MESH'];assert len(meshes)==2
body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];assert len(body.data.polygons)==12078
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1
scene.render.resolution_x=1024;scene.render.resolution_y=1536;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
saved=[]
for mat in {m for o in meshes for m in o.data.materials}:
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');out=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL');em=mat.node_tree.nodes.new('ShaderNodeEmission');color=bs.inputs['Base Color']
    if color.is_linked:mat.node_tree.links.new(color.links[0].from_socket,em.inputs[0])
    else:em.inputs[0].default_value=color.default_value
    mat.node_tree.links.new(em.outputs[0],out.inputs['Surface']);saved.append((mat,bs,out,em))
cam=bpy.data.objects.new('CleanupProjection',bpy.data.cameras.new('CleanupProjection'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.08
center=Vector((0,0,.975));views={}
for name,degrees in [('front',0),('right',90),('back',180),('left',-90)]:
    t=math.radians(degrees);direction=Vector((math.sin(t),-math.cos(t),0));horizontal=Vector((math.cos(t),math.sin(t),0))
    cam.location=center+direction*4;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(name+'_albedo.png')).resolve());bpy.ops.render.render(write_still=True)
    views[name]={'yaw':degrees,'direction':list(direction),'horizontal':list(horizontal)}
for mat,bs,out,em in saved:mat.node_tree.links.new(bs.outputs[0],out.inputs['Surface']);mat.node_tree.nodes.remove(em)
bpy.data.objects.remove(cam,do_unlink=True);bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str((a.output/'baseline.blend').resolve()))
report={'source':str(a.input),'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'height_span':2.08,'width_span':2.08*1024/1536,'center':list(center),'resolution':[1024,1536],'views':views,'method':'Actual mesh emission-only orthographic projections; original geometry and existing UV untouched.'}
(a.output/'projection.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('LIA_MATERIAL_PROJECTION_COMPLETE',flush=True)
