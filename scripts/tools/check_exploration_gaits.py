"""Read actual GLB buffers: preserve mesh/UV/skin/battle clips while replacing gaits."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def load(path):
    raw = path.read_bytes()
    size, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    doc = json.loads(raw[20:20 + size])
    binary = raw[28 + size:]
    return doc, binary


def values(doc, data, index):
    a = doc['accessors'][index]
    v = doc['bufferViews'][a['bufferView']]
    code, width = {5120: ('b', 1), 5121: ('B', 1), 5122: ('h', 2), 5123: ('H', 2), 5125: ('I', 4), 5126: ('f', 4)}[a['componentType']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    offset = a.get('byteOffset', 0) + v.get('byteOffset', 0)
    stride = v.get('byteStride', n * width)
    return [struct.unpack_from('<' + code * n, data, offset + i * stride) for i in range(a['count'])]


reports = []
for name in ['ren', 'lia']:
    old_path = ROOT / f'assets/models/pixal3d/{name}_rigged.glb'
    new_path = ROOT / f'assets/models/pixal3d/{name}_locomotion.glb'
    old, old_bin = load(old_path)
    new, new_bin = load(new_path)
    assert len(old['meshes']) == len(new['meshes'])
    triangles = 0
    for a, b in zip(old['meshes'], new['meshes']):
        assert a['name'] == b['name']
        assert len(a['primitives']) == len(b['primitives'])
        for x, y in zip(a['primitives'], b['primitives']):
            assert x['attributes'].keys() == y['attributes'].keys()
            for key in x['attributes']:
                assert values(old, old_bin, x['attributes'][key]) == values(new, new_bin, y['attributes'][key]), (name, key, 'mesh changed')
            assert values(old, old_bin, x['indices']) == values(new, new_bin, y['indices'])
            triangles += new['accessors'][y['indices']]['count'] // 3
    assert triangles <= 15000
    assert len(new['skins'][0]['joints']) == 19
    old_actions = {a['name']: a for a in old['animations']}
    new_actions = {a['name']: a for a in new['animations']}
    assert old_actions.keys() == new_actions.keys()
    # Nodes are emitted in the same order; compare actual time/rotation buffers.
    assert [n.get('name') for n in old['nodes']] == [n.get('name') for n in new['nodes']]
    for clip in ['attack', 'cast', 'guard', 'hit', 'potion']:
        a, b = old_actions[clip], new_actions[clip]
        assert a['channels'] == b['channels'], (name, clip, 'targets changed')
        for x, y in zip(a['samplers'], b['samplers']):
            for key in ['input', 'output']:
                assert values(old, old_bin, x[key]) == values(new, new_bin, y[key]), (name, clip, 'battle keyframes changed')
    reports.append({'character': name, 'triangles': triangles, 'bones': 19, 'clips': sorted(new_actions), 'geometry_uv_skin_identical': True, 'five_battle_clips_identical': True, 'source_sha256': hashlib.sha256(old_path.read_bytes()).hexdigest(), 'output_sha256': hashlib.sha256(new_path.read_bytes()).hexdigest()})
out = ROOT / 'source_assets/exploration_locomotion_20261021/glb_preservation.json'
out.write_text(json.dumps(reports, indent=2) + '\n', encoding='utf-8')
doors = []
for path in sorted((ROOT / 'assets/models/greystone/buildings').glob('*.glb')):
    doc, _ = load(path)
    extras = doc['nodes'][0]['extras']
    doors.append({'building': path.stem, 'door_width_m': extras['door_width_m'], 'door_height_m': extras['door_height_m'], 'hero_height_m': 1.95, 'head_clearance_m': extras['door_height_m'] - 1.95})
assert all(d['door_width_m'] >= 1.5 and d['head_clearance_m'] >= .3 for d in doors)
(out.parent / 'door_clearance.json').write_text(json.dumps(doors, indent=2) + '\n', encoding='utf-8')
print(json.dumps(reports, indent=2))
