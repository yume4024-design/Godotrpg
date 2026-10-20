"""Package exact candidate receipts, failed attempts and budgeted native frames."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT/'source_assets/asset_production_a03/crystal_bat'
OUT = BASE/'manual_fold_acceptance'
OUT.mkdir(exist_ok=False)


def save_json(source, name):
    value = json.loads((ROOT/source).read_text(encoding='utf-8-sig'))
    (OUT/name).write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n',encoding='utf8',newline='\n')


def capture(source, target):
    picture = Image.open(source).convert('RGB')
    scale = 512/min(picture.size)
    picture = picture.resize((round(picture.width*scale),round(picture.height*scale)))
    picture.save(target,quality=90,method=6)


for source,name in [
    ('artifacts/bat_manual_20261021/anatomy.json','source_anatomy.json'),
    ('artifacts/bat_manual_20261021/reimport_panels_v1/report.json','failed_reimport_v1.json'),
    ('source_assets/asset_production_a03/crystal_bat/anatomical_fold_v1/repair_report.json','failed_hinge_recipe.json'),
    ('source_assets/asset_production_a03/crystal_bat/anatomical_fold_v1/motion_report.json','failed_hinge_motion.json'),
    ('artifacts/bat_manual_20261021/native_rest_assert_failure/report.json','failed_native_identity_assert.json'),
    ('artifacts/bat_manual_20261021/reimport_panels_v3/report.json','blender_reimport.json'),
    ('artifacts/asset_a03/crystal_bat_manual_v3/godot/report.json','godot_motion.json'),
    ('artifacts/a04_crystal_bat_manual_controller/result.json','godot_controller.json')]:
    save_json(source,name)
for source,name in [
    ('artifacts/bat_manual_20261021/degenerate_faces_v2.log','degenerate_corner_diagnosis.txt'),
    ('artifacts/bat_manual_20261021/preservation.log','failed_preservation_serialization.txt'),
    ('artifacts/asset_a03/crystal_bat_manual_v3/godot.log','godot_motion.txt'),
    ('artifacts/asset_a03/crystal_bat_manual_v3/controller.log','godot_controller.txt')]:
    text = (ROOT/source).read_text(encoding='utf-8-sig')
    (OUT/name).write_text(text,encoding='utf8',newline='\n')
frames = OUT/'frames'
frames.mkdir()
for path in sorted((ROOT/'artifacts/asset_a03/crystal_bat_manual_v3/godot').glob('*.webp')):
    capture(path,frames/path.name)
for name in ['fold_30_front.png','fold_30_right.png']:
    capture(BASE/'anatomical_fold_v1'/name,OUT/('failed_hinge_'+Path(name).stem+'.webp'))
for name in ['secondary-fold_wings.webp','full-fold-hold.webp','reset-pair.webp','death.webp']:
    capture(ROOT/'artifacts/a04_crystal_bat_manual_controller'/name,OUT/('controller_'+name))

failed = []
for directory in ['anatomical_fold_v1','manual_panels_v1','manual_panels_v2']:
    for path in sorted((BASE/directory).glob('*')):
        if path.suffix in ['.blend','.glb']:
            failed.append({'path':path.relative_to(ROOT).as_posix(),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                           'bytes':path.stat().st_size,'tracked':False,'rebuildable':True})
(OUT/'intermediate_hashes.json').write_text(json.dumps(failed,indent=2)+'\n',encoding='utf8',newline='\n')
files = [ROOT/'assets/models/rebuilt_enemies/crystal_bat_manual.glb',
         BASE/'topology_v2/crystal_bat_topology.blend',
         BASE/'manual_panels_v3/bat_manual_wings.blend',
         *sorted((BASE/'manual_panels_v3').glob('*.json')),
         *sorted(OUT.rglob('*'))]
for path in files:
    if path.is_file() and path.suffix in ['.json','.txt','.md']:
        path.write_text(path.read_text(encoding='utf-8-sig'),encoding='utf8',newline='\n')
records = [{'path':path.relative_to(ROOT).as_posix(),'bytes':path.stat().st_size,
            'sha256':hashlib.sha256(path.read_bytes()).hexdigest()} for path in files if path.is_file()]
(OUT/'evidence_manifest.json').write_text(json.dumps({'files':records},indent=2)+'\n',encoding='utf8',newline='\n')
print('BAT_MANUAL_EVIDENCE',len(records),'files',len(list(frames.glob('*.webp'))),'native frames')
