import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts/tools'))
from prepare_lia_boundary_review import gltf_to_blender, band

class MappingTests(unittest.TestCase):
    def test_axis_conversion(self):
        self.assertEqual(gltf_to_blender((1,2,3)),(1,-3,2))
    def test_boundaries_in_metres(self):
        self.assertEqual(band(.002),'within_2mm')
        self.assertEqual(band(.002001),'2mm_to_20mm')
        self.assertEqual(band(.02),'2mm_to_20mm')
        self.assertEqual(band(.020001),'over_20mm')

if __name__=='__main__':unittest.main()
