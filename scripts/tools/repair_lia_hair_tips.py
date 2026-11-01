"""Repair selected Lia hair tips in a copy; bake only their material to glTF."""
import argparse, hashlib, json, sys, math
from pathlib import Path
import bpy
from mathutils import Vector
from mathutils.geometry import intersect_ray_tri
sys.path.insert(0,str(Path(__file__).resolve().parent))
from calibrate_corner_normal_codes import calibrate
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--selection',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);sha=hashlib.sha256(a.input.read_bytes()).hexdigest()
assert sha=='9d0a72d8642bef5799e691a1c5e64aa33ac87bf4e6853cd439b26c92cb4cfe98'
if a.output.exists():raise FileExistsError('Preserve previous candidates')
selection=json.loads(a.selection.read_text());assert selection['source_sha256']==sha
selected=set(selection['faces']);assert len(selected)==336
out=a.output.resolve();out.mkdir(parents=True)
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
o=bpy.data.objects['LiaRetainedAuthoredNeckSurface'];m=o.data;collar=bpy.data.objects['LiaAuthoredCollar'].data
original=[v.co.copy() for v in m.vertices];uvs=[tuple(d.uv) for d in m.uv_layers.active.data];normals=[n.vector.copy() for n in m.corner_normals]
protected={ob.name:[tuple(v.co) for v in ob.data.vertices] for ob in bpy.context.scene.objects if ob.type=='MESH' and ob!=o}
incident={i:set() for i in range(len(m.vertices))}
for f in m.polygons:
 for v in f.vertices:incident[v].add(f.index)
# Real triangle/segment intersections, not BVH overlap counts alone.
def intersections():
 m.calc_loop_triangles();collar.calc_loop_triangles()
 ts=[(t.polygon_index,[m.vertices[i].co.copy() for i in t.vertices]) for t in m.loop_triangles if t.polygon_index in selected]
 cs=[[collar.vertices[i].co.copy() for i in t.vertices] for t in collar.loop_triangles]
 def crosses(first,second):
  for i in range(3):
   start=first[i];delta=first[(i+1)%3]-start;length=delta.length
   if length<1e-9:continue
   hit=intersect_ray_tri(*second,delta.normalized(),start,True)
   if hit is not None and 1e-6<(hit-start).dot(delta.normalized())<length-1e-6:return True
  return False
 pairs=[]
 for face,t in ts:
  for j,c in enumerate(cs):
   if any(max(v[k] for v in t)<min(v[k] for v in c)-1e-6 or max(v[k] for v in c)<min(v[k] for v in t)-1e-6 for k in range(3)):continue
   if crosses(t,c) or crosses(c,t):pairs.append([face,j])
 return pairs
before_cross=intersections();assert len(before_cross)==117;old_face_normals=[f.normal.copy() for f in m.polygons];moved=[]
# Keep roots/boundaries fixed. Fan the side tips clear of the standing collar.
for v in m.vertices:
 co=original[v.index]
 if not incident[v.index] or not incident[v.index].issubset(selected) or co.z>=1.72:continue
 t=max(0,min(1,(1.72-co.z)/.115));weight=t*t*(3-2*t)
 if abs(co.x)>.065 and co.y<.075:
  v.co.x += math.copysign(.048*weight,co.x)
 elif co.y>=.075:
  v.co.y += .014*weight
 if (v.co-co).length>1e-8:moved.append(v.index)
# Lift only four buried inner-strand vertices above the collar rim.
inner_vertices=[5901,5907,5912,5918]
for idx in inner_vertices:
 assert incident[idx].issubset(selected | {4223,4224,4990}) # Three hidden rear-head underside faces share vertex 5901.
 m.vertices[idx].co.z=max(m.vertices[idx].co.z,1.675)
 if idx not in moved:moved.append(idx)
m.update()
# Preserve original custom normals outside the affected hair; update deformed faces.
desired=list(normals)
for f in m.polygons:
 for li in f.loop_indices:
  idx=m.loops[li].vertex_index
  if idx not in moved:continue
  if idx in inner_vertices:
   desired[li]=old_face_normals[f.index].rotation_difference(f.normal) @ normals[li]
  else:
   co=original[idx];n=normals[li];t=max(0,min(1,(1.72-co.z)/.115));derivative=-6*t*(1-t)/.115
   dx=math.copysign(.048,co.x)*derivative if abs(co.x)>.065 and co.y<.075 else 0
   dy=.014*derivative if co.y>=.075 else 0
   desired[li]=Vector((n.x,n.y,n.z-dx*n.x-dy*n.y)).normalized()
m.normals_split_custom_set(desired);normal_result=calibrate(m,desired)
after_cross=intersections();assert not after_cross
assert [tuple(d.uv) for d in m.uv_layers.active.data]==uvs
assert all(v.co==original[v.index] for v in m.vertices if v.index not in moved)
for name,coords in protected.items():assert [tuple(v.co) for v in bpy.data.objects[name].data.vertices]==coords
# Bake a portable material on a temporary mesh containing ONLY the reviewed faces.
# The source texture and face/eye atlas remain untouched.
mesh=bpy.data.meshes.new('HairBakeOnly');faces=[tuple(m.polygons[i].vertices) for i in sorted(selected)]
mesh.from_pydata([tuple(v.co) for v in m.vertices],[],faces);mesh.update();uv=mesh.uv_layers.new(name='UVMap')
for dst,idx in zip(mesh.polygons,sorted(selected)):
 for li,source_li in zip(dst.loop_indices,m.polygons[idx].loop_indices):uv.data[li].uv=m.uv_layers.active.data[source_li].uv
baker=bpy.data.objects.new('HairBakeOnly',mesh);bpy.context.scene.collection.objects.link(baker)
mat=bpy.data.materials.new('LiaHairBake');mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
source=next(n.image for n in m.materials[0].node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
tex=nodes.new('ShaderNodeTexImage');tex.image=source
luma=nodes.new('ShaderNodeRGBToBW');links.new(tex.outputs['Color'],luma.inputs[0])
ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=0;ramp.color_ramp.elements[0].color=(.28,.16,.055,1);ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(.78,.56,.24,1);links.new(luma.outputs[0],ramp.inputs[0])
geo=nodes.new('ShaderNodeNewGeometry');xyz=nodes.new('ShaderNodeSeparateXYZ');links.new(geo.outputs['Position'],xyz.inputs[0])
blend=nodes.new('ShaderNodeMapRange');blend.clamp=True;blend.inputs['From Min'].default_value=1.66;blend.inputs['From Max'].default_value=1.735;blend.inputs['To Min'].default_value=1;blend.inputs['To Max'].default_value=0;links.new(xyz.outputs['Z'],blend.inputs['Value'])
mix=nodes.new('ShaderNodeMixRGB');links.new(blend.outputs[0],mix.inputs[0]);links.new(tex.outputs['Color'],mix.inputs[1]);links.new(ramp.outputs[0],mix.inputs[2])
emit=nodes.new('ShaderNodeEmission');links.new(mix.outputs[0],emit.inputs['Color']);output=nodes.new('ShaderNodeOutputMaterial');links.new(emit.outputs[0],output.inputs[0]);mesh.materials.append(mat)
image=bpy.data.images.new('LiaHairTipsAlbedo',2048,2048,alpha=False);image.colorspace_settings.name='sRGB';target=nodes.new('ShaderNodeTexImage');target.image=image;nodes.active=target
bpy.ops.object.select_all(action='DESELECT');baker.select_set(True);bpy.context.view_layer.objects.active=baker
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=1;scene.render.bake.margin=12;scene.render.bake.margin_type='EXTEND'
bpy.ops.object.bake(type='EMIT',use_clear=True)
image.filepath_raw=str(out/'lia_hair_tips_albedo.png');image.file_format='PNG';image.save();image.pack()
bpy.data.objects.remove(baker,do_unlink=True)
clean=bpy.data.materials.new('LiaHairTips');clean.use_nodes=True;bs=next(n for n in clean.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.85;im=clean.node_tree.nodes.new('ShaderNodeTexImage');im.image=image;clean.node_tree.links.new(im.outputs['Color'],bs.inputs['Base Color']);m.materials.append(clean)
for i in selected:m.polygons[i].material_index=len(m.materials)-1
objects=[ob for ob in scene.objects if ob.type=='MESH'];triangles=sum(sum(len(f.vertices)-2 for f in ob.data.polygons) for ob in objects);assert triangles==11492
bpy.ops.object.select_all(action='DESELECT')
for ob in objects:ob.select_set(True)
bpy.context.view_layer.objects.active=o;bpy.context.preferences.filepaths.file_preview_type='NONE';bpy.ops.file.pack_all()
blend_path=out/'lia_hair_repaired.blend';glb=out/'lia_hair_repaired.glb';bpy.ops.wm.save_as_mainfile(filepath=str(blend_path));bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_animations=False)
assert hashlib.sha256(a.input.read_bytes()).hexdigest()==sha
receipt={'source_sha256':sha,'selection_sha256':hashlib.sha256(a.selection.read_bytes()).hexdigest(),'selected_faces':len(selected),'moved_vertices':len(moved),'maximum_displacement_m':max((m.vertices[i].co-original[i]).length for i in moved),'protected_objects':list(protected),'shared_rear_head_faces':[4223,4224,4990],'inner_strand_vertices':inner_vertices,'uv_unchanged':True,'hair_collar_intersections_before':before_cross,'hair_collar_intersections_after':after_cross,'normal_calibration':normal_result,'triangles':triangles,'texture_size':[2048,2048],'blend_sha256':hashlib.sha256(blend_path.read_bytes()).hexdigest(),'glb_sha256':hashlib.sha256(glb.read_bytes()).hexdigest(),'rigged':False,'formal_integrated':False}
(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('HAIR_RESULT',json.dumps(receipt))