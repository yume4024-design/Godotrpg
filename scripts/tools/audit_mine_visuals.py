"""Read-only validation of actual rock shells in the complete Blender master."""
import bpy,bmesh,json,hashlib,sys,argparse
from pathlib import Path
root=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--master',default=str(root/'source_assets/mine_reference_20261024/mine_reference_master.blend'))
parser.add_argument('--output',default=str(root/'artifacts/mine_refinement_20261026/rock_audit.json'))
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
master=Path(args.master)
bpy.ops.wm.open_mainfile(filepath=str(master))
rows=[];failures=[];outside=[]
for obj in bpy.context.scene.objects:
    if obj.type=='MESH' and not obj.hide_render and not any(c.name.startswith('module_') for c in obj.users_collection):
        # The playable extent is 56m; allow 8m for the authored cave envelope.
        if any(abs((obj.matrix_world@v.co).x)>64 or abs((obj.matrix_world@v.co).y)>64 for v in obj.data.vertices):outside.append(obj.name)
    if obj.type!='MESH' or not any(m and m.name.startswith('Mine_Rock') for m in obj.data.materials):continue
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.normal_update()
    invalid_edges=sum(len(e.link_faces)!=2 for e in bm.edges)
    winding_errors=sum(len(e.link_faces)==2 and not e.is_contiguous for e in bm.edges)
    degenerate=sum(f.calc_area()<1e-9 for f in bm.faces)
    unseen=set(bm.verts);components=0;inverted=0
    while unseen:
        pending=[next(iter(unseen))];vertices=set()
        while pending:
            vertex=pending.pop()
            if vertex not in unseen:continue
            unseen.remove(vertex);vertices.add(vertex)
            pending.extend(e.other_vert(vertex) for e in vertex.link_edges)
        if not vertices:continue
        components+=1
        faces={f for v in vertices for f in v.link_faces}
        # Continuous strata can be concave. Centroid-to-face dot products are
        # not an orientation test there; use paired edge winding + signed volume.
        origin=next(iter(vertices)).co
        volume=sum((f.verts[0].co-origin).dot((f.verts[1].co-origin).cross(f.verts[2].co-origin))/6 for f in faces if len(f.verts)==3)
        inverted+=volume<=1e-9
    rows.append({'mesh':obj.name,'closed_components':components,'unpaired_edges':invalid_edges,'degenerate_faces':degenerate,'winding_errors':winding_errors,'nonpositive_components':inverted})
    if invalid_edges or degenerate or winding_errors or inverted:failures.append(obj.name)
    bm.free()
failures.extend(outside)
result={'master_sha256':hashlib.sha256(master.read_bytes()).hexdigest(),'meshes':rows,'closed_rock_components':sum(r['closed_components'] for r in rows),'out_of_bounds_meshes':outside,'horizontal_limit_m':64,'failures':failures,'method':'Actual Blender rock meshes: paired edges, consistent edge winding, nondegenerate faces and positive signed component volume; visible geometry within the 56m extent plus 8m cave-envelope allowance. Supports concave strata; no geometry changed.'}
out=Path(args.output);out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(result,indent=2),encoding='utf-8')
print('MINE_ROCK_AUDIT',result['closed_rock_components'],len(failures))
if failures:raise RuntimeError(str(failures))
