"""Check real master geometry: closed rock shells and grounded turf rim vertices."""
import bpy
import bmesh
import json
import argparse
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser()
parser.add_argument('--output',default='artifacts/reference_edges_20261025/natural_edges_audit.json')
parser.add_argument('--source',default='source_assets/greystone_reference_20261024/greystone_master.blend')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=ROOT/args.output
OUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/args.source))
cliffs=bpy.data.collections['Cliffs']
rocks=[o for o in cliffs.objects if '_RockFace' in o.name]
grass=[o for o in cliffs.objects if o.name.startswith('NaturalRimGrass_')]
bad=[]
convex_rocks=0
for obj in rocks:
    bm=bmesh.new();bm.from_mesh(obj.data)
    if any(not edge.is_manifold for edge in bm.edges):bad.append(obj.name+' open shell')
    if any(face.calc_area()<1e-7 for face in bm.faces):bad.append(obj.name+' degenerate face')
    if any(len(face.verts)!=3 for face in bm.faces):bad.append(obj.name+' averaged polygon normals')
    bm.normal_update()
    convex=all(all(face.normal.dot(v.co-face.verts[0].co)<=1e-4 for v in bm.verts) for face in bm.faces)
    if not convex:bad.append(obj.name+' concave rock shell')
    else:convex_rocks+=1
    bm.free()
points=[];faces=[]
for obj in rocks+list(bpy.data.collections['Terrain'].objects):
    if obj.type!='MESH':continue
    offset=len(points)
    points.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    faces.extend(tuple(offset+i for i in p.vertices) for p in obj.data.polygons)
surface=BVHTree.FromPolygons(points,faces,all_triangles=False)
gaps=[];soil_seams=[]
for obj in grass:
    sector=obj.name.removeprefix('NaturalRimGrass_')
    floor=bpy.data.objects[sector+'_Grass']
    floor_height=max((floor.matrix_world@v.co).z for v in floor.data.vertices)
    soil=bpy.data.objects['NaturalRimSoil_'+sector]
    for i,vertex in enumerate(obj.data.vertices):
        cap,corner=divmod(i,7)
        delta=(obj.matrix_world@vertex.co-soil.matrix_world@soil.data.vertices[cap*14+corner].co).length
        soil_seams.append(delta)
        if delta>1e-5:bad.append(obj.name+' disconnected earth rim')
    for vertex in obj.data.vertices:
        p=obj.matrix_world@vertex.co
        if p.z>floor_height+.05:bad.append(obj.name+' crosses a higher plateau')
        hit=surface.ray_cast(p+Vector((0,0,.5)),Vector((0,0,-1)),2)[0]
        if hit is None:bad.append(obj.name+' unsupported turf')
        else:
            gap=p.z-hit.z;gaps.append(gap)
            if gap<-.002 or gap>.045:bad.append(obj.name+' turf gap '+str(gap))
result={'rock_shells':len(rocks),'convex_rock_shells':convex_rocks,'turf_batches':len(grass),'sampled_turf_vertices':len(gaps),
        'min_surface_gap_m':min(gaps),'max_surface_gap_m':max(gaps),
        'max_soil_seam_m':max(soil_seams),
        'failures':sorted(set(bad)),
        'scope':'Closed convex triangulated rocks, face area, turf support and attached soil skirt; not a full visual quality certificate'}
OUT.write_text(json.dumps(result,indent=2),encoding='utf-8')
print('NATURAL_EDGES_AUDIT',json.dumps(result),flush=True)
assert len(rocks)==195 and len(grass)==8 and not bad,result
