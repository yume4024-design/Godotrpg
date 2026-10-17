"""Read-only GLB inventory for the Windows character acceptance gate."""
import json
import math
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[2]
rows = []
for relative in ("assets/models/hero/ren_user.glb", "assets/models/female/lia_rigged.glb", "assets/models/female/willow_staff.glb"):
    path = ROOT / relative
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", raw)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    chunk_length, chunk_type = struct.unpack_from("<II", raw, 12)
    assert chunk_type == 0x4E4F534A
    doc = json.loads(raw[20:20+chunk_length])
    binary_offset = 20 + chunk_length
    binary_length, binary_type = struct.unpack_from("<II", raw, binary_offset)
    assert binary_type == 0x004E4942
    binary = raw[binary_offset+8:binary_offset+8+binary_length]

    def values(accessor_index):
        accessor = doc["accessors"][accessor_index]
        assert "sparse" not in accessor, "Sparse accessor requires a separate audit"
        view = doc["bufferViews"][accessor["bufferView"]]
        formats = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
        components = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[accessor["type"]]
        fmt = "<" + formats[accessor["componentType"]] * components
        stride = view.get("byteStride", struct.calcsize(fmt))
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        for index in range(accessor["count"]):
            row_values = struct.unpack_from(fmt, binary, start + index * stride)
            if accessor.get("normalized"):
                denominator = {5121: 255, 5123: 65535}[accessor["componentType"]]
                row_values = tuple(value / denominator for value in row_values)
            yield row_values

    triangles = 0
    primitives = []
    max_weight_error = 0.0
    skin_by_mesh = {node["mesh"]: doc["skins"][node["skin"]] for node in doc.get("nodes", []) if "skin" in node}
    for mesh_index, mesh in enumerate(doc.get("meshes", [])):
        for primitive in mesh["primitives"]:
            assert primitive.get("mode", 4) == 4, "Non-triangle primitive"
            count = doc["accessors"][primitive["indices"]]["count"] if "indices" in primitive else doc["accessors"][primitive["attributes"]["POSITION"]]["count"]
            assert count % 3 == 0
            triangles += count // 3
            attributes = primitive["attributes"]
            # Eyes, bracers and equipment may use a constant material colour.
            material = doc["materials"][primitive["material"]]
            color = material.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
            assert len(color) == 4 and all(math.isfinite(component) for component in color)
            for point in values(attributes["POSITION"]):
                assert all(math.isfinite(component) for component in point)
            if mesh_index in skin_by_mesh:
                assert "JOINTS_0" in attributes and "WEIGHTS_0" in attributes
                for joints, weights in zip(values(attributes["JOINTS_0"]), values(attributes["WEIGHTS_0"])):
                    assert all(0 <= joint < len(skin_by_mesh[mesh_index]["joints"]) for joint in joints)
                    assert all(math.isfinite(weight) and weight >= 0 for weight in weights)
                    max_weight_error = max(max_weight_error, abs(sum(weights) - 1))
            primitives.append({"mesh": mesh.get("name"), "triangles": count // 3, "attributes": sorted(primitive["attributes"])})
    assert triangles < 5000, (path, triangles)
    assert max_weight_error < .002, max_weight_error
    row = {"path": path.relative_to(ROOT).as_posix(), "triangles": triangles, "skins": [len(s["joints"]) for s in doc.get("skins", [])], "animations": [a.get("name") for a in doc.get("animations", [])], "materials": len(doc.get("materials", [])), "max_weight_sum_error": max_weight_error, "primitives": primitives}
    rows.append(row)
    print(json.dumps({k: v for k, v in row.items() if k != "primitives"}, ensure_ascii=False))
assert rows[1]["triangles"] + rows[2]["triangles"] < 5000
output = ROOT / "artifacts/character_cp23/glb_audit.json"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(rows, indent=2, ensure_ascii=False), encoding="utf-8")
print("GLB_AUDIT_PASS: individual and equipped Lia budgets < 5000")
