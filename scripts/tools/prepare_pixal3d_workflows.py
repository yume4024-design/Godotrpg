"""Prepare project API workflows; preserve bounding boxes lost by CLI UI conversion.

Upload the named reference files with Comfy MCP first. Never submits a job.
"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
template = ROOT / "scripts/tools/workflows/pixal3d/3d_pixal3d_multi_views.api.json"
workflow = json.loads(template.read_text(encoding="utf-8"))
destination = ROOT / "artifacts/pixal3d/workflows"
destination.mkdir(parents=True, exist_ok=True)
(destination / "ren_api.json").write_text(json.dumps(workflow, indent=2, ensure_ascii=False), encoding="utf-8")
lia = copy.deepcopy(workflow)
for node_id, filename in {"338": "lia_front.png", "341": "lia_left.png", "342": "lia_back.png", "345": "lia_right.png"}.items():
    lia[node_id] = {"class_type": "LoadImage", "inputs": {"image": filename}}
del lia["364"]
lia["372"]["inputs"]["filename_prefix"] = "project_crystal/lia_pixal3d"
(destination / "lia_api.json").write_text(json.dumps(lia, indent=2, ensure_ascii=False), encoding="utf-8")
print("Prepared ren_api.json and lia_api.json; no jobs submitted")
