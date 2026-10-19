"""Copy one existing candidate into a review package; never regenerates it."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
from asset_glb_validation import audit_glb

ROOT = Path(__file__).resolve().parents[2]
OLD = ROOT / 'source_assets/monster_rebuild_20261019'
NEW = ROOT / 'source_assets/asset_production_a03'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def package(name):
    catalog = json.loads((ROOT / 'source_assets/reference_library_20261020/catalog.json').read_text(encoding='utf8'))
    if not catalog[name]['ready_for_generation']:
        raise ValueError('Reference gate is not ready')
    selected = json.loads((OLD / 'surface_manifest.json').read_text(encoding='utf8'))[name]
    generation = json.loads((OLD / 'manifest.json').read_text(encoding='utf8'))
    original = generation['monsters'][name]
    model = ROOT / selected['file']
    blend = ROOT / selected['blend']
    raw = ROOT / original['latest_candidate']['file']
    category = 'boss' if name == 'corrupted_guardian' else 'common_enemy'
    gate = audit_glb(model, category=category)
    if gate['status'] != 'PASS':
        raise ValueError(gate['failures'])
    destination = NEW / name
    destination.mkdir(parents=True, exist_ok=False)
    (NEW / '.gdignore').touch()
    for source, target in [(model, 'optimized.glb'), (blend, 'optimized.blend'), (raw, 'generated_raw.glb')]:
        shutil.copy2(source, destination / target)
    runtime = ROOT / 'assets/models/rebuilt_enemies' / (name + '.glb')
    runtime.parent.mkdir(parents=True, exist_ok=True)
    if runtime.exists():
        raise FileExistsError(runtime)
    shutil.copy2(model, runtime)
    shutil.copytree(ROOT / catalog[name]['references'], destination / 'references')
    gate['file'] = runtime.relative_to(ROOT).as_posix()
    (destination / 'triangle_report.json').write_text(json.dumps(gate, indent=2), encoding='utf8')
    raw_master = next(iter(sorted((OLD / name / 'outputs').glob(name + '_source_*.glb'))), None)
    manifest = {
        'asset': name, 'category': category, 'status': 'IN_PROGRESS',
        'method': 'Reuse existing Pixal3D + Blender surface candidate; no new Comfy job',
        'generation_prompt_id': original.get('generation_prompt_id'),
        'workflow_sha256': generation['workflow_sha256'],
        'shape_resolution': generation['shape_resolution'],
        'texture_resolution': generation['texture_resolution'],
        'remesh_resolution': generation['remesh_resolution'],
        'runtime_glb': runtime.relative_to(ROOT).as_posix(),
        'high_density_master': ({'path': raw_master.relative_to(ROOT).as_posix(),
                                 'sha256': sha(raw_master), 'bytes': raw_master.stat().st_size,
                                 'git_policy': 'Preserved locally; deliberately not committed as a giant binary'} if raw_master else None),
        'selected_source': selected,
        'original_sources': [{'path': p.relative_to(ROOT).as_posix(), 'sha256': sha(p)} for p in [model, blend, raw]],
        'outputs': [{'file': p.name, 'sha256': sha(p)} for p in sorted(destination.glob('*')) if p.is_file()],
        'references': catalog[name],
        'limitations': ['Graphical and deformation gates must run before acceptance',
                        'A04 battle/exploration integration has not run',
                        'High-density original masters remain in their original outputs directory']}
    (destination / 'generation_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
    print('PACKAGED_CANDIDATE', name, gate['triangles'], runtime)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', required=True, choices=['spore_sprite', 'ore_beetle', 'thorn_boar', 'crystal_bat', 'corrupted_guardian'])
    package(parser.parse_args().asset)
