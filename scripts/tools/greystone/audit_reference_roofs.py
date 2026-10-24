"""Raycast the authored roof envelopes for holes, including tile seams/valleys.

blender --background --factory-startup --python-exit-code 1 --python THIS --
  --output artifacts/reference_architecture_20261025/roof_audit.json
No gameplay data or live Blender scene is modified.
"""
import argparse
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser()
parser.add_argument('--output',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source_assets/greystone_reference_20261024/greystone_master.blend'))
rows=[]
for name in ('Inn','ItemShop','WeaponShop','WestHouse','SouthHouse','GuildHall'):
    obj=bpy.data.objects[name]
    vertices=[v.co.copy() for v in obj.data.vertices]
    assert all(math.isfinite(v) for p in vertices for v in p),name
    tree=BVHTree.FromPolygons(vertices,[list(p.vertices) for p in obj.data.polygons])
    inn=name=='Inn';shop=name in ('ItemShop','WeaponShop')
    width=12.0 if inn else (8.0 if shop else 7.0)
    depth=7.5 if inn else (5.5 if shop else 4.5)
    hits=0;failures=[];min_clearance=100.0
    # Unequal pitches sample both columns and rows rather than only tile centers.
    for ix in range(math.ceil((width-.24)/.127)):
        x=-width/2+.12+ix*.127
        for iy in range(math.ceil((depth-.24)/.113)):
            y=-depth/2+.12+iy*.113
            expected=(5.85-2.2*abs(y)/3.75) if inn else (4.1-1.45*abs(x)/(width/2))
            if inn and y<0 and abs(x+3.25)<=2.45:
                expected=max(expected,5.85-2.2*abs(x+3.25)/2.45)
            location,normal,face,distance=tree.ray_cast(Vector((x,y,10)),Vector((0,0,-1)),12)
            hits+=1
            if location is None or location.z<expected-.11:
                failures.append([x,y,expected,list(location) if location else None])
            else:min_clearance=min(min_clearance,location.z-expected)
    rows.append({'building':name,'rays':hits,'missing_or_low_hits':len(failures),
                 'minimum_height_above_ideal_m':min_clearance,'failures':failures[:20]})
result={'method':'Vertical BVH rays over all six roof footprints; lower tolerance 0.11m includes continuous under-tile decking.',
        'passed':all(row['missing_or_low_hits']==0 for row in rows),'buildings':rows}
Path(args.output).write_text(json.dumps(result,indent=2),encoding='utf-8')
assert result['passed'],result
print('REFERENCE_ROOF_AUDIT',json.dumps(result),flush=True)
