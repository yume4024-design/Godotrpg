"""Compare the finished Blender master with a preserved committed baseline.

blender --background --factory-startup --python-exit-code 1 --python THIS --
  --baseline artifacts/.../baseline.blend --output artifacts/.../geometry_audit.json
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
import bpy

ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
from reference_detail_pass import protected_digest

args=argparse.ArgumentParser()
args.add_argument('--baseline',required=True)
args.add_argument('--output',required=True)
opt=args.parse_args(sys.argv[sys.argv.index('--')+1:])
records=[]
for path in [Path(opt.baseline),ROOT/'source_assets/greystone_reference_20261024/greystone_master.blend']:
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    groups={c.name:c for c in bpy.context.scene.collection.children}
    records.append({'file_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'protected_geometry_sha256':protected_digest(groups)})
result={'baseline':records[0],'finished':records[1],
        'unchanged':records[0]['protected_geometry_sha256']==records[1]['protected_geometry_sha256'],
        'scope':'All Terrain / Paths / Bounds world transforms, vertices and polygons. Art-only meshes excluded.'}
Path(opt.output).write_text(json.dumps(result,indent=2),encoding='utf-8')
assert result['unchanged'], 'Terrain, roads or collision proxies changed from the committed baseline'
print('REFERENCE_FINISH_GEOMETRY_AUDIT',json.dumps(result),flush=True)
