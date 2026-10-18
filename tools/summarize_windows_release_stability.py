"""Summarize native G08.3 evidence; preserve raw monitor zeros as unavailable."""
import csv
import json
import math
import pathlib
import statistics
import sys


def stats(values):
    values = sorted(values)
    if not values:
        return None
    return {"n": len(values), "mean": statistics.mean(values),
            "p95": values[math.ceil(len(values) * .95) - 1],
            "p99": values[math.ceil(len(values) * .99) - 1], "max": values[-1]}


manifest_path = pathlib.Path(sys.argv[1]).resolve()
manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
raw = json.loads(pathlib.Path(manifest["metrics"]).read_text(encoding="utf-8-sig"))
with pathlib.Path(manifest["process_samples"]).open(encoding="utf-8-sig", newline="") as file:
    processes = [{k: float(v) for k, v in row.items()} for row in csv.DictReader(file)]
metrics = {k: dict(v) for k, v in raw["metrics"].items()}
for row in metrics.values():
    if not row.get("engine_peak_bytes"):
        row["engine_peak_bytes"] = None
memory = {k: {"peak_mib": max(row[k] for row in processes) / 1048576,
              "first_mib": processes[0][k] / 1048576,
              "last_mib": processes[-1][k] / 1048576}
          for k in ("working_set_bytes", "private_bytes", "peak_working_set_bytes")}
maps = {}
for name in ("greystone_runtime", "forest", "mine"):
    checkpoints = [row for row in raw["checkpoints"] if row["map"] == name]
    maps[name] = {"n": len(checkpoints), "nodes": sorted({row["nodes"] for row in checkpoints}),
                  "objects_min": min(row["objects"] for row in checkpoints),
                  "objects_max": max(row["objects"] for row in checkpoints)} if checkpoints else {}
summary = {"complete": raw["complete"], "release": raw["release"], "display": raw["display"],
           "soak_seconds": raw["soak_seconds"], "total_seconds": raw["total_seconds"],
           "checks": raw["checks"], "failures": raw["failures"], "cycles": raw["cycles"],
           "cap_fps": raw["cap_fps"], "metrics": metrics, "memory": memory,
           "transition_ms": stats([row["ms"] for row in raw["transitions"]]),
           "transition_count": len(raw["transitions"]),
           "operations_ms": {k: stats(v) for k, v in raw["operations"].items()},
           "spikes_top": sorted(raw["spikes_over_33ms"], key=lambda x: x["ms"], reverse=True)[:20],
           "spikes_retained": len(raw["spikes_over_33ms"]), "spike_retention_limit": 300,
           "map_checkpoints": maps,
           "unavailable_release_monitors": ["MEMORY_STATIC", "OBJECT_ORPHAN_NODE_COUNT"],
           "human_playthrough": False, "android_verified": False,
           "method_notes": "60 FPS cap; all frame wall times include test work. Native OS memory includes diagnostics. Transition latency includes authored fades. Zero release-only monitor values are unavailable, not zero memory or proof of zero orphan nodes."}
output = manifest_path.parent / "summary.json"
output.write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
assert summary["complete"] and summary["release"] and summary["display"] != "headless"
assert summary["soak_seconds"] >= 1800 and summary["failures"] == 0
print(json.dumps({"summary": str(output), "soak_seconds": summary["soak_seconds"],
                  "checks": summary["checks"], "failures": summary["failures"]}))
