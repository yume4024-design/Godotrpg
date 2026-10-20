"""Read current Greystone GLB payloads and placeholder bindings; no asset edits."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parents[2]

def summarize(path):
    raw = path.read_bytes()
    magic, version, size, json_size, kind = struct.unpack_from('<IIIII', raw)
    if (magic, version, size, kind) != (0x46546c67, 2, len(raw), 0x4e4f534a):
        raise ValueError('Invalid GLB header: ' + str(path))
    document = json.loads(raw[20:20+json_size])
    counts = []
    for mesh in document.get('meshes', []):
        count = 0
        for primitive in mesh['primitives']:
            if primitive.get('mode', 4) != 4: raise ValueError('Unsupported primitive: ' + str(path))
            accessor = primitive.get('indices', primitive['attributes']['POSITION'])
            size = document['accessors'][accessor]['count']
            if size % 3: raise ValueError('Incomplete triangles: ' + str(path))
            count += size//3
        counts.append(count)
    visited = set()
    def walk(index):
        if index in visited: raise ValueError('Repeated/cyclic scene node: ' + str(path))
        visited.add(index)
        node = document['nodes'][index]
        return (counts[node['mesh']] if 'mesh' in node else 0) + sum(walk(child) for child in node.get('children', []))
    triangles = sum(walk(index) for index in document['scenes'][document.get('scene', 0)]['nodes'])
    return {'file':path.relative_to(ROOT).as_posix(), 'sha256':hashlib.sha256(raw).hexdigest(),
            'bytes':len(raw), 'active_scene_triangles':triangles,
            'material_definitions':len(document.get('materials', [])), 'images':len(document.get('images', [])),
            'qualification':'INVENTORY_ONLY; previous acceptance is separately documented'}

def build():
    groups = {name:[summarize(path) for path in sorted((ROOT/'assets/models/greystone'/name).glob('*.glb'))]
              for name in ['buildings', 'props', 'terrain']}
    scene = ROOT/'scenes/world/greystone_village.tscn'
    text = scene.read_text(encoding='utf8')
    placeholders = []
    for name in sorted(set(re.findall(r'res://scenes/world/greystone/placeholders/([^"\n]+)\.tscn', text))):
        placeholders.append({'asset':name, 'scene':'scenes/world/greystone/placeholders/'+name+'.tscn',
                             'instances':text.count('instance=ExtResource("Prop_'+name+'")')})
    return {'schema_version':1,'date':'2026-10-20','scope':'Current Greystone file inventory only; no new art, collision, LOD or performance acceptance',
            'groups':groups, 'totals':{name:{'files':len(rows), 'triangles_one_instance_each':sum(row['active_scene_triangles'] for row in rows),
                                          'bytes':sum(row['bytes'] for row in rows)} for name,rows in groups.items()},
            'placeholder_scene':scene.relative_to(ROOT).as_posix(), 'placeholders':placeholders,
            'wilderness_sources':['scripts/world/expanded_wilderness.gd','assets/models/cartoon/round_tree.glb','assets/models/cartoon/moss_rock.glb'],
            'unverified':['Current whole-map visuals, instances and draw calls','Forest/mine and item inventory completeness',
                          'Replacement geometry, collision, LOD and route regressions']}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists(): raise FileExistsError('Preserve the previous inventory; select a new output')
    result = build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps({'totals':result['totals'],'placeholders':result['placeholders']},ensure_ascii=False))
