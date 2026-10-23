"""Summarize persisted native evidence after the owned graphical process exits."""
import csv
import gzip
import hashlib
import json
import math
import statistics
import sys
from collections import defaultdict
from pathlib import Path


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def stats(values):
    ordered = sorted(values)
    if not ordered:
        return None
    return {"count": len(ordered), "mean": statistics.mean(ordered),
            "p95": ordered[math.ceil(len(ordered) * .95) - 1],
            "p99": ordered[math.ceil(len(ordered) * .99) - 1],
            "max": ordered[-1], "min": ordered[0]}


def sha(path):
    return hashlib.file_digest(Path(path).open("rb"), "sha256").hexdigest()


def summarize(evidence):
    manifest = read_json(evidence / "manifest.json")
    assert manifest["mode"] == "Soak" and manifest["passed"], "A completed Soak is required"
    metrics_path = Path(manifest["metrics"])
    metrics = read_json(metrics_path)
    assert metrics["complete"] and metrics["soak_seconds"] >= 1800 and not metrics["short_preflight"]
    frame_path = metrics_path.with_name("frames.csv")
    rows = list(csv.DictReader(frame_path.open(encoding="utf-8")))
    assert len(rows) == metrics["raw_frame_count"]
    frames = defaultdict(list)
    spikes = []
    video_bytes = []
    for row in rows:
        ms = float(row["frame_ms"])
        frames[row["phase"]].append(ms)
        video_bytes.append(int(row["video_memory_bytes"]))
        if ms > 33.333:
            spikes.append({**row, "frame_ms": ms})
    process = list(csv.DictReader(Path(manifest["process_samples"]).open(encoding="utf-8-sig")))
    steady = [r for r in process if 60 <= float(r["elapsed_seconds"]) <= manifest["seconds"] - 5]
    memory = {}
    for key in ("working_set_bytes", "private_bytes", "peak_working_set_bytes"):
        memory[key] = {"peak": max(int(r[key]) for r in process),
                       "first_60_mean": statistics.mean(int(r[key]) for r in steady[:60]),
                       "last_60_mean": statistics.mean(int(r[key]) for r in steady[-60:])}
    checkpoints = {}
    for name in ("greystone_runtime", "forest", "mine"):
        selected = [r for r in metrics["checkpoints"] if r["map"] == name]
        checkpoints[name] = {"count": len(selected), "first": selected[0], "last": selected[-1],
                             "node_counts": sorted({r["nodes"] for r in selected}),
                             "object_counts": sorted({r["objects"] for r in selected})}
    summary = {"soak_seconds": metrics["soak_seconds"], "total_seconds": metrics["total_seconds"],
               "process_seconds": manifest["seconds"], "checks": metrics["checks"],
               "failures": metrics["failures"], "cycles_started": metrics["cycles"],
               "transitions": stats([r["ms"] for r in metrics["transitions"]]),
               "operations": {k: stats(v) for k, v in metrics["operations"].items()},
               "all_frames": stats([float(r["frame_ms"]) for r in rows]),
               "raw_phases": {k: stats(v) for k, v in frames.items()},
               "all_spike_count_over_33ms": len(spikes),
               "top_20_spikes": sorted(spikes, key=lambda r: r["frame_ms"], reverse=True)[:20],
               "video_memory_bytes": stats(video_bytes), "process_memory": memory,
               "checkpoints": checkpoints, "metrics_sha256": sha(metrics_path),
               "raw_csv_sha256": sha(frame_path),
               "physical_input_verified": False, "android_verified": False,
               "method": "Native graphical automated QA, CPU frame intervals including cap/waits and diagnostics; not human playthrough or GPU timing. Release engine static memory unavailable is null."}
    (evidence / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    compressed = evidence / "frames.csv.gz"
    with frame_path.open("rb") as src, compressed.open("wb") as target:
        with gzip.GzipFile(filename="frames.csv", mode="wb", fileobj=target, mtime=0) as gz:
            gz.write(src.read())
    with gzip.open(compressed, "rb") as handle:
        assert hashlib.sha256(handle.read()).hexdigest() == summary["raw_csv_sha256"]
    print(json.dumps({k: summary[k] for k in ("soak_seconds", "checks", "failures", "all_frames", "transitions", "process_memory")}, ensure_ascii=False))


if __name__ == "__main__":
    summarize(Path(sys.argv[1]))
