"""Original shared willow staff, grip-centered, no textures or external assets."""
import bpy
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name,color):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
 m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.8
 return m
wood=material('WillowWood',(.22,.105,.045)); wrap=material('LeatherGrip',(.07,.035,.02)); tip=material('StaffBinding',(.55,.32,.08))
def segment(name,a,b,radius,mat):
 bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=radius,radius2=radius*.85,depth=(Vector(b)-Vector(a)).length,location=(Vector(a)+Vector(b))/2)
 o=bpy.context.object; o.name=name; o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler(); o.data.materials.append(mat)
segment('Shaft',(0,0,-.43),(0,0,.64),.024,wood)
segment('Grip',(0,0,-.07),(0,0,.07),.029,wrap)
segment('WillowCrook',(0,0,.62),(.07,0,.75),.025,wood)
segment('CrookTip',(.07,0,.75),(.15,0,.7),.023,wood)
segment('Binding',(0,0,.47),(0,0,.51),.027,tip)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
tris=0
for o in meshes: o.data.calc_loop_triangles(); tris+=len(o.data.loop_triangles)
assert tris<=200
bpy.ops.export_scene.gltf(filepath=str(root/'assets/models/female/willow_staff.glb'),export_format='GLB',use_selection=False)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'assets/source/female/willow_staff.blend'))
print('WILLOW_STAFF_TRIANGLES',tris)
