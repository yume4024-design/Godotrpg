"""Record A02 source evidence without granting automatic human approval."""
import hashlib
import json
from pathlib import Path
from audit_asset_references import audit_references

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'source_assets/reference_library_20261020'


def relative(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def build():
    structural, catalog = {}, {}
    for folder in sorted(BASE.glob('*/*/references')):
        name = folder.parent.name
        audit = audit_references(folder)
        for row in audit['files']:
            row['file'] = relative(row['file'])
        structural[name] = audit
        # Ren's fourth profile was semantically corrected; its final adoption
        # remains a separate pending user review, never inferred from Alpha.
        approval = ('pending_corrected_profile_review' if name == 'ren' else
                    'user_adopted_four_new_npc_designs' if name in
                    ['item_merchant', 'innkeeper', 'villager_male', 'villager_female'] else
                    'existing_user_design_and_remodel_authorization')
        catalog[name] = {
            'references': relative(folder),
            'structural_gate': audit['structural_gate'],
            'visual_review': 'agent_viewed_four_directions',
            'approval_basis': approval,
            'status': 'HUMAN_REVIEW' if name == 'ren' else
                      'PASS' if audit['structural_gate'] == 'PASS' else 'FAIL',
            'ready_for_generation': name != 'ren' and audit['structural_gate'] == 'PASS',
            'files': audit['files'],
        }
    if len(catalog) != 13:
        raise ValueError(f'Expected 13 complete sets, found {len(catalog)}')
    inventory = []
    for path in sorted(BASE.rglob('*')):
        if path.is_file() and path.suffix.lower() == '.png':
            inventory.append({'file': relative(path), 'bytes': path.stat().st_size,
                              'sha256': hashlib.sha256(path.read_bytes()).hexdigest()})
    for file, value in [('structural_audit.json', structural),
                        ('catalog.json', catalog), ('inventory.json', inventory)]:
        (BASE / file).write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf8')
    return catalog


if __name__ == '__main__':
    result = build()
    print(f'A02: {len(result)} sets / {sum(len(v["files"]) for v in result.values())} images; '
          f'{sum(v["ready_for_generation"] for v in result.values())} ready; Ren review pending')
