from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=ROOT/'project.godot';s=p.read_text(encoding='utf8');key='run/main_scene.mine_windows_candidate='
if key not in s:
 s=s.replace('config/features=', 'run/main_scene.mine_windows_candidate="res://scenes/main/mine_reference_candidate.tscn"\nrun/main_scene.mine_windows_qa="res://tests/qa_entry.tscn"\nrun/main_loop_type.mine_windows_qa="MineWindowsTestTree"\nconfig/version.mine_windows_candidate="0.6.1-mine-reference-rc1"\nconfig/version.mine_windows_qa="0.6.1-mine-reference-rc1"\nconfig/features=',1)
p.write_text(s,encoding='utf8',newline='\n')
p=ROOT/'export_presets.cfg';s=p.read_text(encoding='utf8');marker='\n; Mine reference candidate\n';s=s.split(marker)[0].rstrip()+'\n'
start=s.index('[preset.8]');end=s.index('[preset.9]');template=s[start:end].strip()
s+=marker
for index,feature,label,role in [(11,'mine_windows_candidate','Windows Mine Candidate','candidate'),(12,'mine_windows_qa','Windows Mine QA','qa')]:
 t=template.replace('[preset.8',f'[preset.{index}').replace('Windows Blender Candidate',label).replace('blender_windows_candidate',feature).replace('greystone-blender/candidate',f'mine-reference/{role}').replace('data/battles/*.json"','data/battles/*.json,data/world/*.json,assets/models/mine_reference/*.json"')
 if role=='qa':t=t.replace(',tests/*','')
 t=t.replace('Project Crystal Greystone Blender Candidate','Project Crystal Mine Reference Candidate')
 s+='\n'+t+'\n'
p.write_text(s,encoding='utf8',newline='\n')
