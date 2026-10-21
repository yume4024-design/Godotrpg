"""Archive measured A04 bat receipts and images without saves/export packages."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser()
p.add_argument('--regression', type=Path, required=True)
p.add_argument('--performance', type=Path, required=True)
p.add_argument('--packages', type=Path, required=True)
p.add_argument('--exploration-log', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=False)
out = a.output


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def save(name, data):
    path = out/name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8',newline='\n')


def picture(source, name):
    im = Image.open(source).convert('RGB')
    scale = 512/min(im.size)
    im = im.resize((round(im.width*scale),round(im.height*scale)))
    path = out/'frames'/name
    path.parent.mkdir(exist_ok=True)
    im.save(path,quality=90,method=6)


regression, performance, packages = read(a.regression),read(a.performance),read(a.packages)
assert len(regression['results']) == 16 and all(row['passed'] for row in regression['results'])
assert performance['asset'] == 'crystal_bat' and performance['exit_code'] == 0
assert performance['source_commit'] == packages['base_commit']
source_commit = performance['source_commit']
model = ROOT/'assets/models/rebuilt_enemies/crystal_bat_manual.glb'
model_sha = hashlib.sha256(model.read_bytes()).hexdigest()
assert model_sha == 'ab487b6c94b32e9aac451348e739635684e2577f996245d3a90feb8759f7ebf7'
controller = read(ROOT/'artifacts/a04_crystal_bat_controller/result.json')
nameplates = read(ROOT/'artifacts/g083_nameplates/result.json')
assert controller['checks']==67 and not controller['failures']
assert nameplates['checks']==193 and nameplates['failures']==0
save('controller.json',controller)
save('nameplates.json',nameplates)
save('failed_anchor_1_6m.json',read(ROOT/'artifacts/a04_crystal_bat_integration/failed_anchor_1_6m/result.json'))
save('g06_regression.json',regression)
save('performance/manifest.json',performance)
metrics_path = Path(performance['metrics'])
metrics = read(metrics_path)
assert metrics['release'] and metrics['display']!='headless' and metrics['checks']==40 and not metrics['failures']
assert [row['frames'] for row in metrics['cases']] == [600,600]
save('performance/metrics.json',metrics)
process_csv = a.performance.parent/'process.csv'
(out/'performance/process.csv').write_text(process_csv.read_text(encoding='utf-8-sig'),encoding='utf8',newline='\n')
process = list(csv.DictReader(process_csv.read_text(encoding='utf-8-sig').splitlines()))
save('performance/process_summary.json',{'samples':len(process),**{
    key:max(int(row[key]) for row in process) for key in ['working_set_bytes','private_bytes','peak_working_set_bytes']}})
save('release/packages.json',packages)
profile = Path(packages['profile'])
for prefix,checks in [('prologue',141),('reload',35)]:
    matches = list(profile.rglob(prefix+'_result.json'))
    assert len(matches)==1
    result = read(matches[0])
    assert result['checks']==checks and result['failures']==0 and result['release']
    save('release/'+prefix+'_result.json',result)
package_hashes = []
for role in ['candidate','qa']:
    exe = Path(packages[role])
    for path in [exe,exe.with_suffix('.pck')]:
        package_hashes.append({'role':role,'file':path.name,'bytes':path.stat().st_size,
                               'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
save('release/package_hashes.json',package_hashes)

# Keep raw logs and local saves in ignored artifacts. The receipt includes
# actual result lines, error count and original SHA rather than renamed logs.
receipts = []
for path in [a.exploration_log,a.performance.parent/'release.log']:
    text = path.read_text(encoding='utf-8-sig')
    receipts.append({'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                     'results':re.findall(r'^.*_RESULT.*$',text,re.M),
                     'errors':len(re.findall(r'^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:)',text,re.M))})
for row in packages['results']:
    path = Path(row['log'])
    text = path.read_text(encoding='utf-8-sig')
    errors = len(re.findall(r'^\s*(?:ERROR:|SCRIPT ERROR:|Parse Error:)',text,re.M))
    assert row['exit_code']==0 and errors==0
    receipts.append({'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                     'results':row['result'],'errors':errors,
                     'bat_assertions':[line for line in text.splitlines() if line.startswith('PASS ') and
                                       any(word in line.lower() for word in ['bat ', 'post-bat', 'existing bat'])]})
assert any('EXPANSION_RESULT checks=60 failures=0' in line for row in receipts for line in row['results'])
save('test_receipts.json',receipts)

source_paths = read(ROOT/'artifacts/a04_crystal_bat_integration/implementation_paths.json')
sources = []
for name in source_paths:
    committed = subprocess.check_output(['git','show',source_commit+':'+name],cwd=ROOT)
    current = (ROOT/name).read_bytes().replace(b'\r\n',b'\n')
    assert committed.replace(b'\r\n',b'\n')==current,name
    sources.append({'path':name,'source_commit':source_commit,'sha256_lf':hashlib.sha256(current).hexdigest()})
old = subprocess.check_output(['git','show',source_commit+'^:scenes/characters/crystal_bat_visual.tscn'],cwd=ROOT)
legacy = (ROOT/'scenes/characters/legacy/crystal_bat_visual.tscn').read_bytes().replace(b'\r\n',b'\n')
assert old == legacy
changed = subprocess.check_output(['git','diff','--name-only',source_commit+'^',source_commit],cwd=ROOT).decode().splitlines()
protected = [name for name in changed if name.startswith(('data/','scripts/save/','scripts/story/','scripts/quests/'))
             or name in ['project.godot','scenes/main/main.tscn']]
assert not protected,protected
save('source_contract.json',{'source_commit':source_commit,'model_sha256':model_sha,'triangles':6249,'bones':17,
                            'legacy_scene_exact':True,'implementation':sources,
                            'runtime_data_schema_main_entry_changed':bool(protected),
                            'implementation_changed_paths':changed,
                            'scope':'Implementation fixed before native exports; report and exploration assertions follow separately'})
for source,name in [
    (ROOT/'artifacts/g083_nameplates/X003.webp','battle.webp'),
    (ROOT/'artifacts/g083_nameplates/X003-death.webp','death.webp'),
    (ROOT/'artifacts/phase5/expansion-wild_crystal_bat-world.webp','exploration.webp'),
    (ROOT/'artifacts/a04_crystal_bat_integration/failed_anchor_1_6m/X003.webp','failed_anchor.webp'),
    (ROOT/'artifacts/a04_crystal_bat_controller/full-fold-hold.webp','controller_full_fold.webp'),
    (ROOT/'artifacts/a04_crystal_bat_controller/reset-pair.webp','controller_pair.webp'),
    (metrics_path.parent/'crystal_bat_1.webp','release_single.webp'),
    (metrics_path.parent/'crystal_bat_3.webp','release_three.webp')]:
    picture(source,name)
print('BAT_INTEGRATION_EVIDENCE',out)
