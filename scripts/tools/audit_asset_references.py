"""Structural reference-image gate. Direction/anatomy/completeness need human review."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops


def audit_references(folder):
    folder = Path(folder)
    rows, failures, images = [], [], {}
    for view in ['front','left','back','right']:
        path = folder / (view+'.png')
        if not path.is_file():
            failures.append('MISSING_' + view.upper())
            continue
        with Image.open(path) as image:
            if image.format != 'PNG' or image.mode != 'RGBA':
                failures.append('NOT_PNG_RGBA_' + view.upper())
            image = image.convert('RGBA')
            bounds = image.getchannel('A').getbbox()
            alpha = image.getchannel('A').getextrema()
            if alpha[0] != 0 or alpha[1] == 0:
                failures.append('NO_REAL_TRANSPARENT_BACKGROUND_OR_EMPTY_' + view.upper())
            if bounds and (bounds[0] == 0 or bounds[1] == 0 or bounds[2] == image.width or bounds[3] == image.height):
                failures.append('SILHOUETTE_TOUCHES_BORDER_' + view.upper())
            rows.append({'view':view,'file':str(path),'width':image.width,'height':image.height,
                         'alpha_range':alpha,'visible_bounds':bounds,
                         'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
            images[view] = image.copy()
    if len({(r['width'],r['height']) for r in rows}) > 1:
        failures.append('INCONSISTENT_CANVAS_SIZE')
    if len(set(r['sha256'] for r in rows)) != len(rows):
        failures.append('DUPLICATE_IMAGE')
    if 'left' in images and 'right' in images and images['left'].size == images['right'].size:
        mirrored = images['left'].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if not ImageChops.difference(mirrored,images['right']).getbbox(alpha_only=False):
            failures.append('MIRRORED_SIDE_IMAGES')
    return {'files':rows,'structural_gate':'FAIL' if failures else 'PASS',
            'status':'FAIL' if failures else 'HUMAN_REVIEW','failures':failures,
            'requires_review':['orthographic direction','complete limbs/hair/wings',
                               'matching scale/anatomy/equipment','text or drawn annotations'],
            'ready_for_generation':False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    result = audit_references(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    print(result['status'])
    raise SystemExit(1 if result['failures'] else 0)
