"""Read GLB metadata without loading high-density geometry into memory."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def inspect(path):
    path = Path(path)
    with path.open('rb') as f:
        magic, version, size = struct.unpack('<4sII', f.read(12))
        assert magic == b'glTF' and version == 2 and size == path.stat().st_size
        length, kind = struct.unpack('<II', f.read(8))
        assert kind == 0x4E4F534A
        doc = json.loads(f.read(length))
    triangles = 0
    for mesh in doc.get('meshes', []):
        for primitive in mesh['primitives']:
            assert primitive.get('mode', 4) == 4, 'Non-triangle primitive'
            accessor = primitive.get('indices', primitive['attributes']['POSITION'])
            count = doc['accessors'][accessor]['count']
            assert count % 3 == 0
            triangles += count//3
    digest = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024*1024), b''):
            digest.update(chunk)
    return {'file': str(path), 'bytes': size, 'sha256': digest.hexdigest(), 'triangles': triangles, 'materials': len(doc.get('materials', [])), 'images': len(doc.get('images', [])), 'skins': len(doc.get('skins', [])), 'animations': len(doc.get('animations', []))}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('files', nargs='+')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    results = [inspect(path) for path in args.files]
    Path(args.output).write_text(json.dumps(results, indent=2), encoding='utf8')
    print(json.dumps(results, indent=2))
