"""Share exactly identical serialized StandardMaterial3D blocks, preserving IDs in use."""
from pathlib import Path
import re

scene = Path(__file__).resolve().parents[3] / "scenes/world/greystone_village.tscn"
source = scene.read_text(encoding="utf-8")
pattern = re.compile(r'\[sub_resource type="StandardMaterial3D" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', re.S)
canonical = {}
replacements = {}

def keep_first(match):
    resource_id, body = match.groups()
    # Exact serialized properties only; never merge by approximate color or name.
    signature = body.strip()
    if signature in canonical:
        replacements[resource_id] = canonical[signature]
        return ""
    canonical[signature] = resource_id
    return match.group(0)

result = pattern.sub(keep_first, source)
for old, new in replacements.items():
    result = result.replace(f'SubResource("{old}")', f'SubResource("{new}")')
scene.write_text(result, encoding="utf-8")
print(f"Shared {len(replacements)} duplicate materials; {len(canonical)} unique blocks remain")
