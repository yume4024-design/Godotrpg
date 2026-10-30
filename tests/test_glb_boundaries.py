import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"scripts/tools"))
from inspect_glb_boundaries import inventory, load_triangles, region_nearest_vertices
from asset_glb_validation import InvalidAsset
from unittest.mock import patch

class BoundaryInventoryTests(unittest.TestCase):
    def test_square_has_four_open_edges(self):
        a,b,c,d=(0,0,0),(1,0,0),(1,1,0),(0,1,0)
        data=inventory([(a,b,c),(a,c,d)])
        self.assertEqual((data["boundary_edges"],data["nonmanifold_edges"]),(4,0))
        self.assertEqual(data["components"][0]["degrees"],{"2":4})
        self.assertAlmostEqual(data["components"][0]["perimeter_m"],4.0)

    def test_closed_tetrahedron_and_collapsed_triangle(self):
        a,b,c,d=(0,0,0),(1,0,0),(0,1,0),(0,0,1)
        data=inventory([(a,b,c),(a,d,b),(b,d,c),(c,d,a),(a,a,b)])
        self.assertEqual(data["boundary_edges"],0)
        self.assertEqual(data["collapsed_triangles"],1)

    def test_overlapping_triangles_flag_junction(self):
        a,b,c=(0,0,0),(1,0,0),(0,1,0)
        data=inventory([(a,b,c)]*3)
        self.assertEqual(data["nonmanifold_edges"],3)

    def test_region_reports_vertex_not_surface_distance(self):
        triangle=((0,0,0),(1,0,0),(0,1,0))
        reference=((0,0,1),(1,0,1),(0,1,1))
        data=region_nearest_vertices({"surface":[triangle],"neck":[reference]},"neck",[-.1,1.1,-.1,1.1,-.1,.1])
        self.assertEqual(data["boundary_vertices"],3)
        self.assertAlmostEqual(data["nearest_vertex_distance_m"]["min"],1)
        self.assertEqual(data["exact_shared_vertices_all_meshes"],0)

    @patch("inspect_glb_boundaries.read_glb")
    def test_rejects_transformed_nodes(self,read):
        read.return_value=({"scenes":[{"nodes":[0]}],"nodes":[{"translation":[1,0,0],"mesh":0}]},b"")
        with self.assertRaises(InvalidAsset): load_triangles("unused.glb")

if __name__=="__main__": unittest.main()
