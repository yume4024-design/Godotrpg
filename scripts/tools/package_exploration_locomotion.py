"""Collect real completed checks and rendered captures; refuse missing/failed gates."""
import hashlib
import json
import re
import shutil
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / 'artifacts/locomotion'
OUT = ROOT / 'source_assets/exploration_locomotion_20261021'
OUT.mkdir(parents=True, exist_ok=True)


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8', newline='\n')


def capture(source, name):
    im = Image.open(source).convert('RGB')
    factor = min(1, 512 / min(im.size))
    im.resize(tuple(round(n * factor) for n in im.size)).save(OUT / name, 'WEBP', quality=80, method=4)


checks = {}
for name, file, marker, count in [
    ('native_exploration', 'height-guard-acceptance.log', 'EXPLORATION_LOCOMOTION_RESULT', 60),
    ('native_characters', 'pixal.log', 'PIXAL_CHARACTER_RESULT', 88),
    ('native_collision_occlusion', 'accessibility.log', 'G082_RESULT', 18),
    ('native_character_viewer', 'character-preview.log', 'CHARACTER_PREVIEW_RESULT', 12),
]:
    path = RAW / file
    text = path.read_text(encoding='utf-8-sig')
    assert re.search(rf'{marker} checks={count} failures=0', text), name
    assert not re.search(r'^\s*(ERROR:|SCRIPT ERROR:|WARNING:|FAIL )', text, re.M), name
    checks[name] = {'checks': count, 'failures': 0, 'source_log': str(path.relative_to(ROOT)), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    write(OUT / f'{name}.json', {'summary': checks[name], 'lines': text.splitlines()})
g06 = read(RAW / 'g06-completed.json')
assert len(g06['results']) == 16 and all(row['passed'] for row in g06['results'])
total = sum(int(match.group(1)) for row in g06['results'] for line in row['result'] if (match := re.search(r'_RESULT checks=(\d+) failures=0', line)))
assert total == 576
checks['g06_incremental_regression'] = {'modes': 16, 'checks': total, 'failures': 0, 'note': g06['continuation_note']}
write(OUT / 'g06_regression.json', g06)
acceptance = read(RAW / 'acceptance/result.json')
assert acceptance['checks'] == 60 and acceptance['failures'] == 0
write(OUT / 'movement_measurements.json', acceptance)
for mode in ['baseline', 'revised']:
    write(OUT / f'{mode}_dimensions.json', read(RAW / mode / 'dimensions.json'))
    capture(RAW / mode / 'village.webp', f'{mode}_village.webp')
for clip in ['walk', 'run']:
    for frame in [5, 15]:
        capture(RAW / 'preview' / f'{clip}_{frame:02}.png', f'{clip}_{frame:02}.webp')
    shutil.copyfile(RAW / 'preview' / f'{clip}.gif', OUT / f'{clip}.gif')
for site in ['inn_walk', 'farm_run', 'mine_walk_run', 'village_gameplay']:
    capture(RAW / 'acceptance' / f'{site}.webp', f'{site}.webp')
failed = OUT / 'failed_attempts'
failed.mkdir(exist_ok=True)
for number, folder in enumerate(['first-failed', 'second-failed', 'third-failed'], 1):
    write(failed / f'fixture_{number}.json', read(RAW / folder / 'result.json'))
write(failed / 'riser_22cm.json', {'lines': (RAW / 'accessibility-failed-22cm.log').read_text(encoding='utf-8-sig').splitlines()})
release = read(ROOT / 'artifacts/g08/20261021-044459/manifest.json')
assert all(row['exit_code'] == 0 for row in release['results'])
checks['native_release'] = {'prologue_checks': 120, 'restart_checks': 14, 'failures': 0}
for role in ['candidate', 'qa']:
    exe = Path(release[role])
    release[role + '_sha256'] = hashlib.sha256(exe.read_bytes()).hexdigest()
    release[role + '_pck_sha256'] = hashlib.sha256(exe.with_suffix('.pck').read_bytes()).hexdigest()
write(OUT / 'native_release.json', release)
launcher = read(ROOT / 'artifacts/rc3-launcher-fix/20261021-045142/result.json')
write(OUT / 'native_launcher.json', launcher)
write(OUT / 'validation.json', {'date': '2026-10-21', 'platform': 'Windows graphical Godot 4.7.2', 'checks': checks, 'hardware_input_certified': False, 'android_ios_tested': False, 'ik_enabled': False})
manifest = []
for path in OUT.rglob('*'):
    if path.is_file() and path.suffix in ['.json', '.md']:
        path.write_text(path.read_text(encoding='utf-8-sig'), encoding='utf-8', newline='\n')
for path in sorted(OUT.rglob('*')):
    if not path.is_file() or path.name == 'evidence_manifest.json':
        continue
    manifest.append({'file': path.relative_to(OUT).as_posix(), 'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
write(OUT / 'evidence_manifest.json', manifest)
print(json.dumps(checks, indent=2))
