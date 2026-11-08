"""Guard timing-only instrumentation, including composed geometry probes."""
import importlib.util
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("profile_build", ROOT / "tools/profile_prologue_release.py")
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)

class InstrumentationTests(unittest.TestCase):
    def test_composed_geometry_preserves_all_game_statements(self):
        relative = "scripts/world/blender_village_geometry.gd"
        original = (ROOT / relative).read_text(encoding="utf-8-sig")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / relative
            target.parent.mkdir(parents=True)
            target.write_text(original, encoding="utf-8")
            profile.instrument_collision_detail(root)
            profile.instrument_span(root, relative, "_ready", "village_geometry")
            profile.instrument_span(root, relative, "_solid_ground", "village_solid_ground")
            timed = target.read_text(encoding="utf-8")
            cleaned = "\n".join(line for line in timed.splitlines() if not re.match(
                r"\s*(var qa_\w+: int = Time.get_ticks_usec\(\)|PrologueProfileTrace.rows.append\()", line))
            self.assertEqual(cleaned.rstrip(), original.rstrip())
            for kind in ["village_bounds", "village_trimesh", "village_geometry", "village_solid_ground"]:
                self.assertEqual(timed.count('"kind":"' + kind + '"'), 1)
        self.assertEqual((ROOT / relative).read_text(encoding="utf-8-sig"), original)

    def test_unknown_geometry_layout_refuses_instrumentation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "scripts/world/blender_village_geometry.gd"
            target.parent.mkdir(parents=True)
            original = "func _ready() -> void:\n\tpass\n"
            target.write_text(original, encoding="utf-8")
            with self.assertRaises(AssertionError):
                profile.instrument_collision_detail(root)
            self.assertEqual(target.read_text(encoding="utf-8"), original)

if __name__ == "__main__":
    unittest.main()
