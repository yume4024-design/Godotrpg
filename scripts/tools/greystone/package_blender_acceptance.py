"""Freeze real local evidence; fails if an expected executed gate is missing."""
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts/tools'))
from asset_glb_validation import audit_glb

OUT = ROOT / 'source_assets/greystone_blender_20261023/acceptance'
OUT.mkdir(parents=True, exist_ok=True)
ART = ROOT / 'artifacts/greystone_blender_20261023'

models = []
for asset in ['inn', 'house_a', 'house_a_blue', 'item_shop', 'weapon_shop']:
    path = ROOT / f'assets/models/greystone/blender_master/buildings/{asset}.glb'
    report = audit_glb(path, maximum=40000 if asset == 'inn' else 30000,
                       require_uv=True, require_rig=False)
    if report['status'] != 'PASS':
        raise RuntimeError((asset, report['failures']))
    models.append(report)

executed = {}
for mode in ['testgreystoneblender', 'testblendermigration', 'testblendermigrationreload',
             'visualblenderstory', 'testblenderstoryreload', 'visualblendercommerce',
             'testblendercommercereload', 'visualblendernpc']:
    path = ROOT / f'artifacts/blender_delivery_{mode}.log'
    content = path.read_text(encoding='utf8')
    if re.search(r'(?m)^\s*(SCRIPT ERROR:|ERROR:|Parse Error:|FAIL )', content):
        raise RuntimeError(f'Failure in {path}')
    match = re.search(r'RESULT checks=(\d+) failures=(\d+)', content)
    if match:
        checks, failures = map(int, match.groups())
    else:
        match = re.search(r'BLENDER_MASTER_RESULT (\{.+\})', content)
        if not match:
            raise RuntimeError(f'Missing terminal result in {path}')
        data = json.loads(match[1]); checks, failures = data['checks'], len(data['failures'])
    if checks <= 0 or failures:
        raise RuntimeError((mode, checks, failures))
    executed[mode] = {'checks': checks, 'failures': failures}
    shutil.copyfile(path, OUT / f'{mode}.txt')

boundary = json.loads((ART / 'boundary_result.json').read_text())
if boundary['failures'] or boundary['abyss_sweeps'] <= 0:
    raise RuntimeError('Boundary sweep not passed')
regression_path = max((ROOT / 'artifacts/regression').glob('g06-*.json'), key=lambda p: p.stat().st_mtime)
regression = json.loads(regression_path.read_text(encoding='utf-8-sig'))
if len(regression['results']) != 16 or not all(row['passed'] for row in regression['results']):
    raise RuntimeError('Latest existing G06 suite not complete')
shutil.copyfile(regression_path, OUT / 'g06_regression.json')

preserved = []
paths = ['project.godot', 'scenes/main/main.tscn', 'scenes/world/village.tscn',
         'scenes/world/greystone_runtime.tscn', 'scenes/world/greystone_village.tscn']
paths += subprocess.check_output(['git', 'ls-files', 'data'], cwd=ROOT, text=True).splitlines()
for name in paths:
    original = subprocess.check_output(['git', 'show', f'HEAD:{name}'], cwd=ROOT)
    current = (ROOT / name).read_bytes()
    equal = original.replace(b'\r\n', b'\n') == current.replace(b'\r\n', b'\n')
    if not equal:
        raise RuntimeError(f'Protected original changed: {name}')
    preserved.append({'path': name, 'lf_normalized_matches_head': equal})

for name in ['route_result.json', 'boundary_result.json', 'building_geometry_audit.json', 'capture_metrics.json']:
    shutil.copyfile(ART / name, OUT / name)
for name in ['overview.png', 'godot_overview.png', 'godot_plaza.png', 'godot_inn.png', 'godot_bridge.png', 'godot_mine.png', 'godot_dock.png']:
    shutil.copyfile(ART / name, OUT / name)
for name in ['blender_g063-guild.webp', 'blender_g064-shop.webp', 'blender_g064-inn.webp']:
    shutil.copyfile(ROOT / f'artifacts/phase5/{name}', OUT / name)
master = ROOT / 'source_assets/greystone_blender_20261023/greystone_master.blend'
if master.stat().st_size >= 100 * 1024 * 1024:
    raise RuntimeError('Working blend exceeds GitHub single-file limit; keep local until packaged safely')
summary = {
    'status': 'PASS_SCENE_CONSTRUCTION_AND_WINDOWS_AUTOMATION',
    'base_commit_before_changes': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
    'models': models, 'executed': executed, 'boundary': boundary,
    'existing_regression_manifest': str(regression_path.relative_to(ROOT)),
    'preserved_originals': preserved,
    'master_blend': {'path': str(master.relative_to(ROOT)), 'bytes': master.stat().st_size,
                     'sha256': hashlib.sha256(master.read_bytes()).hexdigest()},
    'runtime_files': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                      for p in (ROOT / 'assets/models/greystone/blender_master').rglob('*.glb')},
    'limits': ['Not a new release package, 30-minute endurance test or physical input acceptance',
               'Android/iOS paused', 'AI roof/timber irregularity remains; visual review is not pixel-identical reconstruction',
               'Terrain edge sweep is sampled at <=1.2m, not a continuous proof'],
}
(OUT / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf8')
print('BLENDER_ACCEPTANCE_PACKAGED', json.dumps(executed))
