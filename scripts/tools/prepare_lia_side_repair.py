"""Prepare exact orthographic side-colour projections of the retained Lia candidate.
No topology, UV or runtime asset edits. Fresh output is mandatory.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists(), 'Preserve previous evidence'
a.output.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
meshes=[o for o in scene.objects if o.type=='MESH']
assert len(meshes)==2
body=next(o for o in meshes if o.name=='LiaRetainedAuthoredNeckSurface')
assert len(body.data.polygons)==12078
for obj in list(scene.objects):
    if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1
scene.render.resolution_x=scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=True
scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
scene.world=bpy.data.worlds.new('ProjectionWorld');scene.world.use_nodes=True
saved=[]
for mat in {m for o in meshes for m in o.data.materials}:
    shader=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    output=next(n for n in mat.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
    emission=mat.node_tree.nodes.new('ShaderNodeEmission')
    color=shader.inputs['Base Color']
    if color.is_linked:mat.node_tree.links.new(color.links[0].from_socket,emission.inputs['Color'])
    else:emission.inputs['Color'].default_value=color.default_value
    mat.node_tree.links.new(emission.outputs[0],output.inputs['Surface'])
    saved.append((mat,shader,output,emission))
cam=bpy.data.objects.new('SideProjectionCamera',bpy.data.cameras.new('SideProjectionCamera'))
scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO'
span=.52;center=Vector((0,0,1.735));cam.data.ortho_scale=span
views={}
for name,degrees in [('right',65),('left',-65)]:
    theta=math.radians(degrees);direction=Vector((math.sin(theta),-math.cos(theta),0))
    cam.location=center+direction*4
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(name+'_albedo.png')).resolve())
    bpy.ops.render.render(write_still=True)
    views[name]={'camera_yaw_degrees':degrees,'eye_direction':list(direction),'horizontal_axis':[math.cos(theta),math.sin(theta),0]}
for mat,shader,output,emission in saved:
    mat.node_tree.links.new(shader.outputs[0],output.inputs['Surface'])
    mat.node_tree.nodes.remove(emission)
bpy.data.objects.remove(cam,do_unlink=True)
bpy.context.preferences.filepaths.file_preview_type='NONE'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str((a.output/'baseline.blend').resolve()))
report={'source':str(a.input),'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'body':body.name,'span':span,'center':list(center),'views':views,'method':'Orthographic emission-only base colour, Standard transform, transparent background, unchanged existing UV/topology; neck stays separate and untouched'}
(a.output/'projection.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('LIA_SIDE_PROJECTION_READY',a.output,flush=True)
