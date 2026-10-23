"""Local non-destructive mesh/material corrections for the first Pixal inn."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'source_assets/greystone_ai_20261023/inn/pixal_candidate_01'
OUT=SOURCE/'door_only';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'inn_review.blend'))
scene=bpy.context.scene
meshes=[o for o in scene.objects if o.type=='MESH']
for o in meshes:
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
def mat(name,color):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85
    return m
wood=mat('RepairedDoor_WarmOak',(.22,.12,.055));dark=mat('DoorFrame',(.09,.045,.02));metal=mat('DoorIron',(.07,.07,.065))
def box(name,pos,size,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT')
    meshes.append(o);return o
# Locate the white front-door surface on actual geometry before placing the repair.
deps=bpy.context.evaluated_depsgraph_get()
hit,location,normal,face,obj,_=scene.ray_cast(deps,Vector((-.2,-20,1.15)),Vector((0,1,0)))
if not hit:raise RuntimeError('Cannot locate front door surface')
y=location.y-.065
for i in range(6):box('OakDoorPlank',(-.2+(i-2.5)*.22,y,1.15),(.21,.13,1.95),wood)
for x in [-.92,.52]:box('OakDoorJamb',(x,y-.02,1.2),(.14,.18,2.16),dark)
box('OakDoorLintel',(-.2,y-.02,2.25),(1.58,.18,.16),dark)
box('IronLatch',(.28,y-.12,1.1),(.08,.12,.18),metal)
# Roof overlays from repair01/02 were visually rejected. Retain original
# roof geometry and UV; only the blank front door is repaired for this candidate.
changed=0
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'inn_repaired.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'inn_repaired.blend'))
camera=scene.camera
for name,offset in [('front',(0,-28,0)),('overview',(15,-20,15)),('back',(0,28,0))]:
    center=Vector((0,0,3.6));camera.location=center+Vector(offset);camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'{name}.png');bpy.ops.render.render(write_still=True)
(OUT/'repair_report.json').write_text(json.dumps({'door_surface_y':location.y,'back_roof_faces_recolored':changed,'source_preserved':True,'visual_review':'pending'},indent=2),encoding='utf8')
