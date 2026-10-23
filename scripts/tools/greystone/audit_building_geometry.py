"""Explain source/import face deltas and check final exported building triangles."""
import sys,json
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'scripts/tools'))
from asset_glb_validation import read_glb,accessor_values
rows=[]
sources=ROOT/'source_assets/greystone_ai_20261023'
paths=[sources/a/'pixal_candidate_01'/f'{a}_textured.glb' for a in ['inn','house_a','item_shop','weapon_shop']]
paths+=sorted((ROOT/'assets/models/greystone/blender_master/buildings').glob('*.glb'))
for path in paths:
    doc,binary=read_glb(path);repeated=0;zero=0;triangles=0;duplicates=0;same_winding=0
    for mesh in doc.get('meshes',[]):
        for primitive in mesh['primitives']:
            if primitive.get('mode',4)!=4:continue
            points=np.array(list(accessor_values(doc,binary,primitive['attributes']['POSITION'])),dtype=np.float64)
            indices=np.array(list(accessor_values(doc,binary,primitive['indices'])),dtype=np.int64).reshape(-1,3)
            repeated+=int(np.sum((indices[:,0]==indices[:,1])|(indices[:,1]==indices[:,2])|(indices[:,2]==indices[:,0])))
            faces=points[indices];area=np.cross(faces[:,1]-faces[:,0],faces[:,2]-faces[:,0])
            keys=[tuple(sorted(map(tuple,face))) for face in faces];duplicates+=len(keys)-len(set(keys))
            oriented=[]
            for face in faces:
                vertices=list(map(tuple,face));oriented.append(min(tuple(vertices[i:]+vertices[:i]) for i in range(3)))
            same_winding+=len(oriented)-len(set(oriented))
            zero+=int(np.sum(np.sum(area*area,axis=1)==0));triangles+=len(indices)
    rows.append({'file':path.relative_to(ROOT).as_posix(),'triangles':triangles,'repeated_index_faces':repeated,'exact_zero_area_faces':zero,'duplicate_geometry_faces':duplicates,'same_winding_duplicates':same_winding,'stage':'raw_source' if path.is_relative_to(sources) else 'exported_candidate'})
report={'measure':'Unique mesh triangles; exact zero-area / repeated indices, no automatic edits','rows':rows}
out=ROOT/'artifacts/greystone_blender_20261023/building_geometry_audit.json';out.write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report,indent=2))
raise SystemExit(1 if any(r['stage']=='exported_candidate' and (r['repeated_index_faces'] or r['exact_zero_area_faces']) for r in rows) else 0)
