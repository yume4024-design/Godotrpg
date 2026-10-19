"""Audit one classified GLB, or the existing Windows character bundle (read-only)."""
import argparse
import json
from pathlib import Path
from asset_glb_validation import audit_glb
from asset_triangle_budget import ROOT, resolve_budget


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--pixal', action='store_true')
    parser.add_argument('--input', type=Path)
    parser.add_argument('--category')
    parser.add_argument('--budget', type=int)
    parser.add_argument('--equipment', type=Path, action='append', default=[])
    parser.add_argument('--equipment-budget', type=int)
    parser.add_argument('--allow-missing-uv', action='store_true')
    parser.add_argument('--allow-static', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.input and args.pixal:
        parser.error('Choose --input or --pixal')
    if args.input:
        try:
            maximum = resolve_budget(args.category, args.budget)
        except ValueError as error:
            parser.error(str(error))
        body = audit_glb(args.input, args.category, maximum, not args.allow_missing_uv, not args.allow_static)
        if args.equipment and not args.equipment_budget:
            parser.error('Replaceable equipment requires --equipment-budget')
        equipment = [audit_glb(p, maximum=args.equipment_budget, require_rig=False,
                              require_uv=not args.allow_missing_uv) for p in args.equipment]
        report = {'body': body, 'equipment': equipment,
                  'combined_visible_triangles': body['triangles'] + sum(e['triangles'] for e in equipment),
                  'status': 'PASS' if all(r['status'] == 'PASS' for r in [body, *equipment]) else 'FAIL'}
        output = args.output or ROOT / 'artifacts/asset_validation/glb_audit.json'
    else:
        if args.category or args.equipment:
            parser.error('--category/--equipment require --input')
        maximum = resolve_budget('player_character', args.budget)
        folder = 'pixal3d' if args.pixal else None
        characters = [ROOT / f'assets/models/{folder}/ren_rigged.glb', ROOT / f'assets/models/{folder}/lia_rigged.glb'] if folder else [
            ROOT / 'assets/models/hero/ren_user.glb', ROOT / 'assets/models/female/lia_rigged.glb']
        # This compatibility bundle allows constant-colour surfaces with no UV.
        # The strict single-file gate above requires UV by default.
        rows = [audit_glb(p, 'player_character', maximum, require_uv=False) for p in characters]
        staff = audit_glb(ROOT / 'assets/models/female/willow_staff.glb', maximum=maximum,
                         require_uv=False, require_rig=False)
        report = {'characters': rows, 'equipment': [staff],
                  'combined_lia_and_staff_triangles': rows[1]['triangles'] + staff['triangles'],
                  'equipment_note': 'Separate staff; provisional explicit cap equals character cap',
                  'status': 'PASS' if all(r['status'] == 'PASS' for r in [*rows, staff]) else 'FAIL'}
        output = args.output or ROOT / ('artifacts/pixal3d/glb_audit.json' if args.pixal else 'artifacts/character_cp23/glb_audit.json')
    output.parent.mkdir(parents=True, exist_ok=True)
    if args.input:
        payload = report
    else:
        # Existing write_pixal3d_manifest.py consumes this list and relative path.
        # Preserve that contract; richer gate data lives in a separate sidecar.
        payload = []
        for row in [*rows, staff]:
            row['path'] = Path(row['file']).relative_to(ROOT).as_posix()
            row['max_weight_error'] = row['max_weight_sum_error']
            payload.append(row)
        output.with_suffix('.gate.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f"GLB_AUDIT_{report['status']}: {output}")
    return 0 if report['status'] == 'PASS' else 1


if __name__ == '__main__':
    raise SystemExit(main())
