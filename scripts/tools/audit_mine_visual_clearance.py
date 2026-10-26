"""Sample actual exported-source triangles along the player's protected routes."""
import bpy,json,math,sys,argparse
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--master',default=str(root/'source_assets/mine_reference_20261024/mine_reference_master.blend'))
parser.add_argument('--output',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=args.master)
vertices=[];faces=[];owners=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH' or obj.hide_render:continue
    if any(c.name.startswith('module_') for c in obj.users_collection):continue
    data=obj.data;data.calc_loop_triangles();offset=len(vertices)
    vertices.extend(obj.matrix_world@v.co for v in data.vertices)
    faces.extend(tuple(offset+i for i in t.vertices) for t in data.loop_triangles)
    owners.extend(obj.name for t in data.loop_triangles)
bvh=BVHTree.FromPolygons(vertices,faces,all_triangles=True)
layout=json.loads((root/'data/world/mine_reference_layout.json').read_text(encoding='utf-8'))
tested=0;hits=[]
for name in ['route','cross_route','north_route']:
    for segment,(a,b) in enumerate(zip(layout[name],layout[name][1:])):
        a,b=Vector(a),Vector(b);count=max(1,math.ceil((b-a).length/.6))
        for step in range(count+1):
            p=a.lerp(b,step/count)
            for dx,dz in [(0,0),(.28,0),(-.28,0),(0,.28),(0,-.28)]:
                # Source BVH is Blender Z-up; paths are Godot Y-up.
                start=Vector((p.x+dx,-p.z-dz,p.y+.35))
                point,normal,index,distance=bvh.ray_cast(start,Vector((0,0,1)),1.55)
                tested+=1
                if point is not None:hits.append({'route':name,'segment':segment,'position':list(p),'hit':[point.x,point.z,-point.y],'mesh':owners[index]})
result={'master':args.master,'samples':tested,'hits':hits,'method':'Actual triangle BVH, vertical body rays at centre and four 0.28m offsets, 0.6m route spacing, 0.35–1.90m above nominal floor. Includes existing geometry; excludes hidden module assets. A sampled visual clearance check, not continuous capsule collision or camera occlusion certification.'}
out=Path(args.output);out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(result,indent=2),encoding='utf-8')
print('MINE_VISUAL_CLEARANCE',tested,len(hits))
if hits:raise RuntimeError(str(hits[:4]))
