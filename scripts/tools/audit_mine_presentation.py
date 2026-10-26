"""Check closed earth rims, retained floor support and flame clearance in Blender."""
import bpy,bmesh,json,sys,argparse,hashlib,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[2];p=argparse.ArgumentParser();p.add_argument('--output',required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);master=R/'source_assets/mine_reference_20261024/mine_reference_master.blend'
bpy.ops.wm.open_mainfile(filepath=str(master));layout=json.loads((R/'data/world/mine_reference_layout.json').read_text(encoding='utf-8'));manifest=json.loads((R/'assets/models/mine_reference/manifest.json').read_text(encoding='utf-8'))
failures=[];support=[];earth_rows=[]
def tree(objects):
    vs=[];fs=[]
    for obj in objects:
        offset=len(vs);vs.extend(obj.matrix_world@v.co for v in obj.data.vertices)
        obj.data.calc_loop_triangles();fs.extend(tuple(offset+i for i in t.vertices) for t in obj.data.loop_triangles)
    return BVHTree.FromPolygons(vs,fs,all_triangles=True) if fs else None
for zone in layout['zones']:
    objects=[o for o in bpy.data.collections[zone['id']].objects if o.type=='MESH' and any(m and m.name.startswith('Mine_Earth') for m in o.data.materials)]
    bv=tree(objects);x0,x1,z0,z1=zone['bounds'];h=zone['height'];count=0
    for obj in objects:
        bm=bmesh.new();bm.from_mesh(obj.data);bad=sum(len(e.link_faces)!=2 or not e.is_contiguous for e in bm.edges)
        earth_rows.append({'zone':zone['id'],'unpaired_or_inconsistent_edges':bad});bm.free()
        if bad:failures.append('earth shell '+zone['id'])
    nx=math.ceil((x1-x0)/1.8);nz=math.ceil((z1-z0)/1.8)
    for i in range(nx+1):
        for j in range(nz+1):
            x=x0+.03+(x1-x0-.06)*i/nx;z=z0+.03+(z1-z0-.06)*j/nz
            hit=bv.ray_cast(Vector((x,-z,h+.1)),Vector((0,0,-1)),.2)[0] if bv else None
            if hit is None or abs(hit.z-h)>.01:failures.append('missing earth support '+str((x,h,z)))
            count+=1
    support.append({'zone':zone['id'],'samples':count})
obstacles=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render and any(m and ('crystal' in m.name.lower() or m.name.startswith('Mine_Canvas')) for m in o.data.materials)]
bv=tree(obstacles)
solid=tree([o for o in obstacles if any(m and 'crystal' in m.name.lower() for m in o.data.materials)])
flames=[]
for row in manifest['art_refinement']['presentation']['flame_centers']:
    x,h,z=row['position'];origin=Vector((x,-z,h));near=bv.find_nearest(origin,.30)[0]
    # Solid crystal components are closed; odd crossing count indicates inside.
    direction=Vector((.719,.431,.545)).normalized();point=origin.copy();crossings=0
    for i in range(100):
        hit=solid.ray_cast(point,direction,160)[0]
        if hit is None:break
        crossings+=1;point=hit+direction*.0005
    bad=near is not None or crossings%2==1
    flames.append({'zone':row['zone'],'position':row['position'],'near_surface':near is not None,'ray_crossings':crossings,'clear':not bad})
    if bad:failures.append('flame in canvas/crystal '+str(row))
result={'master_sha256':hashlib.sha256(master.read_bytes()).hexdigest(),'earth_shells':earth_rows,'floor_support':support,'flame_clearance':flames,'failures':failures,'method':'Closed edge winding for earth mesh; original rectangle sampled at <=1.8m including edges, exact original floor height; flame centres at least .30m from canvas/crystal triangles and outside closed crystals via odd/even ray count. Open canvas uses surface distance only. Sampling is not a whole-world collision certificate.'}
Path(a.output).write_text(json.dumps(result,indent=2),encoding='utf-8');print('MINE_PRESENTATION_AUDIT',sum(r['samples'] for r in support),len(flames),len(failures))
if failures:raise RuntimeError(str(failures[:10]))
