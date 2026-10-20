"""Bounded anatomical seam repair after the recorded Ren rig v1-v3 review.

Only blend opposite Leg influences at the diagnosed central crotch seam.
Keep the approved source geometry, UVs, motion amplitudes and all clips exact.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy

p = argparse.ArgumentParser()
p.add_argument('--input', required=True, type=Path)
p.add_argument('--output', required=True, type=Path)
p.add_argument('--profile', choices=['crotch_only','tabard_extension_diagnostic'], default='crotch_only')
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists(), 'Output must be new'
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
body = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
rig = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
assert len(body.data.polygons) == 12808 and len(rig.data.bones) == 19
assert {x.name for x in bpy.data.actions} == {'attack','cast','guard','hit','potion','walk','run'}


def smooth(lo, hi, value):
    t = max(0., min(1., (value-lo)/(hi-lo)))
    return t*t*(3-2*t)


ids = {name: body.vertex_groups[name].index for name in ['LegLeft', 'LegRight']}
edits = []
for vertex in body.data.vertices:
    x, y, z = vertex.co
    width = .075 if a.profile == 'crotch_only' else .34
    low = .76 if a.profile == 'crotch_only' else .74
    if abs(x) >= width or not (low < z < 1.11):
        continue
    previous = {g.group: g.weight for g in vertex.groups}
    strength = sum(previous.get(i, 0.) for i in ids.values())
    # Crotch opening ends below z=.80. Above it, continuity across x=0 is
    # essential; fade to the original weights outside this bounded seam.
    influence = smooth(.76, .83, z)*(1-smooth(1.05, 1.11, z))
    if a.profile != 'crotch_only':
        influence *= 1-smooth(.060, .075, abs(x))
    left = smooth(-.075, .075, x)
    row = dict(previous)
    for name, share in [('LegLeft', left), ('LegRight', 1-left)]:
        index = ids[name]
        row[index] = previous.get(index, 0.)*(1-influence)+strength*share*influence
    # The next diagnosed seam is the lower tabard edge (z=.864/.873,
    # y=-.122), where steep cloth fade pulled it toward the stride leg.
    # Extend only that existing cloth transition, keeping its x/depth mask.
    side = 'Left' if x >= 0 else 'Right'
    old_cloth = smooth(.065,.13,abs(y))*(1-smooth(.98,1.13,z))
    old_cloth *= smooth(.84,.91,z)*(1-smooth(.28,.34,abs(x)))
    new_cloth = smooth(.065,.13,abs(y))*(1-smooth(.98,1.13,z))
    new_cloth *= smooth(.74,.86,z)*(1-smooth(.28,.34,abs(x)))
    if a.profile == 'tabard_extension_diagnostic' and new_cloth > old_cloth and z < .91:
        actual_coat = sum(weight for i,weight in row.items() if body.vertex_groups[i].name.startswith('Coat'))
        # Never add cloth to hanging fingers or any arm-influenced vertex.
        arm = sum(weight for i,weight in row.items() if body.vertex_groups[i].name.startswith(('Arm','Forearm','Hand','Fingers')))
        if arm < 1e-8:
            desired = max(actual_coat,new_cloth)
            scale = (1-desired)/max(1e-8,1-actual_coat)
            row = {i:weight*scale for i,weight in row.items() if not body.vertex_groups[i].name.startswith('Coat')}
            row[body.vertex_groups['Coat'+side].index] = desired
    if all(abs(row.get(i,0)-previous.get(i,0)) < 1e-8 for i in set(row)|set(previous)):
        continue
    row = dict(sorted(row.items(), key=lambda pair: pair[1], reverse=True)[:4])
    total = sum(row.values())
    row = {index: weight/total for index, weight in row.items() if weight > 1e-8}
    for group in body.vertex_groups:
        group.remove([vertex.index])
    for index, weight in row.items():
        body.vertex_groups[index].add([vertex.index], weight, 'REPLACE')
    edits.append({'vertex': vertex.index, 'position': list(vertex.co),
                  'before': {body.vertex_groups[i].name:w for i,w in previous.items()},
                  'after': {body.vertex_groups[i].name:w for i,w in row.items()}})
assert edits
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.rotation_euler = (0,0,0)
    bone.location = (0,0,0)
    bone.scale = (1,1,1)
bpy.context.scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
a.output.mkdir(parents=True)
native, glb = a.output/'ren_rigged.blend', a.output/'ren_rigged.glb'
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()), export_format='GLB', use_selection=True,
                         export_animations=True, export_animation_mode='ACTIONS', export_frame_range=False)
report = {'source':str(a.input), 'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),
          'method':'Codex-directed central crotch region; tabard extension only with explicit diagnostic profile',
          'profile':a.profile,
          'weights_edited_vertices':len(edits), 'edits':edits,
          'geometry_uv_animation_changes':False, 'triangle_count':12808,
          'outputs':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [native,glb]},
          'gates':{'motion':'NOT_TESTED','visual':'NOT_TESTED','formal_gameplay':'NOT_STARTED'}}
(a.output/'crotch_repair.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('REN_CROTCH_REPAIR',len(edits),'vertices',flush=True)
