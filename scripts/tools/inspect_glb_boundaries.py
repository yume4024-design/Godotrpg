"""Read-only exact-position boundary diagnostics for an identity-transform static GLB.

UV splits are grouped only for edge counting. They are not welded and a boundary
is not automatically a defect: hems, collars, hair and layered clothing can be open.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
import math
import statistics
from pathlib import Path
from asset_glb_validation import read_glb, active_nodes, accessor_values, InvalidAsset


def inventory(triangles):
    edge_uses = Counter()
    degenerate = 0
    for a, b, c in triangles:
        if a == b or b == c or c == a:
            degenerate += 1
            continue
        for u, v in ((a, b), (b, c), (c, a)):
            edge_uses[tuple(sorted((u, v)))] += 1
    adjacency = defaultdict(set)
    for (u, v), count in edge_uses.items():
        if count == 1:
            adjacency[u].add(v)
            adjacency[v].add(u)
    unseen = set(adjacency)
    components = []
    while unseen:
        start = min(unseen)
        stack = [start]
        unseen.remove(start)
        vertices = []
        while stack:
            node = stack.pop()
            vertices.append(node)
            for neighbour in sorted(adjacency[node]):
                if neighbour in unseen:
                    unseen.remove(neighbour)
                    stack.append(neighbour)
        edges = [(u, v) for u in vertices for v in adjacency[u] if u < v]
        coords = [v for v in vertices]
        minimum = [min(p[i] for p in coords) for i in range(3)]
        maximum = [max(p[i] for p in coords) for i in range(3)]
        degrees = Counter(len(adjacency[v]) for v in vertices)
        components.append({"vertices":len(vertices),"edges":len(edges),
                           "bounds_min":minimum,"bounds_max":maximum,
                           "center":[(minimum[i]+maximum[i])/2 for i in range(3)],
                           "perimeter_m":sum(math.dist(u,v) for u,v in edges),
                           "degrees":{str(k):v for k,v in sorted(degrees.items())}})
    components.sort(key=lambda c:(-c["edges"],c["center"]))
    return {"collapsed_triangles":degenerate,"physical_edges":len(edge_uses),"boundary_edges":sum(c==1 for c in edge_uses.values()),
            "nonmanifold_edges":sum(c>2 for c in edge_uses.values()),"components":components}


def closest_triangle_distance(point, triangle):
    """Distance to a finite triangle, including edges and degenerate faces."""
    a,b,c = triangle
    ab = tuple(b[i]-a[i] for i in range(3))
    ac = tuple(c[i]-a[i] for i in range(3))
    ap = tuple(point[i]-a[i] for i in range(3))
    dot = lambda u,v: sum(u[i]*v[i] for i in range(3))
    aa, abac, cc = dot(ab,ab),dot(ab,ac),dot(ac,ac)
    denom = aa*cc-abac*abac
    if denom > 1e-24:
        u = (dot(ap,ab)*cc-dot(ap,ac)*abac)/denom
        v = (dot(ap,ac)*aa-dot(ap,ab)*abac)/denom
        if u >= 0 and v >= 0 and u+v <= 1:
            projected = tuple(a[i]+u*ab[i]+v*ac[i] for i in range(3))
            return math.dist(point,projected)
    def segment_distance(start,end):
        direction = tuple(end[i]-start[i] for i in range(3))
        length_squared = dot(direction,direction)
        t = max(0.0,min(1.0,dot(tuple(point[i]-start[i] for i in range(3)),direction)/length_squared)) if length_squared > 0 else 0.0
        return math.dist(point,tuple(start[i]+t*direction[i] for i in range(3)))
    return min(segment_distance(a,b),segment_distance(b,c),segment_distance(c,a))


def region_nearest_vertices(by_object, reference_name, region):
    if reference_name not in by_object:
        raise InvalidAsset("Reference node not found")
    x0,x1,y0,y1,z0,z1 = region
    if x0 > x1 or y0 > y1 or z0 > z1:
        raise InvalidAsset("Invalid region bounds")
    reference = {p for triangle in by_object[reference_name] for p in triangle}
    if not reference:
        raise InvalidAsset("Reference node has no vertices")
    edges = Counter()
    for name, triangles in by_object.items():
        if name == reference_name: continue
        for a,b,c in triangles:
            if a == b or b == c or c == a: continue
            for u,v in ((a,b),(b,c),(c,a)):
                edges[tuple(sorted((u,v)))] += 1
    points = {p for edge,count in edges.items() if count == 1 for p in edge
              if x0 <= p[0] <= x1 and y0 <= p[1] <= y1 and z0 <= p[2] <= z1}
    distances = sorted(min(math.dist(p,q) for q in reference) for p in points)
    surface_samples = sorted((min(closest_triangle_distance(point,triangle) for triangle in by_object[reference_name]), point) for point in points)
    surface_distances = [row[0] for row in surface_samples]
    if not distances: raise InvalidAsset("No boundary vertices in region")
    all_other_vertices = {p for name,triangles in by_object.items() if name != reference_name
                          for triangle in triangles for p in triangle}
    return {"reference_node":reference_name,"bounds":[x0,x1,y0,y1,z0,z1],
            "boundary_vertices":len(points),"reference_vertices":len(reference),
            "exact_shared_vertices_all_meshes":len(reference & all_other_vertices),
            "nearest_vertex_distance_m":{"min":distances[0],"median":statistics.median(distances),
              "p95":distances[math.ceil(.95*len(distances))-1],"max":distances[-1],
              "within_2mm":sum(d<=.002 for d in distances)},
            "nearest_surface_distance_m":{"min":surface_distances[0],"median":statistics.median(surface_distances),
              "p95":surface_distances[math.ceil(.95*len(surface_distances))-1],"max":surface_distances[-1],
              "within_2mm":sum(d<=.002 for d in surface_distances)},
            "surface_extremes":{"closest":[{"distance_m":d,"position":p} for d,p in surface_samples[:5]],
                                "farthest":[{"distance_m":d,"position":p} for d,p in surface_samples[-5:]]},
            "surface_samples":[{"distance_m":d,"position":p} for d,p in surface_samples],
            "limits":"Unsigned distances from selected boundary vertices to reference triangles; not whole-surface gap, intersection or visual verdict."}


def load_triangles(path):
    doc, binary = read_glb(path)
    nodes = doc.get("nodes", [])
    # Bounds from a local node are misleading under any scene-node transform.
    # Reject transformed inputs until transform handling is explicitly added.
    for index in active_nodes(doc):
        node = nodes[index]
        if any(key in node for key in ("matrix", "translation", "rotation", "scale")):
            raise InvalidAsset("Transformed nodes are unsupported by this diagnostic")
    by_object = defaultdict(list)
    for index in active_nodes(doc):
        node = nodes[index]
        if "mesh" not in node:
            continue
        name = node.get("name", "node_%d" % index)
        if name in by_object or "skin" in node:
            raise InvalidAsset("Duplicate mesh node name or skinned mesh unsupported")
        by_object[name] = []
        for primitive in doc["meshes"][node["mesh"]]["primitives"]:
            if primitive.get("targets"):
                raise InvalidAsset("Morph targets unsupported")
            if primitive.get("mode", 4) != 4:
                raise InvalidAsset("Non-triangle primitive unsupported")
            points = list(accessor_values(doc,binary,primitive["attributes"]["POSITION"]))
            indices = [int(x[0]) for x in accessor_values(doc,binary,primitive["indices"])] if "indices" in primitive else list(range(len(points)))
            if len(indices)%3 or any(x<0 or x>=len(points) for x in indices):
                raise InvalidAsset("Invalid triangle indices")
            if any(not all(math.isfinite(v) for v in point) for point in points):
                raise InvalidAsset("Nonfinite vertex")
            by_object[name].extend(tuple(points[i] for i in indices[j:j+3]) for j in range(0,len(indices),3))
    if not by_object:
        raise InvalidAsset("No mesh geometry")
    return by_object


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--region", type=float, nargs=6, metavar=("X0","X1","Y0","Y1","Z0","Z1"))
    parser.add_argument("--reference-node")
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Output already exists; preserve previous evidence")
    if bool(args.region) != bool(args.reference_node):
        parser.error("--region and --reference-node must be specified together")
    by_object = load_triangles(args.input)
    all_triangles = [triangle for group in by_object.values() for triangle in group]
    result = {"source":str(args.input),"source_sha256":hashlib.sha256(args.input.read_bytes()).hexdigest(),
              "axes":"glTF Y up; units as exported", "triangle_count":len(all_triangles),
              "objects":{name:{"triangles":len(group),**inventory(group)} for name,group in by_object.items()},
              "combined":inventory(all_triangles),
              "limits":["Exact coincident coordinates grouped only for counting, never welded",
                        "Exact coincident positions may belong to separate overlapping surfaces; junction counts are not a topology verdict",
                        "No geometric intersection, inside/outside classification, tolerance merge, animation, rig or visual quality test",
                        "Open boundaries can be intentional; diagnose before editing"]}
    if args.region:
        result["region_vertex_comparison"] = region_nearest_vertices(by_object,args.reference_node,args.region)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("GLB_BOUNDARY_INVENTORY triangles=%d components=%d boundary_edges=%d" % (len(all_triangles),len(result["combined"]["components"]),result["combined"]["boundary_edges"]))

if __name__ == "__main__":
    main()
