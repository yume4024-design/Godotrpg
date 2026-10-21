"""Freeze real Ren runtime candidate evidence after all required local tests pass."""
import hashlib, json, re, shutil, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'artifacts/ren_runtime'
OUT=ROOT/'source_assets/character_rebuild_20261020/ren/runtime_acceptance_20261022'

def read(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    raw=path.read_bytes()
    if path.suffix in {'.py','.gd','.tscn','.tres','.md','.json','.ps1','.gitignore','.import','.uid'}:
        raw=raw.decode('utf-8-sig').replace('\r\n','\n').encode()
    return hashlib.sha256(raw).hexdigest()

checks={}
for name,path,count in [('controller',WORK/'controller/report.json',93),('movement',WORK/'movement/result.json',64),
                        ('story',WORK/'story/story.json',84),('restart',WORK/'story/reload.json',9)]:
    report=read(path)
    assert report['checks']==count and not report['failures'], (name,report)
    checks[name]={'checks':count,'failures':0,'source':path.relative_to(ROOT).as_posix()}
for name in ['glb_final','equipment_final_grip','preservation_final']:
    assert read(WORK/(name+'.json'))['status']=='PASS'
regression=ROOT/'artifacts/regression/g06-20261022-042327.json'
reg=read(regression)
assert len(reg['results'])==16 and all(row['passed'] for row in reg['results'])
total=sum(int(match.group(1)) for row in reg['results'] for line in row['result']
          if (match:=re.search(r'_RESULT checks=(\d+) failures=0',line)))
assert total==576,total
assert not OUT.exists(), 'Do not overwrite frozen evidence'
OUT.mkdir(parents=True)
for folder in ['controller','movement','story']:
    shutil.copytree(WORK/folder,OUT/folder)
for name in ['glb_final','equipment_final_grip','preservation_final']:
    shutil.copy2(WORK/(name+'.json'),OUT/(name+'.json'))
shutil.copy2(WORK/'blender_import_final/report.json',OUT/'blender_import.json')
shutil.copy2(regression,OUT/'g06_regression.json')
failures=OUT/'failures';failures.mkdir()
for name in ['equipment_v1.json','equipment_v2.json','equipment_v3.json']:
    shutil.copy2(WORK/name,failures/name)
for source,name in [('movement_wide_failure/result.json','wide_gait_60_2.json'),
                    ('controller_static_gait_failure/report.json','static_gait_93_2.json')]:
    shutil.copy2(WORK/source,failures/name)
for source,name in [('controller_v2/guard_right.webp','v2_weak_guard.webp'),
                    ('controller_static_gait_failure/run_narrow.webp','static_gait_failure.webp')]:
    shutil.copy2(WORK/source,failures/name)
for version in ['runtime_actions_v1_20261021','runtime_actions_v2_20261021','runtime_actions_v3_20261021',
                'runtime_narrow_20261021','runtime_narrow_motion_20261022','sword_20261021']:
    shutil.copy2(OUT.parent/version/'build_report.json',OUT/(version+'_build.json'))
logs=[]
for mode in ['visualrenruntime','visualrenmovement','visualrenstory','testrenstoryreload','testpixalcharacters','check']:
    path=max((ROOT/'artifacts/logs').glob(mode+'-*.log'),key=lambda p:p.stat().st_mtime)
    text=path.read_text(encoding='utf-8-sig')
    assert not re.search(r'^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:)',text,re.M),path
    logs.append({'mode':mode,'local_log':path.name,'sha256':sha(path),
                 'result_lines':[line for line in text.splitlines() if '_RESULT' in line or 'REN_RUNTIME_STORY' in line]})
formal=['scenes/main/main.tscn','scenes/characters/ren_pixal_visual.tscn','scenes/characters/lia_pixal_visual.tscn',
        'assets/models/pixal3d/ren_locomotion.glb','assets/models/pixal3d/lia_locomotion.glb',
        'scripts/save/save_codec.gd','data/story/prologue_events.json']
formal_rows=[]
for relative in formal:
    path=ROOT/relative
    expected=subprocess.check_output(['git','show','HEAD:'+relative],cwd=ROOT)
    actual=path.read_bytes()
    if path.suffix in ['.tscn','.gd','.json']:actual=actual.replace(b'\r\n',b'\n');expected=expected.replace(b'\r\n',b'\n')
    assert actual==expected,relative
    formal_rows.append({'path':relative,'sha256':sha(path),'unchanged_from_base':True})
evidence={'base_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
          'branch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),
          'engine':'4.7.2.stable.official.ed1daf0bf','blender':'5.2.2 LTS','platform':'Windows Compatibility / RTX 3080',
          'checks':checks,'g06':{'modes':16,'checks':total,'failures':0},'legacy_pixal':{'checks':88,'failures':0},
          'logs':logs,'formal_baseline':formal_rows,'formal_replacement':False,
          'limits':['No new packaged or endurance performance acceptance','No new physical Xbox/human acceptance',
                    'No independent finger rig, eyelid/mouth morphs or terrain IK','Android/iOS paused; chapter one incomplete']}
(OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
manifest={p.relative_to(ROOT).as_posix():sha(p) for p in sorted(OUT.rglob('*')) if p.is_file()}
(OUT/'sha256.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8')
print('REN_RUNTIME_EVIDENCE',len(manifest),'files',sum(p.stat().st_size for p in OUT.rglob('*') if p.is_file()),'bytes')
