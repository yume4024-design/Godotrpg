"""Parameterize a Pixal3D UI workflow copy. Never queues a generation job."""
import argparse
import hashlib
import json
from pathlib import Path

from asset_triangle_budget import resolve_budget


def prepare(source, output, category, maximum=None, headroom=.08):
    source, output = Path(source), Path(output)
    if source.resolve() == output.resolve() or output.exists():
        raise ValueError('Output must be a new file, separate from source')
    if not .05 <= headroom <= .10:
        raise ValueError('Headroom must be 5%-10%')
    maximum = resolve_budget(category, maximum)
    target = int(maximum * (1-headroom))
    raw = source.read_bytes()
    doc = json.loads(raw)
    changes = []
    found = 0
    for node in doc['nodes']:
        if node['type'] not in ['DecimateMesh','Trellis2UpsampleStage']:
            continue
        fields = [i for i in node.get('inputs', []) if 'widget' in i]
        values = node.get('widgets_values', [])
        if len(fields) != len(values):
            raise ValueError('Changed widget layout; inspect workflow before editing')
        for index, field in enumerate(fields):
            key = field['name']
            if key not in ['target_face_count','target_resolution']:
                continue
            if field.get('link') is not None:
                raise ValueError('Target linked to graph; widget cannot safely override it')
            original = values[index]
            value = target if key == 'target_face_count' else int(original)
            if value < 1:
                raise ValueError('Invalid resolution/triangle target')
            values[index] = value
            changes.append({'node':node['id'], 'field':key, 'before':original, 'after':value})
            found += key == 'target_face_count'
    if found != 1:
        raise ValueError('Expected one DecimateMesh target; inspect current workflow')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding='utf8')
    report = {'schema_version':1, 'source_sha256':hashlib.sha256(raw).hexdigest(),
              'category':category, 'maximum_triangles':maximum, 'candidate_target':target,
              'workflow_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),
              'changes':changes, 'generation_submitted':False,
              'unverified':['crop conversion','conditioning images','GPU generation','final triangles']}
    output.with_suffix('.manifest.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--category', required=True)
    parser.add_argument('--budget', type=int)
    args = parser.parse_args()
    print(json.dumps(prepare(args.source,args.output,args.category,args.budget),indent=2))
