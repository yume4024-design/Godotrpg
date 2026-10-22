"""Author a rigid three-part mine frame in a separate background Blender.

All geometry fits the existing two post boxes and overhead visual box. No new
braces project into the opening. Materials reuse the approved G04 palette.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import bmesh
import bpy
from mathutils import Vector


def arguments():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--budget", type=int, required=True)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:])


def blender_point(point):
    return (point[0], -point[2], point[1])


def profile(a, b, bevel):
    return [(a-bevel,-b),(a,-b+bevel),(a,b-bevel),(a-bevel,b),
            (-a+bevel,b),(-a,b-bevel),(-a,-b+bevel),(-a+bevel,-b)]


def axis_point(axis, t, a, b):
    return blender_point((a,t,b) if axis == "y" else (t,a,b))


def mesh_object(name, vertices, faces, indices, palette):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for material in palette:
        mesh.materials.append(material)
    for polygon, index in zip(mesh.polygons, indices):
        polygon.material_index = index
        polygon.use_smooth = False
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def prism(name, center, axis, length, half_a, half_b, bevel, palette):
    rings = [(-length/2,half_a-bevel,half_b-bevel,bevel/2),
             (-length/2+bevel,half_a,half_b,bevel),
             (length/2-bevel,half_a,half_b,bevel),
             (length/2,half_a-bevel,half_b-bevel,bevel/2)]
    vertices = [axis_point(axis,t,a,b) for t,ha,hb,c in rings for a,b in profile(ha,hb,c)]
    faces, indices = [], []
    for ring in range(3):
        for index in range(8):
            next_index = (index+1) % 8
            faces.append((ring*8+index,ring*8+next_index,(ring+1)*8+next_index,(ring+1)*8+index))
            indices.append(0)
    faces.extend([tuple(reversed(range(8))),tuple(range(24,32))])
    indices.extend([1,1])
    obj = mesh_object(name,vertices,faces,indices,palette)
    obj.location = blender_point(center)
    return obj


def strap(name, center, axis, outer, inner, palette):
    vertices = []
    for t,half in [(-.045,outer),(.045,outer),(-.045,inner),(.045,inner)]:
        vertices += [axis_point(axis,t,a,b) for a,b in profile(*half,.012)]
    faces = []
    for low,high in [(0,8),(16,24),(8,24),(0,16)]:
        for index in range(8):
            next_index = (index+1) % 8
            faces.append((low+index,low+next_index,high+next_index,high+index))
    obj = mesh_object(name,vertices,faces,[2]*len(faces),palette)
    obj.location = blender_point(center)
    return obj


def rivet(name, center, palette):
    vertices = [blender_point((math.cos(i*math.tau/6)*.018,
                              math.sin(i*math.tau/6)*.018,z))
                for z in [-.003,.003] for i in range(6)]
    faces = [(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)]
    faces.extend([tuple(reversed(range(6))),tuple(range(6,12))])
    obj = mesh_object(name,vertices,faces,[2]*len(faces),palette)
    obj.location = blender_point(center)
    return obj


def combine(body, parts):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [body,*parts]: obj.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.data.name = body.name
    return body


def inspect(obj, expected):
    mesh = obj.data
    mesh.calc_loop_triangles()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    assert all(edge.is_manifold for edge in bm.edges), obj.name
    assert all(face.calc_area() > 1e-10 for face in bm.faces), obj.name
    bm.free()
    points = [obj.matrix_world @ vertex.co for vertex in mesh.vertices]
    # Convert back to the declared Godot coordinate system for source checks.
    godot = [Vector((p.x,p.z,-p.y)) for p in points]
    low = Vector([min(p[i] for p in godot) for i in range(3)])
    high = Vector([max(p[i] for p in godot) for i in range(3)])
    assert all(math.isfinite(value) for p in godot for value in p)
    for index in range(3):
        assert low[index] >= expected[0][index]-1e-6, (obj.name,low,expected)
        assert high[index] <= expected[1][index]+1e-6, (obj.name,high,expected)
    return {"node":obj.name,"triangles":len(mesh.loop_triangles),
            "godot_bounds":[list(low),list(high)],"boundary_or_nonmanifold_edges":0,
            "zero_area_faces":0,"intentional_closed_overlapping_components":True,
            "self_intersection_union_tested":False}


def main():
    args = arguments()
    assert 0 < args.budget <= 10000
    assert not args.output.exists(), "Preserve previous builds."
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # No UI thumbnail cache should be written outside this controlled build.
    preferences = bpy.context.preferences.filepaths
    preview_property = preferences.bl_rna.properties.get("file_preview_type")
    assert preview_property is not None
    assert "NONE" in [item.identifier for item in preview_property.enum_items]
    preferences.file_preview_type = "NONE"
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    materials = []
    for key,rgb in [("wood",(.43,.29,.16)),("wood_cut",(.73,.54,.32)),("iron",(.27,.31,.33))]:
        material = bpy.data.materials.new("G04_"+key)
        material.diffuse_color = (*rgb,1)
        if material.node_tree is None: material.use_nodes = True
        shader = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = (*[v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in rgb],1)
        shader.inputs["Roughness"].default_value = .9
        materials.append(material)
    root = bpy.data.objects.new("MineSupportFrame",None)
    bpy.context.scene.collection.objects.link(root)
    objects = []
    for name,x in [("PostLeft",-2.2),("PostRight",2.2)]:
        body = prism(name,(x,1.2,0),"y",2.4,.112,.112,.015,materials)
        parts = []
        for height in [.24,2.08]:
            parts.append(strap(name+"Band",(x,height,0),"y",(.125,.12),(.110,.110),materials))
            for sign in [-1,1]: parts.append(rivet(name+"Rivet",(x,height,sign*.122),materials))
        objects.append(combine(body,parts))
    body = prism("Beam",(0,2.5,0),"x",4.7,.117,.142,.018,materials)
    parts = []
    for x in [-2.2,2.2]:
        parts.append(strap("BeamBand",(x,2.5,0),"x",(.125,.145),(.113,.133),materials))
        for sign in [-1,1]: parts.append(rivet("BeamRivet",(x,2.5,sign*.147),materials))
    objects.append(combine(body,parts))
    for obj in objects: obj.parent = root
    bpy.context.view_layer.update()
    bounds = [((-2.325,0,-.125),(-2.075,2.4,.125)),
              ((2.075,0,-.125),(2.325,2.4,.125)),
              ((-2.35,2.375,-.15),(2.35,2.625,.15))]
    metrics = [inspect(obj,bound) for obj,bound in zip(objects,bounds)]
    triangles = sum(row["triangles"] for row in metrics)
    assert triangles <= args.budget
    args.output.mkdir(parents=True)
    native = (args.output/"mine_support_frame.blend").resolve()
    glb = (args.output/"mine_support_frame.glb").resolve()
    bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format="GLB",use_selection=True,
                              export_animations=False,export_yup=True)
    receipt = {"author":"Project Crystal; original procedural mesh","blender":bpy.app.version_string,
               "triangles":triangles,"budget":args.budget,"parts":metrics,
               "palette":"existing G04 wood / wood_cut / iron; shared post-import resources",
               "textures":0,"materials":3,"rigid_meshes":3,
               "scale":"1 unit = 1 metre; Y-up glTF; ground-centre root",
               "original_collision_boxes_unchanged":True,"formal_map_integrated":False,
               "outputs":{p.name:{"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"bytes":p.stat().st_size}for p in [native,glb]}}
    (args.output/"build.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8",newline="\n")
    print("MINE_SUPPORT_BUILT",triangles,"triangles",flush=True)


if __name__ == "__main__":
    main()
