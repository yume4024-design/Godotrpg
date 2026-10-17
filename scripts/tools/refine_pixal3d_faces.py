"""Add small, original readable eyes to the new mesh; preserve generated UV clothes."""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

name = sys.argv[sys.argv.index("--")+1]
root = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root/f"artifacts/pixal3d/{name}/candidate.blend"))
body = next(obj for obj in bpy.context.scene.objects if obj.type=="MESH")
bpy.context.view_layer.objects.active = body
bvh = BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
def material(label,color):
    mat = bpy.data.materials.new(label)
    mat.use_nodes = True
    shader = next(node for node in mat.node_tree.nodes if node.type=="BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color,1)
    shader.inputs["Roughness"].default_value = .85
    return mat
skin = material("PixalFaceSkin",(.62,.40,.28))
body.data.materials.append(skin)
for polygon in body.data.polygons:
    center = polygon.center
    if 1.55<center.z<1.79 and abs(center.x)<.115 and center.y<-.065 and polygon.normal.y<-.25:
        polygon.material_index = len(body.data.materials)-1
white = material("PixalEyeWhite",(.87,.91,.94))
iris = material("PixalIris",(.025,.23,.55) if name=="lia" else (.12,.055,.022))
pupil = material("PixalPupil",(.006,.008,.012))
glint = material("PixalEyeGlint",(1,1,1))
mouth = material("PixalMouth",(.20,.06,.035))
def project(x,z,offset):
    point,normal,index,distance = bvh.ray_cast(Vector((x,-2,z)),Vector((0,1,0)),4)
    assert point is not None, (x,z)
    return (x,point.y-offset,z)
def eye(label,x,z,width,height,offset,mat,segments):
    vertices = [project(x,z,offset)]
    vertices += [project(x+width*.5*math.cos(index/segments*math.tau),z+height*.5*math.sin(index/segments*math.tau),offset) for index in range(segments)]
    faces = [(0,index+1,(index+1)%segments+1) for index in range(segments)]
    mesh = bpy.data.meshes.new(label)
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        co = mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = ((co.x-x)/width+.5,(co.z-z)/height+.5)
    obj = bpy.data.objects.new(label,mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(mat)
    obj.shape_key_add(name="Basis")
    blink = obj.shape_key_add(name="Blink")
    for vertex in blink.data: vertex.co.z = z
    obj["pixal_head_attachment"] = True
    return obj
for side,sign in [("Left",1),("Right",-1)]:
    x,z = sign*.057,1.735
    eye("PixalWhite"+side,x,z,.065,.036,.004,white,8)
    eye("PixalIris"+side,x,z,.029,.032,.006,iris,8)
    eye("PixalPupil"+side,x,z,.014,.022,.008,pupil,8)
    eye("PixalGlint"+side,x-.004,z+.006,.006,.008,.010,glint,3)
vertices = [project(x,z,.004) for x,z in [(-.021,1.642),(0,1.638),(.021,1.642),(-.021,1.645),(0,1.641),(.021,1.645)]]
mesh = bpy.data.meshes.new("PixalSmile")
mesh.from_pydata(vertices,[],[(0,1,4),(0,4,3),(1,2,5),(1,5,4)])
mesh.update()
uv = mesh.uv_layers.new(name="UVMap")
for loop in mesh.loops:
    co = mesh.vertices[loop.vertex_index].co
    uv.data[loop.index].uv = (co.x/.05+.5,(co.z-1.638)/.01)
smile = bpy.data.objects.new("PixalSmile",mesh)
bpy.context.collection.objects.link(smile)
mesh.materials.append(mouth)
smile["pixal_head_attachment"] = True
scene = bpy.context.scene
triangles = 0
for obj in scene.objects:
    if obj.type=="MESH":
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
assert triangles+140<5000, triangles
bpy.ops.wm.save_as_mainfile(filepath=str(root/f"artifacts/pixal3d/{name}/face.blend"))
print("PIXAL_FACE",json.dumps({"character":name,"triangles":triangles,"with_staff":triangles+140,"blink_surfaces":8}))
