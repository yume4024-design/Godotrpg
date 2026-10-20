"""Record A02 source evidence without granting automatic human approval."""
import hashlib
import json
from pathlib import Path
from audit_asset_references import audit_references

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'source_assets/reference_library_20261020'


def relative(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def adoption_matches(approval, name, files):
    """A user approval applies to these exact four images, not later replacements."""
    expected = approval.get('assets', {}).get(name)
    actual = {row['view']: row['sha256'] for row in files}
    return (approval.get('source') == 'user_reply' and
            approval.get('decision') == 'adopt_all_thirteen_sets' and
            set(actual) == {'front', 'left', 'back', 'right'} and expected == actual)


def build():
    structural, catalog = {}, {}
    receipt = BASE / 'source_adoption_20261020.json'
    approval = json.loads(receipt.read_text(encoding='utf8')) if receipt.exists() else {}
    for folder in sorted(BASE.glob('*/*/references')):
        name = folder.parent.name
        audit = audit_references(folder)
        for row in audit['files']:
            row['file'] = relative(row['file'])
        structural[name] = audit
        adopted = adoption_matches(approval, name, audit['files'])
        catalog[name] = {
            'references': relative(folder),
            'structural_gate': audit['structural_gate'],
            'visual_review': 'agent_viewed_four_directions',
            'approval_basis': ('user_adopted_thirteen_sets_20261020' if adopted else
                               'missing_or_stale_source_adoption'),
            'approval_record': relative(receipt) if receipt.exists() else None,
            'status': ('FAIL' if audit['structural_gate'] != 'PASS' else
                       'PASS' if adopted else 'HUMAN_REVIEW'),
            'ready_for_generation': adopted and audit['structural_gate'] == 'PASS',
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
          f'{sum(v["ready_for_generation"] for v in result.values())} ready; '
          'structural checks and user adoption recorded separately')
