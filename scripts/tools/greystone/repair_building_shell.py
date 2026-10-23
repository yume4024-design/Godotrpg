"""Add an inset plaster backing shell to generated facade gaps, keeping originals."""
import bpy,json,argparse,sys,statistics,numpy as np
from pathlib import Path
from mathutils import Vector
parser=argparse.ArgumentParser();parser.add_argument('--asset',required=True)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'source_assets/greystone_ai_20261023'/args.asset/'pixal_candidate_01'
OUT=BASE/'shell_repair02';OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/f'{args.asset}_review.blend'))
scene=bpy.context.scene;meshes=[o for o in scene.objects if o.type=='MESH']
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in corners) for i in range(3)]);hi=Vector([max(v[i] for v in corners) for i in range(3)])
w,d,h=hi-lo;deps=bpy.context.evaluated_depsgraph_get();front=[];back=[]
for x in [-w*.28,0,w*.28]:
    for z in [h*.22,h*.36,h*.46]:
        for origin,direction,result in [(Vector((x,-d*2,z)),Vector((0,1,0)),front),(Vector((x,d*2,z)),Vector((0,-1,0)),back)]:
            hit,p,*_=scene.ray_cast(deps,origin,direction)
            if hit:result.append(p.y)
if len(front)<4 or len(back)<4:raise RuntimeError('Facade sampling insufficient')
y0=statistics.median(front)+.40;y1=statistics.median(back)-.40
if y1<=y0:raise RuntimeError('Invalid backing shell bounds')
material=bpy.data.materials.new('AuthoredInsetPlaster');material.use_nodes=True
material.diffuse_color=(.66,.57,.40,1)
bsdf=material.node_tree.nodes['Principled BSDF'];bsdf.inputs['Base Color'].default_value=material.diffuse_color;bsdf.inputs['Roughness'].default_value=.95
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,(y0+y1)/2,h*.285))
shell=bpy.context.object;shell.name='InsetPlasterBacking';shell.scale=(w*.78,y1-y0,h*.46)
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);shell.data.materials.append(material)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT')
meshes.append(shell)
roof_patches=0
if args.asset=='weapon_shop':
    # Read the existing atlas to locate the erroneous pale roof triangles; leave
    # the original image and UV untouched, assigning a matching local material.
    roof=bpy.data.materials.new('AuthoredTerracottaPatch');roof.use_nodes=True;roof.diffuse_color=(.29,.040,.008,1)
    roof.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=roof.diffuse_color
    roof.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    for obj in meshes[:-1]:
        mesh=obj.data;texture=next(n.image for m in mesh.materials if m and m.use_nodes for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image)
        tw,th=texture.size;pixels=np.empty(tw*th*4,dtype=np.float32);texture.pixels.foreach_get(pixels);pixels=pixels.reshape(th,tw,4)
        index=len(mesh.materials);mesh.materials.append(roof)
        for face in mesh.polygons:
            center=obj.matrix_world@face.center;normal=(obj.matrix_world.to_3x3()@face.normal).normalized()
            if not (2.15<center.z<3.85 and normal.z>.35):continue
            uv=sum((mesh.uv_layers.active.data[i].uv for i in face.loop_indices),Vector((0,0)))/len(face.loop_indices)
            color=pixels[int(uv.y*th)%th,int(uv.x*tw)%tw,:3]
            if float(color.min())>.18 and float(color.max()-color.min())<.28:face.material_index=index;roof_patches+=1
        del pixels
    iron=bpy.data.materials.new('AuthoredAnvilIron');iron.use_nodes=True;iron.diffuse_color=(.065,.075,.08,1)
    iron.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=iron.diffuse_color
    iron.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.72
    for name,pos,size in [('AnvilFoot',(.9,-2.03,.68),(.48,.35,.13)),('AnvilWaist',(.9,-2.03,.87),(.26,.25,.30)),('AnvilFace',(.9,-2.03,1.07),(.80,.38,.13))]:
        bpy.ops.mesh.primitive_cube_add(size=1,location=pos);part=bpy.context.object;part.name=name;part.scale=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);part.data.materials.append(iron)
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT');meshes.append(part)
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.17,radius2=.025,depth=.48,location=(1.50,-2.03,1.05),rotation=(0,1.5707963268,0))
    horn=bpy.context.object;horn.name='AnvilHorn';horn.data.materials.append(iron);meshes.append(horn)
if args.asset=='house_a':
    x=w*.39;depth=(y1-y0)/2;ym=(y0+y1)/2;z0=h*.50;z1=h*.76
    verts=[(side,y,z) for side in [-x,x] for y,z in [(ym-depth,z0),(ym+depth,z0),(ym,z1)]]
    data=bpy.data.meshes.new('InsetGableBacking');data.from_pydata(verts,[],[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]);data.update()
    gable=bpy.data.objects.new('InsetGableBacking',data);scene.collection.objects.link(gable);data.materials.append(material)
    bpy.ops.object.select_all(action='DESELECT');gable.select_set(True);bpy.context.view_layer.objects.active=gable
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT')
    meshes.append(gable)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/f'{args.asset}_repaired.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{args.asset}_repaired.blend'))
camera=scene.camera;center=Vector((0,0,h/2))
for name,offset in [('front',(0,-28,0)),('overview',(15,-20,15)),('back',(0,28,0))]:
    camera.location=center+Vector(offset);camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'{name}.png');bpy.ops.render.render(write_still=True)
(OUT/'repair_report.json').write_text(json.dumps({'front_samples':front,'back_samples':back,'shell_y':[y0,y1],'roof_patches':roof_patches,'source_preserved':True,'visual_review':'pending'},indent=2),encoding='utf8')
