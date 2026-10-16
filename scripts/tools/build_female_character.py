import bpy, math, json, bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/female'; OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'assets/source/female'; SOURCE.mkdir(parents=True,exist_ok=True); (SOURCE/'.gdignore').write_text('')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'artifacts/female_character/source.blend'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=obj; bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
obj.data.calc_loop_triangles(); source_tris=len(obj.data.loop_triangles)
lo=min(v.co.z for v in obj.data.vertices); height=max(v.co.z for v in obj.data.vertices)-lo
for v in obj.data.vertices: v.co=Vector((v.co.x,v.co.y,v.co.z-lo))*(1.95/height)
remesh=obj.modifiers.new('CleanSurface','REMESH'); remesh.mode='VOXEL'; remesh.voxel_size=.008; remesh.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=remesh.name)
# Cut the generated ground fragment only after voxel reconstruction, then cap soles.
bm=bmesh.new(); bm.from_mesh(obj.data)
bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),plane_co=(0,0,.035),plane_no=(0,0,1),clear_inner=True,dist=.00001)
boundaries=[e for e in bm.edges if e.is_boundary]
if boundaries: bmesh.ops.holes_fill(bm,edges=boundaries,sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
for v in bm.verts: v.co.z-=.035
bm.to_mesh(obj.data); bm.free()
obj.data.calc_loop_triangles()
mod=obj.modifiers.new('GameBudget','DECIMATE'); mod.ratio=4200/len(obj.data.loop_triangles)
bpy.ops.object.modifier_apply(modifier=mod.name)
palette={'skin':(.88,.63,.43),'hair':(.95,.69,.30),'purple':(.32,.13,.48),'cloth':(.045,.036,.038),'leather':(.17,.075,.035),'gold':(.65,.35,.06),'ivory':(.81,.72,.53)}
obj.data.materials.clear()
for name,c in palette.items():
 m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); obj.data.materials.append(m)
keys=list(palette)
for p in obj.data.polygons:
 x,y,z=sum((obj.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
 ax=abs(x); name='cloth'
 if z>1.81: name='hair'
 elif z>1.57: name='skin' if y<-.025 and ax<.17 else 'hair'
 elif z>1.01:
  name='purple'
  if ax<.085 and y<-.10: name='ivory'
  if z>1.49 and ax<.09: name='skin'
 elif z>.83:
  name='purple' if ax>.11 or y>.03 else 'cloth'
 if ax>.30 and 1.13<z<1.24: name='ivory'
 if ax>.37 and 1.01<z<1.15: name='skin'
 if ax>.43 and .82<z<1.04: name='leather'
 if ax>.56 and z<.88: name='skin'
 if 1.005<z<1.07 and ax<.32: name='leather'
 if 1.01<z<1.06 and ax<.07 and y<-.11: name='gold'
 if z<.38: name='leather'
 if .33<z<.41: name='leather'
 p.material_index=keys.index(name); p.use_smooth=True
# Interpolated vertex color avoids jagged material boundaries on reduced triangles.
attr=obj.data.color_attributes.new(name='HeroColor',type='FLOAT_COLOR',domain='POINT')
for v in obj.data.vertices:
 adjacent=[p for p in obj.data.polygons if v.index in p.vertices]
 colors=[palette[keys[p.material_index]] for p in adjacent]
 c=tuple(sum(c[i] for c in colors)/len(colors) for i in range(3)) if colors else palette['cloth']
 attr.data[v.index].color=(*c,1)
mat=bpy.data.materials.new('HeroPalette'); mat.use_nodes=True
node=mat.node_tree.nodes.new('ShaderNodeVertexColor'); node.layer_name='HeroColor'
mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
obj.data.materials.clear(); obj.data.materials.append(mat)
for p in obj.data.polygons: p.material_index=0
obj.data.validate(clean_customdata=True)
obj.name='LiaBody'
bpy.context.scene.display.shading.color_type='VERTEX'
# Seven-bone lightweight rig: low amplitude representative motions, no auto-weight claim.
bpy.ops.object.armature_add(); rig=bpy.context.object; rig.name='LiaRig'
bpy.ops.object.mode_set(mode='EDIT'); rig.data.edit_bones.remove(rig.data.edit_bones[0])
spec={'Root':((0,0,0),(0,0,1)), 'Torso':((0,0,1),(0,0,1.5)), 'Head':((0,0,1.52),(0,0,1.8)), 'ArmLeft':((.29,0,1.4),(.63,0,.85)), 'ArmRight':((-.29,0,1.4),(-.63,0,.85)), 'LegLeft':((.16,0,.95),(.23,0,.12)), 'LegRight':((-.16,0,.95),(-.23,0,.12))}
for name,(head,tail) in spec.items():
 b=rig.data.edit_bones.new(name); b.head=head; b.tail=tail
 if name!='Root': b.parent=rig.data.edit_bones['Root']
bpy.ops.object.mode_set(mode='OBJECT')
for name in spec: obj.vertex_groups.new(name=name)
for v in obj.data.vertices:
 x,y,z=v.co; ax=abs(x)
 name='Head' if z>1.52 else ('ArmLeft' if x>0 else 'ArmRight') if ax>.30 and z>.78 else ('LegLeft' if x>0 else 'LegRight') if z<.96 else 'Torso'
 obj.vertex_groups[name].add([v.index],1,'REPLACE')
obj.parent=rig; mod=obj.modifiers.new('Skin','ARMATURE'); mod.object=rig
extras=[]
for x in [-.065,.065]:
 hit,loc,normal,face=obj.ray_cast(Vector((x,-2,1.715)),Vector((0,1,0)))
 if hit:
  for name,color,scale,dy in [('EyeWhite',(.9,.86,.77),(.034,.006,.022),.001),('Iris',(.015,.25,.7),(.014,.003,.018),-.006)]:
   bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,location=(x,loc.y+dy,1.715))
   eye=bpy.context.object; eye.name=name; eye.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
   material=bpy.data.materials.new(name); material.diffuse_color=(*color,1); material.use_nodes=True; material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
   eye.data.materials.append(material); eye.parent=rig; eye.vertex_groups.new(name='Head').add(list(range(len(eye.data.vertices))),1,'REPLACE'); arm=eye.modifiers.new('Skin','ARMATURE'); arm.object=rig; extras.append(eye)
# Cream lapel piping and gold belt buckle follow the actual front surface.
def ornament(o, name, color, bone='Torso'):
 o.name=name
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
 m.diffuse_color=(*color,1); m.use_nodes=True; m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
 o.data.materials.append(m); o.parent=rig
 o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1,'REPLACE')
 a=o.modifiers.new('Skin','ARMATURE'); a.object=rig; extras.append(o)
def surface(x,z):
 hit,p,_,_=obj.ray_cast(Vector((x,-2,z)),Vector((0,1,0)))
 return p+Vector((0,-.008,0)) if hit else None
for sign in [-1,1]:
 points=[surface(sign*x,z) for x,z in [(.075,1.51),(.15,1.44),(.105,1.33),(.085,1.12)]]
 for a,b in zip(points,points[1:]):
  if a is None or b is None: continue
  bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.008,depth=(b-a).length,location=(a+b)/2)
  o=bpy.context.object; o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); ornament(o,'CreamPiping',palette['ivory'])
p=surface(0,1.04)
if p is not None:
 for dx,dz,sx,sz in [(0,.035,.10,.012),(0,-.035,.10,.012),(-.045,0,.012,.07),(.045,0,.012,.07)]:
  bpy.ops.mesh.primitive_cube_add(size=1,location=p+Vector((dx,-.008,dz)))
  o=bpy.context.object; o.scale=(sx,.012,sz); ornament(o,'BuckleGold',palette['gold'])
obj.data.calc_loop_triangles(); tris=len(obj.data.loop_triangles)
for eye in extras: eye.data.calc_loop_triangles(); tris+=len(eye.data.loop_triangles)
assert tris<=5000,tris
bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); rig.select_set(True)
for eye in extras: eye.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'lia_user.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'lia_user.blend'))
(OUT/'report.json').write_text(json.dumps({'triangles':tris,'source_triangles':source_tris,'materials':keys,'bones':list(spec),'rig':'Rigid regional weights; limited amplitude procedural motion'},indent=2))
scene=bpy.context.scene
for name in ['front','back','side']:
 direction={'front':(0,-1,0),'back':(0,1,0),'side':(1,0,0)}[name]
 cam=scene.camera; cam.location=Vector((0,0,.975))+Vector(direction)*6; cam.rotation_euler=(Vector((0,0,.975))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=2.2
 scene.render.filepath=str(ROOT/'artifacts/female_character'/('colored_'+name+'.png')); bpy.ops.render.render(write_still=True)
