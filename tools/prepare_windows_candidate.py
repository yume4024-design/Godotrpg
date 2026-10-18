"""Generate isolated G08 presets from reviewed runtime resources, never root references."""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
root_references = sorted(p.name for p in ROOT.iterdir() if p.is_file()
                         and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".glb", ".gltf", ".blend"})
common_excludes = ["assets/source/*", "source_assets/*", "scripts/tools/*", "docs/*",
                   "tools/*", "artifacts/*", "builds/*", "*.md", "*.blend"] + root_references
presets = ROOT / "export_presets.cfg"
text = presets.read_text(encoding="utf-8")
marker = "\n; G08 generated presets (tools/prepare_windows_candidate.py)"
if marker not in text and any(f"[preset.{index}]" in text for index in (4, 5)):
    raise RuntimeError("Preset slots 4/5 already belong to another configuration")
if marker in text and any(int(index) not in (4, 5) for index in re.findall(r"\[preset\.(\d+)\]", text.split(marker, 1)[1])):
    raise RuntimeError("Unmanaged preset after G08 block; preserve it before regenerating")
text = text.split(marker)[0].rstrip() + "\n" + marker + "\n"
for index, label, feature in [
    (4, "Windows G08 Candidate", "g08_candidate"),
    (5, "Windows G08 QA", "g08_qa"),
]:
    text += f'''\n[preset.{index}]
name="{label}"
custom_features="{feature}"
platform="Windows Desktop"
runnable=false
advanced_options=false
export_filter="all_resources"
include_filter="data/story/*.json,data/quests/*.json,data/battles/*.json"
exclude_filter={json.dumps(','.join(common_excludes + (['tests/*'] if feature == 'g08_candidate' else [])), ensure_ascii=False)}
export_path="builds/g08/{feature}/ProjectCrystal.exe"
script_export_mode=2

[preset.{index}.options]
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
application/product_name="Project Crystal G08 Candidate"
'''
presets.write_text(text, encoding="utf-8")
print(f"G08 presets prepared; excluded root reference files={len(root_references)}")
