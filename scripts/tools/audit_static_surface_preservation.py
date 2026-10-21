"""Read-only static geometry/UV/normal preservation and physical-edge inventory.

Coincident glTF seam vertices are grouped for diagnostics without welding the
asset. Open clothing and original topology warnings are reported, not hidden.
"""
import argparse,hashlib,json,sys
from collections import Counter, defaultdict
from pathlib import Path
import bpy
import numpy as np

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--before',type=Path,required=True)
p.add_argument('--after',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])

def capture(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    meshes=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
    assert len(meshes)==1 and not any(obj.type=='ARMATURE' for obj in bpy.context.scene.objects)
    mesh=meshes[0].data;mesh.calc_loop_triangles()
    return {'points':np.array([tuple(v.co) for v in mesh.vertices]),
            'uv':np.array([tuple(loop.uv) for loop in mesh.uv_layers.active.data]),
            'faces':[tuple(face.vertices) for face in mesh.polygons],
            'normals':np.array([tuple(normal.vector) for normal in mesh.corner_normals]),
            'triangles':len(mesh.loop_triangles)}

before=capture(a.before);after=capture(a.after)
checks={'positions_exact':np.array_equal(before['points'],after['points']),
        'uv_exact':np.array_equal(before['uv'],after['uv']),
        'face_indices_exact':before['faces']==after['faces'],
        'corner_normals_exact':np.array_equal(before['normals'],after['normals']),
        'triangle_count_exact':before['triangles']==after['triangles']}
ids={};canonical=[]
for point in after['points']:
    canonical.append(ids.setdefault(tuple(point),len(ids)))
edge_uses=Counter()
incidence=defaultdict(list)
for face_id,face in enumerate(after['faces']):
    for lo,hi in zip(face,face[1:]+face[:1]):
        edge=tuple(sorted((canonical[lo],canonical[hi])))
        edge_uses[edge]+=1
        incidence[edge].append(face_id)
physical_positions=list(ids)
problem_edges=[{'kind':'boundary' if count==1 else 'junction',
                'points':[[float(v)for v in physical_positions[point]]for point in edge],
                'face_ids':incidence[edge]}for edge,count in edge_uses.items()if count!=2]
topology={'uv_split_vertices':len(canonical),'unique_physical_positions':len(ids),
          'physical_edges':len(edge_uses),'physical_boundary_edges':sum(count==1 for count in edge_uses.values()),
          'physical_edges_over_two_faces':sum(count>2 for count in edge_uses.values()),
          'zero_length_physical_edges':sum(lo==hi for lo,hi in edge_uses)}
report={'status':'PASS' if all(checks.values()) else 'FAIL','checks':checks,
        'before':{'path':str(a.before),'sha256':hashlib.sha256(a.before.read_bytes()).hexdigest()},
        'after':{'path':str(a.after),'sha256':hashlib.sha256(a.after.read_bytes()).hexdigest()},
        'triangles':after['triangles'],'bounds_min':after['points'].min(axis=0).tolist(),
        'bounds_max':after['points'].max(axis=0).tolist(),'physical_topology_diagnostic':topology,
        'physical_problem_edges':problem_edges,
        'limits':['Colour atlas intentionally changes; not an albedo equality claim',
                  'Exact-position grouping is diagnostic only; no weld or topology repair',
                  'No rig, animation, cloth collision or gameplay acceptance']}
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('STATIC_SURFACE_PRESERVATION',report['status'],topology,flush=True)
if not all(checks.values()):raise RuntimeError(checks)
