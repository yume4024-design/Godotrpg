"""Inspect exported GLB payloads, not the generating script's success messages."""
from pathlib import Path
import struct
import json
import hashlib
import re
import sys

root=Path(__file__).resolve().parents[3]
result=[]
materials={}
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
    extras=doc['nodes'][0].get('extras',{})
    assert extras['door_width_m']>=1.5,(path,'Door face too narrow')
    for mat in doc['materials']:
        name=mat['name']
        pbr=mat['pbrMetallicRoughness']
        if name in materials: assert materials[name]==pbr,(path,'Palette mismatch')
        materials[name]=pbr
    mesh=doc['meshes'][0]
    triangles=sum(doc['accessors'][p['indices']]['count']//3 for p in mesh['primitives'])
    position=[doc['accessors'][p['attributes']['POSITION']] for p in mesh['primitives']]
    low=[min(a['min'][i] for a in position) for i in range(3)]
    high=[max(a['max'][i] for a in position) for i in range(3)]
    assert abs(low[1])<.001,(path,'Not grounded')
    assert abs(high[0]+low[0])<.01 and abs(high[2]+low[2])<.01,(path,'Not centered')
    assert 0<triangles<10000,(path,'Prototype budget exceeded')
    # Verify the declared door width against all four actual GLB panel corners.
    binary_start=20+chunk_size+8
    actual=[]
    for a in position:
        bv=doc['bufferViews'][a['bufferView']]
        stride=bv.get('byteStride',12)
        offset=binary_start+bv.get('byteOffset',0)+a.get('byteOffset',0)
        actual.extend(struct.unpack_from('<fff',raw,offset+i*stride) for i in range(a['count']))
    for side in [-1,1]:
        for y in [0,extras['door_height_m']]:
            corner=(extras['door_center_x_m']+side*extras['door_width_m']/2,y,extras['door_front_z_m'])
            assert any(max(abs(p[i]-corner[i]) for i in range(3))<.002 for p in actual),(path,'Door corner absent',corner)
    result.append({'file':path.name,'triangles':triangles,'surfaces':len(mesh['primitives']),'dimensions_xyz':[round(high[i]-low[i],3) for i in range(3)],'door_width_m':extras['door_width_m'],'door_center_x_m':extras['door_center_x_m'],'door_front_z_m':extras['door_front_z_m'],'wall_back_z_m':extras['wall_back_z_m'],'obstacle_boxes':json.loads(extras['obstacle_boxes_json']),'min':low,'max':high,'sha256':hashlib.sha256(raw).hexdigest()})
    result[-1]['wall_width_m']=extras['wall_width_m']
assert len(result)==7
out=root/'source_assets/greystone_g03/export_metrics.json'
out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
if '--prepare-materials' in sys.argv:
    palette_dir=root/'assets/materials/greystone'
    palette_dir.mkdir(parents=True,exist_ok=True)
    for name,pbr in materials.items():
        key=re.sub(r'(?<!^)(?=[A-Z])','_',name.removeprefix('CrystalG03_')).lower()
        color=pbr['baseColorFactor']
        srgb=[v*12.92 if v<=.0031308 else 1.055*v**(1/2.4)-.055 for v in color[:3]]
        text='[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\nresource_name = "'+name+'"\nalbedo_color = Color('+', '.join(f'{v:.8f}' for v in srgb)+', 1)\nroughness = 0.88\n'
        (palette_dir/(key+'.tres')).write_text(text,encoding='utf-8')
print(json.dumps(result,indent=2))
