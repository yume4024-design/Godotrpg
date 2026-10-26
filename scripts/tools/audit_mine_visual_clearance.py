"""Sample actual exported-source triangles along the player's protected routes."""
import bpy,json,math,sys,argparse
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
root=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--master',default=str(root/'source_assets/mine_reference_20261024/mine_reference_master.blend'))
parser.add_argument('--output',required=True)
parser.add_argument('--spacing',type=float,default=.15)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
if not .05<=args.spacing<=1.0:raise ValueError('Route spacing must be .05–1m')
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
        a,b=Vector(a),Vector(b);count=max(1,math.ceil((b-a).length/args.spacing))
        for step in range(count+1):
            p=a.lerp(b,step/count)
            for dx,dz in [(0,0),(.28,0),(-.28,0),(0,.28),(0,-.28),(.198,.198),(.198,-.198),(-.198,.198),(-.198,-.198)]:
                # Source BVH is Blender Z-up; paths are Godot Y-up.
                start=Vector((p.x+dx,-p.z-dz,p.y+.35))
                point,normal,index,distance=bvh.ray_cast(start,Vector((0,0,1)),1.55)
                tested+=1
                if point is not None:hits.append({'route':name,'segment':segment,'position':list(p),'hit':[point.x,point.z,-point.y],'mesh':owners[index]})
            # A vertical ray can start inside a tall narrow post and exit only
            # above the head. Cross-body rays catch its sides within the body.
            for height in [.55,1.05,1.6]:
                center=Vector((p.x,-p.z,p.y+height))
                for direction in [Vector((1,0,0)),Vector((0,1,0)),Vector((.70710678,.70710678,0)),Vector((.70710678,-.70710678,0))]:
                    point,normal,index,distance=bvh.ray_cast(center-direction*.28,direction,.56)
                    tested+=1
                    if point is not None:hits.append({'route':name,'segment':segment,'position':list(p),'hit':[point.x,point.z,-point.y],'mesh':owners[index],'probe':'horizontal_body'})
result={'master':args.master,'samples':tested,'spacing_m':args.spacing,'hits':hits,'method':'Actual triangle BVH, vertical body rays at centre, four axial and four diagonal offsets; four cross-body diameters at heights .55/1.05/1.6m catch tall thin posts. Body radius .28m, configured route spacing. Includes existing geometry; excludes hidden module assets. Sampled, not continuous capsule or camera certification.'}
out=Path(args.output);out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(result,indent=2),encoding='utf-8')
print('MINE_VISUAL_CLEARANCE',tested,len(hits))
if hits:raise RuntimeError(str(hits[:4]))
