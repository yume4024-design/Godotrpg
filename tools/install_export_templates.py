"""Install only Windows x64 + ICU from the verified official Godot 4.7.2 TPZ.

Usage: python tools/install_export_templates.py [path-to-official-tpz]
Download: https://godotengine.org/download/archive/4.7.2-stable/
The hash is from the official godotengine/godot-builds release asset digest.
"""
import hashlib
from pathlib import Path
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'artifacts/downloads/verified_templates.tpz'
DIGEST = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
with ARCHIVE.open('rb') as stream:
    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
if actual != DIGEST:
    raise SystemExit(f'Template SHA256 mismatch: {actual}')
destination = ROOT / 'artifacts/godot-user/Godot/export_templates/4.7.2.stable'
destination.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(ARCHIVE) as archive:
    for entry in archive.infolist():
        name = Path(entry.filename).name
        if name in ['windows_debug_x86_64.exe', 'windows_release_x86_64.exe', 'version.txt', 'icudt_godot.dat']:
            with archive.open(entry) as source, (destination / name).open('wb') as target:
                shutil.copyfileobj(source, target)
            print(name, entry.file_size)
if not (destination / 'windows_release_x86_64.exe').exists():
    raise SystemExit('Archive has no Windows x64 release template; inspect archive before exporting.')
if (destination / 'version.txt').read_text().strip() != '4.7.2.stable':
    raise SystemExit('Template version mismatch.')
print('Verified official archive and installed templates into isolated project profile.')
