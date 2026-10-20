"""Read-only exact degenerate-face evidence after the candidate GLB import."""
import json
from pathlib import Path
import sys
import bpy
import bmesh
p = Path(sys.argv[sys.argv.index('--')+1])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(p.resolve()))
rows = []
for obj in bpy.context.scene.objects:
    if obj.type != 'MESH' or obj.parent is None or obj.parent.type != 'ARMATURE':
        continue
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    for f in bm.faces:
        if f.calc_area() < 1e-11:
            rows.append({'mesh':obj.name,'face':f.index, 'area':f.calc_area(),
                         'vertices':[list(v.co) for v in f.verts]})
    bm.free()
print(json.dumps(rows,indent=2))
