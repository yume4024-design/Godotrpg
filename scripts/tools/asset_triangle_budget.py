"""Shared inclusive budget contract. No Godot/Blender imports or source mutations."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONFIG = ROOT / "data/validation/asset_triangle_budgets.json"


def policy(path=CONFIG):
    result = json.loads(Path(path).read_text(encoding="utf-8"))
    if result["schema_version"] != 1 or result["comparison"] != "inclusive_maximum":
        raise ValueError("Unsupported asset triangle policy")
    for category, definition in result["categories"].items():
        value = definition["maximum_triangles"]
        if type(value) is not int or value < 1:
            raise ValueError(f"Invalid budget: {category}")
    return result


def resolve_budget(category=None, maximum=None):
    config = policy()
    if category is not None and category not in config["categories"]:
        raise ValueError(f"Unknown asset category: {category}")
    category_maximum = config["categories"][category]["maximum_triangles"] if category else None
    if maximum is None:
        maximum = category_maximum
    if type(maximum) is not int or maximum < 1:
        raise ValueError("Supply --category or an explicit positive --budget")
    if category_maximum is not None and maximum > category_maximum:
        raise ValueError("Explicit budget cannot exceed its category maximum")
    return maximum


def budget_result(triangles, maximum):
    if type(triangles) is not int or triangles < 0:
        raise ValueError("Invalid triangle count")
    return {"maximum_triangles": maximum, "triangles": triangles,
            "headroom_triangles": maximum - triangles,
            "triangle_gate": "PASS" if 0 < triangles <= maximum else "FAIL"}
