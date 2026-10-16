import bpy, json, math
from mathutils import Vector
from pathlib import Path
out=Path('D:/RPGGAME/artifacts/female_character'); out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath='D:/RPGGAME/artifacts/female_character/generated.glb')
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
print([(o.name,list(o.dimensions),len(o.data.vertices),len(o.data.materials)) for o in meshes])
points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector(tuple(min(p[i] for p in points) for i in range(3))); hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
center=(lo+hi)/2
scene=bpy.context.scene
scene.render.engine='BLENDER_WORKBENCH'
scene.render.resolution_x=650; scene.render.resolution_y=850; scene.render.resolution_percentage=100
scene.display.shading.light='STUDIO'; scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=True; scene.display.shading.show_cavity=True
for name,direction in [('front',(0,-1,0)),('back',(0,1,0)),('side',(1,0,0))]:
 bpy.ops.object.camera_add(location=center+Vector(direction)*max(hi-lo)*3)
 cam=bpy.context.object; cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=(hi.z-lo.z)*1.15; scene.camera=cam
 scene.render.filepath=str(out/(name+'.png')); bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source.blend'))
