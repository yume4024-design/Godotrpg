"""Strict, read-only GLB preflight. Counts active node occurrences, not mesh definitions.

This complements (does not replace) evaluated Blender meshes and visual/motion QA.
Unsupported sparse/external/instancing extensions fail explicitly.
"""
import hashlib
import json
import math
from pathlib import Path
import struct

from asset_triangle_budget import budget_result, resolve_budget


class InvalidAsset(ValueError):
    pass


def read_glb(path):
    raw = Path(path).read_bytes()
    if len(raw) < 20:
        raise InvalidAsset("Truncated GLB")
    magic, version, length = struct.unpack_from("<III", raw)
    if magic != 0x46546C67 or version != 2 or length != len(raw):
        raise InvalidAsset("Invalid GLB header or length")
    offset, chunks = 12, []
    while offset < len(raw):
        if offset + 8 > len(raw):
            raise InvalidAsset("Truncated chunk header")
        size, kind = struct.unpack_from("<II", raw, offset)
        offset += 8
        if size % 4 or offset + size > len(raw):
            raise InvalidAsset("Invalid chunk length")
        chunks.append((kind, raw[offset:offset + size]))
        offset += size
    if not chunks or chunks[0][0] != 0x4E4F534A:
        raise InvalidAsset("Missing JSON chunk")
    doc = json.loads(chunks[0][1])
    binary = next((data for kind, data in chunks if kind == 0x004E4942), b"")
    if len(doc.get("buffers", [])) > 1 or any("uri" in b for b in doc.get("buffers", [])):
        raise InvalidAsset("External/multiple buffers need separate validation")
    if doc.get("buffers") and doc["buffers"][0]["byteLength"] > len(binary):
        raise InvalidAsset("Buffer exceeds BIN chunk")
    return doc, binary


def accessor_values(doc, binary, index):
    accessor = doc["accessors"][index]
    if "sparse" in accessor or "bufferView" not in accessor:
        raise InvalidAsset("Sparse or bufferless accessor unsupported")
    view = doc["bufferViews"][accessor["bufferView"]]
    if view.get("buffer", 0) != 0:
        raise InvalidAsset("External buffer view")
    formats = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}
    widths = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
    fmt = "<" + formats[accessor["componentType"]] * widths[accessor["type"]]
    size = struct.calcsize(fmt)
    stride = view.get("byteStride", size)
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    count = accessor["count"]
    end = start + (count - 1) * stride + size if count else start
    if count < 0 or stride < size or start < view.get("byteOffset", 0) or end > min(
            len(binary), view.get("byteOffset", 0) + view["byteLength"]):
        raise InvalidAsset("Accessor exceeds bufferView")
    for number in range(count):
        row = struct.unpack_from(fmt, binary, start + number * stride)
        if accessor.get("normalized"):
            divisor = {5120: 127, 5121: 255, 5122: 32767, 5123: 65535}[accessor["componentType"]]
            row = tuple(max(-1, v / divisor) for v in row)
        yield row


def active_nodes(doc):
    nodes = doc.get("nodes", [])
    scenes = doc.get("scenes", [])
    if not scenes:
        raise InvalidAsset("No active scene")
    result, seen = [], set()

    def visit(index):
        if index < 0 or index >= len(nodes) or index in seen:
            raise InvalidAsset("Cyclic or repeated node reference")
        seen.add(index)
        result.append(index)
        for child in nodes[index].get("children", []):
            visit(child)

    for root in scenes[doc.get("scene", 0)].get("nodes", []):
        visit(root)
    return result


def audit_glb(path, category=None, maximum=None, require_uv=True, require_rig=True):
    path = Path(path)
    maximum = resolve_budget(category, maximum)
    failures, warnings, primitives = [], [], []
    triangles, max_weight_error = 0, 0.0
    doc = {}
    try:
        doc, binary = read_glb(path)
        occurrences = {}
        active = active_nodes(doc)
        for index in active:
            node = doc["nodes"][index]
            if "EXT_mesh_gpu_instancing" in node.get("extensions", {}):
                failures.append("UNACCOUNTED_INSTANCES")
            transform = [*node.get("matrix", []), *node.get("translation", []),
                         *node.get("rotation", []), *node.get("scale", [])]
            if not all(math.isfinite(v) for v in transform):
                failures.append("NONFINITE_TRANSFORM")
            if "mesh" not in node:
                continue
            mesh_index = node["mesh"]
            occurrences[mesh_index] = occurrences.get(mesh_index, 0) + 1
            mesh = doc["meshes"][mesh_index]
            if not mesh.get("primitives"):
                failures.append("EMPTY_MESH")
            skin = None
            if "skin" in node:
                skin = doc["skins"][node["skin"]]
                if not skin.get("joints") or any(j not in active for j in skin["joints"]):
                    failures.append("INVALID_SKIN_JOINTS")
                if "inverseBindMatrices" in skin:
                    matrices = list(accessor_values(doc, binary, skin["inverseBindMatrices"]))
                    if len(matrices) != len(skin["joints"]) or not all(
                            math.isfinite(v) for row in matrices for v in row):
                        failures.append("INVALID_BIND_MATRICES")
            elif require_rig:
                failures.append("MISSING_RIG")
            for primitive in mesh.get("primitives", []):
                attributes = primitive["attributes"]
                positions = list(accessor_values(doc, binary, attributes["POSITION"]))
                if not positions:
                    failures.append("EMPTY_MESH")
                if not all(len(p) == 3 and all(math.isfinite(v) for v in p) for p in positions):
                    failures.append("NONFINITE_OR_INVALID_POSITION")
                mode = primitive.get("mode", 4)
                if mode != 4:
                    raise InvalidAsset("Non-triangle primitive unsupported")
                if "indices" in primitive:
                    indices = [row[0] for row in accessor_values(doc, binary, primitive["indices"])]
                    if any(type(v) is not int or not 0 <= v < len(positions) for v in indices):
                        failures.append("INVALID_INDEX")
                else:
                    indices = list(range(len(positions)))
                if len(indices) % 3:
                    failures.append("INVALID_TRIANGLE_COUNT")
                triangles += len(indices) // 3
                if "TEXCOORD_0" in attributes:
                    uv = list(accessor_values(doc, binary, attributes["TEXCOORD_0"]))
                    if len(uv) != len(positions) or not all(
                            len(row) == 2 and all(math.isfinite(v) for v in row) for row in uv):
                        failures.append("INVALID_UV")
                elif require_uv:
                    failures.append("MISSING_UV")
                if skin:
                    if not {"JOINTS_0", "WEIGHTS_0"} <= attributes.keys():
                        failures.append("MISSING_SKIN_WEIGHTS")
                    else:
                        joints = list(accessor_values(doc, binary, attributes["JOINTS_0"]))
                        weights = list(accessor_values(doc, binary, attributes["WEIGHTS_0"]))
                        if len(joints) != len(positions) or len(weights) != len(positions):
                            failures.append("INVALID_SKIN_LENGTH")
                        for js, ws in zip(joints, weights):
                            if not all(type(j) is int and 0 <= j < len(skin["joints"]) for j in js):
                                failures.append("INVALID_SKIN_INDEX")
                            if len(ws) != 4 or not all(math.isfinite(w) and w >= 0 for w in ws):
                                failures.append("INVALID_SKIN_WEIGHT")
                            else:
                                max_weight_error = max(max_weight_error, abs(sum(ws) - 1))
                primitives.append({"node": index, "mesh": mesh_index,
                                   "triangles": len(indices) // 3, "attributes": sorted(attributes)})
        if any(count > 1 for count in occurrences.values()):
            failures.append("DUPLICATE_MESH_INSTANCE")
        if max_weight_error >= .002:
            failures.append("INVALID_WEIGHT_SUM")
        if not primitives or triangles == 0:
            failures.append("EMPTY_MESH")
    except (InvalidAsset, OSError, ValueError, KeyError, IndexError, TypeError, struct.error) as error:
        failures.append("INVALID_GLB: " + str(error))
    budget = budget_result(triangles, maximum)
    if triangles > maximum:
        failures.append("TRIANGLE_BUDGET_EXCEEDED")
    if triangles > maximum * .95 and triangles <= maximum:
        warnings.append("Less than 5% correction headroom; cap is still inclusive")
    return {"schema_version": 1, "file": str(path), "category": category,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None,
            **budget, "status": "FAIL" if failures else "PASS",
            "measurement": "GLB active scene triangle primitives; Blender evaluated QA separate",
            "requirements": {"uv": require_uv, "rig": require_rig},
            "max_weight_sum_error": max_weight_error, "primitives": primitives,
            "skins": [len(s.get("joints", [])) for s in doc.get("skins", [])],
            "materials": len(doc.get("materials", [])),
            "animations": [a.get("name") for a in doc.get("animations", [])],
            "failures": sorted(set(failures)), "warnings": warnings,
            "visual_gate": "HUMAN_REVIEW", "animation_gate": "NOT_STARTED"}
