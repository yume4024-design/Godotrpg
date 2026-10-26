"""Check rebuilt wall continuity and furniture against the frozen walking bodies."""
import argparse,json,sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--output',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source_assets/greystone_reference_20261024/greystone_master.blend'))
rows=[]
for obj in bpy.data.collections['Buildings_Candidate'].objects:
    source=[p for p in obj.data.polygons if not obj.data.materials[p.material_index].name.startswith(('ReferenceRoof_','ReferenceFacade_'))]
    plaster=[p for p in obj.data.polygons if obj.data.materials[p.material_index].name=='ReferenceFacade_plaster']
    tree=BVHTree.FromPolygons([v.co.copy() for v in obj.data.vertices],[tuple(p.vertices) for p in plaster])
    xs=[obj.data.vertices[i].co.x for p in plaster for i in p.vertices]
    ys=[obj.data.vertices[i].co.y for p in plaster for i in p.vertices]
    xmin,xmax=min(xs),max(xs);ymin,ymax=min(ys),max(ys)
    rays=0;missing=[]
    for i in range(17):
        x=xmin+.08+(xmax-xmin-.16)*i/16;y=ymin+.08+(ymax-ymin-.16)*i/16
        for z in [.15,.5,1,1.6,2.2]:
            for origin,direction in [((x,ymin-2,z),(0,1,0)),((x,ymax+2,z),(0,-1,0)),((xmin-2,y,z),(1,0,0)),((xmax+2,y,z),(-1,0,0))]:
                hit=tree.ray_cast(Vector(origin),Vector(direction),20)[0];rays+=1
                if hit is None:missing.append(origin)
    body=bpy.data.objects[obj.name+'Body-colonly']
    corners=[body.matrix_world@Vector(p) for p in body.bound_box]
    lo=Vector([min(p[i] for p in corners) for i in range(3)])
    hi=Vector([max(p[i] for p in corners) for i in range(3)])
    extension=0
    for v in obj.data.vertices:
        p=obj.matrix_world@v.co
        if p.z>obj.location.z+2.2:continue
        extension=max(extension,lo.x-p.x,p.x-hi.x,lo.y-p.y,p.y-hi.y)
    rows.append({'building':obj.name,'wall_rays':rays,'missing':missing,'legacy_faces':len(source),
                 'maximum_low_furniture_extension_m':extension,
                 'passed':not missing and not source and extension<.26})
result={'passed':all(r['passed'] for r in rows),'buildings':rows,
        'scope':'Closed plaster shell, no generated atlas faces, low furniture less than 0.26m outside body; player radius 0.32m. Native traversal remains required.'}
Path(args.output).write_text(json.dumps(result,indent=2),encoding='utf8')
assert result['passed'],result
print('REFERENCE_FACADE_AUDIT',json.dumps(result))
