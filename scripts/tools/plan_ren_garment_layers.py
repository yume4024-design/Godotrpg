"""Select actual garment faces from a manually inspected cylindrical hem contour.

This is a topology plan, never a brightness/depth skin mask. The explicit face
receipt and colored views must be inspected before the layer builder is run.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert sha=='93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
body=next(o for o in scene.objects if o.type=='MESH')
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
for bone in rig.pose.bones:bone.matrix_basis.identity()
scene.frame_set(0)
bpy.context.view_layer.update()
# Seen in actual front/back/left close-ups. Clockwise contour at the underside
# of the existing hem; center front/back notches rise towards the belt.
anchors=[(-.210,0,.942),(-.186,.093,.929),(-.110,.153,.918),
         (-.023,.142,.909),(0,.107,1.020),(.019,.131,.946),
         (.111,.152,.930),(.185,.089,.947),(.205,0,.968),
         (.184,-.048,.980),(.136,-.138,.914),(.087,-.149,.897),
         (.004,-.135,1.006),(-.014,-.134,1.061),(-.068,-.127,1.013),
         (-.091,-.148,.897),(-.135,-.126,.920),(-.176,-.075,.951)]
knots=sorted((math.atan2(y,x),z) for x,y,z in anchors)

def hem_height(x,y):
    angle=math.atan2(y,x)
    extended=[(knots[-1][0]-math.tau,knots[-1][1])]+knots+[(knots[0][0]+math.tau,knots[0][1])]
    for (lo,hlo),(hi,hhi) in zip(extended,extended[1:]):
        if lo<=angle<=hi:
            return hlo+(hhi-hlo)*(angle-lo)/(hi-lo)
    raise ValueError(angle)

selected=[]
for face in body.data.polygons:
    x,y,z=face.center
    if abs(x)>.295 or not hem_height(x,y)<z<1.112:continue
    arm=max(sum(g.weight for g in body.data.vertices[v].groups
                if body.vertex_groups[g.group].name.startswith(('Arm','Forearm','Hand','Fingers')))
            for v in face.vertices)
    if arm>.15:continue
    selected.append(face.index)
assert 100<len(selected)<len(body.data.polygons)//3,len(selected)
a.output.mkdir(parents=True)
report={'source_sha256':sha,'mesh':body.name,'source_triangles':12808,
        'method':'Manually inspected hem contour, explicit face receipt for real garment separation',
        'hem_landmarks':anchors,'waist_z':1.112,'selected_faces':selected,
        'selected_face_count':len(selected),'status':'VISUAL_REVIEW_REQUIRED',
        'limitations':['No rig change or export yet','Face selection must retain the white hem and exclude hands/trousers']}
(a.output/'layer_plan.json').write_text(json.dumps(report,indent=2),encoding='utf8')
gray=bpy.data.materials.new('RetainedBodyPlan');gray.diffuse_color=(.27,.32,.36,1)
red=bpy.data.materials.new('DetachedGarmentPlan');red.diffuse_color=(.75,.08,.04,1)
body.data.materials.clear();body.data.materials.append(gray);body.data.materials.append(red)
selected=set(selected)
for face in body.data.polygons:face.material_index=int(face.index in selected)
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_cavity=True
scene.render.resolution_x=scene.render.resolution_y=800
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
data=bpy.data.cameras.new('LayerPlanCamera');camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera);scene.camera=camera
data.type='ORTHO';data.ortho_scale=.74
for name,position in [('front',(0,-3,.98)),('back',(0,3,.98)),('left',(3,0,.98))]:
    camera.location=position
    camera.rotation_euler=(Vector((0,0,.98))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(name+'.png')).resolve())
    bpy.ops.render.render(write_still=True)
print('REN_LAYER_PLAN',len(selected),'faces',flush=True)
