"""Real GLB fixtures exercise inclusive caps and malformed-source rejection."""
import argparse
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import unittest
from datetime import datetime
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/tools'))
from asset_glb_validation import audit_glb
from asset_triangle_budget import resolve_budget
from prepare_asset_workflow import prepare
from audit_asset_references import audit_references
from PIL import Image, ImageDraw

OUT = ROOT / 'artifacts/asset_a01'
FIXTURES = OUT / 'fixtures'


def fixture(path, triangles, variant='valid'):
    binary, views, accessors = bytearray(), [], []

    def pack(rows, width, kind, fmt):
        start = len(binary)
        for row in rows:
            binary.extend(struct.pack('<' + fmt * width, *row))
        views.append({'buffer': 0, 'byteOffset': start, 'byteLength': len(binary) - start})
        accessors.append({'bufferView': len(views) - 1, 'componentType': kind,
                          'count': len(rows), 'type': {1:'SCALAR', 2:'VEC2', 3:'VEC3', 4:'VEC4'}[width]})
        while len(binary) % 4:
            binary.append(0)
        return len(accessors) - 1

    points = []
    for i in range(triangles):
        x, y = (i % 150) * .02, (i // 150) * .02
        points.extend([(x, y, 0), (x+.01, y, 0), (x, y+.01, 0)])
    if variant in ['nan', 'inf']:
        points[0] = (float(variant), 0, 0)
    attributes = {'POSITION': pack(points, 3, 5126, 'f')}
    accessors[0]['min'], accessors[0]['max'] = [0,0,0], [3,3,0]
    if variant != 'missing_uv':
        attributes['TEXCOORD_0'] = pack([(0,0),(1,0),(0,1)] * triangles, 2, 5126, 'f')
    if variant != 'missing_rig':
        attributes['JOINTS_0'] = pack([(0,0,0,0)] * len(points), 4, 5121, 'B')
        attributes['WEIGHTS_0'] = pack([(1,0,0,0)] * len(points), 4, 5126, 'f')
    indices = list(range(len(points)))
    if variant == 'bad_index':
        indices[-1] = len(points) + 9
    primitive = {'attributes': attributes, 'indices': pack([(i,) for i in indices], 1, 5125, 'I')}
    nodes = [{'name':'Root', 'children':[1,2]}, {'name':'Body','mesh':0},
             {'name':'Joint','children':[3]}, {'name':'Tip','translation':[0,0,.2]}]
    doc = {'asset':{'version':'2.0'}, 'scene':0, 'scenes':[{'nodes':[0]}], 'nodes':nodes,
           'meshes':[{'primitives':[primitive]}], 'buffers':[{'byteLength':len(binary)}],
           'bufferViews':views, 'accessors':accessors}
    if variant != 'missing_rig':
        nodes[1]['skin'] = 0
        doc['skins'] = [{'joints':[2], 'skeleton':2}]
    if variant == 'duplicate':
        nodes.append(dict(nodes[1]))
        nodes[0]['children'].append(4)
    if variant == 'invalid_mesh':
        nodes[1]['mesh'] = 999
    if variant == 'empty':
        doc['meshes'][0]['primitives'] = []
    if variant == 'instancing':
        nodes[1]['extensions'] = {'EXT_mesh_gpu_instancing': {'attributes':{}}}
    text = json.dumps(doc).encode('utf-8')
    text += b' ' * (-len(text) % 4)
    chunks = struct.pack('<II', len(text), 0x4E4F534A) + text
    chunks += struct.pack('<II', len(binary), 0x004E4942) + binary
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack('<III', 0x46546C67, 2, len(chunks)+12) + chunks)
    return path


CASES = [(str(n), n, 'valid', category, n <= cap) for category, cap in [
    ('common_enemy',10000), ('boss',15000)] for n in [cap-1,cap,cap+1]]
CASES += [(v, 2, v, 'common_enemy', False) for v in [
    'missing_uv','missing_rig','empty','invalid_mesh','nan','inf','bad_index','duplicate','instancing']]


class AssetValidationTest(unittest.TestCase):
    def test_existing_character_bundle_contract(self):
        output = OUT/'bundle_compatibility.json'
        run = subprocess.run([sys.executable,str(ROOT/'scripts/tools/audit_character_glb.py'),
                              '--pixal','--output',str(output)],capture_output=True)
        self.assertEqual(run.returncode,0,run.stderr)
        rows = json.loads(output.read_text(encoding='utf8'))
        for character,expected in [('ren',4815),('lia',4806)]:
            relative = f'assets/models/pixal3d/{character}_rigged.glb'
            row = next(row for row in rows if row['path']==relative)
            self.assertEqual(row['triangles'],expected)
            self.assertEqual(row['status'],'PASS')
            self.assertIn('materials',row)
        gate = json.loads(output.with_suffix('.gate.json').read_text(encoding='utf8'))
        self.assertEqual(gate['combined_lia_and_staff_triangles'],4946)

    def test_workflow_budget_copy(self):
        with tempfile.TemporaryDirectory(dir=OUT) as directory:
            folder = Path(directory)
            source = folder/'source.json'
            source.write_text(json.dumps({'nodes':[
                {'id':1,'type':'DecimateMesh','inputs':[{'name':'target_face_count','widget':{'name':'target_face_count'}}], 'widgets_values':[30000]},
                {'id':2,'type':'Trellis2UpsampleStage','inputs':[{'name':'target_resolution','widget':{'name':'target_resolution'}}], 'widgets_values':['1536']}
            ]}),encoding='utf8')
            original = source.read_bytes()
            for category, maximum in [('common_enemy',10000), ('boss',15000)]:
                output = folder/(category+'.json')
                report = prepare(source,output,category)
                self.assertEqual(report['candidate_target'], int(maximum*.92))
                self.assertFalse(report['generation_submitted'])
                self.assertEqual(source.read_bytes(),original)
                with self.assertRaises(ValueError):
                    prepare(source,output,category)
            with self.assertRaises(ValueError):
                prepare(source,source,'boss')

    def test_reference_structure_and_human_gate(self):
        with tempfile.TemporaryDirectory(dir=OUT) as directory:
            folder = Path(directory)
            for index,view in enumerate(['front','left','back','right']):
                image = Image.new('RGBA',(64,64))
                ImageDraw.Draw(image).rectangle((12,10,40+index,54),fill=(index*60,170,100,255))
                image.save(folder/(view+'.png'))
            report = audit_references(folder)
            self.assertEqual(report['structural_gate'],'PASS')
            self.assertEqual(report['status'],'HUMAN_REVIEW')
            self.assertFalse(report['ready_for_generation'])
            Image.open(folder/'left.png').transpose(Image.Transpose.FLIP_LEFT_RIGHT).save(folder/'right.png')
            self.assertIn('MIRRORED_SIDE_IMAGES',audit_references(folder)['failures'])
            Image.new('RGBA',(64,64),(40,80,120,255)).save(folder/'front.png')
            self.assertIn('NO_REAL_TRANSPARENT_BACKGROUND_OR_EMPTY_FRONT',audit_references(folder)['failures'])
            (folder/'back.png').unlink()
            self.assertIn('MISSING_BACK',audit_references(folder)['failures'])

    def test_boundaries_and_invalid_glb(self):
        for name, count, variant, category, passed in CASES:
            with self.subTest(name=name):
                report = audit_glb(fixture(FIXTURES/(name+'.glb'), count, variant), category)
                self.assertEqual(report['status'], 'PASS' if passed else 'FAIL', report)
                if variant == 'valid':
                    self.assertEqual(report['triangles'], count)
                    self.assertEqual(report['triangle_gate'], 'PASS' if passed else 'FAIL')
                if variant == 'duplicate':
                    self.assertEqual(report['triangles'], count*2)
                    self.assertIn('DUPLICATE_MESH_INSTANCE', report['failures'])

    def test_explicit_budget_and_categories(self):
        for category in ['elite_enemy','boss','player_character','npc']:
            self.assertEqual(resolve_budget(category), 15000)
        self.assertEqual(resolve_budget('common_enemy'), 10000)
        self.assertEqual(resolve_budget(maximum=3456), 3456)
        for category, maximum in [(None,None), (None,0), (None,-1), ('unknown',100), ('common_enemy',15000)]:
            with self.subTest(category=category, maximum=maximum):
                with self.assertRaises(ValueError):
                    resolve_budget(category, maximum)

    def test_empty_buffer_mesh(self):
        report = audit_glb(fixture(FIXTURES/'zero.glb',0), 'common_enemy')
        self.assertEqual(report['status'], 'FAIL')
        self.assertIn('EMPTY_MESH', report['failures'])

    def test_truncated_glb(self):
        path = FIXTURES/'truncated.glb'
        path.write_bytes(b'glTF')
        self.assertEqual(audit_glb(path,'npc')['status'], 'FAIL')


def blender_cases(executable):
    reports = []
    run_folder = OUT / ('blender_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
    checker = ROOT / 'docs/skills/ai-3d-agent/scripts/check_export.py'
    for name, count, variant, category, expected in CASES:
        folder = run_folder / name
        command = [executable, '--background', '--factory-startup', '--python-exit-code', '1',
                   '--python', str(checker), '--', '--input', str(FIXTURES/(name+'.glb')),
                   '--output', str(folder), '--project-root', str(ROOT), '--category', category,
                   '--require-uv','--require-rig']
        run = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', errors='replace')
        (OUT/(name+'_blender.log')).write_text(run.stdout+run.stderr, encoding='utf8')
        report = json.loads((folder/'report.json').read_text(encoding='utf8'))
        actual = report['basic_checks_passed']
        success = actual == expected and (run.returncode == 0) == expected
        if expected:
            success = success and report['total_triangles'] == count
        reports.append({'case':name,'expected_asset_pass':expected,'actual_asset_pass':actual,
                        'exit_code':run.returncode,'test_passed':success,
                        'triangles':report['total_triangles'],'failures':report['failures']})
    (OUT/'blender_cases.json').write_text(json.dumps(reports,indent=2), encoding='utf8')
    return all(r['test_passed'] for r in reports)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--blender')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AssetValidationTest))
    good = result.wasSuccessful()
    if args.blender:
        good = blender_cases(args.blender) and good
    raise SystemExit(0 if good else 1)
