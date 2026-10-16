import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/hero'; OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'assets/source/hero'; SOURCE.mkdir(parents=True,exist_ok=True); (SOURCE/'.gdignore').write_text('')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'artifacts/hero_inspection/source.blend'))
obj=next(o for o in bpy.context.scene.objects if o.type=='MESH')
bpy.context.view_layer.objects.active=obj; bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True)
bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
lo=min(v.co.z for v in obj.data.vertices); height=max(v.co.z for v in obj.data.vertices)-lo
for v in obj.data.vertices: v.co=Vector((v.co.x,v.co.y,v.co.z-lo))*(1.95/height)
remesh=obj.modifiers.new('CleanSurface','REMESH'); remesh.mode='VOXEL'; remesh.voxel_size=.008; remesh.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=remesh.name)
obj.data.calc_loop_triangles()
mod=obj.modifiers.new('GameBudget','DECIMATE'); mod.ratio=4400/len(obj.data.loop_triangles)
bpy.ops.object.modifier_apply(modifier=mod.name)
palette={'skin':(.72,.40,.23),'hair':(.025,.022,.025),'red':(.34,.045,.038),'cloth':(.055,.049,.055),'leather':(.16,.075,.034),'metal':(.45,.38,.29),'cuff':(.48,.39,.29)}
obj.data.materials.clear()
for name,c in palette.items():
 m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True; m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1); m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.82; obj.data.materials.append(m)
keys=list(palette)
for p in obj.data.polygons:
 x,y,z=sum((obj.data.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)
 ax=abs(x); name='cloth'
 if z>1.79 or (z>1.73 and ax>.12): name='hair'
 elif z>1.64: name='skin' if y<.00 else 'hair'
 elif z>1.23:
  name='red'
  if ax<.12 and y<-.10: name='cloth'
  if z>1.56 and ax<.11 and y<-.06: name='skin'
 elif z>1.11: name='red' if ax>.27 else 'cloth'
 if ax>.33 and .99<z<1.28: name='cuff' if z>1.19 else 'skin'
 if ax>.47 and z<1.02: name='leather' if z>.87 else 'skin'
 if .99<z<1.08 and ax<.30: name='leather'
 if .91<z<1.09 and x<-.27: name='leather'
 if z<.40: name='leather'
 if .66<z<.82 and x>.22 and y<-.05: name='leather'
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
obj.name='RenBody'
bpy.context.scene.display.shading.color_type='VERTEX'
# Seven-bone lightweight rig: low amplitude representative motions, no auto-weight claim.
bpy.ops.object.armature_add(); rig=bpy.context.object; rig.name='RenRig'
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
  for name,color,scale,dy in [('EyeWhite',(.8,.74,.62),(.032,.014,.026),-.008),('Iris',(.035,.018,.01),(.015,.008,.021),-.023)]:
   bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,location=(x,loc.y+dy,1.715))
   eye=bpy.context.object; eye.name=name; eye.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
   material=bpy.data.materials.new(name); material.diffuse_color=(*color,1); material.use_nodes=True; material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
   eye.data.materials.append(material); eye.parent=rig; eye.vertex_groups.new(name='Head').add(list(range(len(eye.data.vertices))),1,'REPLACE'); arm=eye.modifiers.new('Skin','ARMATURE'); arm.object=rig; extras.append(eye)
obj.data.calc_loop_triangles(); tris=len(obj.data.loop_triangles)
for eye in extras: eye.data.calc_loop_triangles(); tris+=len(eye.data.loop_triangles)
assert tris<=5000,tris
bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); rig.select_set(True)
for eye in extras: eye.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'ren_user.glb'),export_format='GLB',use_selection=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'ren_user.blend'))
(OUT/'report.json').write_text(json.dumps({'triangles':tris,'source_triangles':1112602,'materials':keys,'bones':list(spec),'rig':'Rigid regional weights; limited amplitude procedural motion'},indent=2))
scene=bpy.context.scene
for name in ['front','back','side']:
 direction={'front':(0,-1,0),'back':(0,1,0),'side':(1,0,0)}[name]
 cam=scene.camera; cam.location=Vector((0,0,.975))+Vector(direction)*6; cam.rotation_euler=(Vector((0,0,.975))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.ortho_scale=2.2
 scene.render.filepath=str(ROOT/'artifacts/hero_inspection'/('colored_'+name+'.png')); bpy.ops.render.render(write_still=True)
