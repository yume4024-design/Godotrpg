"""Blender: read-only evaluated motion sampling for one native candidate."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts/tools'))
from asset_triangle_budget import resolve_budget

p = argparse.ArgumentParser()
p.add_argument('--input', required=True, type=Path)
p.add_argument('--category', required=True)
p.add_argument('--output', required=True, type=Path)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
limit = resolve_budget(a.category)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == 'MESH']
rigs = [o for o in scene.objects if o.type == 'ARMATURE']
failures, actions, topology = [], {}, []
if len(rigs) != 1 or not meshes:
    raise ValueError('Expected one real rig and at least one mesh')
rig = rigs[0]
baseline = {}
for body in meshes:
    points = np.array([tuple(v.co) for v in body.data.vertices])
    edges = np.array([tuple(e.vertices) for e in body.data.edges])
    lengths = np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1)
    baseline[body.name] = (edges, lengths, lengths > max(np.ptp(points[:, 2]) * .004, 1e-6))
    counts = np.zeros(len(body.data.edges), dtype=int)
    edge_map = {tuple(sorted(e.vertices)): e.index for e in body.data.edges}
    for polygon in body.data.polygons:
        for pair in polygon.edge_keys:
            counts[edge_map[tuple(sorted(pair))]] += 1
    topology.append({'mesh': body.name, 'boundary_edges': int(np.sum(counts == 1)),
                     'nonmanifold_edges': int(np.sum(counts != 2))})
for action in bpy.data.actions:
    rig.animation_data_create()
    rig.animation_data.action = action
    if action.slots:
        rig.animation_data.action_slot = action.slots[0]
    frames, stretch, maximum, floor = 0, 0.0, 0, []
    first_points, last_points = {}, {}
    for frame in range(int(action.frame_range[0]), int(action.frame_range[1]) + 1):
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        total = 0
        for body in meshes:
            evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
            mesh = evaluated.to_mesh()
            mesh.calc_loop_triangles()
            total += len(mesh.loop_triangles)
            points = np.array([tuple(v.co) for v in mesh.vertices])
            if frames == 0:
                first_points[body.name] = points.copy()
            last_points[body.name] = points.copy()
            if not np.isfinite(points).all():
                failures.append(f'{action.name}:{frame}:NONFINITE_VERTEX')
            edges, lengths, valid = baseline[body.name]
            if len(points) != len(body.data.vertices):
                failures.append(f'{action.name}:{frame}:TOPOLOGY_CHANGED')
            else:
                stretch = max(stretch, float((np.linalg.norm(points[edges[:, 0]] - points[edges[:, 1]], axis=1)[valid] / lengths[valid]).max()))
            floor.append(float(points[:, 2].min()))
            evaluated.to_mesh_clear()
        maximum = max(maximum, total)
        frames += 1
    if maximum <= 0 or maximum > limit:
        failures.append(action.name + ':TRIANGLE_BUDGET')
    if stretch >= 2.5:
        failures.append(action.name + ':EXCESSIVE_EDGE_STRETCH')
    loop_error = max(float(np.abs(last_points[name] - values).max()) for name, values in first_points.items())
    if action.name in ['idle', 'walk', 'run'] and loop_error > 1e-4:
        failures.append(action.name + ':LOOP_SEAM')
    actions[action.name] = {'frames': frames, 'maximum_triangles': maximum,
                            'endpoint_vertex_difference': loop_error,
                            'max_edge_stretch': stretch, 'floor_range': [min(floor), max(floor)]}
if not actions:
    failures.append('NO_ACTIONS')
report = {'input': str(a.input), 'sha256': hashlib.sha256(a.input.read_bytes()).hexdigest(),
          'category': a.category, 'maximum_triangles': limit, 'bones': len(rig.data.bones),
          'actions': actions, 'total_frames': sum(v['frames'] for v in actions.values()),
          'topology_warnings': topology, 'failures': failures,
          'status': 'FAIL' if failures else 'PASS',
          'limitations': ['Numeric screening does not certify intersections or artistic fidelity',
                          'Nonmanifold counts are warnings; visual review remains separate']}
a.output.parent.mkdir(parents=True, exist_ok=True)
a.output.write_text(json.dumps(report, indent=2), encoding='utf8')
print('ASSET_MOTION', report['status'], report['total_frames'], 'frames', flush=True)
if failures:
    raise RuntimeError(failures)
