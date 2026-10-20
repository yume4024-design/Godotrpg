"""Create real separate coat/trouser topology from the inspected Ren work copy.

Clip source triangles at the authored hem/waist contour, interpolating UVs and
preserving all original triangles outside it. Add a small hidden upper-trouser
shell. No stride, action, texture pixels, character IDs or gameplay edits.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

p=argparse.ArgumentParser()
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--profile',choices=['layers_v1','layers_v2','layers_v3'],default='layers_v3')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
assert not a.output.exists()
sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert sha=='93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
source=next(o for o in scene.objects if o.type=='MESH')
rig=next(o for o in scene.objects if o.type=='ARMATURE')
rig.animation_data.action=None
for track in rig.animation_data.nla_tracks:track.mute=True
for bone in rig.pose.bones:bone.matrix_basis.identity()
scene.frame_set(0);bpy.context.view_layer.update()
groups=[g.name for g in source.vertex_groups]
materials=list(source.data.materials)
anchors=[(-.210,0,.942),(-.186,.093,.929),(-.110,.153,.918),
         (-.023,.142,.909),(0,.107,1.020),(.019,.131,.946),
         (.111,.152,.930),(.185,.089,.947),(.205,0,.968),
         (.184,-.048,.960),(.136,-.138,.914),(.087,-.149,.897),
         (.025,-.140,1.010),(-.014,-.134,1.061),(-.025,-.140,1.010),
         (-.091,-.148,.897),(-.135,-.126,.920),(-.176,-.075,.951)]
knots=sorted((math.atan2(y,x),z) for x,y,z in anchors)
if a.profile=='layers_v3':
    # Actual front close-up shows the inner hem reaching x=-.05 / +.03 at
    # z=.90. The previous contour began the high notch at x=-.09 / +.087,
    # incorrectly leaving part of the white hem on the full-stride trousers.
    anchors=[point for point in anchors if point not in
             [(.087,-.149,.897),(.025,-.140,1.010),(-.025,-.140,1.010),(-.091,-.148,.897)]]
    anchors.extend([(.030,-.150,.895),(-.050,-.155,.895)])
    knots=sorted((math.atan2(y,x),z) for x,y,z in anchors)

def smooth(lo,hi,x):
    t=max(0.,min(1.,(x-lo)/(hi-lo)))
    return t*t*(3-2*t)

def hem_height(x,y):
    angle=math.atan2(y,x)
    extended=[(knots[-1][0]-math.tau,knots[-1][1])]+knots+[(knots[0][0]+math.tau,knots[0][1])]
    for (lo,hlo),(hi,hhi) in zip(extended,extended[1:]):
        if lo<=angle<=hi:return hlo+(hhi-hlo)*(angle-lo)/(hi-lo)
    raise ValueError(angle)

def field(point):
    x,y,z=point
    return min(z-hem_height(x,y),1.112-z,.295-abs(x))

def normalize(row):
    row=dict(sorted(((n,w) for n,w in row.items() if w>1e-8),key=lambda p:-p[1])[:4])
    total=sum(row.values());assert total>0
    return {n:w/total for n,w in row.items()}

def interpolate(first,second,t):
    return {'point':first['point'].lerp(second['point'],t),
            'uv':first['uv'].lerp(second['uv'],t),
            'normal':first['normal'].lerp(second['normal'],t).normalized(),
            'weights':normalize({n:first['weights'].get(n,0)*(1-t)+second['weights'].get(n,0)*t
                                 for n in set(first['weights'])|set(second['weights'])}),
            'field':0.}

def clip(poly,inside):
    result=[]
    for first,second in zip(poly,poly[1:]+poly[:1]):
        first_in=(first['field']>=0)==inside
        second_in=(second['field']>=0)==inside
        if first_in:result.append(first)
        if first_in!=second_in:
            t=first['field']/(first['field']-second['field'])
            result.append(interpolate(first,second,t))
    return result

retained,garment=[],[]
cut_faces=[]
for face in source.data.polygons:
    poly=[]
    for loop_id in face.loop_indices:
        loop=source.data.loops[loop_id];vertex=source.data.vertices[loop.vertex_index]
        weights={groups[g.group]:g.weight for g in vertex.groups}
        poly.append({'point':vertex.co.copy(),'uv':source.data.uv_layers.active.data[loop_id].uv.copy(),
                     'normal':source.data.corner_normals[loop_id].vector.copy(),
                     'weights':weights,'field':field(vertex.co)})
    assert len(poly)==3
    arms=max(sum(w for n,w in v['weights'].items() if n.startswith(('Arm','Forearm','Hand','Fingers'))) for v in poly)
    if arms>.15 or all(v['field']<0 for v in poly):
        retained.append((poly,face.material_index));continue
    inner,outer=clip(poly,True),clip(poly,False)
    if len(inner)>=3:garment.append((inner,face.material_index))
    if len(outer)>=3:retained.append((outer,face.material_index))
    if inner and outer:cut_faces.append(face.index)

def pants_weights(point,old=None):
    x,y,z=point
    if old is not None:
        row={n:w for n,w in old.items() if not n.startswith('Coat')}
        removed=sum(w for n,w in old.items() if n.startswith('Coat'))
        if removed<1e-8:return normalize(row)
        left=smooth(-.075,.075,x)
        row['LegLeft']=row.get('LegLeft',0)+removed*left
        row['LegRight']=row.get('LegRight',0)+removed*(1-left)
        return normalize(row)
    left=smooth(-.075,.075,x);leg=1-smooth(.98,1.11,z)
    return normalize({'Torso':1-leg,'LegLeft':leg*left,'LegRight':leg*(1-left)})

def garment_weights(point,old):
    x,y,z=point
    # Three continuous influences avoid top-four truncation switching left/right
    # leg at the center notch. The two old coat bones remain in the preserved rig
    # and actions but are no longer used as deformers for this separate layer.
    lower=1-smooth(.94,1.112,z)
    left=smooth(-.045,.045,x)
    if a.profile=='layers_v1':
        return normalize({'Torso':1-lower,'LegLeft':lower*.45*left,
                          'LegRight':lower*.45*(1-left),
                          'CoatLeft':lower*.55*left,'CoatRight':lower*.55*(1-left)})
    return normalize({'Torso':1-lower*.45,'LegLeft':lower*.45*left,
                      'LegRight':lower*.45*(1-left)})

def make_mesh(name,polygons,weight_fn,mats):
    vertices,faces,uvs,normals,weights,mat_ids=[],[],[],[],[],[]
    for poly,mat in polygons:
        for index in range(1,len(poly)-1):
            corners=[poly[0],poly[index],poly[index+1]]
            if (corners[1]['point']-corners[0]['point']).cross(corners[2]['point']-corners[0]['point']).length<1e-10:continue
            ids=[]
            for corner in corners:
                ids.append(len(vertices));vertices.append(corner['point'])
                uvs.append(corner['uv']);weights.append(weight_fn(corner['point'],corner['weights']))
                normals.append(corner.get('normal'))
            faces.append(ids);mat_ids.append(mat)
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj)
    for mat in mats:data.materials.append(mat)
    for face,mat in zip(data.polygons,mat_ids):face.material_index=mat;face.use_smooth=True
    uv=data.uv_layers.new(name='UVMap')
    for loop in data.loops:uv.data[loop.index].uv=uvs[loop.vertex_index]
    if a.profile!='layers_v1' and all(normal is not None for normal in normals):
        data.normals_split_custom_set([normals[loop.vertex_index] for loop in data.loops])
    for group in groups:obj.vertex_groups.new(name=group)
    for index,row in enumerate(weights):
        for group,weight in row.items():obj.vertex_groups[group].add([index],weight,'REPLACE')
    obj.parent=rig;obj.modifiers.new('LayerSkin','ARMATURE').object=rig
    return obj

body=make_mesh('RenRetainedBody',retained,pants_weights,materials)
coat=make_mesh('RenSeparatedCoat',garment,garment_weights,materials)
# An authored simple upper-trouser volume under the now movable coat. It is
# intentionally plain dark fabric, independent of the original 4K outer UVs.
dark=bpy.data.materials.new('RenInnerTrouserFabric');dark.diffuse_color=(.025,.028,.032,1)
dark.use_nodes=True
shader=dark.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=dark.diffuse_color;shader.inputs['Roughness'].default_value=.93
under=[]
for sign in [-1,1]:
    rings=[]
    for z,center,rx,ry in [(.865,.141,.100,.108),(.955,.117,.110,.116),(1.105,.092,.095,.109)]:
        rings.append([Vector((sign*center+rx*math.cos(i/16*math.tau),ry*math.sin(i/16*math.tau),z)) for i in range(16)])
    for level in range(2):
        for i in range(16):
            j=(i+1)%16
            points=[rings[level][i],rings[level][j],rings[level+1][j],rings[level+1][i]]
            poly=[{'point':point,'uv':Vector((k%2,level/2)), 'weights':{}} for k,point in enumerate(points)]
            under.append((poly,0))
inner=make_mesh('RenInnerTrousers',under,lambda point,old:pants_weights(point),[dark])
bpy.data.objects.remove(source,do_unlink=True)
objects=[body,coat,inner]
triangles=sum(len(o.data.polygons) for o in objects)
assert triangles<=15000,(triangles,'BUDGET')
assert all(len(v.groups)<=4 for o in objects for v in o.data.vertices)
error=max(abs(sum(g.weight for g in v.groups)-1) for o in objects for v in o.data.vertices)
assert error<1e-5
bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
a.output.mkdir(parents=True)
bpy.ops.file.pack_all()
native,glb=a.output/'ren_rigged.blend',a.output/'ren_rigged.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
report={'source_sha256':sha,'method':'Real triangle clipping and separate coat plus authored inner trouser shell',
        'profile':a.profile,
        'hem_landmarks':anchors,'cut_source_faces':cut_faces,'source_triangles':12808,
        'triangles':triangles,'meshes':{o.name:len(o.data.polygons) for o in objects},
        'maximum_weight_sum_error':error,'bones':len(rig.data.bones),'clips':[action.name for action in bpy.data.actions],
        'action_keyframes_changed':False,'original_outer_albedo_pixels_changed':False,
        'coat_deformers':('Torso/LegLeft/LegRight/CoatLeft/CoatRight with top-four truncation'
                          if a.profile=='layers_v1' else 'Torso/LegLeft/LegRight; old coat bones preserved but unused'),
        'original_corner_normals':('Not copied in rejected layers_v1' if a.profile=='layers_v1'
                                    else 'Copied/interpolated; numerical preservation must be audited separately'),
        'gates':{'motion':'NOT_TESTED','visual':'NOT_TESTED','formal_gameplay':'NOT_STARTED'},
        'outputs':{path.name:hashlib.sha256(path.read_bytes()).hexdigest() for path in [native,glb]}}
(a.output/'layer_build.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('REN_GARMENT_LAYERS',triangles,report['meshes'],flush=True)
