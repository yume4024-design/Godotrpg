"""Record actual inputs, outputs and embedded texture limits, without generation."""
import hashlib
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
def fingerprint(relative):
    content = (ROOT/relative).read_bytes()
    return {"path":relative,"bytes":len(content),"sha256":hashlib.sha256(content).hexdigest()}
audit = json.loads((ROOT/"artifacts/pixal3d/glb_audit.json").read_text(encoding="utf-8"))
rows = []
for character,prompt_id in [("ren","4397b111-bf37-4ff4-8312-02494c7ba4f5"),("lia","5bed02b9-a91d-463d-9b5a-b13db2b591fa")]:
    relative = f"assets/models/pixal3d/{character}_rigged.glb"
    raw = (ROOT/relative).read_bytes()
    json_length = struct.unpack_from("<I",raw,12)[0]
    doc = json.loads(raw[20:20+json_length])
    binary = raw[28+json_length:]
    sizes = []
    for image in doc["images"]:
        view = doc["bufferViews"][image["bufferView"]]
        offset = view.get("byteOffset",0)
        png = binary[offset:offset+view["byteLength"]]
        assert png[:8]==b"\x89PNG\r\n\x1a\n"
        dimensions = struct.unpack_from(">II",png,16)
        assert max(dimensions)<=1024, dimensions
        sizes.append(dimensions)
    record = next(row for row in audit if row["path"]==relative)
    references = ["ren_turnaround.png"] if character=="ren" else ["lia_front.png","lia_left.png","lia_back.png","lia_right.png"]
    rows.append({"character":character,"prompt_id":prompt_id,"runtime":fingerprint(relative),"raw":fingerprint(f"assets/source/pixal3d/raw/{character}_generated.glb"),"workfile":fingerprint(f"assets/source/pixal3d/{character}_rigged.blend"),"references":[fingerprint("assets/source/pixal3d/references/"+name) for name in references],"triangles":record["triangles"],"skin_joint_counts":record["skins"],"animations":record["animations"],"texture_sizes":sizes})
manifest = {"workflow":"3d_pixal3d_multi_views","template":fingerprint("scripts/tools/workflows/pixal3d/3d_pixal3d_multi_views.api.json"),"comfyui":"0.41.3","comfy_cli":"1.22.0","model":"pixal3d_multiview_int8_convrot.safetensors","shape_resolution":1024,"texture_resolution":1024,"remesh_resolution":384,"target_faces":4800,"hardware":"RTX 3080 12GiB","cost":"local inference; no partner API","cancelled_invalid_crop_prompt":"eda8fda3-d667-4641-a65a-80513c6bb39f","characters":rows}
destination = ROOT/"assets/source/pixal3d/generation_manifest.json"
destination.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print("PIXAL_MANIFEST_PASS",[(row["character"],row["triangles"],row["texture_sizes"]) for row in rows])
