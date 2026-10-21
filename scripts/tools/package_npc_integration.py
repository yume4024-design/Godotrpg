"""Collect A05 evidence without copying saves, export binaries or unrelated work."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
FILES = [
    "scenes/world/greystone_npcs.tscn", "scenes/world/legacy/greystone_npcs.tscn",
    "scripts/core/greystone_integration.gd", "tests/npc_integration_test.gd",
    "tests/windows_candidate_test.gd", "tools/godot.ps1",
]
ASSETS = ["blacksmith", "item_merchant", "innkeeper", "villager_male", "villager_female"]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def git_blob(commit: str, path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{commit}:{path}"], cwd=ROOT)


def gameplay(text: str) -> str:
    text = re.sub(r"^\[ext_resource[^\n]*\n", "", text, flags=re.M)
    text = re.sub(r'\[node name="Appearance"[^\n]*\n[^\[]*', "", text)
    return re.sub(r"\n+", "\n", text).strip()


def receipt(path: Path) -> dict:
    text = read(path)
    return {"path": path.relative_to(ROOT).as_posix(), "sha256": sha(path),
            "results": re.findall(r"^\w+_RESULT[^\r\n]*", text, re.M),
            "errors": re.findall(r"^(?:FAIL |SCRIPT ERROR:|ERROR:)[^\r\n]*", text, re.M)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--baseline", required=True)
    parser.add_argument("--native-log", type=Path, required=True)
    parser.add_argument("--regression", type=Path, required=True)
    parser.add_argument("--packages", type=Path, required=True)
    parser.add_argument("--failed-log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.relative_to(ROOT)
    if output.exists():
        raise SystemExit("Output must be new; previous evidence is preserved")
    source = subprocess.check_output(["git", "rev-parse", args.source_commit], cwd=ROOT, text=True).strip()
    baseline = subprocess.check_output(["git", "rev-parse", args.baseline], cwd=ROOT, text=True).strip()
    contract = {}
    for name in FILES + [f"assets/models/rebuilt_npc/{name}.glb" for name in ASSETS]:
        path = ROOT / name
        # Text checkout newlines may differ from committed LF; binary assets may not.
        actual = path.read_bytes()
        committed = git_blob(source, name)
        matches = actual == committed if path.suffix == ".glb" else actual.replace(b"\r\n", b"\n") == committed.replace(b"\r\n", b"\n")
        if not matches:
            raise SystemExit(f"Source differs from fixed checkpoint: {name}")
        if path.suffix == ".glb" and actual != git_blob(baseline, name):
            raise SystemExit(f"Accepted original model was changed: {name}")
        contract[name] = {"sha256": sha(path), "git_blob_sha256": hashlib.sha256(committed).hexdigest()}
    legacy = ROOT / "scenes/world/legacy/greystone_npcs.tscn"
    if legacy.read_bytes() != git_blob(baseline, "scenes/world/greystone_npcs.tscn"):
        raise SystemExit("Legacy scene is not an exact copy")
    if gameplay(read(legacy)) != gameplay(read(ROOT / "scenes/world/greystone_npcs.tscn")):
        raise SystemExit("NPC gameplay sections changed")
    native = receipt(args.native_log.resolve())
    regression = json.loads(read(args.regression))
    packages = json.loads(read(args.packages))
    if native["errors"] or not native["results"] or not all("failures=0" in line for line in native["results"]):
        raise SystemExit("Native evidence failed")
    if len(regression["results"]) != 16 or not all(row["passed"] for row in regression["results"]):
        raise SystemExit("G06 regression incomplete")
    if packages["base_commit"] != source or len(packages["results"]) != 3:
        raise SystemExit("Packages do not match fixed source or expected three executions")
    if not all(row["exit_code"] == 0 and all("failures=0" in line for line in row["result"]) for row in packages["results"]):
        raise SystemExit("Package execution failed")
    logs = [receipt((ROOT / "artifacts/logs" / row["log"]).resolve()) for row in regression["results"]]
    logs += [receipt(Path(row["log"]).resolve()) for row in packages["results"]]
    if any(row["errors"] for row in logs):
        raise SystemExit("Regression/package log contains errors")
    exports = {}
    for role in ["candidate", "qa"]:
        exe = Path(packages[role])
        exports[role] = {"exe": exe.as_posix(), "exe_sha256": sha(exe), "pck_sha256": sha(exe.with_suffix(".pck"))}
    output.mkdir(parents=True)
    (output / "captures").mkdir()
    for image in sorted((ROOT / "artifacts/asset_a05/integration").glob("*.webp")):
        shutil.copyfile(image, output / "captures" / image.name)
    # Deliberate failed test is a receipt, never mixed into PASS results.
    data = {"source_commit": source, "baseline": baseline, "engine": "4.7.2.stable.official.ed1daf0bf",
            "scope": "Four original NPC appearance slots only; female remains candidate by user instruction",
            "source_contract": contract, "npc_gameplay_sections_exact": True,
            "native": native, "regression": regression, "packages": packages, "export_hashes": exports,
            "log_receipts": logs, "failed_test_receipt": receipt(args.failed_log.resolve()),
            "limits": ["Automated native graphics and injected input; no new human hardware acceptance",
                       "No patrol, item handoff, hammer work, finger rig or cloth simulation acceptance",
                       "Not a new 30-minute whole-game soak; Android/iOS paused"]}
    (output / "evidence.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    manifest = {p.relative_to(output).as_posix(): sha(p) for p in sorted(output.rglob("*")) if p.is_file()}
    (output / "sha256.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"output": str(output), "files": len(manifest), "source": source}))


if __name__ == "__main__":
    main()
