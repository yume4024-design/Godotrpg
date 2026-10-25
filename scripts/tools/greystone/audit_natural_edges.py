"""Check real master geometry: closed rock shells and grounded turf rim vertices."""
import bpy
import bmesh
import json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'artifacts/reference_edges_20261025/natural_edges_audit.json'
OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source_assets/greystone_reference_20261024/greystone_master.blend'))
cliffs=bpy.data.collections['Cliffs']
rocks=[o for o in cliffs.objects if '_RockFace' in o.name]
grass=[o for o in cliffs.objects if o.name.startswith('NaturalRimGrass_')]
bad=[]
for obj in rocks:
    bm=bmesh.new();bm.from_mesh(obj.data)
    if any(not edge.is_manifold for edge in bm.edges):bad.append(obj.name+' open shell')
    if any(face.calc_area()<1e-7 for face in bm.faces):bad.append(obj.name+' degenerate face')
    bm.free()
points=[];faces=[]
for obj in rocks+list(bpy.data.collections['Terrain'].objects):
    if obj.type!='MESH':continue
    offset=len(points)
    points.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
surface=BVHTree.FromPolygons(points,faces,all_triangles=False)
gaps=[]
for obj in grass:
    sector=obj.name.removeprefix('NaturalRimGrass_')
    floor=bpy.data.objects[sector+'_Grass']
    floor_height=max((floor.matrix_world@v.co).z for v in floor.data.vertices)
    for vertex in obj.data.vertices:
        p=obj.matrix_world@vertex.co
        if p.z>floor_height+.05:bad.append(obj.name+' crosses a higher plateau')
        hit=surface.ray_cast(p+Vector((0,0,.5)),Vector((0,0,-1)),2)[0]
        if hit is None:bad.append(obj.name+' unsupported turf')
        else:
            gap=p.z-hit.z;gaps.append(gap)
            if gap<-.002 or gap>.045:bad.append(obj.name+' turf gap '+str(gap))
result={'rock_shells':len(rocks),'turf_batches':len(grass),'sampled_turf_vertices':len(gaps),
        'min_surface_gap_m':min(gaps),'max_surface_gap_m':max(gaps),
        'failures':sorted(set(bad)),
        'scope':'Manifold rock edges, face area, turf vertices over actual rock/terrain; not a full visual quality certificate'}
OUT.write_text(json.dumps(result,indent=2),encoding='utf-8')
print('NATURAL_EDGES_AUDIT',json.dumps(result),flush=True)
assert len(rocks)==195 and len(grass)==8 and not bad,result
