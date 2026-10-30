"""Add committed notices to an existing prologue candidate without changing its fixed ZIP/PCK."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
NAMES = ("ASSET_CREDITS.md", "GODOT_LICENSES.txt")
ORIGINALS = {"ProjectCrystal.exe", "ProjectCrystal.pck", "start_prologue_candidate.cmd", "README.txt", "manifest.json"}


def sha_stream(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda:stream.read(1024*1024), b""): h.update(block)
    return h.hexdigest()


def compressed_digest(path, info):
    with Path(path).open("rb") as stream:
        stream.seek(info.header_offset)
        header = stream.read(30)
        if len(header) != 30 or header[:4] != b"PK\x03\x04": raise ValueError("Invalid ZIP local header")
        name_length, extra_length = struct.unpack_from("<HH",header,26)
        stream.seek(name_length + extra_length,1)
        remaining = info.compress_size
        digest = hashlib.sha256()
        while remaining:
            block = stream.read(min(1024*1024,remaining))
            if not block: raise ValueError("Truncated compressed entry")
            digest.update(block)
            remaining -= len(block)
        return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root",type=Path,required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    candidate = root / "candidate"
    manifest = json.loads((candidate / "manifest.json").read_text(encoding="utf-8-sig"))
    source = manifest["source_commit"]
    if not re.fullmatch(r"[0-9a-f]{40}",source): raise ValueError("Invalid source commit")
    # Resolve the fixed original ZIP by the package's previously verified receipt.
    delivery = json.loads((root / "delivery.json").read_text(encoding="utf-8-sig"))
    baseline = PROJECT / Path(delivery["zip"])
    if baseline.parent.resolve() != root or sha_stream(baseline) != delivery["sha256"]: raise ValueError("Original ZIP identity mismatch")
    for name, key in [("ProjectCrystal.exe","executable_sha256"),("ProjectCrystal.pck","pck_sha256")]:
        if sha_stream(candidate/name) != manifest[key]: raise ValueError("Candidate binary identity mismatch: " + name)
    with zipfile.ZipFile(baseline) as old:
        if len(old.namelist()) != len(ORIGINALS) or set(old.namelist()) != ORIGINALS: raise ValueError("Unexpected original ZIP contents")
        original = {info.filename:{"size":info.file_size,"crc":info.CRC,"compressed_sha256":compressed_digest(baseline,info)} for info in old.infolist()}
    notices = {}
    for name in NAMES:
        content = subprocess.check_output(["git","-C",str(PROJECT),"show",source+":docs/"+name])
        if not content or re.search(rb"gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|-----BEGIN (?:RSA |EC )?PRIVATE KEY-----",content): raise ValueError("Notice failed content check: " + name)
        notices[name] = content
    if b"GODOT ENGINE 4.7.2" not in notices["GODOT_LICENSES.txt"]: raise ValueError("Unexpected Godot notice version")
    target = root / ("ProjectCrystal-" + manifest["version"] + "-Windows-with-notices.zip")
    receipt_path = root / "delivery-with-notices.json"
    if target.exists() or receipt_path.exists() or any((candidate/n).exists() for n in NAMES): raise FileExistsError("Refusing to overwrite existing delivery or notice")
    for name, data in notices.items():
        with (candidate/name).open("xb") as stream: stream.write(data)
    with baseline.open("rb") as source_stream, target.open("xb") as target_stream:
        shutil.copyfileobj(source_stream,target_stream,1024*1024)
    with zipfile.ZipFile(target,"a",compression=zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for name,data in notices.items(): archive.writestr(name,data)
    with zipfile.ZipFile(target) as archive:
        if len(archive.namelist()) != len(ORIGINALS)+len(NAMES) or set(archive.namelist()) != ORIGINALS | set(NAMES): raise ValueError("Unexpected ZIP entry list")
        for name, expected in original.items():
            info = archive.getinfo(name)
            if (info.file_size != expected["size"] or info.CRC != expected["crc"] or compressed_digest(target,info) != expected["compressed_sha256"]): raise ValueError("Original ZIP entry changed: " + name)
        for name, data in notices.items():
            if archive.read(name) != data or (candidate/name).read_bytes() != data: raise ValueError("Notice bytes changed: " + name)
    receipt = {"source_commit":source,"original_zip_sha256":delivery["sha256"],"supplemented_zip":str(target),"supplemented_zip_sha256":sha_stream(target),"size":target.stat().st_size,"original_entries_checked":len(original),"notice_sha256":{name:hashlib.sha256(data).hexdigest() for name,data in notices.items()},"method":"Copied original compressed entries unchanged; added exact committed notices; original ZIP, PCK and manifest preserved."}
    receipt_path.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("PROLOGUE_NOTICES_VERIFIED",json.dumps(receipt,ensure_ascii=False))

if __name__ == "__main__": main()
