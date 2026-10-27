"""Authored anatomical neck candidate; never run the rejected box/ribbon recipe.

This edits only a new background copy and writes a complete face-ID receipt.
Visual and future deformation acceptance remain mandatory; no automatic adoption.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bmesh, bpy, numpy as np
from mathutils import Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--input',type=Path,required=True)
p.add_argument('--plan',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
plan=json.loads(a.plan.read_text(encoding='utf-8-sig'))
source_sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert source_sha==plan['source_sha256']
assert not a.output.exists(), 'Preserve previous attempts'
a.output.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
bpy.context.preferences.filepaths.file_preview_type='NONE'
scene=bpy.context.scene
source=next(o for o in scene.objects if o.type=='MESH')
assert len([o for o in scene.objects if o.type=='MESH'])==1
assert not any(o.type=='ARMATURE' for o in scene.objects)
mesh=source.data
normals=[n.vector.copy() for n in mesh.corner_normals]
fixes=[]
for face in mesh.polygons:
    for loop in face.loop_indices:
        if normals[loop].length<.5:
            fixes.append([face.index,loop]); normals[loop]=face.normal.copy()
assert fixes==plan['known_source_normal_exceptions']

def width(z):
    controls=plan['front_replacement_half_width_by_z']
    for (lo,x0),(hi,x1) in zip(controls,controls[1:]):
        if lo<=z<=hi: return x0+(x1-x0)*(z-lo)/(hi-lo)
    return None

removed=[]
for face in mesh.polygons:
    x,y,z=face.center
    half=width(z)
    if half is None or abs(x)>half or y>plan['front_replacement_max_y']: continue
    # Retain actual fasteners and the jaw, rather than cutting a rectangle
    # through arbitrary crossing triangles and trying to bridge each fragment.
    if abs(x)>.075 and z<1.510: continue
    points=[mesh.vertices[i].co for i in face.vertices]
    if any(v.z>1.645 or v.z<1.477 or abs(v.x)>.135 or v.y>.05 for v in points): continue
    removed.append(face.index)
assert 100<len(removed)<900,len(removed)
original_uv=mesh.uv_layers.active
original_signatures={f.index:[(tuple(mesh.vertices[mesh.loops[i].vertex_index].co),tuple(original_uv.data[i].uv),tuple(normals[i])) for i in f.loop_indices] for f in mesh.polygons if f.index not in removed}

body=source.copy(); body.data=mesh.copy(); body.name='LiaRetainedAuthoredNeckSurface'; scene.collection.objects.link(body)
bm=bmesh.new(); bm.from_mesh(body.data); bm.faces.ensure_lookup_table()
face_layer=bm.faces.layers.int.new('OriginalSourceFace')
normal_layer=bm.loops.layers.float_vector.new('RetainedNormal')
for face in bm.faces:
    face[face_layer]=face.index
    for loop,index in zip(face.loops,mesh.polygons[face.index].loop_indices): loop[normal_layer]=normals[index]
bmesh.ops.delete(bm,geom=[bm.faces[i] for i in removed],context='FACES_ONLY')
loose=[v for v in bm.verts if not v.link_faces]
if loose: bmesh.ops.delete(bm,geom=loose,context='VERTS')
bm.to_mesh(body.data); bm.free(); body.data.update()
desired=[v.vector.copy() for v in body.data.attributes['RetainedNormal'].data]
body.data.normals_split_custom_set(desired)
calibration=calibrate(body.data,desired)
body.data.attributes.remove(body.data.attributes['RetainedNormal'])
max_normal_error=0.0
for face in body.data.polygons:
    source_face=body.data.attributes['OriginalSourceFace'].data[face.index].value
    expected=original_signatures[source_face]
    for loop,(point,uv,normal) in zip(face.loop_indices,expected):
        assert (body.data.vertices[body.data.loops[loop].vertex_index].co-Vector(point)).length<1e-7
        assert (body.data.uv_layers.active.data[loop].uv-Vector(uv)).length<1e-7
        error=(body.data.corner_normals[loop].vector-Vector(normal)).length
        max_normal_error=max(max_normal_error,error)
        assert error<=.002,(source_face,loop,error)

# Plain shader colour derived from approved facial skin, not another projected
# image. Cylindrical UVs are a real editable chart for later character texturing.
shader=next(n for n in mesh.materials[0].node_tree.nodes if n.type=='BSDF_PRINCIPLED')
image=shader.inputs['Base Color'].links[0].from_node.image
pixels=np.asarray(image.pixels[:],dtype=np.float32).reshape(image.size[1],image.size[0],4)
samples=[]; sample_faces=[]
for face in mesh.polygons:
    if not(1.69<face.center.z<1.73 and abs(face.center.x)<.025 and face.center.y<-.08):continue
    uv=sum((original_uv.data[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
    samples.append(pixels[int(uv.y*(image.size[0]-1)),int(uv.x*(image.size[1]-1)),:3]);sample_faces.append(face.index)
assert len(samples)>3
skin=np.median(samples,axis=0)
def linear(c): return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
material=bpy.data.materials.new('LiaAuthoredSkin');material.use_nodes=True
material.diffuse_color=tuple(linear(float(c)) for c in skin)+(1.0,)
shader=material.node_tree.nodes.get('Principled BSDF')
shader.inputs['Base Color'].default_value=material.diffuse_color
shader.inputs['Roughness'].default_value=.8
segments=plan['radial_segments']; sections=plan['sections_z_radius_x_front_y_back_y']
points=[]; faces=[]
for z,rx,front,back in sections:
    cy=(front+back)/2;ry=(back-front)/2
    for i in range(segments):
        theta=math.tau*i/segments
        points.append((rx*math.cos(theta),cy+ry*math.sin(theta),z))
for row in range(len(sections)-1):
    for i in range(segments):
        lo=row*segments+i; nxt=row*segments+(i+1)%segments
        faces.append((lo,nxt,nxt+segments,lo+segments))
faces.append(tuple(reversed(range(segments))))
faces.append(tuple((len(sections)-1)*segments+i for i in range(segments)))
data=bpy.data.meshes.new('LiaContinuousNeckClavicle');data.from_pydata(points,[],faces);data.update()
neck=bpy.data.objects.new('LiaContinuousNeckClavicle',data);scene.collection.objects.link(neck);data.materials.append(material)
data.uv_layers.new(name='UVMap')
for face in data.polygons:
    side=len(face.vertices)==4; face.use_smooth=side
    for loop in face.loop_indices:
        index=data.loops[loop].vertex_index; row=index//segments; step=index%segments
        if side:
            if step==0 and any(data.loops[j].vertex_index%segments==segments-1 for j in face.loop_indices): step=segments
            uv=(step/segments,(sections[row][0]-sections[0][0])/(sections[-1][0]-sections[0][0]))
        else: uv=(.5+points[index][0]/.3,.5+(points[index][1]+.03)/.3)
        data.uv_layers.active.data[loop].uv=uv
check=bmesh.new();check.from_mesh(data)
assert all(edge.is_manifold for edge in check.edges)
assert len({v.index for v in check.verts})==len(points)
check.free()
bpy.data.objects.remove(source,do_unlink=True)
objects=[body,neck]
for obj in objects: obj.data.calc_loop_triangles()
triangles=sum(len(obj.data.loop_triangles) for obj in objects)
assert triangles<=15000,triangles
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:obj.select_set(True)
bpy.context.view_layer.objects.active=body
native=a.output/'lia_authored_neck.blend';glb=a.output/'lia_authored_neck.glb'
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,export_animations=False)
receipt={'source_sha256':source_sha,'plan_sha256':hashlib.sha256(a.plan.read_bytes()).hexdigest(),'status':'IN_PROGRESS; visual not evaluated, no rig','triangles':triangles,'new_neck_triangles':len(data.loop_triangles),'removed_face_ids':removed,'retained_faces_verified':len(original_signatures),'source_zero_normal_exceptions':fixes,'max_retained_normal_error':max_normal_error,'normal_calibration':calibration,'skin_sample_face_ids':sample_faces,'skin_encoded_rgb':skin.tolist(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'blend_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'method':plan['method']}
(a.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
for obj in list(scene.objects):
    if obj.type!='MESH':bpy.data.objects.remove(obj,do_unlink=True)
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=8
scene.render.resolution_x=scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
scene.world=bpy.data.worlds.new('AuthoredNeckReviewWorld');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.12,.16,.20,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.7
camera=bpy.data.objects.new('AuthoredNeckReviewCamera',bpy.data.cameras.new('AuthoredNeckReviewCamera'));scene.collection.objects.link(camera)
scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=.36
for index,(point,power) in enumerate([((2,-3,4),350),((-2,1,3),160)]):
    light=bpy.data.lights.new('ReviewLight'+str(index),'AREA');light.energy=power;light.size=3
    obj=bpy.data.objects.new(light.name,light);scene.collection.objects.link(obj);obj.location=point
    obj.rotation_euler=(Vector((0,0,1.6))-obj.location).to_track_quat('-Z','Y').to_euler()
for name,angle in [('front',0),('right',math.pi/2),('three_quarter',math.pi/4),('back',math.pi)]:
    camera.location=(math.sin(angle)*3,-math.cos(angle)*3,1.59)
    camera.rotation_euler=(Vector((0,0,1.59))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(name+'.png')).resolve());bpy.ops.render.render(write_still=True)
print('LIA_AUTHORED_NECK_RESULT',json.dumps({'triangles':triangles,'removed_faces':len(removed),'retained_faces_verified':len(original_signatures)}),flush=True)
