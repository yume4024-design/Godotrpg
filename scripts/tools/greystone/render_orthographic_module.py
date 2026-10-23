"""Render four true orthographic elevations from ONE mesh, preserving scale."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'source_assets/greystone_ai_20261023/inn/blender_calibration'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/greystone/reference_modules/inn.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
low=Vector(tuple(min(v[i] for v in corners) for i in range(3)))
high=Vector(tuple(max(v[i] for v in corners) for i in range(3)))
center=(high+low)/2
scale=max(high.x-low.x,high.y-low.y,high.z-low.z)*1.15
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.film_transparent=True
scene.render.resolution_x=768;scene.render.resolution_y=768;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.65,.65,1)
for p in [(5,-9,16),(-8,9,12)]:
    bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=1600;o.data.size=10
    o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam
records=[]
for name,direction in [('front',(0,-1,0)),('left',(-1,0,0)),('back',(0,1,0)),('right',(1,0,0))]:
    cam.location=center+Vector(direction)*30
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'{name}.png');bpy.ops.render.render(write_still=True)
    records.append({'view':name,'projection':cam.data.type,'scale':scale,'camera':list(cam.location),'target':list(center),'pitch_degrees':0})
(OUT/'cameras.json').write_text(json.dumps({'status':'geometric calibration only; visual fidelity not accepted','source':'assets/models/greystone/reference_modules/inn.glb','bounds':[list(low),list(high)],'views':records},indent=2),encoding='utf8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'orthographic_calibration.blend'))
