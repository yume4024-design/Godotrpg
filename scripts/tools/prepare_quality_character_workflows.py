"""Build local Pixal3D API copies from the current UI graph, without decimation."""
import copy
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path("D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/user/default/workflows/3d_pixal3d_multi_views.json")
DEST = ROOT / "source_assets/quality_characters_20261018"
WORK = ROOT / "artifacts/quality_characters"
WORK.mkdir(parents=True, exist_ok=True)
DEST.mkdir(parents=True, exist_ok=True)
raw = SOURCE.read_bytes()
ui = json.loads(raw)
(DEST / "workflow_source.json").write_bytes(raw)
nodes = {str(n["id"]): n for n in ui["nodes"]}
links = {row[0]: row for row in ui["links"]}
slot_path = WORK / 'slots.json'
if not slot_path.exists():
    slot_path = DEST / 'workflow_slots.json'
slots = json.loads(slot_path.read_text(encoding="utf-8"))
(DEST / 'workflow_slots.json').write_text(json.dumps(slots, ensure_ascii=False, indent=2), encoding='utf-8')
values = {row["address"]: row["value"] for row in slots}


def origin(link_id):
    link = links[link_id]
    node = nodes[str(link[1])]
    # UI bypass and the explicitly removed DecimateMesh are identity edges.
    if node.get("mode", 0) == 4 or node["type"] == "DecimateMesh":
        kind = node["outputs"][link[2]]["type"]
        matches = [i for i in node["inputs"] if i.get("link") is not None and i["type"] == kind]
        assert len(matches) == 1, (node["id"], matches)
        return origin(matches[0]["link"])
    return [str(link[1]), link[2]]


api = {}
for node_id, node in nodes.items():
    if node.get("mode", 0) != 0 or node["type"] in {"Note", "MarkdownNote", "DecimateMesh"}:
        continue
    inputs = {row["address"].split(".", 1)[1]: row["value"] for row in slots if row["address"].startswith(node_id + ".")}
    for port in node.get("inputs", []):
        if port.get("link") is not None:
            inputs[port["name"]] = origin(port["link"])
    api[node_id] = {"class_type": node["type"], "inputs": inputs}
api["94"]["inputs"]["target_resolution"] = 1536
api["241"]["inputs"]["smooth_iters"] = 0
api["241"]["inputs"]["drop_small_components"] = 0.0


def ancestors(graph, roots):
    result = {}
    def visit(key):
        if key in result:
            return
        result[key] = graph[key]
        for value in graph[key]["inputs"].values():
            if isinstance(value, list) and len(value) == 2 and isinstance(value[0], str) and value[0] in graph:
                visit(value[0])
    for key in roots:
        visit(key)
    return result


manifest = {"source": str(SOURCE), "source_sha256": hashlib.sha256(raw).hexdigest(),
            "quality_policy": "No DecimateMesh, no final triangle budget; preserve source and textured output.",
            "shape_resolution": 1536, "texture_resolution": 4096, "remesh_resolution": 768,
            "remesh_smooth_iters": 0, "drop_small_components": 0, "characters": {}}
directions = [("front", "正面", "正", "364", "340"), ("left", "左側", "左", "377", "344"),
              ("back", "背面", "背", "378", "343"), ("right", "右側", "右", "379", "346")]
for actor in ("blacksmith", "aerin"):
    graph = copy.deepcopy(api)
    refs = DEST / "references"
    refs.mkdir(exist_ok=True)
    records = []
    for direction, blacksmith_name, aerin_name, node_id, save_id in directions:
        source = ROOT / (f"npc/鐵匠-{blacksmith_name}.Png" if actor == "blacksmith" else f"艾琳角色圖/{aerin_name}.png")
        target = refs / f"{actor}_{direction}.png"
        shutil.copy2(source, target)
        graph[node_id]["inputs"]["image"] = target.name
        graph[save_id]["inputs"]["filename_prefix"] = f"project_crystal_quality/{actor}/{direction}"
        records.append({"direction": direction, "source": str(source.relative_to(ROOT)), "copy": str(target.relative_to(ROOT)), "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
    graph["372"]["inputs"]["filename_prefix"] = f"project_crystal_quality/{actor}/{actor}_textured_full"
    graph["10001"] = {"class_type": "MeshToFile3D", "inputs": {"mesh": ["202", 0]}}
    graph["10002"] = {"class_type": "Save3DAdvanced", "inputs": {"model_3d": ["10001", 0], "filename_prefix": f"project_crystal_quality/{actor}/{actor}_shape_full", "viewport_state": "", "width": 1024, "height": 1024}}
    full = ancestors(graph, ["372", "10002"])
    assert not any(n["class_type"] == "DecimateMesh" for n in full.values())
    # Save all four actual conditioning images for inspection before 3D inference.
    preview = ancestors(graph, [row[4] for row in directions])
    (WORK / f"{actor}_full.api.json").write_text(json.dumps(full, ensure_ascii=False, indent=2), encoding="utf-8")
    (WORK / f"{actor}_inputs.api.json").write_text(json.dumps(preview, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest["characters"][actor] = {"references": records, "full_nodes": len(full), "input_nodes": len(preview)}
# Preserve completed-job evidence when rebuilding workflow copies later.
manifest_path = DEST / 'generation_manifest.json'
if manifest_path.exists():
    previous = json.loads(manifest_path.read_text(encoding='utf-8-sig'))
    for actor, record in manifest['characters'].items():
        for key, value in previous.get('characters', {}).get(actor, {}).items():
            if key not in record:
                record[key] = value
manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps({"prepared": list(manifest["characters"]), "source_sha256": manifest["source_sha256"]}))
