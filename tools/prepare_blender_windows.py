"""Append dedicated Blender candidate presets, preserving all existing presets."""
import json,re
from pathlib import Path

root=Path(__file__).resolve().parents[1]
path=root/'export_presets.cfg'
text=path.read_text(encoding='utf-8')
marker='\n; Blender Windows candidate (tools/prepare_blender_windows.py)\n'
text=text.split(marker)[0].rstrip()+'\n'
slots=[int(v) for v in re.findall(r'^\[preset\.(\d+)\]$',text,re.M)]
next_slot=max(slots,default=-1)+1
excludes=['assets/source/*','source_assets/*','scripts/tools/*','scenes/tools/*','docs/*','tools/*','artifacts/*','builds/*','*.md','*.blend','*.blend1','*.blend2','npc/*','敵人/*','艾琳角色圖/*']
excludes += [p.name for p in root.iterdir() if p.is_file() and p.suffix.lower() in ('.png','.jpg','.jpeg','.glb','.gltf')]
text+=marker
for offset,(label,feature,role) in enumerate([
    ('Windows Blender Candidate','blender_windows_candidate','candidate'),
    ('Windows Blender QA','blender_windows_qa','qa')]):
    slot=next_slot+offset
    filtering=excludes+(['tests/*'] if role=='candidate' else [])
    text+=f'''\n[preset.{slot}]
name="{label}"
platform="Windows Desktop"
runnable=false
advanced_options=false
dedicated_server=false
custom_features="{feature}"
export_filter="all_resources"
include_filter="data/story/*.json,data/quests/*.json,data/battles/*.json"
exclude_filter={json.dumps(','.join(filtering),ensure_ascii=False)}
export_path="builds/greystone-blender/{role}/ProjectCrystal.exe"
script_export_mode=2

[preset.{slot}.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=0
binary_format/architecture="x86_64"
binary_format/embed_pck=false
texture_format/s3tc_bptc=true
codesign/enable=false
application/modify_resources=false
application/file_version="0.6.1.0"
application/product_version="0.6.1.0"
application/product_name="Project Crystal Greystone Blender Candidate"
'''
path.write_text(text,encoding='utf-8',newline='\n')
print('BLENDER_WINDOWS_PRESETS',next_slot,next_slot+1)
