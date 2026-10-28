"""Reproject four cleaned orthographic colour references onto an unchanged Lia mesh.
Only a fresh static candidate is produced. Face identity, neck mesh, geometry,
UV and normals are preserved. Native rendered review is still required.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);assert not a.output.exists();a.output.mkdir(parents=True)
plan=json.loads((a.source/'projection.json').read_text(encoding='utf-8'))
bpy.ops.wm.open_mainfile(filepath=str((a.source/'baseline.blend').resolve()))
scene=bpy.context.scene;body=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];mesh=body.data
assert len(mesh.polygons)==12078 and len(mesh.materials)==1
meshes=[o for o in scene.objects if o.type=='MESH'];assert len(meshes)==2
assert body.matrix_world==__import__('mathutils').Matrix.Identity(4)
def signature(obj):
    h=hashlib.sha256()
    for v in obj.data.vertices:h.update(np.asarray(v.co,dtype=np.float64).tobytes())
    for f in obj.data.polygons:h.update(np.asarray(f.vertices,dtype=np.int64).tobytes())
    for uv in obj.data.uv_layers.active.data:h.update(np.asarray(uv.uv,dtype=np.float64).tobytes())
    for n in obj.data.corner_normals:h.update(np.asarray(n.vector,dtype=np.float64).tobytes())
    return h.hexdigest()
before={o.name:signature(o) for o in meshes}
mat=mesh.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links
shader=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
original=shader.inputs['Base Color'].links[0].from_node
base_image=original.image;w,h=base_image.size
pixels=np.empty(len(base_image.pixels),dtype=np.float32);base_image.pixels.foreach_get(pixels);pixels=pixels.reshape(h,w,4)
uvname=mesh.uv_layers.active.name
verts=[];faces=[]
for obj in meshes:
    offset=len(verts);verts.extend([obj.matrix_world@v.co for v in obj.data.vertices]);faces.extend([tuple(offset+i for i in f.vertices) for f in obj.data.polygons])
bvh=BVHTree.FromPolygons(verts,faces,all_triangles=False)
center=Vector(plan['center']);width=plan['width_span'];height=plan['height_span']
views=list(plan['views']);visible={};selected={v:[] for v in views};weights={}
protected_loops=0
for f in mesh.polygons:
    eligible=[]
    for view in views:
        direction=Vector(plan['views'][view]['direction'])
        hit=bvh.ray_cast(f.center+direction*4,-direction,4.02)
        eligible.append(hit[0] is not None and (hit[0]-f.center).length<.004)
    for loop in f.loop_indices:
        point=mesh.vertices[mesh.loops[loop].vertex_index].co
        normal=mesh.corner_normals[loop].vector
        scores=np.array([max(0,float(normal.dot(Vector(plan['views'][v]['direction']))))**2 if eligible[i] else 0 for i,v in enumerate(views)],dtype=float)
        # Do not repaint face, eyes, mouth, or already repaired front/side fringe.
        protect=max(0,min(1,(point.z-1.60)/.04))*max(0,min(1,(.055-point.y)/.03))
        if protect>.999:protected_loops+=1
        total=scores.sum()
        weights[loop]=(scores/total if total>1e-7 else scores)*(1-protect)
    for i,view in enumerate(views):
        if any(weights[loop][i]>0 for loop in f.loop_indices):selected[view].append(f.index)

def mathnode(operation,a,b=None):
    n=nodes.new('ShaderNodeMath');n.operation=operation
    if hasattr(a,'node'):links.new(a,n.inputs[0])
    else:n.inputs[0].default_value=a
    if b is not None:
        if hasattr(b,'node'):links.new(b,n.inputs[1])
        else:n.inputs[1].default_value=b
    return n.outputs[0]
def vectornode(operation,a,b):
    n=nodes.new('ShaderNodeVectorMath');n.operation=operation;links.new(a,n.inputs[0]);links.new(b,n.inputs[1]);return n.outputs[0]
sum_color=None;sum_weight=None;new_layers=[];patches=[]
for i,view in enumerate(views):
    uv=mesh.uv_layers.new(name='CleanupUV_'+view);mask=mesh.color_attributes.new(name='CleanupWeight_'+view,type='FLOAT_COLOR',domain='CORNER');new_layers.append((uv.name,mask.name))
    horizontal=Vector(plan['views'][view]['horizontal'])
    for loop in mesh.loops:
        point=mesh.vertices[loop.vertex_index].co
        uv.data[loop.index].uv=(.5+(point-center).dot(horizontal)/width,.5+(point.z-center.z)/height)
        weight=float(weights[loop.index][i]);mask.data[loop.index].color=(weight,weight,weight,1)
    texture=nodes.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str((a.source/(view+'_cleanup.png')).resolve()),check_existing=False);texture.image.colorspace_settings.name='sRGB';texture.extension='CLIP'
    uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map=uv.name;links.new(uvnode.outputs[0],texture.inputs['Vector'])
    attribute=nodes.new('ShaderNodeVertexColor');attribute.layer_name=mask.name
    # Ignore generated transparent halos. Colour is sampled only inside the
    # actual mesh and from near-opaque generated pixels, never background RGB.
    alpha=mathnode('GREATER_THAN',texture.outputs['Alpha'],.94)
    weight=mathnode('MULTIPLY',attribute.outputs['Color'],alpha)
    colour=vectornode('MULTIPLY',texture.outputs['Color'],weight)
    sum_color=colour if sum_color is None else vectornode('ADD',sum_color,colour)
    sum_weight=weight if sum_weight is None else mathnode('ADD',sum_weight,weight)
    patches.append({'view':view,'image_sha256':hashlib.sha256((a.source/(view+'_cleanup.png')).read_bytes()).hexdigest(),'selected_faces':selected[view]})
minimum=mathnode('MAXIMUM',sum_weight,.000001)
normalized=vectornode('DIVIDE',sum_color,minimum)
mix=nodes.new('ShaderNodeMixRGB');links.new(mathnode('MINIMUM',sum_weight,1),mix.inputs[0]);links.new(original.outputs['Color'],mix.inputs[1]);links.new(normalized,mix.inputs[2])
em=nodes.new('ShaderNodeEmission');links.new(mix.outputs[0],em.inputs[0]);links.new(em.outputs[0],output.inputs['Surface'])
mesh.uv_layers.active=mesh.uv_layers[uvname];mesh.uv_layers[uvname].active_render=True
bake=bpy.data.images.new('CleanMaterialBake',width=w,height=h,alpha=True);bake.colorspace_settings.name='sRGB'
target=nodes.new('ShaderNodeTexImage');target.image=bake;nodes.active=target
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1;scene.render.bake.margin=8;scene.render.bake.margin_type='EXTEND'
bpy.ops.object.bake(type='EMIT',use_clear=True)
colour=np.empty(len(bake.pixels),dtype=np.float32);bake.pixels.foreach_get(colour);colour=colour.reshape(h,w,4)
mask_image=bpy.data.images.new('CleanCoverage',width=w,height=h,alpha=True);mask_image.colorspace_settings.name='Non-Color';target.image=mask_image;links.new(sum_weight,em.inputs[0])
bpy.ops.object.bake(type='EMIT',use_clear=True)
coverage=np.empty(len(mask_image.pixels),dtype=np.float32);mask_image.pixels.foreach_get(coverage);coverage=coverage.reshape(h,w,4)[:,:,0]
painted=coverage>1e-5;result=pixels.copy();result[painted]=colour[painted];result[:,:,3]=pixels[:,:,3]
assert np.array_equal(result[~painted],pixels[~painted]);assert np.isfinite(result).all()
final=bpy.data.images.new('LiaCleanAlbedo',width=w,height=h,alpha=True);final.colorspace_settings.name='sRGB';final.pixels.foreach_set(result.ravel());final.filepath_raw=str((a.output/'albedo.png').resolve());final.file_format='PNG';final.save();final.pack()
target.image=final;links.new(target.outputs['Color'],shader.inputs['Base Color']);links.new(shader.outputs[0],output.inputs['Surface'])
for n in list(nodes):
    if n not in [target,shader,output]:nodes.remove(n)
for uv,mask in new_layers:mesh.uv_layers.remove(mesh.uv_layers[uv]);mesh.color_attributes.remove(mesh.color_attributes[mask])
mesh.uv_layers.active=mesh.uv_layers[uvname]
after={o.name:signature(o) for o in meshes};assert before==after
triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes);assert triangles==12554
for image in list(bpy.data.images):
    if image.users==0 and image.type!='RENDER_RESULT':bpy.data.images.remove(image)
for obj in meshes:obj.select_set(True)
bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend=a.output/'lia_material_cleanup.blend';glb=a.output/'lia_material_cleanup.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(blend.resolve()));bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,export_animations=False)
receipt={'method':'Four orthographic colour projections, occlusion-tested corner-normal blending, preserve front head and original UV/geometry/normals, original alpha and untouched pixels retained in memory','triangles':triangles,'geometry_uv_normals_unchanged':before==after,'signatures':after,'painted_pixels':int(painted.sum()),'protected_face_loops':protected_loops,'patches':patches,'static_only':True,'visual_gate':'PENDING','source_sha256':hashlib.sha256((a.source/'baseline.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest()}
(a.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
# Original geometry rendered directly; these images are never AI-edited.
scene.cycles.samples=8;scene.render.resolution_x=640;scene.render.resolution_y=960;scene.render.resolution_percentage=100;scene.render.film_transparent=False;scene.view_settings.view_transform='AgX'
scene.world=bpy.data.worlds.new('MaterialReviewWorld');scene.world.use_nodes=True
background=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');background.inputs['Color'].default_value=(.12,.16,.2,1);background.inputs['Strength'].default_value=.7
cam=bpy.data.objects.new('MaterialReviewCamera',bpy.data.cameras.new('MaterialReviewCamera'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.08
center=Vector((0,0,.975))
for idx,(position,power) in enumerate([((2,-3,4),350),((-2,1,3),160)]):
    data=bpy.data.lights.new('ReviewLight'+str(idx),'AREA');data.energy=power;data.size=3;obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=position;obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
for view,degrees in [('front',0),('right',90),('back',180),('left',-90),('quarter',45)]:
    t=math.radians(degrees);cam.location=center+Vector((math.sin(t)*4,-math.cos(t)*4,0));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str((a.output/(view+'.png')).resolve());bpy.ops.render.render(write_still=True)
print('LIA_MATERIAL_CLEANUP',json.dumps({'triangles':triangles,'painted_pixels':int(painted.sum())}),flush=True)
