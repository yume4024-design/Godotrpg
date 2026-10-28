"""Bake reviewed side-view colour repairs into Lia's existing atlas.
Geometry, UV, normals, neck and unselected atlas pixels are preserved.
"""
import argparse, hashlib, json, math, sys
from pathlib import Path
import bpy, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);assert not a.output.exists();a.output.mkdir(parents=True)
plan=json.loads((a.source/'projection.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str((a.source/'baseline.blend').resolve()))
scene=bpy.context.scene;body=bpy.data.objects[plan['body']];mesh=body.data
assert len(mesh.materials)==1
assert body.matrix_world==__import__('mathutils').Matrix.Identity(4)
uvname=mesh.uv_layers.active.name

def signature(obj):
    h=hashlib.sha256()
    for v in obj.data.vertices:h.update(np.asarray(v.co,dtype=np.float32).tobytes())
    for f in obj.data.polygons:h.update(np.asarray(f.vertices,dtype=np.int32).tobytes())
    for uv in obj.data.uv_layers.active.data:h.update(np.asarray(uv.uv,dtype=np.float32).tobytes())
    for n in obj.data.corner_normals:h.update(np.asarray(n.vector,dtype=np.float32).tobytes())
    return h.hexdigest()
before={o.name:signature(o) for o in scene.objects if o.type=='MESH'}
mat=mesh.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links
shader=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
original=shader.inputs['Base Color'].links[0].from_node.image
pixels=np.empty(len(original.pixels),dtype=np.float32);original.pixels.foreach_get(pixels)
pixels=pixels.reshape(original.size[1],original.size[0],4)
width,height=original.size
points=[];triangles=[]
for obj in [o for o in scene.objects if o.type=='MESH']:
    start=len(points);points.extend(obj.matrix_world@v.co for v in obj.data.vertices)
    obj.data.calc_loop_triangles();triangles.extend(tuple(start+i for i in t.vertices) for t in obj.data.loop_triangles)
tree=BVHTree.FromPolygons(points,triangles,all_triangles=True)
color_socket=shader.inputs['Base Color'].links[0].from_socket
patches=[];masks=[];maxmask=None
# Preserve eyes, lashes, brows, nose and mouth in the existing front repair.
protected={'right':[(245,380,445,547),(240,495,379,710)],'left':[(560,380,754,560),(663,510,790,713)]}
for view,params in plan['views'].items():
    image=bpy.data.images.load(str((a.source/(view+'_repair.png')).resolve()))
    direction=Vector(params['eye_direction']);horizontal=Vector(params['horizontal_axis']);center=Vector(plan['center']);span=plan['span']
    uv=mesh.uv_layers.new(name='Projection_'+view);mask=mesh.color_attributes.new(name='VisiblePatch_'+view,type='FLOAT_COLOR',domain='CORNER')
    selected=[]
    for f in mesh.polygons:
        point=f.center
        hit,normal,index,distance=tree.ray_cast(point+direction*4,-direction,8)
        visible=hit is not None and (hit-point).length<.005
        original_uv=sum((mesh.uv_layers[uvname].data[i].uv for i in f.loop_indices),Vector((0,0)))/len(f.loop_indices)
        rgb=pixels[min(height-1,max(0,int(original_uv.y*height))),min(width-1,max(0,int(original_uv.x*width))),:3]
        skin_or_hair=rgb[0]>.22 and rgb[0]>rgb[2]*1.12
        corner_normal=sum((mesh.corner_normals[i].vector for i in f.loop_indices),Vector()).normalized()
        facing=max(0,min(1,(corner_normal.dot(direction)-.15)/.35))
        # The cheek has closely overlapping source layers with contrary face
        # normals. Paint the bounded skin layer on its own side too; do not
        # broaden visibility globally or project hair colour across the face.
        side=1 if view=='right' else -1
        cheek=(point.x*side>.012 and 1.63<point.z<1.735 and point.y<.015 and rgb[0]>.5 and rgb[2]/rgb[0]>.58 and rgb[1]/rgb[0]>.58)
        if cheek: visible=True;facing=1.0
        touched=False
        for loop in f.loop_indices:
            point=mesh.vertices[mesh.loops[loop].vertex_index].co
            u=.5+(point-center).dot(horizontal)/span;v=.5+(point.z-center.z)/span
            uv.data[loop].uv=(u,v)
            factor=facing if visible and skin_or_hair else 0
            if cheek: factor*=max(0,min(1,(point.x*side-.012)/.025))
            factor*=max(0,min(1,(point.z-1.58)/.035,(1.98-point.z)/.025))
            x,y=u*1024,(1-v)*1024
            for x0,y0,x1,y1 in protected[view]:
                distance=max(x0-x, x-x1, y0-y, y-y1)
                factor*=max(0,min(1,distance/12))
            mask.data[loop].color=(factor,factor,factor,1)
            touched=touched or factor>0
        if touched:selected.append(f.index)
    tex=nodes.new('ShaderNodeTexImage');tex.image=image
    uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map=uv.name;links.new(uvnode.outputs[0],tex.inputs['Vector'])
    attribute=nodes.new('ShaderNodeVertexColor');attribute.layer_name=mask.name
    alpha=nodes.new('ShaderNodeMath');alpha.operation='MULTIPLY';links.new(attribute.outputs['Color'],alpha.inputs[0]);links.new(tex.outputs['Alpha'],alpha.inputs[1])
    mix=nodes.new('ShaderNodeMixRGB');links.new(alpha.outputs[0],mix.inputs[0]);links.new(color_socket,mix.inputs[1]);links.new(tex.outputs['Color'],mix.inputs[2]);color_socket=mix.outputs[0]
    if maxmask is None:maxmask=alpha.outputs[0]
    else:
        maximum=nodes.new('ShaderNodeMath');maximum.operation='MAXIMUM';links.new(maxmask,maximum.inputs[0]);links.new(alpha.outputs[0],maximum.inputs[1]);maxmask=maximum.outputs[0]
    masks.append((uv.name,mask.name))
    patches.append({'view':view,'selected_faces':selected,'image_size':list(image.size),'image_sha256':hashlib.sha256((a.source/(view+'_repair.png')).read_bytes()).hexdigest(),'protected_rectangles':protected[view]})
mesh.uv_layers.active=mesh.uv_layers[uvname];mesh.uv_layers[uvname].active_render=True
emission=nodes.new('ShaderNodeEmission');links.new(color_socket,emission.inputs[0]);links.new(emission.outputs[0],output.inputs['Surface'])
bake=bpy.data.images.new('LiaSideColorBake',width=width,height=height,alpha=True);bake.colorspace_settings.name='sRGB'
target=nodes.new('ShaderNodeTexImage');target.image=bake;nodes.active=target
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1;scene.render.bake.margin=8;scene.render.bake.margin_type='EXTEND'
bpy.ops.object.bake(type='EMIT',use_clear=True)
colour=np.empty(len(bake.pixels),dtype=np.float32);bake.pixels.foreach_get(colour);colour=colour.reshape(height,width,4)
mask_image=bpy.data.images.new('LiaSideMaskBake',width=width,height=height,alpha=True);mask_image.colorspace_settings.name='Non-Color'
target.image=mask_image;links.new(maxmask,emission.inputs[0]);bpy.ops.object.bake(type='EMIT',use_clear=True)
coverage=np.empty(len(mask_image.pixels),dtype=np.float32);mask_image.pixels.foreach_get(coverage);coverage=coverage.reshape(height,width,4)[:,:,0]
selected_pixels=coverage>1e-5
result=pixels.copy();result[selected_pixels]=colour[selected_pixels];result[:,:,3]=pixels[:,:,3]
assert np.array_equal(result[~selected_pixels],pixels[~selected_pixels])
final=bpy.data.images.new('LiaSideRepairedAlbedo',width=width,height=height,alpha=True);final.colorspace_settings.name='sRGB';final.pixels.foreach_set(result.ravel())
final.filepath_raw=str((a.output/'albedo.png').resolve());final.file_format='PNG';final.save();final.pack()
target.image=final;links.new(target.outputs['Color'],shader.inputs['Base Color']);links.new(shader.outputs[0],output.inputs['Surface'])
for n in list(nodes):
    if n not in [shader,output,target]:nodes.remove(n)
for uv,mask in masks:mesh.uv_layers.remove(mesh.uv_layers[uv]);mesh.color_attributes.remove(mesh.color_attributes[mask])
mesh.uv_layers.active=mesh.uv_layers[uvname]
after={o.name:signature(o) for o in scene.objects if o.type=='MESH'}
assert before==after,'Colour bake changed geometry/UV/normals'
for image in list(bpy.data.images):
    if image.users==0 and image.type!='RENDER_RESULT':bpy.data.images.remove(image)
meshes=[o for o in scene.objects if o.type=='MESH'];triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in meshes)
assert triangles==12554
for obj in meshes:obj.select_set(True)
bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
native=a.output/'lia_side_surface.blend';glb=a.output/'lia_side_surface.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,export_animations=False)
receipt={'method':'Two original orthographic views, built-in imagegen repairs, depth-occluded visible surface masks, protected original face features, original UV emission bake; untouched atlas pixels preserved in memory','triangles':triangles,'geometry_uv_normals_unchanged':before==after,'signatures':after,'patches':patches,'patched_pixels':int(selected_pixels.sum()),'total_pixels':width*height,'bounded_cheek_layer_repair':True,'static_only':True,'visual_gate':'PENDING','source_sha256':hashlib.sha256((a.source/'baseline.blend').read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest()}
(a.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
# Native lit views, not edited screenshots, for judging actual reprojection.
scene.cycles.samples=8;scene.render.resolution_x=scene.render.resolution_y=640
scene.render.film_transparent=False;scene.view_settings.view_transform='AgX'
background=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND');background.inputs['Color'].default_value=(.12,.16,.2,1);background.inputs['Strength'].default_value=.7
cam=bpy.data.objects.new('SideRepairReview',bpy.data.cameras.new('SideRepairReview'));scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=.58
center=Vector((0,0,1.72))
for idx,(position,power) in enumerate([((2,-3,4),350),((-2,1,3),160)]):
    data=bpy.data.lights.new('ReviewLight'+str(idx),'AREA');data.energy=power;data.size=3
    obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj);obj.location=position;obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
for view,degrees in [('front',0),('right',65),('left',-65),('back',180)]:
    theta=math.radians(degrees);cam.location=center+Vector((math.sin(theta)*3,-math.cos(theta)*3,0));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(view+'.png')).resolve());bpy.ops.render.render(write_still=True)
print('LIA_SIDE_SURFACE_RESULT',json.dumps({'triangles':triangles,'patched_pixels':int(selected_pixels.sum()),'geometry_uv_normals_unchanged':before==after}),flush=True)
