"""Bounded manual repair of dark trouser faces misclassified as the short coat.

This is based on the recorded seam points and actual UV/albedo diagnosis, not
another whole-body weight recipe or a reduced animation amplitude.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy

p=argparse.ArgumentParser()
p.add_argument('--input',required=True,type=Path)
p.add_argument('--output',required=True,type=Path)
p.add_argument('--scope',choices=['diagnosed_seam','below_hem'],default='diagnosed_seam')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
assert hashlib.sha256(a.input.read_bytes()).hexdigest()=='93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850', 'Different source; inspect its actual hem before repairing'
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
body=next(o for o in bpy.context.scene.objects if o.type=='MESH')
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
assert len(body.data.polygons)==12808 and len(rig.data.bones)==19


def smooth(lo,hi,value):
    t=max(0.,min(1.,(value-lo)/(hi-lo)))
    return t*t*(3-2*t)


edits=[]
width=.10 if a.scope=='diagnosed_seam' else .34
fade_start=.055 if a.scope=='diagnosed_seam' else .28
for vertex in body.data.vertices:
    x,y,z=vertex.co
    if not (.79<z<.915 and abs(x)<width and abs(y)<.18):continue
    old={body.vertex_groups[g.group].name:g.weight for g in vertex.groups}
    cloth=sum(weight for name,weight in old.items() if name.startswith('Coat'))
    legs=sum(old.get(name,0.) for name in ['LegLeft','LegRight'])
    if cloth<1e-8 or legs<1e-8:continue
    factor=(1-smooth(.89,.915,z))*(1-smooth(fade_start,width,abs(x)))
    factor*=smooth(.79,.83,z)*(1-smooth(.15,.18,abs(y)))
    row=dict(old)
    removed=cloth*factor
    for name in list(row):
        if name.startswith('Coat'):row[name]*=1-factor
    for name in ['LegLeft','LegRight']:
        row[name]=old.get(name,0.)+removed*old.get(name,0.)/legs
    total=sum(row.values())
    row={name:weight/total for name,weight in row.items() if weight>1e-8}
    for group in body.vertex_groups:group.remove([vertex.index])
    for name,weight in row.items():body.vertex_groups[name].add([vertex.index],weight,'REPLACE')
    edits.append({'vertex':vertex.index,'point':list(vertex.co),'factor':factor,'before':old,'after':row})
assert edits
assert max(len(v.groups) for v in body.data.vertices)<=4
assert max(abs(sum(g.weight for g in v.groups)-1) for v in body.data.vertices)<1e-5
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
for bone in rig.pose.bones:
    bone.rotation_euler=(0,0,0)
    bone.location=(0,0,0)
    bone.scale=(1,1,1)
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True);rig.select_set(True)
bpy.context.view_layer.objects.active=rig
a.output.mkdir(parents=True)
native,glb=a.output/'ren_rigged.blend',a.output/'ren_rigged.glb'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,
 export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
report={'source':str(a.input),'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),
 'method':'Codex-directed bounded false-cloth exclusion below the inspected bright hem (lowest z=.91134); trouser faces at z=.864/.873 are dark',
 'scope':a.scope,'edits':edits,'changed_vertices':len(edits),'geometry_uv_animation_changes':False,
 'outputs':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [native,glb]},
 'gates':{'motion':'NOT_TESTED','visual':'NOT_TESTED','formal_gameplay':'NOT_STARTED'}}
(a.output/'false_cloth_repair.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('REN_FALSE_CLOTH_REPAIR',len(edits),flush=True)
