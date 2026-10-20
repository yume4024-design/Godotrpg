"""Resolve actual PowerShell command routes without launching Godot."""
from pathlib import Path
import json
import shutil
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = shutil.which("pwsh") or shutil.which("powershell")


def describe(mode):
    result = subprocess.run([SHELL,"-NoProfile","-File",str(ROOT/"tools/godot.ps1"),"-Mode",mode,"-Describe"],cwd=ROOT,capture_output=True,text=True,encoding="utf-8",timeout=15)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    return json.loads(result.stdout[result.stdout.index("{"):])


class GodotCommandRoutes(unittest.TestCase):
    def test_headless_tests_do_not_export(self):
        for mode,script in [("TestEnemyController","rigged_enemy_controller_test.gd"),("TestBattleNameplates","battle_nameplate_test.gd"),("TestPhase3","phase3_battle_test.gd")]:
            with self.subTest(mode=mode):
                args=describe(mode)["arguments"]
                self.assertIn("--headless",args)
                self.assertNotIn("--export-release",args)
                self.assertIn("res://tests/"+script,args)

    def test_visual_routes_remain_native(self):
        for mode in ["VisualEnemyController","VisualBattleNameplates","ProfileEnemyAssets"]:
            with self.subTest(mode=mode):
                args=describe(mode)["arguments"]
                self.assertNotIn("--headless",args)
                self.assertNotIn("--export-release",args)
                self.assertIn("--script",args)

    def test_export_routes_are_separate(self):
        for mode,preset in [("ExportG083QA","Windows G083 Soak QA"),("ExportEnemyAssetQA","Windows A04 Enemy QA")]:
            with self.subTest(mode=mode):
                args=describe(mode)["arguments"]
                self.assertIn("--headless",args)
                self.assertEqual(args[args.index("--export-release")+1],preset)
                self.assertNotIn("--script",args)


if __name__=="__main__":
    unittest.main()
