"""Verify that G08.3 timed methods preserve their production behavior.

This host audit does not validate FPS or the exported PCK. It rejects drift in
copied QA methods rather than letting a stale fast path become performance evidence.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re

METHODS = {
    "flow": ("scripts/core/battle_flow.gd", "_spawn"),
    "arena": ("scripts/battle/battle_arena.gd", "setup"),
    "stage": ("scripts/battle/battle_stage.gd", "setup"),
    "game": ("scripts/core/exploration_game.gd", "validate_loaded_position"),
}
TIMESTAMP = re.compile(r"^\s*var qa_[a-z_]+: int = Time\.get_ticks_usec\(\)$")
RECORD = re.compile(r"^\s*qa_(?:samples\.append|actor_spans\.append|validation_samples\.append|spans=)")


def normalized(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


def method(text: str, name: str) -> str:
    begin = text.index("func " + name + "(")
    end = text.find("\nfunc ", begin + 1)
    return text[begin:end if end >= 0 else len(text)].strip()


def without_timing(text: str) -> str:
    return "\n".join(line for line in text.splitlines()
                     if not TIMESTAMP.fullmatch(line) and not RECORD.match(line)).strip()


def audit(root: Path) -> list[dict]:
    results = []
    receipt = json.loads(normalized(root / "tests/g083_detail/source_methods.json"))
    for path, digest in receipt["sources"].items():
        actual = hashlib.sha256(normalized(root / path).encode()).hexdigest()
        results.append({"check": "source hash " + path, "passed": actual == digest})
    for probe, (path, name) in METHODS.items():
        production = normalized(root / path)
        timed = normalized(root / ("tests/g083_detail/" + probe + ".gd"))
        results.append({"check": "method equivalence " + probe + "." + name,
                        "passed": method(production, name) == without_timing(method(timed, name))})
    flow = normalized(root / "tests/g083_detail/flow.gd")
    results.append({"check": "launch forwards to production", "passed": method(flow, "launch") ==
                    "func launch(id: StringName, practice: bool = true) -> int:\n\tqa_launch_stamp = Time.get_ticks_usec()\n\treturn super.launch(id,practice)"})
    game = normalized(root / "scripts/core/greystone_integration.gd")
    results.append({"check": "integration inherits location validator", "passed": "func validate_loaded_position(" not in game})
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    checks = audit(args.root)
    result = {"checks": len(checks), "failures": sum(not c["passed"] for c in checks),
              "normalization": "UTF-8 without BOM; CRLF to LF", "results": checks}
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    raise SystemExit(1 if result["failures"] else 0)


if __name__ == "__main__":
    main()
