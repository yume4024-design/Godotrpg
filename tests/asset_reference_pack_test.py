"""A02 packaging regressions; does not grant visual/human signoff."""
from pathlib import Path
import json
import sys
import tempfile
import unittest
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/tools'))
from normalize_asset_references import normalize
from audit_asset_references import audit_references


class ReferencePackTest(unittest.TestCase):
    def test_actual_thirteen_reference_sets(self):
        reports=json.loads((ROOT/'source_assets/reference_library_20261020/structural_audit.json').read_text(encoding='utf8'))
        self.assertEqual(len(reports),13)
        for name,previous in reports.items():
            with self.subTest(asset=name):
                folder=ROOT/Path(previous['files'][0]['file']).parent
                current=audit_references(folder)
                self.assertEqual(current['structural_gate'],'PASS',current['failures'])
                self.assertEqual([r['sha256'] for r in previous['files']],[r['sha256'] for r in current['files']])
                for row in current['files']:
                    self.assertEqual((row['width'],row['height']),(1024,1024))
                    self.assertEqual(row['alpha_range'][0],0)
                    self.assertLess(row['visible_bounds'][3],1024)
                # Automatic structural validation must still not self-approve the design.
                self.assertEqual(current['status'],'HUMAN_REVIEW')
                self.assertFalse(current['ready_for_generation'])

    def test_sheet_split_preserves_sides_and_source(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'artifacts') as directory:
            folder=Path(directory);source=folder/'sheet.png'
            image=Image.new('RGBA',(1600,600))
            draw=ImageDraw.Draw(image)
            for i in range(4):draw.rectangle((i*400+50,50,i*400+250,550),fill=(50+i*50,150,80,255))
            image.save(source);original=source.read_bytes()
            result=normalize(source,folder/'views',sheet=True)
            self.assertEqual(source.read_bytes(),original)
            self.assertEqual([r['view'] for r in result],['front','left','back','right'])
            self.assertEqual(audit_references(folder/'views')['structural_gate'],'PASS')
            with self.assertRaises(FileExistsError):normalize(source,folder/'views',sheet=True)

    def test_incomplete_sheet_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT/'artifacts') as directory:
            folder=Path(directory);source=folder/'blank.png';Image.new('RGBA',(64,64)).save(source)
            with self.assertRaises(ValueError):normalize(source,folder/'views',sheet=True)


if __name__=='__main__':unittest.main(verbosity=2)
