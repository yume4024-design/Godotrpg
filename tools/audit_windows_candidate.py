"""Inspect PCKs in an empty Godot project and compare shared runtime bytes."""
import json
import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
manifest_path = pathlib.Path(sys.argv[1]).resolve()
manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
audit_outputs = manifest_path.parent / "pack_audit"
audit_root = audit_outputs / "workspace"
audit_root.mkdir(parents=True, exist_ok=True)
(audit_root / "project.godot").write_text('config_version=5\n', encoding="utf-8")
shutil.copyfile(ROOT / "tools/audit_windows_pack.gd", audit_root / "audit.gd")
engine = os.environ.get("GODOT_PATH", "D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe")
inventories = {}
environment = os.environ.copy()
environment["APPDATA"] = manifest["profile"]
environment["LOCALAPPDATA"] = str(manifest_path.parent / "local")
for role in ("candidate", "qa"):
    output = audit_outputs / f"{role}.json"
    run = subprocess.run([engine, "--headless", "--log-file", str(audit_outputs / f"{role}-engine.log"), "--path", str(audit_root), "--script", "audit.gd", "--",
                          str(pathlib.Path(manifest[role]).with_suffix(".pck")), str(output)],
                         capture_output=True, text=True, encoding="utf-8", timeout=60, env=environment)
    (audit_outputs / f"{role}.log").write_text(run.stdout + run.stderr, encoding="utf-8")
    assert run.returncode == 0 and "ERROR:" not in run.stdout + run.stderr, run.stdout + run.stderr
    inventory = json.loads(output.read_text(encoding="utf-8"))
    assert all(inventory["required"].values()), inventory["required"]
    scaffold = {"res://project.godot", "res://audit.gd", "res://audit.gd.uid"}
    inventories[role] = {p: sha for p, sha in inventory["files"].items() if p not in scaffold}
candidate, qa = inventories["candidate"], inventories["qa"]
forbidden = ("res://tests/", "res://tools/", "res://docs/", "res://assets/source/",
             "res://source_assets/", "res://scripts/tools/", "res://artifacts/", "res://builds/")
bad = [p for p in candidate if p.startswith(forbidden) or p.endswith(".blend")]
root_images = [p for p in candidate if p.startswith("res://") and "/" not in p[6:]
               and pathlib.PurePosixPath(p).suffix.lower() in {".png", ".jpg", ".jpeg", ".glb"}]
assert not bad and not root_images, (bad, root_images)
shared_runtime = [p for p in candidate if p.startswith(("res://assets/", "res://scripts/", "res://scenes/", "res://data/", "res://.godot/imported/", "res://.godot/exported/"))]
mismatches = [p for p in shared_runtime if candidate[p] != qa.get(p)]
assert not mismatches, mismatches
assert any(p.startswith("res://data/story/") and p.endswith(".json") for p in candidate)
summary = {"candidate_files": len(candidate), "qa_files": len(qa), "shared_runtime_hashes_matched": len(shared_runtime),
           "forbidden": bad, "root_references": root_images, "mismatches": mismatches}
(manifest_path.parent / "pack_audit.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
print(json.dumps(summary))
