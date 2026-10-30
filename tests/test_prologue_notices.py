import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/"tools"))
import supplement_prologue_notices as subject

class NoticeDeliveryTests(unittest.TestCase):
    def test_original_archive_preserved_and_rerun_refused(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)/"rc5";candidate=root/"candidate";candidate.mkdir(parents=True)
            for name in ("ProjectCrystal.exe","ProjectCrystal.pck","start_prologue_candidate.cmd","README.txt"):
                (candidate/name).write_bytes((name+" fixture").encode())
            manifest={"version":"test-rc5","source_commit":"a"*40,
                "executable_sha256":subject.sha_stream(candidate/"ProjectCrystal.exe"),
                "pck_sha256":subject.sha_stream(candidate/"ProjectCrystal.pck")}
            (candidate/"manifest.json").write_text(json.dumps(manifest),encoding="utf-8")
            original=root/"original.zip"
            with zipfile.ZipFile(original,"w",zipfile.ZIP_DEFLATED) as archive:
                for name in subject.ORIGINALS: archive.write(candidate/name,name)
            original_hash=subject.sha_stream(original)
            (root/"delivery.json").write_text(json.dumps({"zip":str(original),"sha256":original_hash}),encoding="utf-8")
            def git_show(args):
                return b"GODOT ENGINE 4.7.2 test notice" if args[-1].endswith("GODOT_LICENSES.txt") else b"fixture asset credits"
            with patch.object(subject.subprocess,"check_output",side_effect=git_show),patch.object(sys,"argv",["tool","--root",str(root)]),contextlib.redirect_stdout(io.StringIO()):
                subject.main()
                with self.assertRaises(FileExistsError):subject.main()
            self.assertEqual(subject.sha_stream(original),original_hash)
            result=root/"ProjectCrystal-test-rc5-Windows-with-notices.zip"
            with zipfile.ZipFile(result) as archive:
                self.assertEqual(set(archive.namelist()),subject.ORIGINALS|set(subject.NAMES))
                self.assertEqual(archive.read("ASSET_CREDITS.md"),b"fixture asset credits")
            self.assertEqual(json.loads((root/"delivery-with-notices.json").read_text())["original_entries_checked"],5)

if __name__=="__main__": unittest.main()
