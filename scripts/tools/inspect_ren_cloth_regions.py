"""Read the owned Ren albedo once to locate the real hem, never edit pixels."""
import argparse
from array import array
import hashlib
import json
from pathlib import Path
import sys
import bpy

p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--white-threshold',type=float,default=.65)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert 0<a.white_threshold<1
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
body=next(o for o in bpy.context.scene.objects if o.type=='MESH' and o.name!='Icosphere')
shader=next(n for n in body.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
image=shader.inputs['Base Color'].links[0].from_node.image
pixels=array('f',[0.0])*len(image.pixels)
image.pixels.foreach_get(pixels)
samples={}
for loop in body.data.loops:
    vertex=body.data.vertices[loop.vertex_index]
    if not (.76<vertex.co.z<1.15 and abs(vertex.co.x)<.33):continue
    uv=body.data.uv_layers.active.data[loop.index].uv
    ix=(max(0,min(image.size[1]-1,int(uv.y*image.size[1])))*image.size[0]+max(0,min(image.size[0]-1,int(uv.x*image.size[0]))))*4
    color=tuple(pixels[ix:ix+3])
    samples.setdefault(vertex.index,{'vertex':vertex.index,'point':list(vertex.co),'colors':[]})['colors'].append(color)
white=[row for row in samples.values() if any(min(c)>a.white_threshold and max(c)-min(c)<.30 for c in row['colors'])]
near=[row for row in samples.values() if abs(row['point'][0]-.04)<.035 and abs(row['point'][1]+.12)<.035 and .83<row['point'][2]<.94]
report={'source':str(a.input),'sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),'mode':'Read-only albedo/UV point diagnosis, not semantic repaint',
        'texture_size':list(image.size),'white_hem_threshold':a.white_threshold, 'white_hem_vertices':len(white),'white_hem_z_range':[min(r['point'][2] for r in white),max(r['point'][2] for r in white)],
        'lowest_white_hem':sorted(white,key=lambda row:row['point'][2])[:24],'diagnosed_seam_neighbors':near,
        'limitations':['Colour alone cannot prove cloth topology; compare actual geometry and rendered views']}
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(report,indent=2),encoding='utf8')
print('REN_HEM_DIAGNOSTIC',report['white_hem_vertices'],report['white_hem_z_range'],'near',len(near),flush=True)
