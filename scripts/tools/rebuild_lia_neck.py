"""Bounded native retopology of the diagnosed Lia front-neck false surfaces.

EXPERIMENTAL / REJECTED: recipes 1-3 did not pass visual acceptance. Do not use
their outputs as production models or retry without an authored topology plan.
Subtract a measured box with interpolated UV/normal boundary fragments. Retain
all original faces outside it, add a closed low-poly neck volume, and preserve
the source. This is an isolated candidate, never a production replacement.
"""
import argparse,hashlib,json,math,sys
from pathlib import Path
import bmesh,bpy,numpy as np
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--seal-cut',action='store_true',help='Third recipe: bridge each measured cut edge into the neck volume')
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
source_sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert source_sha=='935c47d37706c711cafbb8f1156b6efb6fba1cdbc1edd341fcb3b7da4ec01281'
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene=bpy.context.scene
source=next(obj for obj in scene.objects if obj.type=='MESH')
assert not any(obj.type=='ARMATURE'for obj in scene.objects)
mesh=source.data
box=[[-.075,.075],[-.14,.032],[1.535,1.635]]
normals=[item.vector.copy()for item in mesh.corner_normals]
normal_fixes=[]
for face in mesh.polygons:
    for loop in face.loop_indices:
        if normals[loop].length<.5:
            # Independent source inspection found exactly three undefined zero
            # vectors at one waist vertex. Preserve every other source normal;
            # these three get their own face normals and an explicit receipt.
            normal_fixes.append({'source_face':face.index,'source_loop':loop,
                                 'point':list(mesh.vertices[mesh.loops[loop].vertex_index].co),
                                 'old':list(normals[loop]),'new':list(face.normal)})
            normals[loop]=face.normal.copy()
assert [(row['source_face'],row['source_loop'])for row in normal_fixes]==[(2805,8417),(3091,9274),(3123,9371)]

def blend(lo,hi,t):
    return {'point':lo['point'].lerp(hi['point'],t),'uv':lo['uv'].lerp(hi['uv'],t),
            'normal':lo['normal'].lerp(hi['normal'],t).normalized()}

def clip(poly,axis,plane,greater):
    result=[]
    for lo,hi in zip(poly,poly[1:]+poly[:1]):
        first=lo['point'][axis]>=plane if greater else lo['point'][axis]<=plane
        second=hi['point'][axis]>=plane if greater else hi['point'][axis]<=plane
        if first:result.append(lo)
        if first!=second:result.append(blend(lo,hi,(plane-lo['point'][axis])/(hi['point'][axis]-lo['point'][axis])))
    return result

def area(poly):
    return sum((poly[i]['point']-poly[0]['point']).cross(poly[i+1]['point']-poly[0]['point']).length for i in range(1,len(poly)-1))

planes=[(axis,lo,True)for axis,(lo,hi)in enumerate(box)]+[(axis,hi,False)for axis,(lo,hi)in enumerate(box)]
replace=[];fragments=[]
for face in mesh.polygons:
    poly=[{'point':mesh.vertices[mesh.loops[i].vertex_index].co.copy(),
           'uv':mesh.uv_layers.active.data[i].uv.copy(),'normal':normals[i].copy()}for i in face.loop_indices]
    inside=poly
    for axis,plane,greater in planes:
        if not inside:break
        inside=clip(inside,axis,plane,greater)
    if len(inside)<3 or area(inside)<1e-10:continue
    replace.append(face.index)
    remaining=poly
    for axis,plane,greater in planes:
        outside=clip(remaining,axis,plane,not greater)
        if len(outside)>=3 and area(outside)>1e-10:fragments.append((face.index,face.material_index,face.use_smooth,outside))
        remaining=clip(remaining,axis,plane,greater)
        if not remaining:break
assert 50<len(replace)<1000,len(replace)
body=source.copy();body.data=mesh.copy();body.name='LiaRetainedSurface';scene.collection.objects.link(body)
bm=bmesh.new();bm.from_mesh(body.data);bm.faces.ensure_lookup_table()
normal_layer=bm.loops.layers.float_vector.new('RetainedNormal')
face_layer=bm.faces.layers.int.new('OriginalSourceFace')
for face in bm.faces:
    face[face_layer]=face.index
    for loop,index in zip(face.loops,mesh.polygons[face.index].loop_indices):loop[normal_layer]=normals[index]
uv_layer=bm.loops.layers.uv.active
bmesh.ops.delete(bm,geom=[bm.faces[i]for i in replace],context='FACES_ONLY')
for source_index,material,smooth,poly in fragments:
    for index in range(1,len(poly)-1):
        corners=[poly[0],poly[index],poly[index+1]]
        if area(corners)<1e-10:continue
        vertices=[bm.verts.new(corner['point'])for corner in corners]
        face=bm.faces.new(vertices);face.material_index=material;face.smooth=smooth;face[face_layer]=source_index
        for loop,corner in zip(face.loops,corners):loop[uv_layer].uv=corner['uv'];loop[normal_layer]=corner['normal']
unused=[vertex for vertex in bm.verts if not vertex.link_faces]
if unused:bmesh.ops.delete(bm,geom=unused,context='VERTS')
bm.to_mesh(body.data);bm.free();body.data.update()
desired=[item.vector.copy()for item in body.data.attributes['RetainedNormal'].data]
body.data.normals_split_custom_set(desired)
try:
    normal_receipt=calibrate(body.data,desired)
except RuntimeError as error:
    a.output.mkdir(parents=True)
    bad=[]
    for face in body.data.polygons:
        for loop in face.loop_indices:
            actual=body.data.corner_normals[loop].vector
            if (actual-desired[loop]).length>.002:
                bad.append({'loop':loop,'source_face':int(body.data.attributes['OriginalSourceFace'].data[face.index].value),
                            'target':list(desired[loop]),'actual':list(actual),'area':face.area,
                            'points':[list(body.data.vertices[i].co)for i in face.vertices]})
    (a.output/'normal_failure.json').write_text(json.dumps({'source_sha256':source_sha,'error':str(error),'bad_loops':bad},indent=2)+'\n',encoding='utf8')
    raise
body.data.attributes.remove(body.data.attributes['RetainedNormal'])

# Sample the already repaired lower face in linear colour; do not invent a new
# skin palette or use a giant texture for the new 128-triangle surface.
shader=next(n for n in source.data.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
image=shader.inputs['Base Color'].links[0].from_node.image
pixels=np.asarray(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)
colors=[];color_faces=[]
for face in mesh.polygons:
    if not(1.69<face.center.z<1.73 and abs(face.center.x)<.025 and face.center.y<-.08):continue
    uv=sum((mesh.uv_layers.active.data[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
    colors.append(pixels[min(image.size[1]-1,max(0,int(uv.y*image.size[1]))),min(image.size[0]-1,max(0,int(uv.x*image.size[0]))),:3]);color_faces.append(face.index)
assert len(colors)>3
skin=np.median(colors,axis=0)
assert skin[0]>skin[1]>skin[2] and skin[0]>.3,skin
palette=bpy.data.images.new('LiaNeckSkinPalette',width=8,height=8,alpha=False)
palette.colorspace_settings.name='sRGB';palette.pixels.foreach_set(np.tile(np.r_[skin,1.],64));palette.pack()
material=bpy.data.materials.new('LiaAuthoredNeckSkin');material.use_nodes=True
nodes=material.node_tree.nodes;texture=nodes.new('ShaderNodeTexImage');texture.image=palette
shader=nodes.get('Principled BSDF');shader.inputs['Roughness'].default_value=.8
material.node_tree.links.new(texture.outputs['Color'],shader.inputs['Base Color'])
profiles=[(1.528,.075,.0625,-.0275),(1.56,.046,.050,-.015),(1.62,.044,.045,-.013),(1.65,.046,.045,-.013)]
points=[];faces=[];uv_rows=[]
for row,(height,rx,ry,cy)in enumerate(profiles):
    for step in range(17):
        angle=(step%16)/16*math.tau
        points.append((rx*math.cos(angle),cy+ry*math.sin(angle),height));uv_rows.append((step/16,row/3))
for row in range(3):
    for step in range(16):
        lo=row*17+step;faces.append((lo,lo+1,lo+18,lo+17))
for row,up in [(0,False),(3,True)]:
    center=len(points);height,rx,ry,cy=profiles[row];points.append((0,cy,height));uv_rows.append((.5,.5))
    for step in range(16):
        ring=row*17;tri=(center,ring+step,ring+step+1);faces.append(tri if up else tuple(reversed(tri)))
data=bpy.data.meshes.new('LiaAuthoredNeckMesh');data.from_pydata(points,[],faces);data.update()
neck=bpy.data.objects.new('LiaAuthoredNeck',data);scene.collection.objects.link(neck);data.materials.append(material)
data.uv_layers.new(name='UVMap')
for face in data.polygons:
    face.use_smooth=True
    for loop in face.loop_indices:data.uv_layers.active.data[loop].uv=uv_rows[data.loops[loop].vertex_index]
transition=None;transition_edges=[]
if a.seal_cut:
    # Diagnose actual physical edges, not UV split vertices. New strips retain
    # the exact outer cut endpoint and terminate 0.5mm inside the neck, avoiding
    # the rectangular open gaps seen in recipe 2. No global merge or hole fill.
    from collections import defaultdict
    edges=defaultdict(list)
    def key(point):return tuple(round(float(v),6)for v in point)
    for face in body.data.polygons:
        vertices=list(face.vertices)
        for first,second in zip(vertices,vertices[1:]+vertices[:1]):
            lo,hi=key(body.data.vertices[first].co),key(body.data.vertices[second].co)
            edges[tuple(sorted((lo,hi)))].append((lo,hi,face.index))
    def inset(point):
        x,y,z=point
        for lower,upper in zip(profiles,profiles[1:]):
            if lower[0]<=z<=upper[0]:
                t=(z-lower[0])/(upper[0]-lower[0])
                rx,ry,cy=[lo*(1-t)+hi*t for lo,hi in zip(lower[1:],upper[1:])]
                theta=math.atan2((y-cy)/ry,x/rx)
                return ((rx-.0005)*math.cos(theta),cy+(ry-.0005)*math.sin(theta),z)
        raise ValueError(point)
    ribbon_points=[];ribbon_faces=[]
    for edge,incidence in edges.items():
        if len(incidence)!=1:continue
        lo,hi,face_id=incidence[0]
        on_plane=any(abs(lo[axis]-side)<2e-6 and abs(hi[axis]-side)<2e-6 for axis in range(3)for side in box[axis])
        in_box=all(box[axis][0]-2e-6<=point[axis]<=box[axis][1]+2e-6 for point in [lo,hi]for axis in range(3))
        if not(on_plane and in_box):continue
        # Reverse shared outer edge orientation relative to the retained face.
        corners=[hi,lo,inset(lo),inset(hi)]
        offset=len(ribbon_points);ribbon_points.extend(corners)
        for tri in [(0,1,2),(0,2,3)]:
            if (Vector(corners[tri[1]])-Vector(corners[tri[0]])).cross(Vector(corners[tri[2]])-Vector(corners[tri[0]])).length>1e-10:
                ribbon_faces.append(tuple(offset+i for i in tri))
        transition_edges.append({'outer':[lo,hi],'inner':[corners[2],corners[3]],'retained_face':face_id})
    assert len(transition_edges)==235,len(transition_edges)
    ribbon=bpy.data.meshes.new('LiaNeckTransitionMesh');ribbon.from_pydata(ribbon_points,[],ribbon_faces);ribbon.update()
    transition=bpy.data.objects.new('LiaNeckTransition',ribbon);scene.collection.objects.link(transition);ribbon.materials.append(material)
    ribbon.uv_layers.new(name='UVMap')
    for face in ribbon.polygons:
        face.use_smooth=True
        for loop in face.loop_indices:ribbon.uv_layers.active.data[loop].uv=(.5,.5)
bpy.data.objects.remove(source,do_unlink=True)
triangles=0
objects=[body,neck]+([transition]if transition else[])
for obj in objects:obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
assert triangles<=15000
a.output.mkdir(parents=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=body
native=a.output/'lia_neck.blend';glb=a.output/'lia_neck.glb'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,export_animations=False)
report={'source_sha256':source_sha,'box':box,'removed_or_clipped_source_faces':replace,
        'original_face_count':len(mesh.polygons),'retained_surface_triangles':len(body.data.loop_triangles),
        'new_neck_triangles':len(neck.data.loop_triangles),'transition_edges':transition_edges,
        'transition_triangles':len(transition.data.loop_triangles)if transition else 0,
        'total_triangles':triangles,'profiles':profiles,
        'skin_sample_faces':color_faces,'skin_linear':skin.tolist(),'normal_calibration':normal_receipt,
        'undefined_source_normal_fixes':normal_fixes,
        'gates':{'source_preservation':'NOT_TESTED','visual':'NOT_TESTED','rig':'NOT_STARTED','formal_game':'NOT_STARTED'},
        'outputs':{path.name:hashlib.sha256(path.read_bytes()).hexdigest()for path in [native,glb]}}
(a.output/'repair_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('LIA_NECK_CANDIDATE',triangles,'triangles;',len(replace),'source faces intersect the bounded box',flush=True)
