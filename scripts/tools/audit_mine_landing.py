"""Check actual exported timber/earth separation at the east bridge landing."""
import bpy,json,argparse,sys,hashlib
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--master',default=str(R/'source_assets/mine_reference_20261024/mine_reference_master.blend'));p.add_argument('--output',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);bpy.ops.wm.open_mainfile(filepath=a.master)
def tree(group,material):
    vertices=[];faces=[]
    for obj in bpy.data.collections[group].objects:
        if obj.type!='MESH' or not any(m and m.name.startswith(material) for m in obj.data.materials):continue
        offset=len(vertices);vertices.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        obj.data.calc_loop_triangles();faces.extend(tuple(offset+i for i in t.vertices) for t in obj.data.loop_triangles)
    return BVHTree.FromPolygons(vertices,faces,all_triangles=True)
wood=tree('connections','Mine_WoodLight');earth=tree('bridge_junction','Mine_Earth');rows=[]
for i in range(32):
    x=20.2+i*.11;origin=Vector((x,-.37,3.2));direction=Vector((0,0,-1))
    w,normal,_,_=wood.ray_cast(origin,direction,.5);e=earth.ray_cast(origin,direction,.5)[0]
    if w is not None and e is not None:rows.append({'x':x,'wood_top':w.z,'earth_top':e.z,'gap':w.z-e.z,'normal_z':normal.z})
flat=[r for r in rows if r['normal_z']>.99]
result={'master_sha256':hashlib.sha256(Path(a.master).read_bytes()).hexdigest(),'samples':rows,'flat_top_samples':len(flat),'status':'PASS' if len(flat)>=20 and all(r['gap']>=.02 for r in flat) and all(r['gap']>.002 for r in rows) else 'FAIL','method':'BVH rays against actual WoodLight bridge triangles and Earth platform triangles; east landing only. Flat top faces >=2cm; sloping bevels >2mm. Normals distinguish bevels from coplanar tops; no collision edits.'}
Path(a.output).write_text(json.dumps(result,indent=2),encoding='utf-8');print('MINE_LANDING_AUDIT',result['status'],len(rows))
if result['status']!='PASS':raise RuntimeError('Coplanar or missing landing surfaces')
