"""Freeze the completed startup experiments without saves or shader caches.

This is the 2026-10-22 experiment manifest, not a generic PASS generator. Every
successful sample must contain actual native frames and an exit-0 receipt.
"""
from pathlib import Path
import gzip
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "source_assets/windows_startup_20261022"
BATCHES = {
    "uncapped_baseline": "20261022-060435-566",
    "capped_baseline": "20261022-063441-330",
    "capped_loading": "20261022-063521-909",
}


def canonical(data):
    return data.decode("utf-8-sig").replace("\r\n", "\n").encode("utf-8")


def copy_text(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    data = canonical(source.read_bytes())
    if source.suffix == ".log":
        data = data.rstrip(b"\n") + b"\n"
    target.write_bytes(data)


def main():
    assert not OUT.exists(), "Preserve the existing frozen experiment."
    OUT.mkdir(parents=True)
    summaries = []
    for label, batch in BATCHES.items():
        source = ROOT / "artifacts/g083_startup_20261022" / batch
        dest = OUT / label
        runs = json.loads((source / "runs.json").read_text(encoding="utf-8-sig"))
        for name in ("runs.json", "sources.json"):
            copy_text(source / name, dest / name)
        for run in runs:
            case = Path(run["directory"])
            report = json.loads((case / "startup.json").read_text(encoding="utf-8-sig"))
            assert run["exit_code"] == 0 and not run["timed_out"]
            assert report["release"] and report["display"] == "Windows"
            assert not report["errors"] and report["ready_to_play"]
            assert len(report["frames"]) >= 180
            target = dest / case.name
            target.mkdir(parents=True)
            raw = canonical((case / "startup.json").read_bytes())
            (target / "startup.json.gz").write_bytes(gzip.compress(raw, mtime=0))
            copy_text(case / "process.csv", target / "process.csv")
            for log in case.glob("*.log"):
                copy_text(log, target / (log.name + ".txt"))
            began = report["script_entry_engine_usec"]
            events = {e["event"]: e for e in report["events"]}
            splash = events.get("bootstrap_splash_presented")
            ready = events.get("bootstrap_ready")
            frame = report["frames"][0]
            summaries.append({
                "batch": label, "case": case.name, "frames": len(report["frames"]),
                "process_seconds": run["seconds"], "fps_limit": report["fps_limit"],
                "first_frame_ms": (frame["begin_usec"] - began) / 1000,
                "first_draw_wall_ms": (frame["post_draw_usec"] - frame["pre_draw_usec"]) / 1000,
                "splash_from_script_ms": (splash["engine_usec"] - began) / 1000 if splash else None,
                "ready_from_script_ms": (ready["engine_usec"] - began) / 1000 if ready else None,
                "source_raw_sha256": hashlib.sha256(raw).hexdigest(),
            })
    # Selected actual captures; every native frame remains in the gzip files.
    image_source = ROOT / "artifacts/g083_startup_20261022" / BATCHES["capped_loading"] / "app_cache_fresh-0"
    for name in ("loading_screen.webp", "viewport.webp"):
        shutil.copy2(image_source / name, OUT / name)
    diagnostics = ROOT / "artifacts/windows_bootstrap"
    for name in ("story.log", "reload.log", "story_result.json", "reload_result.json",
                 "missing-fixed.log", "timeout-render-disposal.log", "detail_contract_before.json",
                 "detail_contract_after.json", "threaded_story_rejected.txt", "threaded_bootstrap.gd.txt",
                 "lifecycle-stdout.txt", "lifecycle-direct-stdout.txt", "lifecycle-sync-stdout.txt",
                 "timeout.log", "timeout-fixed.log"):
        copy_text(diagnostics / name, OUT / "regression" / (name + ".txt" if name.endswith(".log") else name))
    copy_text(ROOT / "artifacts/regression/g06-20261022-062935.json", OUT / "g06.json")
    copy_text(ROOT / "builds/g08/startup-probe-20261022-final/comparison.json", OUT / "frozen_rc3_pack_comparison.json")
    copy_text(ROOT / "builds/g08/startup-probe-20261022-final/export_receipt.json", OUT / "frozen_rc3_export_receipt.json")
    draft = ROOT / "artifacts/g08/20261022-115937"
    for name in ("manifest.json", "qa-prologue.log", "qa-restart.log", "candidate-smoke.log"):
        copy_text(draft / name, OUT / "draft_rc4" / (name + ".txt" if name.endswith(".log") else name))
    (OUT / "summary.json").write_text(json.dumps(summaries, indent=2) + "\n", encoding="utf-8", newline="\n")
    receipt = [{"path": p.relative_to(OUT).as_posix(), "bytes": p.stat().st_size,
                "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
               for p in sorted(OUT.rglob("*")) if p.is_file()]
    (OUT / "SHA256.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"cases": len(summaries), "files": len(receipt), "bytes": sum(r["bytes"] for r in receipt)}))


if __name__ == "__main__":
    main()
