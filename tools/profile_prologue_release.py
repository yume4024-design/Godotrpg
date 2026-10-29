"""Build a disposable native Release probe from a Git snapshot, with audited timing-only inserts.
No game source, fixed package or user save is overwritten. Overlay paths are explicit and hashed.
"""
import argparse,hashlib,json,os,re,shutil,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ENGINE=Path('D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def method(text,name):
 start=text.index('func '+name+'(');end=text.find('\nfunc ',start+1)
 return text[start:end if end>=0 else len(text)].rstrip()
def instrument(work,path,name,stops,tail):
 p=work/path;s=p.read_text(encoding='utf-8-sig');original=method(s,name)
 if name=='validate_loaded_position':
  stops=[(next(l for l in original.splitlines() if l.startswith('\tvar candidate: Node3D =')), stops[0][1]),*stops[1:]]
 lines=original.splitlines();lines.insert(1,'\tvar qa_start: int = Time.get_ticks_usec()');timed='\n'.join(lines)
 for anchor,label in stops:
  assert timed.count(anchor)==1,(path,name,anchor,timed.count(anchor))
  timed=timed.replace(anchor,anchor+'\n\tvar qa_'+label+': int = Time.get_ticks_usec()',1)
 final=tail[0];record=tail[1]
 assert timed.count(final)==1,(path,name,final)
 timed=timed.replace(final,'\tPrologueProfileTrace.rows.append('+record+')\n'+final,1)
 stripped='\n'.join(l for l in timed.splitlines() if not re.match(r'\s*(var qa_\w+: int = Time.get_ticks_usec\(\)|PrologueProfileTrace.rows.append\()',l))
 assert stripped==original,(path,name,'not timing-only')
 p.write_text(s.replace(original,timed,1),encoding='utf-8')
 return {'path':path,'method':name,'original_method_sha256':hashlib.sha256(original.encode()).hexdigest(),'timing_only':True}
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--overlay',action='append',default=[])
 a=ap.parse_args();out=a.output.resolve();assert not out.exists();out.mkdir(parents=True);work=out/'source';work.mkdir()
 commit=subprocess.check_output(['git','-C',str(ROOT),'rev-parse','HEAD'],text=True).strip()
 archive=out/'source.zip';subprocess.run(['git','-C',str(ROOT),'archive','--format=zip','--output='+str(archive),commit,'project.godot','default_bus_layout.tres','export_presets.cfg','assets','scenes','scripts','data','tests'],check=True)
 with zipfile.ZipFile(archive) as z:z.extractall(work)
 overlays=['tests/prologue_performance_probe.gd','tests/prologue_profile_trace.gd',*a.overlay];overlay_receipt={}
 for relative in overlays:
  source=(ROOT/relative).resolve();assert source.is_relative_to(ROOT) and source.is_file()
  dest=work/source.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest);overlay_receipt[relative]=sha(source)
 receipt={'source_commit':commit,'overlays':overlay_receipt,'instrumented_methods':[],'runtime_kind':'Godot Windows x64 Release export with timing-only source overlays'}
 specs=[
 ('scripts/core/exploration_game.gd','validate_loaded_position',[
 ('\tvar candidate: Node3D = selected.instantiate() as Node3D','instance'),('\tviewport.add_child(candidate)','ready'),('\tvar position: Vector3 = Vector3(location.x, location.y, location.z)','waited')],
 ('\treturn empty and grounded','{"kind":"validate","phase":PrologueProfileTrace.phase,"map":str(location.map),"layout":int(location.get("layout_version",1)),"create_ms":(qa_instance-qa_start)/1000.0,"ready_ms":(qa_ready-qa_instance)/1000.0,"physics_wait_ms":(qa_waited-qa_ready)/1000.0,"query_ms":(Time.get_ticks_usec()-qa_waited)/1000.0,"accepted":empty and grounded}')),
 ('scripts/core/battle_flow.gd','_spawn',[
 ('\tarena = battle_scene.instantiate() as BattleArena','instance'),('\tadd_child(arena)','ready'),('\tarena.setup(_party, _inventory, catalog.enemies(battle_id), catalog.encounters[battle_id], _practice)','setup')],
 ('\tarena.manager.settled.connect(_on_settled)','{"kind":"battle_spawn","phase":PrologueProfileTrace.phase,"battle":str(battle_id),"instantiate_ms":(qa_instance-qa_start)/1000.0,"ready_ms":(qa_ready-qa_instance)/1000.0,"setup_ms":(qa_setup-qa_ready)/1000.0}')),
 ('scripts/battle/battle_arena.gd','setup',[
 ('\tmanager.setup(party, inventory, enemies, encounter)','manager'),('\tstage.setup(manager)','stage'),('\tinterface.bind_manager(manager, encounter.name, practice)','ui')],
 ('\tmanager.start()','{"kind":"battle_setup","phase":PrologueProfileTrace.phase,"backdrop_manager_ms":(qa_manager-qa_start)/1000.0,"actors_ms":(qa_stage-qa_manager)/1000.0,"ui_ms":(qa_ui-qa_stage)/1000.0}')),
 ('scripts/world/scene_manager.gd','_swap',[
 ('\tcurrent_map = scene.instantiate() as ExplorationMap','instance'),('\t_container.add_child(current_map)','ready'),('\tmap_changed.emit(current_map)','signals')],
 ('\ttransitioning = false','{"kind":"map_swap","phase":PrologueProfileTrace.phase,"map":str(current_map.map_id),"fade_and_instance_ms":(qa_instance-qa_start)/1000.0,"ready_ms":(qa_ready-qa_instance)/1000.0,"signals_ms":(qa_signals-qa_ready)/1000.0,"total_ms":(Time.get_ticks_usec()-qa_start)/1000.0}'))]
 for spec in specs:receipt['instrumented_methods'].append(instrument(work,*spec))
 project=work/'project.godot';text=project.read_text(encoding='utf-8');text=text.replace('run/main_loop_type.prologue_qa="PrologueCandidateTestTree"','run/main_loop_type.prologue_qa="ProloguePerformanceProbe"');project.write_text(text,encoding='utf-8')
 profile=out/'build-profile';profile.mkdir();templates=ROOT/'artifacts/godot-user/Godot/export_templates/4.7.2.stable'
 assert (templates/'version.txt').read_text().strip()=='4.7.2.stable'
 shutil.copytree(templates,profile/'Godot/export_templates/4.7.2.stable')
 env=os.environ.copy();env.update(APPDATA=str(profile),LOCALAPPDATA=str(profile),TEMP=str(out),TMP=str(out))
 for name,args in [('import',['--import']),('export',['--export-release','Windows Prologue QA',str(out/'ProjectCrystal.exe')])]:
  r=subprocess.run([str(ENGINE),'--headless','--path',str(work),*args],capture_output=True,env=env,timeout=600)
  log=r.stdout+b'\n'+r.stderr;(out/(name+'.txt')).write_bytes(log)
  assert r.returncode==0 and not re.search(rb'(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:)',log),(name,r.returncode,log[-2500:])
  print('PROFILE_BUILD_STEP',name,flush=True)
 receipt['files']={n:sha(out/n) for n in ['ProjectCrystal.exe','ProjectCrystal.pck']}
 (out/'build_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8');print('PROLOGUE_PROFILE_EXPORTED',out,flush=True)
if __name__=='__main__':main()
