"""Read-only validation of actual rock shells in the complete Blender master."""
import bpy,bmesh,json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2]
master=root/'source_assets/mine_reference_20261024/mine_reference_master.blend'
bpy.ops.wm.open_mainfile(filepath=str(master))
rows=[];failures=[]
for obj in bpy.context.scene.objects:
    if obj.type!='MESH' or not any(m and m.name.startswith('Mine_Rock') for m in obj.data.materials):continue
    bm=bmesh.new();bm.from_mesh(obj.data);bm.normal_update()
    invalid_edges=sum(len(e.link_faces)!=2 for e in bm.edges)
    degenerate=sum(f.calc_area()<1e-9 for f in bm.faces)
    unseen=set(bm.verts);components=0;inward=0
    while unseen:
        pending=[next(iter(unseen))];vertices=set()
        while pending:
            vertex=pending.pop()
            if vertex not in unseen:continue
            unseen.remove(vertex);vertices.add(vertex)
            pending.extend(e.other_vert(vertex) for e in vertex.link_edges)
        if not vertices:continue
        components+=1;center=sum((v.co for v in vertices),vertices.copy().pop().co*0)/len(vertices)
        faces={f for v in vertices for f in v.link_faces}
        inward+=sum(f.normal.dot(f.calc_center_median()-center)<-1e-5 for f in faces)
    rows.append({'mesh':obj.name,'closed_components':components,'unpaired_edges':invalid_edges,'degenerate_faces':degenerate,'inward_faces':inward})
    if invalid_edges or degenerate or inward:failures.append(obj.name)
    bm.free()
result={'master_sha256':hashlib.sha256(master.read_bytes()).hexdigest(),'meshes':rows,'closed_rock_components':sum(r['closed_components'] for r in rows),'failures':failures,'method':'Actual Blender rock material meshes; every edge paired, nondegenerate faces, component outward orientation. No geometry changed.'}
out=root/'artifacts/mine_refinement_20261026/rock_audit.json';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(result,indent=2),encoding='utf-8')
print('MINE_ROCK_AUDIT',result['closed_rock_components'],len(failures))
if failures:raise RuntimeError(str(failures))
