"""Read-only anatomy inventory for the preserved bat topology work copy."""
import argparse
import json
from pathlib import Path
import sys
import bpy
import numpy as np

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.rotation_mode = 'QUATERNION'
    bone.rotation_quaternion = (1, 0, 0, 0)
    bone.location = (0, 0, 0)
    bone.scale = (1, 1, 1)
bpy.context.view_layer.update()
points = np.array([tuple(v.co) for v in body.data.vertices])
weights = np.zeros((len(points), len(body.vertex_groups)))
for v in body.data.vertices:
    for g in v.groups:
        weights[v.index, g.group] = g.weight
rows = []
for group in body.vertex_groups:
    ids = np.flatnonzero(weights[:, group.index] > .05)
    rows.append({'name': group.name, 'vertices_gt_05': len(ids),
                 'bounds_gt_05': np.array([points[ids].min(0), points[ids].max(0)]).tolist()
                 if len(ids) else None})
report = {'mesh': body.name, 'vertices': len(points), 'faces': len(body.data.polygons),
          'matrix': [list(row) for row in body.matrix_world],
          'bounds': [points.min(0).tolist(), points.max(0).tolist()],
          'bones': [{'name': b.name, 'parent': b.parent.name if b.parent else None,
                     'head': list(b.head_local), 'tail': list(b.tail_local)} for b in rig.data.bones],
          'groups': rows,
          'actions': {act.name: list(act.frame_range) for act in bpy.data.actions},
          'materials': [m.name for m in body.data.materials]}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, indent=2), encoding='utf8', newline='\n')
np.savez_compressed(a.output.with_suffix('.npz'), points=points, weights=weights,
                    faces=np.array([tuple(f.vertices) for f in body.data.polygons]))
texture = next(n.image for n in body.data.materials[0].node_tree.nodes
               if n.type == 'TEX_IMAGE' and n.image.colorspace_settings.name == 'sRGB')
pixels = np.array(texture.pixels[:], dtype=np.float32).reshape(texture.size[1], texture.size[0], 4)
uv = np.array([tuple(item.uv) for item in body.data.uv_layers.active.data])
px = (np.mod(uv[:, 0], 1) * (texture.size[0]-1)).astype(int)
py = (np.mod(uv[:, 1], 1) * (texture.size[1]-1)).astype(int)
colors = pixels[py, px]
np.savez_compressed(a.output.with_name('surface.npz'),
                    loop_colors=colors, loop_uv=uv,
                    loop_vertices=np.array([item.vertex_index for item in body.data.loops]),
                    normals=np.array([tuple(item.normal) for item in body.data.polygons]))
print(json.dumps(report, indent=2))
