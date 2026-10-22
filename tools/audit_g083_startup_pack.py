"""Compare actual physical candidate/QA pack entries, including hidden binaries.

The separate minimal host project avoids merging the active game worktree into
the mounted pack inventory. Only three documented QA metadata entries may vary.
"""
from pathlib import Path
import argparse,hashlib,json,os,subprocess

ROOT=Path(__file__).resolve().parents[1]
ENGINE=Path('D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe')
ALLOWED={'res://project.binary','res://.godot/global_script_class_cache.cfg','res://.godot/uid_cache.bin'}
BOOTSTRAP_ADDITIONS={'res://scripts/core/windows_candidate_bootstrap.gd.remap','res://scripts/core/windows_candidate_bootstrap.gdc','res://scenes/main/windows_candidate_bootstrap.tscn.remap'}
def compare(candidate,probe):
 def physical(rows):return {k:v for k,v in rows.items()if k!='res://project.godot'and not k.startswith(('res://profile/','res://local/'))}
 candidate=physical(candidate);probe=physical(probe)
 missing=sorted(set(candidate)-set(probe))
 mismatches=sorted(k for k in candidate.keys()&probe.keys()if candidate[k]!=probe[k]and k not in ALLOWED)
 extra=sorted(set(probe)-set(candidate))
 new_game=[k for k in extra if k.startswith(('res://assets/','res://scenes/','res://scripts/','res://data/'))and k not in BOOTSTRAP_ADDITIONS]
 return {'status':'FAIL'if missing or mismatches or new_game else'PASS','candidate_entries':len(candidate),'probe_entries':len(probe),
         'unchanged_entries':sum(k in probe and candidate[k]==probe[k]for k in candidate),
         'missing':missing,'game_entry_mismatches':mismatches,'new_game_paths':new_game,
         'allowed_metadata_differences':sorted(k for k in ALLOWED if k in candidate and candidate.get(k)!=probe.get(k)),
         'extra_qa_entries':extra}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--candidate',type=Path,required=True);p.add_argument('--probe',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True);p.add_argument('--workspace',type=Path,required=True)
 a=p.parse_args();assert not a.workspace.exists();a.workspace.mkdir(parents=True)
 host=a.workspace/'project';host.mkdir()
 (host/'project.godot').write_bytes(b'[application]\nconfig/name="Crystal Pack Audit"\n')
 env=os.environ.copy();env.update(APPDATA=str(a.workspace.resolve()/'profile'),LOCALAPPDATA=str(a.workspace.resolve()/'local'))
 rows={}
 for name,pack in [('candidate',a.candidate),('probe',a.probe)]:
  dest=a.workspace/(name+'.json')
  result=subprocess.run([str(ENGINE),'--headless','--path',str(host.resolve()),'--script',str(ROOT/'tools/audit_native_pack.gd'),'--',str(pack.resolve()),str(dest.resolve())],capture_output=True,env=env,timeout=30)
  (a.workspace/(name+'.txt')).write_bytes(result.stdout+b'\n'+result.stderr)
  assert result.returncode==0,result.stderr.decode(errors='replace')
  rows[name]=json.loads(dest.read_text(encoding='utf-8-sig'))
 report=compare(rows['candidate'],rows['probe'])
 report.update(candidate_pck_sha256=hashlib.sha256(a.candidate.read_bytes()).hexdigest(),probe_pck_sha256=hashlib.sha256(a.probe.read_bytes()).hexdigest())
 assert report['candidate_pck_sha256']=='2758b063385a25e724b13a546cff9585f65557dafed2989ebad005baf276d13c'
 assert report['unchanged_entries']>=698
 a.output.write_bytes((json.dumps(report,indent=2)+'\n').encode())
 print('G083_PACK_COMPARISON',report['status'],report['unchanged_entries'],'unchanged physical entries')
 if report['status']!='PASS':raise SystemExit(1)
if __name__=='__main__':main()
