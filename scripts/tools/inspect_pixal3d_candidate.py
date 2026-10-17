"""Inspect and render a new ComfyUI GLB in an isolated Blender process."""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument("--input", required=True)
parser.add_argument("--character", choices=["ren", "lia"], required=True)
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
root = Path(__file__).resolve().parents[2]
output = root / "artifacts/pixal3d" / args.character
output.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=args.input)
models = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
triangles = 0
for obj in models:
    obj.data.calc_loop_triangles()
    triangles += len(obj.data.loop_triangles)
points = [obj.matrix_world @ v.co for obj in models for v in obj.data.vertices]
low = Vector(tuple(min(point[axis] for point in points) for axis in range(3)))
high = Vector(tuple(max(point[axis] for point in points) for axis in range(3)))
report = {"input": args.input, "triangles": triangles, "bounds_min": list(low), "bounds_max": list(high), "objects": [{"name": obj.name, "vertices": len(obj.data.vertices), "uv_layers": len(obj.data.uv_layers), "materials": [m.name if m else None for m in obj.data.materials]} for obj in models], "images": [{"name": image.name, "size": list(image.size)} for image in bpy.data.images], "rigged": any(obj.type == "ARMATURE" for obj in bpy.context.scene.objects)}
(output / "raw_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
assert triangles < 5000, f"Candidate exceeds budget: {triangles}"
assert all(obj.data.uv_layers for obj in models), "UV missing"
assert bpy.data.images, "Generated textures missing"
# Normalize only the presentation copy; preserve the raw generated file.
center = (low + high) * .5
scale = 1.95 / (high.z - low.z)
for obj in models:
    matrix = obj.matrix_world.copy()
    for vertex in obj.data.vertices:
        point = matrix @ vertex.co
        vertex.co = Vector((point.x-center.x, point.y-center.y, point.z-low.z)) * scale
    obj.matrix_world.identity()
source = root / "assets/source/pixal3d"
source.mkdir(parents=True, exist_ok=True)
(source / ".gdignore").write_text("")
bpy.ops.wm.save_as_mainfile(filepath=str(output / "candidate.blend"))
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.render.resolution_x = 700
scene.render.resolution_y = 850
scene.render.resolution_percentage = 100
scene.world = bpy.data.worlds.new("InspectionWorld")
scene.world.use_nodes = True
background = next(node for node in scene.world.node_tree.nodes if node.type == "BACKGROUND")
background.inputs[0].default_value = (.14,.17,.22,1)
background.inputs[1].default_value = .7
for location, power, size in [((3,-4,5),500,4),((-3,1,3),350,3)]:
    light = bpy.data.lights.new("Softbox", "AREA")
    light.energy = power
    light.shape = "DISK"
    light.size = size
    obj = bpy.data.objects.new("Softbox", light)
    scene.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector((0,0,1))-obj.location).to_track_quat("-Z","Y").to_euler()
camera = bpy.data.objects.new("InspectionCamera", bpy.data.cameras.new("InspectionCamera"))
scene.collection.objects.link(camera)
scene.camera = camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.15
for name, angle in [("front",0),("right",math.pi/2),("back",math.pi),("left",3*math.pi/2)]:
    camera.location = (3*math.sin(angle),-3*math.cos(angle),1.05)
    camera.rotation_euler = (Vector((0,0,.98))-camera.location).to_track_quat("-Z","Y").to_euler()
    scene.render.filepath = str(output / (name + ".png"))
    bpy.ops.render.render(write_still=True)
print("PIXAL3D_CANDIDATE", json.dumps(report))
