"""Build an isolated QA main loop from the attached fixed RC3 worktree.

Only new QA code and feature/preset settings are installed temporarily. Existing
config bytes are backed up and restored with ownership checks; no git reset,
checkout, source import cleanup, or game-method replacement occurs.
"""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess

ROOT=Path(__file__).resolve().parents[1]
ENGINE=Path('D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
EXPECTED='d03db5fa5e77aeb4a8710cd7c441e1048e355bed'

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--worktree',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True)
 a=p.parse_args();work=a.worktree.resolve();out=a.output.resolve()
 assert work!=ROOT and (work/'.git').is_file()
 assert subprocess.check_output(['git','-C',str(work),'rev-parse','HEAD'],text=True).strip()==EXPECTED
 assert not out.exists();out.mkdir(parents=True)
 originals={name:(work/name).read_bytes()for name in ['project.godot','export_presets.cfg']}
 for name,data in originals.items():
  assert subprocess.check_output(['git','-C',str(work),'show','HEAD:'+name]).decode('utf-8-sig').replace('\r\n','\n')==data.decode('utf-8-sig').replace('\r\n','\n'),name
  (out/(name+'.backup')).write_bytes(data)
 additions=['tests/g083_startup_probe.gd','scripts/core/windows_candidate_bootstrap.gd','scenes/main/windows_candidate_bootstrap.tscn']
 for relative in additions:
  assert not(work/relative).exists()and not(work/relative).with_suffix(Path(relative).suffix+'.uid').exists()
 text=originals['project.godot'].decode('utf-8-sig').replace('\r\n','\n')
 settings='run/main_scene.g083_startup="res://tests/qa_entry.tscn"\nrun/main_loop_type.g083_startup="G083StartupProbe"\nconfig/version.g083_startup="0.6.1-g08-rc3-startup-probe"\n\n'
 text=text.replace('[debug]',settings+'[debug]',1)
 presets=originals['export_presets.cfg'].decode('utf-8-sig').replace('\r\n','\n')
 index=max(map(int,re.findall(r'\[preset\.(\d+)\]',presets)))+1
 # Reuse the existing soak QA preset including its precise exclusion filters.
 source=re.search(r'(?ms)^\[preset\.(\d+)\]\nname="Windows G083 Soak QA".*?(?=^\[preset\.\d+\]\n|\Z)',presets)
 assert source
 extra=source.group(0).replace('preset.'+source.group(1),'preset.'+str(index)).replace('Windows G083 Soak QA','Windows G083 Startup QA').replace('custom_features="g083_qa"','custom_features="g083_startup"')
 template=ROOT/'artifacts/godot-user/Godot/export_templates/4.7.2.stable/windows_release_x86_64.exe'
 assert template.is_file()and(template.parent/'version.txt').read_text().strip().startswith('4.7.2.stable')
 extra=extra.replace('custom_template/release=""','custom_template/release="'+template.as_posix()+'"')
 changed={'project.godot':text.encode(),'export_presets.cfg':(presets+'\n'+extra).encode()}
 try:
  for name,data in changed.items():(work/name).write_bytes(data)
  for relative in additions:shutil.copy2(ROOT/relative,work/relative)
  profile=out/'editor_profile';profile.mkdir()
  import os
  env=os.environ.copy();env.update(APPDATA=str(profile),LOCALAPPDATA=str(out/'editor_local'))
  for mode,args in [('scan',['--headless','--editor','--quit']),('export',['--headless','--export-release','Windows G083 Startup QA',str(out/'ProjectCrystal.exe')])]:
   result=subprocess.run([str(ENGINE),'--path',str(work),*args],capture_output=True,env=env,timeout=120)
   (out/(mode+'.txt')).write_bytes(result.stdout+b'\n'+result.stderr)
   assert result.returncode==0,(mode,result.returncode)
   assert not re.search(rb'(?m)^(SCRIPT ERROR:|ERROR:|Parse Error:)',result.stdout+result.stderr),mode
  assert (out/'ProjectCrystal.exe').is_file()and(out/'ProjectCrystal.pck').is_file()
 finally:
  for name,data in originals.items():
   assert (work/name).read_bytes()==changed[name], 'Concurrent config change; do not overwrite '+name
   (work/name).write_bytes(data)
  for relative in additions:
   path=work/relative
   assert path.read_bytes()==(ROOT/relative).read_bytes()
   path.unlink()
   uid=path.with_suffix(path.suffix+'.uid')
   if uid.exists():uid.unlink()
 receipt={'source_commit':EXPECTED,'worktree':str(work),'main_loop':'G083StartupProbe','game_entry':'res://scenes/main/greystone_preview.tscn',
          'config_restored':all((work/name).read_bytes()==data for name,data in originals.items()),
          'gameplay_methods_modified':False,'files':{name:hashlib.sha256((out/name).read_bytes()).hexdigest()for name in ['ProjectCrystal.exe','ProjectCrystal.pck']},
          'shared_pack_comparison':'NOT_TESTED'}
 (out/'export_receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
 print('G083_STARTUP_QA_EXPORTED',out)

if __name__=='__main__':main()
