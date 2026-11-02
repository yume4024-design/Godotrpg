"""Ray-test the visible waist covering; catches coat-through-belt regressions."""
import argparse,json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);assert not a.output.exists();bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
prefixes=('LiaTailored','LiaCoatTail','LiaWaistBelt','LiaBuckle','LiaSinglePouch','LiaPouch','LiaBeltLoop')
objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(prefixes)];assert objects
checks=0;failures=[]
for z in [1.173,1.18,1.19,1.20,1.21,1.23]:
 for deg in range(0,360,5):
  t=math.radians(deg);direction=Vector((-math.sin(t),math.cos(t),0));origin=Vector((0,-.035,z))-direction*.75;hits=[]
  for o in objects:
   inv=o.matrix_world.inverted();ok,hit,n,face=o.ray_cast(inv@origin,inv.to_3x3()@direction)
   if ok:
    distance=(o.matrix_world@hit-origin).length;mat=o.data.materials[o.data.polygons[face].material_index].name;hits.append((distance,mat,o.name))
  checks+=1
  if not hits:failures.append({'z':z,'angle':deg,'error':'missing_surface'});continue
  hit=min(hits)
  if hit[1] not in ['LiaCoatLeather','LiaCoatGold']:failures.append({'z':z,'angle':deg,'material':hit[1],'object':hit[2]})
assert checks==432
result={'blender':bpy.app.version_string,'input':str(a.input),'checks':checks,'failures':failures,'scope':'Static waist-band radial visibility, not animation or full body intersection QA'};a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n');print('COAT_FIT',checks,'checks',len(failures),'failures')
if failures:sys.exit(1)