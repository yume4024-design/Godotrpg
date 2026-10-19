"""Blender evaluated-mesh gate; read-only unless --export. Uses project policy."""
import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import bmesh


def inspect_scene(maximum, require_uv=False, require_rig=False, require_closed=False):
    rows, failures, warnings, seen = [], [], [], set()
    # glTF importer creates custom bone display meshes in glTF_not_exported.
    # They are editor helpers, not model nodes; do not skip arbitrary hidden meshes.
    helper_objects = {bone.custom_shape for rig in bpy.context.scene.objects if rig.type == 'ARMATURE' and rig.pose is not None
                      for bone in rig.pose.bones if bone.custom_shape is not None}
    ignored_helpers = []
    graph = bpy.context.evaluated_depsgraph_get()
    for instance in graph.object_instances:
        if instance.is_instance:
            failures.append("UNACCOUNTED_INSTANCES")
    for obj in bpy.context.scene.objects:
        if obj.instance_type != 'NONE':
            failures.append("UNACCOUNTED_INSTANCES")
        if obj.type != 'MESH':
            continue
        if obj in helper_objects and any(c.name.startswith('glTF_not_exported') for c in obj.users_collection):
            ignored_helpers.append(obj.name)
            continue
        if obj.data.as_pointer() in seen:
            failures.append("DUPLICATE_MESH_INSTANCE")
        seen.add(obj.data.as_pointer())
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        bm = bmesh.new()
        try:
            mesh.calc_loop_triangles()
            bm.from_mesh(mesh)
            nonmanifold = sum(not edge.is_manifold for edge in bm.edges)
            degenerate = sum(face.calc_area() < 1e-12 for face in bm.faces)
            rows.append({"name": obj.name, "triangles": len(mesh.loop_triangles),
                         "vertices": len(mesh.vertices), "uv_layers": len(mesh.uv_layers),
                         "nonmanifold_edges": nonmanifold, "degenerate_faces": degenerate})
            if not mesh.vertices or not mesh.loop_triangles:
                failures.append("EMPTY_MESH")
            if not all(math.isfinite(c) for vertex in mesh.vertices for c in obj.matrix_world @ vertex.co):
                failures.append("NONFINITE_POSITION")
            if degenerate:
                failures.append("DEGENERATE_FACE")
            if nonmanifold:
                (failures if require_closed else warnings).append("NONMANIFOLD_OR_BOUNDARY")
            if require_uv and not mesh.uv_layers:
                failures.append("MISSING_UV")
            if require_uv and mesh.uv_layers and not all(
                    math.isfinite(c) for item in mesh.uv_layers.active.data for c in item.uv):
                failures.append("INVALID_UV")
            if require_rig and not any(m.type == 'ARMATURE' and m.object is not None for m in obj.modifiers):
                failures.append("MISSING_BOUND_ARMATURE")
        finally:
            bm.free()
            evaluated.to_mesh_clear()
    total = sum(row['triangles'] for row in rows)
    if not rows or total == 0:
        failures.append("EMPTY_MESH")
    if total > maximum:
        failures.append("TRIANGLE_BUDGET_EXCEEDED")
    if maximum * .95 < total <= maximum:
        warnings.append("Less than 5% correction headroom")
    return {"total_triangles": total, "objects": rows,
            "ignored_importer_bone_helpers": ignored_helpers,
            "failures": sorted(set(failures)), "warnings": sorted(set(warnings))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--project-root', type=Path, default=Path.cwd())
    parser.add_argument('--category')
    parser.add_argument('--budget', type=int)
    parser.add_argument('--export', action='store_true')
    parser.add_argument('--require-uv', action='store_true')
    parser.add_argument('--require-rig', action='store_true')
    parser.add_argument('--require-closed', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    sys.path.insert(0, str(args.project_root / 'scripts/tools'))
    from asset_triangle_budget import resolve_budget
    from asset_glb_validation import audit_glb
    maximum = resolve_budget(args.category, args.budget)
    args.output.mkdir(parents=True, exist_ok=False)
    preflight = audit_glb(args.input, args.category, maximum, args.require_uv, args.require_rig)
    report = {"source": str(args.input.resolve()), "blender_version": bpy.app.version_string,
              "triangle_budget": maximum, "category": args.category, "preflight": preflight,
              "exported": False, "unverified": ['silhouette', 'overlapping faces', 'rig deformation',
                                                'animation transitions', 'engine functional QA']}
    if preflight['status'] == 'PASS':
        bpy.ops.wm.read_factory_settings(use_empty=True)
        try:
            bpy.ops.import_scene.gltf(filepath=str(args.input.resolve()))
            report.update(inspect_scene(maximum, args.require_uv, args.require_rig, args.require_closed))
        except Exception as error:
            report['failures'] = ['BLENDER_IMPORT_FAILED: ' + str(error)]
    else:
        report['failures'] = preflight['failures']
        report['total_triangles'] = preflight['triangles']
        report['measurement'] = 'Rejected before Blender can sanitize invalid source data'
    report['basic_checks_passed'] = not report['failures']
    if args.export and report['basic_checks_passed']:
        bpy.ops.wm.save_as_mainfile(filepath=str(args.output / 'character.blend'))
        bpy.ops.export_scene.gltf(filepath=str(args.output / 'character.glb'), export_format='GLB')
        report['exported'] = True
    (args.output / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print('ASSET_GATE', 'PASS' if report['basic_checks_passed'] else 'FAIL', report.get('total_triangles'))
    if not report['basic_checks_passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
