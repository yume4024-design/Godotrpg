"""Inspect exported GLB payloads, not the generating script's success messages."""
from pathlib import Path
import struct
import json
import hashlib

root=Path(__file__).resolve().parents[3]
result=[]
for path in sorted((root/'assets/models/greystone/buildings').glob('*.glb')):
    raw=path.read_bytes()
    magic,version,size=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and size==len(raw),path
    chunk_size,kind=struct.unpack_from('<II',raw,12)
    assert kind==0x4e4f534a
    doc=json.loads(raw[20:20+chunk_size])
    assert len(doc['meshes'])==1 and len(doc['nodes'])==1,(path,'Unexpected exported objects')
    assert len(doc['scenes'])==1,(path,'Unexpected exported scenes')
    assert not doc.get('images') and not doc.get('animations')
    mesh=doc['meshes'][0]
    triangles=sum(doc['accessors'][p['indices']]['count']//3 for p in mesh['primitives'])
    position=[doc['accessors'][p['attributes']['POSITION']] for p in mesh['primitives']]
    low=[min(a['min'][i] for a in position) for i in range(3)]
    high=[max(a['max'][i] for a in position) for i in range(3)]
    assert abs(low[1])<.001,(path,'Not grounded')
    assert abs(high[0]+low[0])<.01 and abs(high[2]+low[2])<.01,(path,'Not centered')
    assert 0<triangles<10000,(path,'Prototype budget exceeded')
    result.append({'file':path.name,'triangles':triangles,'surfaces':len(mesh['primitives']),'dimensions_xyz':[round(high[i]-low[i],3) for i in range(3)],'min':low,'max':high,'sha256':hashlib.sha256(raw).hexdigest()})
assert len(result)==7
out=root/'source_assets/greystone_g03/export_metrics.json'
out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
