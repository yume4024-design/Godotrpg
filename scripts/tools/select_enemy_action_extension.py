"""Select an evaluated extension only after it passes the strict GLB gate."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from asset_glb_validation import audit_glb

ROOT = Path(__file__).resolve().parents[2]


def select(name, version):
    folder = ROOT / 'source_assets/asset_production_a03' / name
    source = folder / version
    if not source.is_dir() or not version.startswith('action_extension_v'):
        raise ValueError('Expected an existing separate action candidate')
    category = 'boss' if name == 'corrupted_guardian' else 'common_enemy'
    gate = audit_glb(source / 'extended.glb', category=category)
    deformation = json.loads((ROOT / 'artifacts/asset_a03' / name / 'deformation.json').read_text(encoding='utf8'))
    if gate['status'] != 'PASS' or deformation['status'] != 'PASS':
        raise ValueError('Extension has not passed executable gates')
    if hashlib.sha256((source / 'extended.blend').read_bytes()).hexdigest() != deformation['sha256']:
        raise ValueError('Evaluated evidence belongs to a different Blend')
    previous = json.loads((folder / 'triangle_report.json').read_text(encoding='utf8'))
    if previous['triangles'] != gate['triangles']:
        raise ValueError('Action extension unexpectedly changed mesh topology')
    runtime = ROOT / 'assets/models/rebuilt_enemies' / (name + '.glb')
    for original, destination in [(source / 'extended.blend', folder / 'optimized.blend'),
                                  (source / 'extended.glb', folder / 'optimized.glb'),
                                  (source / 'extended.glb', runtime)]:
        shutil.copy2(original, destination)
    gate['file'] = runtime.relative_to(ROOT).as_posix()
    (folder / 'triangle_report.json').write_text(json.dumps(gate, indent=2), encoding='utf8')
    manifest_path = folder / 'generation_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf8'))
    manifest['action_extension'] = {'selected': version,
        'details': json.loads((source / 'extension.json').read_text(encoding='utf8')),
        'failed_attempt_reports': [p.name for p in sorted(folder.glob('failed_extension_*_report.json'))]}
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
    print('SELECTED_ACTION_EXTENSION', name, version, gate['triangles'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', required=True)
    parser.add_argument('--version', required=True)
    args = parser.parse_args()
    select(args.asset, args.version)
