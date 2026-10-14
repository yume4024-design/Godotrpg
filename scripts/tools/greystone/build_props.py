"""Run with Blender --background --factory-startup --python build_props.py.
Reuses G05 primitives and G02 meshes; exports 17 flat-shaded, texture-free props.
"""
from pathlib import Path
import bpy, math, json, re
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/models/greystone/props'; OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'source_assets/greystone_g04'; SOURCE.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').write_text('')
MAT=ROOT/'assets/materials/greystone/props'; MAT.mkdir(parents=True,exist_ok=True)
palette={'wood':(.43,.29,.16),'stone':(.60,.59,.51),'water':(.12,.24,.28),
 'leaf':(.24,.43,.24),'leaf_light':(.42,.57,.28),'flower':(.87,.57,.58),
 'gold':(.95,.72,.30),'iron':(.27,.31,.33),'crystal':(.22,.64,.86)}
materials={}
for name,rgb in palette.items():
 m=bpy.data.materials.new('G04_'+name); m.diffuse_color=(*rgb,1)
 m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF')
 bs.inputs['Base Color'].default_value=(*(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb),1)
 bs.inputs['Roughness'].default_value=.9
 materials[name]=m
 (MAT/(name+'.tres')).write_text('[gd_resource type="StandardMaterial3D" format=3]\n[resource]\nresource_name = "G04_'+name+'"\nalbedo_color = Color('+','.join(map(str,rgb))+',1)\nroughness = 0.9\n')

def clear():
 for o in list(bpy.data.objects): bpy.data.objects.remove(o,do_unlink=True)
def finish(o,mat):
 o.data.materials.clear(); o.data.materials.append(materials[mat]); return o
def box(pos,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0],-pos[2],pos[1]))
 o=bpy.context.object; o.scale=(size[0],size[2],size[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,mat)
def cone(pos,r,h,mat,top=0,verts=8):
 bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=top,depth=h,location=(pos[0],-pos[2],pos[1]))
 return finish(bpy.context.object,mat)
def ball(pos,scale,mat):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(pos[0],-pos[2],pos[1]))
 o=bpy.context.object;o.scale=(scale[0],scale[2],scale[1]);return finish(o,mat)
def nearest(rgb): return min(palette,key=lambda k:sum((a-b)**2 for a,b in zip(palette[k],rgb)))
def reuse_placeholder(name):
 text=(ROOT/f'scenes/world/greystone/placeholders/{name}.tscn').read_text()
 resources={m[1]:m[2] for m in re.findall(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]([^\[]*)',text)}
 types={m[1]:m[0] for m in re.findall(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]([^\[]*)',text)}
 def vec(s,key,default=(0,0,0)):
  m=re.search(key+r' = Vector3\(([^)]+)\)',s); return tuple(map(float,m[1].split(','))) if m else default
 for header,body in re.findall(r'(\[node[^\]]+\])([^\[]*)',text):
  mesh=re.search(r'mesh = SubResource\("([^"]+)"\)',body)
  if not mesh: continue
  g=resources[mesh[1]]; pos=vec(body,'position')
  parent=re.search(r'parent="([^"]+)"',header)[1]
  if parent!='.':
   node=re.search(r'\[node name="'+re.escape(parent)+r'"[^\]]*\]([^\[]*)',text)
   pos=vec(node[1],'position')
  mid=re.search(r'material = SubResource\("([^"]+)"\)',g)[1]
  rgb=tuple(map(float,re.search(r'Color\(([^)]+)\)',resources[mid])[1].split(',')[:3])); mat=nearest(rgb)
  if types[mesh[1]]=='CylinderMesh':
   val=lambda key:float(re.search(key+r' = ([\d.]+)',g)[1])
   cone(pos,val('bottom_radius'),val('height'),mat,val('top_radius'),12)
  else: box(pos,vec(g,'size'),mat)
def reuse_mesh(file,size,mat):
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/greystone/terrain'/file))
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 coords=[o.matrix_world@Vector(v) for o in meshes for v in o.bound_box]
 lo=Vector(tuple(min(v[i] for v in coords) for i in range(3))); hi=Vector(tuple(max(v[i] for v in coords) for i in range(3)))
 center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)); target=(size[0],size[2],size[1])
 for o in meshes:
  for v in o.data.vertices:
   p=o.matrix_world@v.co-center
   v.co=Vector(tuple(p[i]*target[i]/(hi[i]-lo[i]) for i in range(3)))
  o.matrix_world.identity();finish(o,mat)

metrics=[]
def export(name,source):
 bpy.ops.object.select_all(action='DESELECT')
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for o in meshes:o.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();o=bpy.context.object
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 o.name=name;o.data.name=name
 o.data.calc_loop_triangles()
 count=len(o.data.loop_triangles)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
 metrics.append({'name':name,'triangles':count,'source':source})

for name,old in [('stone_well','well'),('wooden_bridge','bridge_deck'),('wooden_dock','dock_deck'),('wooden_fence','fence'),('lamp_post','lamp'),('wooden_sign','sign')]:
 clear();reuse_placeholder(old)
 if name=='wooden_bridge':
  for z in [-3,3]: box((0,.6,z),(8,1.2,.25),'wood')
  for x in [-3.7,3.7]:box((x,-1.3,0),(.35,2.6,5.5),'wood')
 if name=='wooden_dock':
  for z in [-4,4]:box((0,.6,z),(4,1.2,.25),'wood')
  box((2,.6,0),(.25,1.2,8),'wood')
  for x in [-1.6,1.6]:
   for z in [-3.6,3.6]:box((x,-2,z),(.4,4,.4),'wood')
 export(name,'G05 '+old+' geometry reused'+('; G02 rails/supports reused for standalone deck' if name in ['wooden_bridge','wooden_dock'] else ''))
for name,size in [('pine_tree_a',(4.2,7,4.2)),('pine_tree_b',(3.5,8.5,3.5))]:
 clear();reuse_mesh('pinecontext.glb',size,'leaf' if name.endswith('a') else 'leaf_light');box((0,.8,0),(.5,1.6,.5),'wood');export(name,'G02 pinecontext reused with trunk')
for name,file,size in [('rock_small','riverrock0.glb',(1.2,.8,1)),('rock_medium','cliff2.glb',(2.5,1.8,2)),('rock_cliff','cliff0.glb',(6,4,5))]:
 clear();reuse_mesh(file,size,'stone');export(name,'G02 '+file+' reused')
clear()
for x,z in [(-.45,0),(.4,.2),(0,-.35)]:ball((x,.5,z),(.65,.6,.6),'leaf_light')
export('bush_a','Original procedural')
clear()
for x,z in [(-.4,0),(.4,.2),(0,-.4)]:
 cone((x,.2,z),.06,.4,'leaf',.04)
 for n in range(5):
  a=n*math.tau/5;ball((x+math.cos(a)*.16,.45,z+math.sin(a)*.16),(.15,.09,.15),'flower')
 ball((x,.48,z),(.09,.09,.09),'gold')
export('flower_a','Original procedural')
clear()
for n in range(5):cone(((n%3)*.2-.2,.25,(n//3)*.25),.1,.5,'leaf_light',0,4)
export('grass_a','Original procedural')
clear();cone((0,.6,0),.5,1.2,'wood',.45,10)
for y in [.18,1.02]:cone((0,y,0),.51,.1,'iron',.51,10)
export('barrel','Original procedural')
clear();box((0,.5,0),(1,1,1),'wood')
for x in [-.45,.45]:
 for z in [-.51,.51]:box((x,.5,z),(.12,1.05,.1),'gold')
export('crate','Original procedural')
clear()
for x,z,h in [(0,0,1.8),(.5,.2,1.1),(-.4,.1,.9)]:
 cone((x,h*.35,z),.3,h*.7,'crystal',.3,5)
 cone((x,h*.85,z),.3,h*.3,'crystal',0,5)
export('crystal_blue','Original procedural')
(SOURCE/'metrics.json').write_text(json.dumps(metrics,indent=2))
print('G04_EXPORT',len(metrics),'models',sum(m['triangles'] for m in metrics),'triangles')
