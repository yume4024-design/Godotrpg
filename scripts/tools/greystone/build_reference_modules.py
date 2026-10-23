"""Original Blender models authored from the bottom asset strip, reference 2026-10-23.
Run only in an isolated background Blender. No vendor models or textures.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector, Matrix

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'assets/models/greystone/reference_modules'
SOURCE=ROOT/'source_assets/greystone_reference_20261023'
RENDER=ROOT/'artifacts/greystone_reference_modules'
for folder in [OUT,SOURCE,RENDER]:folder.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').write_text('')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
colors={'plaster':(.83,.79,.66),'timber':(.30,.23,.16),'oak':(.48,.34,.20),
        'roof_red':(.66,.32,.19),'roof_blue':(.36,.43,.46),'stone':(.52,.54,.49),
        'stone_light':(.63,.64,.57),'iron':(.22,.25,.25),'glass':(.48,.44,.29),
        'warm':(.96,.68,.27),'leaf':(.27,.40,.19),'leaf_light':(.38,.50,.23),'dark':(.08,.10,.095)}
materials={}
for name,rgb in colors.items():
    m=bpy.data.materials.new('GreystoneRef_'+name);m.use_nodes=True
    linear=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)
    m.diffuse_color=(*linear,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*linear,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.88
    materials[name]=m

parts=[]
def finish(obj,name,mat):
    obj.name=name;obj.data.materials.append(materials[mat]);parts.append(obj)
    return obj
def box(name,pos,size,mat,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    obj=bpy.context.object;obj.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Soft worn edge','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj,name,mat)
def cylinder(name,pos,radius,depth,mat,verts=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=pos)
    return finish(bpy.context.object,name,mat)
def beam(name,a,b,width,mat):
    a,b=Vector(a),Vector(b)
    obj=box(name,(a+b)/2,(width,width,(b-a).length),mat)
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return obj
def solid(name,verts,faces,mat):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces)
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);scene.collection.objects.link(obj);return finish(obj,name,mat)
def roof(cx,cy,w,d,eave,peak,mat,dormer=False):
    # Thick overlapping shingle courses, ridge cap and exposed timber fascia.
    solid('PlasterGable',[(cx-w/2,cy-d/2,eave),(cx+w/2,cy-d/2,eave),(cx,cy-d/2,peak),
                          (cx-w/2,cy+d/2,eave),(cx+w/2,cy+d/2,eave),(cx,cy+d/2,peak)],
          [(0,1,2),(3,5,4),(0,3,4,1),(0,2,5,3),(1,4,5,2)],'plaster')
    ew=w/2+.4;ed=d+.6
    for side in [-1,1]:
        slope=math.atan2(peak-eave,ew)
        length=math.hypot(ew,peak-eave)
        panel=box('RoofUnderlay',(cx+side*ew/2,cy,(peak+eave)/2),(length,ed,.13),mat)
        panel.rotation_euler.y=side*slope
        for row in range(5):
            t=(row+.5)/5
            for col in range(max(4,int(ed/.78))):
                count=max(4,int(ed/.78));yy=cy-ed/2+(col+.5)*ed/count
                shingle=box('RoofTile',(cx+side*ew*t,yy,peak-(peak-eave)*t+.10),(length/5+.045,ed/count-.018,.09),mat,.015)
                shingle.rotation_euler.y=side*slope
        for yy in [cy-ed/2-.02,cy+ed/2+.02]:
            beam('Bargeboard',(cx,yy,peak+.12),(cx+side*ew,yy,eave),.18,'timber')
    beam('Ridge',(cx,cy-ed/2-.1,peak+.12),(cx,cy+ed/2+.1,peak+.12),.22,mat)
    beam('GableTie',(cx-w/2,cy-d/2-.025,eave),(cx+w/2,cy-d/2-.025,eave),.16,'timber')
    beam('KingPost',(cx,cy-d/2-.05,eave),(cx,cy-d/2-.05,peak),.17,'timber')
    if dormer:
        # Expose the dormer above the main slope; the first prototype was
        # swallowed by its roof instead of reading as the reference skylight.
        box('Dormer',(cx-.9,cy-d*.26,peak-.15),(1.15,1.2,1.1),'plaster')
        roof(cx-.9,cy-d*.26,1.25,1.25,peak+.3,peak+.8,mat)
        window(cx-.9,cy-d*.26-.64,peak-.15,.65,.75)

def window(x,y,z,w=.8,h=1.1):
    box('WindowFrame',(x,y,z),(w+.20,.18,h+.2),'timber',.02)
    box('WindowPane',(x,y-.105,z),(w,.035,h),'glass')
    box('WindowMullion',(x,y-.14,z),(.065,.06,h),'oak')
    box('WindowSill',(x,y-.18,z-h/2),(w+.3,.32,.12),'oak')
    for s in [-1,1]:
        box('Shutter',(x+s*(w*.5+.22),y-.07,z),(.3,.14,h),'oak')
def door(x,y):
    box('DoorPanel',(x,y,1.2),(1.65,.18,2.4),'oak')
    for i in range(5):box('DoorGroove',(x-.66+i*.33,y-.1,1.2),(.018,.025,2.32),'timber')
    for s in [-1,1]:box('DoorPost',(x+s*.92,y-.08,1.24),(.19,.3,2.48),'timber',.025)
    box('DoorHeader',(x,y-.08,2.52),(2.05,.3,.22),'timber',.025)
    box('DoorHandle',(x+.51,y-.16,1.2),(.11,.08,.14),'iron')
def side_window(x,y,z,angle):
    start=len(parts)
    window(0,0,z)
    transform=Matrix.Translation((x,y,z))@Matrix.Rotation(angle,4,'Z')@Matrix.Translation((0,0,-z))
    for obj in parts[start:]:obj.matrix_world=transform@obj.matrix_world
def chimney(x,y,z):
    box('Chimney',(x,y,z),(.7,.8,2),'stone',.03)
    box('ChimneyCap',(x,y,z+1.02),(.91,1.0,.2),'timber',.025)
    box('Flue',(x,y,z+1.13),(.55,.62,.035),'dark')
def wall_frame(cx,cy,w,d,h):
    box('PlasterWall',(cx,cy,h/2),(w,d,h),'plaster',.035)
    box('Foundation',(cx,cy,.18),(w+.14,d+.14,.36),'stone',.05)
    for x in [cx-w/2,cx,cx+w/2]:
        for y in [cy-d/2-.04,cy+d/2+.04]:box('WallPost',(x,y,h/2),(.18,.19,h),'timber')
    for y in [cy-d/2-.055,cy+d/2+.055]:
        for z in [.46,h-.08]:box('WallTie',(cx,y,z),(w,.18,.17),'timber')
    for x in [cx-w/2-.04,cx+w/2+.04]:
        for y in [cy-d/2,cy,cy+d/2]:box('SidePost',(x,y,h/2),(.18,.18,h),'timber')
        for z in [.46,h-.08]:box('SideTie',(x,cy,z),(.18,d,.17),'timber')
def porch(cx,y,width,depth,mat):
    awning=box('PorchRoof',(cx,y,2.85),(width,depth,.16),mat,.02)
    awning.rotation_euler.x=.10
    for x in [cx-width/2+.15,cx+width/2-.15]:
        box('PorchPost',(x,y-depth/2+.12,1.38),(.20,.20,2.76),'timber',.02)
        beam('Brace',(x,y-depth/2+.12,2.2),(x+(.5 if x<cx else -.5),y-depth/2+.12,2.74),.12,'oak')
def board(x,y,z,kind):
    beam('SignBracket',(x,y+.6,z+.5),(x,y-.05,z+.5),.12,'iron')
    box('Sign',(x,y,z),(1.05,.15,.72),'oak',.05)
    if kind=='inn':
        box('Bed',(x,y-.10,z-.08),(.65,.06,.13),'warm')
        for xx in [x-.28,x+.28]:box('BedLeg',(xx,y-.10,z-.16),(.09,.06,.28),'warm')
    elif kind=='item':
        cylinder('Bottle',(x,y-.14,z),.13,.35,'warm',8).rotation_euler.x=math.pi/2
    else:
        beam('Sword',(x-.22,y-.12,z-.24),(x+.22,y-.12,z+.24),.09,'warm')
        beam('Guard',(x-.24,y-.12,z-.06),(x-.05,y-.12,z-.24),.09,'warm')

manifest=[]
def export(name,kind):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
    obj.data.calc_loop_triangles();triangles=len(obj.data.loop_triangles)
    assert 0<triangles<=12000,(name,triangles)
    for p in obj.data.polygons:p.use_smooth=False
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'{name}.blend'),copy=True)
    dims=[round(obj.dimensions.x,3),round(obj.dimensions.z,3),round(obj.dimensions.y,3)]
    manifest.append({'name':name,'category':kind,'triangles':triangles,'dimensions_xyz_godot':dims,'materials':len(obj.data.materials),'uv':True,'textures':0,'source':'Original geometry authored against bottom asset strip'})
    obj.location=(len(manifest)%5*16,len(manifest)//5*15,0)
    parts.clear()

for name in ['house_a','inn','item_shop','weapon_shop']:
    if name=='inn':
        wall_frame(-1,0,7.2,6,4.2);roof(-1,0,7.2,6,4.2,6.9,'roof_red',True)
        wall_frame(3.2,.1,3.6,5.3,3.2);roof(3.2,.1,3.6,5.3,3.2,5.25,'roof_red')
        door(-1,-3.12);window(-3.2,-3.12,1.7);window(1,-3.12,1.7)
        porch(-1,-3.7,5.5,1.4,'roof_red');board(1.9,-4.05,2.0,'inn');chimney(-3,1.2,6.4)
        side_window(5.06,.1,1.7,math.pi/2)
        side_window(-4.66,0,2.1,-math.pi/2)
        side_window(-1,3.12,2.0,math.pi)
    else:
        w=6 if name=='house_a' else 6.5;d=4.7;h=3.0
        wall_frame(0,0,w,d,h);roof(0,0,w,d,h,5.15 if name=='house_a' else 5.45,'roof_blue' if name=='item_shop' else 'roof_red',name=='house_a')
        door(-1.0,-d/2-.12);window(1.7,-d/2-.12,1.6)
        chimney(1.9,1.1,4.9)
        side_window(w/2+.10,0,1.6,math.pi/2)
        side_window(-w/2-.10,0,1.6,-math.pi/2)
        side_window(0,d/2+.10,1.6,math.pi)
        if name!='house_a':
            porch(0,-3.0,7.0,1.7,'roof_blue' if name=='item_shop' else 'roof_red')
            board(2.7,-3.5,2.0,'item' if name=='item_shop' else 'weapon')
            if name=='item_shop':
                box('StoreCounter',(1.6,-3.0,.7),(2.0,.65,1.25),'oak',.03)
                for i in range(4):cylinder('Goods',(.9+i*.43,-3,1.45),.13,.30,'warm',8)
            else:
                box('Forge',(2.1,-2.6,.85),(1.4,1.1,1.7),'stone',.04)
                box('ForgeMouth',(2.1,-3.17,.95),(.85,.03,.7),'dark')
                cylinder('AnvilStump',(1.4,-3.8,.45),.32,.9,'oak',8)
                box('Anvil',(1.4,-3.8,1.0),(1.1,.4,.3),'iron',.07)
    export(name,'building')

# Circular masonry well; low rim with tall central suspension, as pictured.
for row in range(2):
    for i in range(12):
        a=(i+row*.5)*math.tau/12
        o=box('WellStone',(math.cos(a)*1.1,math.sin(a)*1.1,.25+row*.42),(.60,.36,.40),'stone_light',.035);o.rotation_euler.z=a+math.pi/2
cylinder('WellWater',(0,0,.1),.9,.04,'dark',12)
for x in [-1,1]:box('WellPost',(x,0,1.55),(.20,.20,2.6),'oak',.02)
beam('WellHeader',(-1.1,0,2.8),(1.1,0,2.8),.24,'oak')
beam('WellRope',(0,0,.4),(0,0,2.75),.045,'timber')
export('stone_well','prop')
for name,w,d in [('wooden_bridge',8,3.4),('wooden_dock',6,5)]:
    for i in range(int(w/.4)):
        box('Deck',(-w/2+(i+.5)*.4,0,-.07),(.38,d,.14),'oak',.015)
    for y in [-d/2+.12,d/2-.12]:
        beam('DeckBeam',(-w/2,y,-.28),(w/2,y,-.28),.22,'timber')
        for x in [-w/2+.15,0,w/2-.15]:
            box('Pier',(x,y,-.7 if name=='wooden_dock' else 0),(.24,.24,3.6 if name=='wooden_dock' else 2.9),'timber',.02)
        if name=='wooden_bridge':
            for z in [.55,1.05]:beam('Rail',(-w/2,y,z),(w/2,y,z),.12,'oak')
    export(name,'prop')

for i in range(3):
    bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=1.5-i*.28,radius2=0,depth=2.5,location=(0,0,2+i*1.05))
    finish(bpy.context.object,'PineLayer','leaf' if i%2 else 'leaf_light')
cylinder('Trunk',(0,0,.65),.21,1.3,'oak',7);export('pine_tree_a','prop')
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(0,0,.7))
o=finish(bpy.context.object,'FacetedRock','stone');o.scale=(1.4,1.1,.95);export('rock_medium','prop')
for x in [-1.4,1.4]:box('FencePost',(x,0,.65),(.2,.22,1.3),'timber',.035)
for z in [.45,.95]:beam('FenceRail',(-1.4,0,z),(1.4,0,z),.14,'oak')
export('wooden_fence','prop')
cylinder('LampBase',(0,0,.1),.28,.2,'iron',8)
beam('LampPole',(0,0,.1),(0,0,2.8),.14,'iron')
beam('LampArm',(0,0,2.8),(.55,0,2.8),.12,'iron')
box('Lantern',(.55,0,2.4),(.35,.35,.55),'warm',.02)
for z in [2.1,2.7]:box('LanternCap',(.55,0,z),(.48,.48,.12),'iron',.04)
export('lamp_post','prop')
beam('SignPost',(0,0,0),(0,0,1.9),.16,'timber')
box('SignBoard',(0,-.06,1.5),(1.65,.18,.65),'oak',.07);export('wooden_sign','prop')
for i in range(12):
    a=i*math.tau/12
    box('Stave',(math.cos(a)*.43,math.sin(a)*.43,.6),(.23,.20,1.2),'oak',.025).rotation_euler.z=a+math.pi/2
for z in [.18,1.02]:
    bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=4,location=(0,0,z),major_radius=.48,minor_radius=.045)
    finish(bpy.context.object,'BarrelHoop','iron')
cylinder('BarrelLid',(0,0,1.19),.43,.06,'oak',12);export('barrel','prop')
box('CrateBody',(0,0,.5),(.94,.94,1),'oak',.015)
for x in [-.46,.46]:
    for y in [-.51,.51]:box('CrateFrame',(x,y,.5),(.12,.1,1.04),'timber')
for y in [-.52,.52]:beam('CrateBrace',(-.42,y,.1),(.42,y,.9),.12,'timber')
export('crate','prop')
(SOURCE/'metrics.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'module_library.blend'),copy=True)
# Review is a native Blender render of actual exported geometry, no generated illustration.
scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=1200;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world.color=(.25,.28,.30)
bpy.ops.object.light_add(type='AREA',location=(8,-12,28));bpy.context.object.data.energy=2600;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=18
bpy.ops.object.camera_add(location=(44,-48,39));camera=bpy.context.object
camera.rotation_euler=(Vector((30,15,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=77;scene.camera=camera
scene.render.filepath=str(RENDER/'module_library.png');bpy.ops.render.render(write_still=True)
print('REFERENCE_MODULES '+json.dumps(manifest))
