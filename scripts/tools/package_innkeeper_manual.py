"""Package the completed independent NPC candidate; never promote gameplay implicitly."""
import hashlib
import json
from pathlib import Path
import shutil

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'artifacts/innkeeper_manual'
SOURCE = ROOT / 'source_assets/npc_rebuild_20261020/innkeeper'
OUT = SOURCE / 'manual_acceptance'
OUT.mkdir(parents=True, exist_ok=True)

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')

def webp(source, target):
    im = Image.open(source).convert('RGB')
    factor = min(1, 512 / min(im.size))
    im.resize(tuple(round(n * factor) for n in im.size)).save(target, 'WEBP', quality=82, method=4)

rigged = ROOT / 'assets/models/rebuilt_npc/innkeeper.glb'
sha = hashlib.sha256(rigged.read_bytes()).hexdigest()
motion = read(RAW / 'deformation.json')
native = read(ROOT / 'artifacts/asset_a05/innkeeper/godot/report.json')
control = read(ROOT / 'artifacts/asset_a05/innkeeper/controller/report.json')
preserve = read(RAW / 'final_preservation.json')
assert motion['status'] == 'PASS' and motion['total_frames'] == 98
assert native['checks'] == 225 and not native['failures'] and native['model_sha256'] == sha
assert control['checks'] == 19 and not control['failures'] and control['model_sha256'] == sha
assert preserve['status'] == 'PASS' and preserve['missing_retained_faces'] == 0
assert read(RAW / 'merchant_comparison.json')['status'] == 'PASS'
assert read(RAW / 'female_comparison.json')['status'] == 'PASS'
for src, dest in [
    (RAW / 'deformation.json', 'deformation.json'),
    (RAW / 'glb_audit.json', 'glb_audit.json'),
    (RAW / 'blender_reimport/report.json', 'blender_reimport.json'),
    (RAW / 'final_preservation.json', 'retained_surface_audit.json'),
    (RAW / 'panel_uv.json', 'panel_uv.json'),
    (RAW / 'merchant_comparison.json', 'merchant_rebuild_regression.json'),
    (RAW / 'female_comparison.json', 'female_rebuild_regression.json'),
    (RAW / 'boundary_samples.json', 'source_waist_samples.json'),
    (ROOT / 'artifacts/asset_a05/innkeeper/godot/report.json', 'godot_rig.json'),
    (ROOT / 'artifacts/asset_a05/innkeeper/controller/report.json', 'godot_controller.json'),
    (ROOT / 'artifacts/asset_a05/item_merchant/controller/report.json', 'merchant_controller_regression.json'),
    (SOURCE / 'idle_talk_manual_v1/npc_recipe.json', 'rig_recipe.json'),
]:
    write(OUT / dest, read(src))
topology = read(SOURCE / 'manual_topology_uv/manual_topology_report.json')
topology.pop('retained_corner_position_uv_normals_preserved', None)
topology['retained_corner_positions_uv_preserved'] = True
topology['retained_normal_max_component_error'] = preserve['retained_normal_max_component_error']
topology['status'] = 'PASS_LOCAL_TOPOLOGY_AND_INDEPENDENT_RIG; formal NPC integration untested'
write(OUT / 'manual_topology_report.json', topology)
static = read(RAW / 'godot_static_uv/report.json')
assert static['checks'] == 21 and not static['failures']
static['archived_model'] = 'source_assets/npc_rebuild_20261020/innkeeper/manual_topology_uv/innkeeper_retopology.glb'
static['note'] = 'Temporary unrigged runtime copy removed after review; rigged asset is the deliverable.'
write(OUT / 'static_review.json', static)
webp(SOURCE / 'inspection/front.png', OUT / 'before.webp')
for name in ['view_0', 'view_1', 'view_2', 'view_3', 'idle', 'idle_side', 'talk', 'talk_side']:
    webp(ROOT / f'artifacts/asset_a05/innkeeper/godot/{name}.webp', OUT / f'{name}.webp')
webp(RAW / 'godot_static_uv/body_0.webp', OUT / 'static_front.webp')
webp(ROOT / 'artifacts/asset_a05/innkeeper/controller/idle_talk_pair.webp', OUT / 'two_instances.webp')
failed = OUT / 'failed_attempts'
failed.mkdir(exist_ok=True)
for name in ['failed_v2_front', 'failed_v2_side', 'failed_v3_front', 'failed_v3_back', 'failed_hem_selection_front', 'failed_triangle_boundary']:
    webp(RAW / (name + '.webp'), failed / (name + '.webp'))
for name in ['rebuild.log', 'preflight2.log', 'preservation.log', 'controller_unregistered_failure.log']:
    write(failed / (name.replace('.log', '.json')), {'source_log': 'artifacts/innkeeper_manual/' + name, 'lines': (RAW / name).read_text(encoding='utf-8-sig').splitlines()})
attempts = []
for name in ['manual_topology_v2', 'manual_topology_v3', 'manual_topology_v4', 'manual_topology_final', 'manual_topology_clipped', 'manual_topology_uv']:
    f = SOURCE / name / 'innkeeper_retopology.glb'
    attempts.append({'folder': name, 'glb_sha256': hashlib.sha256(f.read_bytes()).hexdigest(), 'final': name == 'manual_topology_uv'})
write(failed / 'intermediate_versions.json', {'no_new_comfy_generation': True, 'versions': attempts,
    'sequence': ['Colour-only removal left crossed dark cloth', 'Geometric removal reached above actual vest seam', 'Wrong hem selection touched trousers', 'Restoring hem alone was insufficient', 'Geometric clipping restored trousers; UV layer mismatch found', 'Shared TEXCOORD_0 corrected and validated before rigging'],
    'note': 'Bounded local topology recipe and its implementation defects, not six new AI generations. All failed native/source files remain local; no failed version promoted.'})
manifest = {'status': 'PASS_INDEPENDENT_NPC_CANDIDATE', 'model': rigged.relative_to(ROOT).as_posix(), 'sha256': sha,
            'triangles': 12785, 'category': 'npc', 'budget': 15000, 'bones': 20, 'clips': ['idle', 'talk'],
            'working_blend': 'source_assets/npc_rebuild_20261020/innkeeper/idle_talk_manual_v1/innkeeper_npc.blend',
            'source_baseline_sha256': hashlib.sha256((SOURCE / 'surface_diagnosis/baseline.blend').read_bytes()).hexdigest(),
            'source_baseline': 'source_assets/npc_rebuild_20261020/innkeeper/manual_acceptance/source_baseline.blend',
            'scene': 'scenes/characters/npc/innkeeper_visual.tscn', 'formal_npc_replaced': False,
            'story_prices_save_changed': False, 'physical_input_tested': False, 'android_ios_tested': False,
            'visual_review': 'Original black triangular slit absent in four native views and idle/talk samples; waist seams remain a small source-style limitation. Not a complete manifold/finger/cloth-simulation certificate.'}
write(OUT / 'candidate_manifest.json', manifest)
shutil.copyfile(SOURCE / 'surface_diagnosis/baseline.blend', OUT / 'source_baseline.blend')
for path in OUT.rglob('*'):
    if path.is_file() and path.suffix in ['.json', '.md']:
        path.write_text(path.read_text(encoding='utf-8-sig'), encoding='utf-8', newline='\n')
write(OUT / 'evidence_manifest.json', [{'file': p.relative_to(OUT).as_posix(), 'bytes': p.stat().st_size,
    'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(OUT.rglob('*')) if p.is_file() and p.name != 'evidence_manifest.json'])
print('INNKEEPER_CANDIDATE_PACKAGED', sha, '12785 triangles; independent 225+19; formal integration remains pending')
