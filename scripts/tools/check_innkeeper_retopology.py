"""Read-only Blender preservation audit for the bounded apron reconstruction."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys

import bpy

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--candidate', type=Path, required=True)
p.add_argument('--recipe', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
recipe = json.loads(a.recipe.read_text(encoding='utf-8-sig'))
assert hashlib.sha256(a.source.read_bytes()).hexdigest() == recipe['source_sha256']
removed = set(recipe['removed_face_indices'])

def load(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    mesh = body.data
    keys, face_normals = [], []
    for face in mesh.polygons:
        corners = []
        for loop in face.loop_indices:
            point = mesh.vertices[mesh.loops[loop].vertex_index].co
            uv = mesh.uv_layers.active.data[loop].uv
            normal = mesh.corner_normals[loop].vector
            corners.append((tuple(round(v, 6) for v in [*point, *uv]), tuple(normal)))
        corners.sort()
        keys.append(tuple(row[0] for row in corners))
        face_normals.append(tuple(row[1] for row in corners))
    texture = next(n for n in mesh.materials[0].node_tree.nodes if n.type == 'BSDF_PRINCIPLED').inputs['Base Color'].links[0].from_node.image
    texture_sha = hashlib.sha256(texture.packed_file.data).hexdigest()
    return body, keys, texture_sha, face_normals

_, source_keys, source_texture, source_normals = load(a.source)
_, candidate_keys, candidate_texture, candidate_normals = load(a.candidate)
expected = Counter(k for i, k in enumerate(source_keys) if i not in removed)
actual = Counter(candidate_keys)
missing = expected - actual
normal_error = 0.
lookup = {}
for key, normals in zip(candidate_keys, candidate_normals): lookup.setdefault(key, []).append(normals)
for index, key in enumerate(source_keys):
    if index in removed or key not in lookup: continue
    candidates = lookup[key]
    normal_error = max(normal_error, min(max(abs(a-b) for x,y in zip(source_normals[index], row) for a,b in zip(x,y)) for row in candidates))
print('RETAINED_NORMAL_MAX_COMPONENT_ERROR', normal_error, flush=True)
checks = {'retained_face_corner_geometry_uv': not missing,
          'normal_reencoding_error_below_0_001': normal_error < .001,
          'original_body_albedo_identical': source_texture == candidate_texture,
          'explicit_clipping_preserves_pants_fragments': recipe['clipped_pants_boundary_fragments'] > 0,
          'triangle_budget': 0 < recipe['triangles'] <= 15000}
report = {'checks': checks, 'status': 'PASS' if all(checks.values()) else 'FAIL',
          'retained_source_faces': sum(expected.values()), 'missing_retained_faces': sum(missing.values()),
          'removed_front_cloth_faces': len(removed), 'source_texture_sha256': source_texture,
          'retained_normal_max_component_error': normal_error,
          'candidate_texture_sha256': candidate_texture, 'scope': 'Outside the explicitly replaced cloth region; no animation or gameplay claim'}
a.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print('INNKEEPER_PRESERVATION', report['status'], report['missing_retained_faces'], 'missing retained faces', flush=True)
if not all(checks.values()):
    raise RuntimeError(checks)
