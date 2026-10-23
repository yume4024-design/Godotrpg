"""Owned Blender master scene with four Pixal3D designs and reusable modules.
Run in background factory startup; never edits the user's live Blender scene.
"""
import bpy, bmesh, math, random, json
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.geometry import tessellate_polygon

ROOT=Path(__file__).resolve().parents[3]
DEST=ROOT/'source_assets/greystone_blender_20261023'
ART=ROOT/'artifacts/greystone_blender_20261023'
DEST.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True)
(DEST/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.name='Greystone_Master_Candidate'
rng=random.Random(231023)
groups={}
for name in ['Terrain','Paths','Buildings_Candidate','Water','Cliffs','Vegetation','Props','Mine','Bounds','Review']:
    c=bpy.data.collections.new(name);scene.collection.children.link(c);groups[name]=c
materials={}
for name,col in {'grass':(.32,.43,.17,1),'earth':(.62,.46,.27,1),'stone':(.37,.38,.35,1),'water':(.12,.52,.64,1),'foam':(.48,.78,.81,1),'wood':(.26,.15,.065,1),'black':(.025,.03,.025,1)}.items():
    col=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in col[:3])+(1,)
    m=bpy.data.materials.new(name);m.diffuse_color=col;m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=col
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.9
    materials[name]=m
for suffix,factor in [('light',1.08),('shade',.94)]:
    m=materials['grass'].copy();m.name='grass_'+suffix
    color=materials['grass'].diffuse_color
    m.diffuse_color=tuple(v*factor for v in color[:3])+(1,)
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;materials['grass_'+suffix]=m
def group(obj,key):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    groups[key].objects.link(obj);return obj
def mesh(name,vertices,faces,mat,key):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);groups[key].objects.link(obj);obj.data.materials.append(materials[mat]);return obj
def box(name,pos,size,mat,key):
    # Native data avoids repeated whole-scene operator updates for edge proxies.
    x,y,z=(v/2 for v in size)
    o=mesh(name,[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)],
        [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,key)
    o.location=pos;return o
RAMPS=[((-7,-29,0),(-7,-23,3)),((-27,1,3),(-33,1,5)),((-19,19,3),(-24,25,6)),((3,36,6),(0,43,10))]
SLABS=[]
def corridor_planes(a,b):
    a,b=Vector(a),Vector(b);d=b-a;d.z=0;length=d.length;d.normalize();n=Vector((-d.y,d.x,0))
    # Inside rectangle includes only the rising flight, ending at the landing.
    return [(d,d.dot(a)-.2),(-d,-d.dot(b)),(n,n.dot(a)-2.15),(-n,-n.dot(a)-2.15)]
def clip_half(poly,normal,offset,inside=True):
    result=[]
    for p,q in zip(poly,poly[1:]+poly[:1]):
        dp=normal.dot(p)-offset;dq=normal.dot(q)-offset
        pin=dp>=-1e-7 if inside else dp<=1e-7
        qin=dq>=-1e-7 if inside else dq<=1e-7
        if pin:result.append(p)
        if pin!=qin and abs(dp-dq)>1e-9:result.append(p+(q-p)*(dp/(dp-dq)))
    return result
def subtract_corridor(poly,planes):
    outside=[];remainder=poly
    for normal,offset in planes:
        if len(remainder)<3:break
        piece=clip_half(remainder,normal,offset,False)
        if len(piece)>=3:outside.append(piece)
        remainder=clip_half(remainder,normal,offset)
    return outside
def slab(name,poly,h,bottom=-5):
    n=len(poly);vs=[(x,y,h) for x,y in poly]+[(x,y,bottom) for x,y in poly]
    top=[Vector(v) for v in vs[:n]]
    tris=tessellate_polygon([top]);faces=[tuple(v if isinstance(v,int) else top.index(v) for v in t) for t in tris]
    cuts=[corridor_planes(a,b) for a,b in RAMPS if abs(b[2]-h)<.01]
    SLABS.append((poly,h,cuts))
    def cut_mesh(label,verts,polygons,material):
        points=[];indices=[]
        for face in polygons:
            pieces=[[Vector(verts[i]) for i in face]]
            for planes in cuts:pieces=[part for p in pieces for part in subtract_corridor(p,planes)]
            for piece in pieces:
                start=len(points);points.extend(piece);indices.append(tuple(range(start,len(points))))
        o=mesh(label,points,indices,material,'Terrain')
        if material=='grass':
            for key in ['grass_light','grass_shade']:o.data.materials.append(materials[key])
            for p in o.data.polygons:p.material_index=rng.choices([0,1,2],[.7,.15,.15])[0]
    cut_mesh(name+'_Grass',vs[:n],faces,'grass')
    sides=[]
    for i in range(n):j=(i+1)%n;sides.extend([(i,n+i,n+j),(i,n+j,j)])
    cut_mesh(name+'_Cliff',vs,sides,'stone')
    # Jagged stone skirts break the long planar terrace faces without invading paths.
    for i,(x,y) in enumerate(poly):
        q=poly[(i+1)%n];length=math.hypot(q[0]-x,q[1]-y)
        for j in range(max(1,int(length/4))):
            t=(j+.5)/max(1,int(length/4));px=x+(q[0]-x)*t;py=y+(q[1]-y)*t
            if any(all(normal.dot(Vector((px,py,0)))>=offset-2.6 for normal,offset in planes) for planes in cuts):continue
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(px,py,(h+bottom)/2))
            o=bpy.context.object;o.name=name+'_RockFace';o.scale=(rng.uniform(1.7,2.6),rng.uniform(1.6,2.5),(h-bottom)*.53)
            o.data.materials.append(materials['stone']);group(o,'Cliffs')
def path(name,points,width=3):
    if len(points)>2 and max(p[2] for p in points)-min(p[2] for p in points)<.01 and name!='River':
        # Rounded dirt lanes retain their authored endpoints and stair landings.
        control=[Vector(p) for p in points];smooth=[]
        for i in range(len(control)-1):
            a=control[max(0,i-1)];b=control[i];c=control[i+1];d=control[min(len(control)-1,i+2)]
            count=max(2,int((c-b).length/1.7))
            for step in range(count):
                t=step/count;smooth.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
        smooth.append(control[-1]);points=smooth
    vs=[]
    # Separate overlapping road strips by millimeters to avoid coplanar intersections.
    lift=0.0 if name=='River' else .04 if 'RampCollisionGuide' in name else .04+len(groups['Paths'].objects)*.002
    for i,p in enumerate(points):
        q=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        q.z=0;q.normalize()
        variation=1.0 if 'RampCollisionGuide' in name or name=='River' else 1+.035*math.sin(i*1.7)
        normal=Vector((-q.y,q.x,0))*width*variation/2
        vs.extend([Vector(p)+normal+Vector((0,0,lift)),Vector(p)-normal+Vector((0,0,lift))])
    return mesh(name,vs,[(i,i+1,i+3,i+2) for i in range(0,len(vs)-2,2)],'stone' if 'RampCollisionGuide' in name else 'earth','Paths')
def stairs(name,start,end,width=3):
    a,b=Vector(start),Vector(end);delta=b-a;n=max(2,round(abs(delta.z)/.18));flat=Vector((delta.x,delta.y,0));length=flat.length
    for i in range(n):
        p=a+delta*((i+.5)/n);height=.12
        o=box(name+str(i),p,(width,length/n+.03,height),'stone','Paths');o.rotation_euler.z=-math.atan2(delta.x,delta.y)
    # Match the 4.3 m cut corridor: no thin unwalkable seam beside the treads.
    path(name+'_RampCollisionGuide',[start,end],width+.3)

# North is +Y in Blender; GLTF export maps it to Godot -Z.
slab('VillageCore',[(-28,-23),(-13,-28),(4,-24),(17,-17),(23,-4),(20,13),(11,23),(-8,25),(-26,17),(-33,1)],3)
slab('NorthTerrace',[(-30,13),(-20,24),(-4,23),(11,19),(23,25),(24,39),(5,46),(-14,43),(-34,30)],6)
slab('MineRidge',[(-19,35),(-10,43),(11,39),(23,40),(22,51),(-9,53),(-25,46)],10)
slab('WesternApproach',[(-45,-18),(-33,-23),(-26,-13),(-31,0),(-29,15),(-36,27),(-46,20),(-49,3)],5)
slab('SouthEntry',[(-24,-38),(-5,-43),(12,-35),(16,-24),(2,-21),(-12,-27),(-29,-22)],0)
slab('EastBank',[(34,-24),(48,-20),(50,18),(44,43),(32,40),(33,25),(37,12),(32,-2)],6)
slab('WaterfallCliff',[(20,43),(31,39),(44,43),(45,55),(20,56)],14)
plaza=[(0,0,3.035)]+[(8.2*math.cos(i*math.tau/24)*(1+.025*math.sin(i*2.3)),7.2*math.sin(i*math.tau/24),3.035) for i in range(24)]
mesh('VillagePlaza',plaza,[(0,i+1,(i+1)%24+1) for i in range(24)],'earth','Paths')
for name,pts,w in [
 ('InnRoad',[(0,-2,3),(-5,7,3),(-10,15,3)],4),
 ('WestRoad',[(-1,0,3),(-15,3,3),(-27,1,3)],4),
 ('SouthRoad',[(0,0,3),(-3,-12,3),(-7,-23,3)],4),
 ('ShopRoad',[(0,0,3),(8,6,3),(9,12.5,3)],4),
 ('WeaponLane',[(4,-1,3),(6,-8,3),(13,-9,3)],3.2),
 ('DockRoad',[(0,-7,3),(12,-13,3),(20,-16,3)],3),
 ('NorthRoad',[(-24,25,6),(-25,26.2,6),(-25,29,6),(-21,29,6),(-10,29,6),(8,27,6),(20,29,6)],3.2),
 ('MineRoad',[(8,29,6),(3,36,6)],4),
 ('MineLanding',[(0,43,10),(-.4,44,10),(0,45,10)],4),
 ('Exit',[(-33,1,5),(-36,1,5),(-40,4,5),(-45,18,5)],4),
 ('Entry',[(-7,-29,0),(-6,-38,0)],4),
 ('EastTrail',[(32,29,6),(39,22,6),(40,10,6),(36,0,6)],3)]:path(name,pts,w)
stairs('WestSteps',(-27,1,3),(-33,1,5),4)
stairs('NorthSteps',(-19,19,3),(-24,25,6),4)
stairs('MineSteps',(3,36,6),(0,43,10),4)
stairs('EntrySteps',(-7,-23,3),(-7,-29,0),4)
# Continuous winding river ribbon and broader lake, with raised eastern bank.
river=[(28,51,2),(28,41,2),(27,30,2),(28,19,2),(25,6,2),(28,-6,2),(27,-20,2),(23,-36,2)]
o=path('River',river,12);group(o,'Water');o.data.materials.clear();o.data.materials.append(materials['water'])
lake=[Vector(v) for v in [(-1,-50,2),(49,-50,2),(49,-20,2),(24,-17,2),(14,-30,2)]]
# Clip the river against the lake so coplanar water never self-shadows black
# in Cycles or flickers in the engine; both retain exactly the same waterline.
planes=[]
for a,b in zip(lake,lake[1:]+lake[:1]):
    d=b-a;n=Vector((-d.y,d.x,0)).normalized();planes.append((n,n.dot(a)))
points=[];faces=[]
for face in o.data.polygons:
    for piece in subtract_corridor([o.data.vertices[i].co.copy() for i in face.vertices],planes):
        start=len(points);points.extend(piece);faces.append(tuple(range(start,len(points))))
data=bpy.data.meshes.new('RiverClipped');data.from_pydata(points,[],faces);data.materials.append(materials['water']);data.update();o.data=data
mesh('Lake',lake,[(0,1,2,3,4)],'water','Water')
box('Waterfall',(28,39.8,8),(7,.3,12),'foam','Water')
for i in range(9):
    x=25+i*.73
    mesh('WaterfallStream',[(x,39.59,13.5),(x+.22,39.59,13.5),(x+.40,39.59,2.02),(x-.08,39.59,2.02)],[(0,3,2,1)],'water' if i%3==0 else 'foam','Water')

library={}
cleanup_counts={}
ai_sources={
    'inn':ROOT/'source_assets/greystone_ai_20261023/inn/pixal_candidate_01/door_only/inn_repaired.glb',
    'house_a':ROOT/'source_assets/greystone_ai_20261023/house_a/pixal_candidate_01/shell_repair02/house_a_repaired.glb',
    'house_a_blue':ROOT/'source_assets/greystone_ai_20261023/house_a/pixal_candidate_01/shell_repair02/house_a_repaired.glb',
    'item_shop':ROOT/'source_assets/greystone_ai_20261023/item_shop/pixal_candidate_01/shell_repair02/item_shop_repaired.glb',
    'weapon_shop':ROOT/'source_assets/greystone_ai_20261023/weapon_shop/pixal_candidate_01/shell_repair02/weapon_shop_repaired.glb'
}
def slate_roof(data):
    blue_index=len(data.materials)
    for i in range(3):
        blue=bpy.data.materials.new('HouseSlateBlue'+str(i));blue.use_nodes=True
        blue.diffuse_color=(.13+i*.008,.18+i*.008,.23+i*.008,1)
        bsdf=blue.node_tree.nodes['Principled BSDF'];bsdf.inputs['Base Color'].default_value=blue.diffuse_color;bsdf.inputs['Roughness'].default_value=.9
        data.materials.append(blue)
    for face in data.polygons:
        if 2.4<face.center.z<4.0 and face.normal.z>.28:face.material_index=blue_index+(int(face.center.x*1.7)+int(face.center.z*4))%3

def remove_same_facing_duplicates(data,asset):
    # Remove only exact cyclic-order/material duplicates; opposite faces stay.
    seen=set();duplicate_ids=[]
    for face in data.polygons:
        coords=[tuple(data.vertices[i].co) for i in face.vertices]
        key=(face.material_index,min(tuple(coords[i:]+coords[:i]) for i in range(len(coords))))
        if key in seen:duplicate_ids.append(face.index)
        else:seen.add(key)
    if duplicate_ids:
        bm=bmesh.new();bm.from_mesh(data);bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=[bm.faces[i] for i in duplicate_ids],context='FACES_ONLY')
        bm.to_mesh(data);bm.free();data.update()
    cleanup_counts[asset]=len(duplicate_ids)

def instance(asset,name,pos,scale=1,angle=0,key='Props'):
    if asset=='house_a_blue' and asset not in library and 'house_a' in library:
        data,transform=library['house_a'];data=data.copy();slate_roof(data);library[asset]=(data,transform.copy())
    if asset not in library:
        file=ai_sources.get(asset,ROOT/'assets/models/greystone/reference_modules'/f'{asset}.glb')
        if not file.exists():file=ROOT/'assets/models/greystone/props'/f'{asset}.glb'
        before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(file))
        imported=list(set(bpy.data.objects)-before);meshes=[o for o in imported if o.type=='MESH']
        if asset in ai_sources:
            bpy.ops.object.select_all(action='DESELECT')
            for o in meshes:
                matrix=o.matrix_world.copy();o.parent=None;o.matrix_world=matrix;o.select_set(True)
            bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join()
            proto=bpy.context.object;data=proto.data.copy();data.transform(proto.matrix_world)
            remove_same_facing_duplicates(data,asset)
            if asset=='house_a_blue':slate_roof(data)
            library[asset]=(data,Matrix.Identity(4))
            imported=list(set(bpy.data.objects)-before)
        else:
            if len(meshes)!=1:raise ValueError((asset,len(meshes)))
            proto=meshes[0];bpy.context.view_layer.update();library[asset]=(proto.data.copy(),proto.matrix_world.copy())
        for o in imported:bpy.data.objects.remove(o,do_unlink=True)
    data,transform=library[asset];o=bpy.data.objects.new(name,data);groups[key].objects.link(o)
    o.matrix_world=transform;o.location=pos;o.scale=(scale,)*3;o.rotation_euler.z=angle;return o
placements=[('inn','Inn',(-10,15,3),1,0),('item_shop','ItemShop',(-20,9,3),1,0),('weapon_shop','WeaponShop',(13,-5,3),1.18,0),('house_a','WestHouse',(-15,-13,3),1,0),('house_a','FarmHouse',(-17,33,6),1,0),('house_a_blue','SouthHouse',(5,-18,3),1,0),('house_a_blue','GuildHall',(9,17,3),1.25,0)]
for a,n,p,s,r in placements:instance(a,n,p,s,r,'Buildings_Candidate')
instance('stone_well','CentralWell',(0,0,3),1.1)
instance('wooden_bridge','UpstreamBridge',(27,29,6.10),2.0)
instance('wooden_dock','LakesideDock',(23,-17,3),1.4)
# A short gangway joins the irregular shore to the dock without an open gap.
for i in range(8):box('DockGangway', (16.15+i*.4,-16,2.95),(.39,3.2,.14),'wood','Props')
# Dock rails match the existing pier posts; the western shore entrance stays open.
for y in [-20.3,-13.7]:box('DockRimRail',(23,y,4.05),(8.2,.14,.18),'wood','Props')
box('DockOuterRail',(27,-17,4.05),(.14,6.6,.18),'wood','Props')
for y in [-17.6,-14.4]:box('DockGangwayRail',(17.55,y,4.05),(3.2,.14,.18),'wood','Props')
for y,length in [(-18.975,2.65),(-14.025,.65)]:box('DockShoreRail',(18.9,y,4.05),(.14,length,.18),'wood','Props')
for x,y,z in [(-8,-3,3),(8,-12,3),(-24.8,6.5,3),(19,26,6),(18,-15,3)]:instance('lamp_post','Lantern',(x,y,z))
for x,y,z in [(-18,12,3),(-14,12,3),(-20,-15,3),(15,7,3),(22,-14,3)]:
    instance('barrel','Barrel',(x,y,z));instance('crate','Crate',(x+1,y,z),.8)
for x,y,z in [(-24,12,3),(-20,13.4,3),(-20,-18,3),(-16,-20,3),(-12,-22,3),(11,-22,3),(15,-19,3),(35,25,6),(39,26,6),(-13,39,6)]:instance('wooden_fence','Fence',(x,y,z),1,0)
for x,y,z in [(-28,32,6),(-30,36,6),(-35,14,5),(-42,17,5),(-37,-12,5),(-20,-31,0),(-12,-36,0),(9,-31,0),(16,-19,3),(20,3,3),(18,17,3),(11,34,6),(-9,39,6),(38,35,6),(42,29,6),(44,15,6),(37,-9,6),(8,48,10)]:
    instance('pine_tree_a','Pine',(x,y,z),rng.uniform(1.0,1.5),rng.random()*math.tau,'Vegetation')
    instance('pine_tree_a','PineSmall',(x+2.3,y-1.5,z),rng.uniform(.6,.9),rng.random()*math.tau,'Vegetation')
for x,y,z in [(-30,-17,1),(-29,-9,1),(19,-14,0),(22,-5,0),(22,14,1),(25,35,3),(34,15,2),(33,1,1),(-20,39,7),(12,43,8),(-40,27,3)]:
    instance('rock_medium','CliffRock',(x,y,z),rng.uniform(2,3.5),rng.random()*6,'Cliffs')
box('MineDark',(0,48.7,12.5),(6.6,.3,5),'black','Mine')
for x in [-3,3]:box('MinePost',(x,46.5,12.4),(.65,.65,4.8),'wood','Mine')
box('MineLintel',(0,46.5,15),(7,.8,.65),'wood','Mine')
for x in [-5,5]:instance('rock_medium','MineRock',(x,47,10),3,0,'Mine')
def portal_rock(name,profile,front=48,depth=4):
    n=len(profile);vs=[(x,front,z) for x,z in profile]+[(x,front+depth,z) for x,z in profile]
    faces=[tuple(range(n)),tuple(range(n*2-1,n-1,-1))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,faces,'stone','Mine')
portal_rock('MineCliffLeft',[(-18,10),(-3.3,10),(-3.3,15.2),(-1.5,17),(-4,23),(-10,24),(-17,21)])
portal_rock('MineCliffRight',[(3.3,10),(14,10),(16,17),(12,22),(5,23),(3.3,15.2)])
portal_rock('MineCliffCrown',[(-3.3,15.2),(3.3,15.2),(5,21),(-1.5,23.5),(-4.5,21)])
for x in [-.65,.65]:box('MineRail',(x,45.5,10.06),(.08,5,.10),'black','Mine')
for y in [43.5,44.3,45.1,45.9,46.7]:box('RailSleeper',(0,y,10.025),(1.7,.18,.10),'wood','Mine')
instance('crate','MineSupplyCrate',(-5,44,10),1.3,0,'Mine')
instance('barrel','MineSupplyBarrel',(4.8,44.5,10),1,0,'Mine')
for x,y,s in [(-3.7,45.5,.8),(3.8,46.2,1.0),(-4.5,46.5,.5)]:instance('crystal_blue','MineCrystal',(x,y,10),s,0,'Mine')
# Waterwheel: visible spokes and paddle boards on the eastern bank.
for i in range(12):
    a=i*math.tau/12
    o=box('WheelSpoke',(34,8,4),(.18,5.6,.18),'wood','Props');o.rotation_euler.x=a
    o=box('WheelPaddle',(34,8+2.8*math.cos(a),4+2.8*math.sin(a)),(1.7,.55,.22),'wood','Props');o.rotation_euler.x=a
for x in [33.3,34.7]:
    bpy.ops.mesh.primitive_torus_add(major_segments=24,minor_segments=4,location=(x,8,4),major_radius=2.7,minor_radius=.16,rotation=(0,math.pi/2,0))
    o=bpy.context.object;o.name='WaterwheelRim';o.data.materials.append(materials['wood']);group(o,'Props')
# Small shore boat with hollow hull and seats, separated from the walkable dock.
outline=[(-.9,-1.8),(.9,-1.8),(1.1,1.1),(0,2.3),(-1.1,1.1)]
vs=[(30+x,-21+y,2.25) for x,y in outline]+[(30+x*.7,-21+y*.85,1.6) for x,y in outline]
mesh('BoatHull',vs,[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]+[(5,6,7,8,9)],'wood','Props')
for y in [-21.8,-20.4]:box('BoatSeat',(30,y,2.3),(1.8,.3,.16),'wood','Props')
# Garden clusters stay beside houses rather than on their approach paths.
for x,y,z in [(-23,-12,3),(-20,-17,3),(-12,-18,3),(-20,4,3),(-16,8,3),(-4,19,3),(16,8,3),(17,-8,3),(9,-20,3),(-10,34,6),(36,30,6)]:
    instance('bush_a','Shrub',(x,y,z),.8,rng.random()*6,'Vegetation')
    instance('flower_a','Flowers',(x+.8,y-.6,z),.65,rng.random()*6,'Vegetation')
    for j in range(4):instance('grass_a','GrassTuft',(x+rng.uniform(-1.5,1.5),y+rng.uniform(-1.5,1.5),z),rng.uniform(.5,.9),rng.random()*6,'Vegetation')
for x in [-32,-30,-28]:
    box('FarmBed',(x,29,6.06),(1.4,6,.12),'earth','Props')
    for y in [26.5,27.5,28.5,29.5,30.5,31.5]:instance('leafy_crop','FarmCrop',(x,y,6.15),.7,0,'Vegetation')
for x,y in [(-33,25),(-29,25),(-33,33),(-29,33)]:instance('wooden_fence','FarmFence',(x,y,6),1,0)
for x,y,z in [(-43,11,5),(-44,22,5),(-37,23,5),(-32,39,6),(-24,38,6),(-17,41,6),(-13,48,10),(-9,49,10),(9,48,10),(14,47,10),(37,43,14),(41,48,14),(45,27,6),(44,5,6),(39,-15,6)]:
    instance('pine_tree_a','PineContext',(x,y,z),rng.uniform(1.1,1.7),rng.random()*math.tau,'Vegetation')

# Static body volumes are independent of AI topology and remain editable in Blender.
for building in list(groups['Buildings_Candidate'].objects):
    corners=[building.matrix_world@Vector(c) for c in building.bound_box]
    lo=Vector([min(p[i] for p in corners) for i in range(3)]);hi=Vector([max(p[i] for p in corners) for i in range(3)])
    size=hi-lo;height=min(3.8,size.z*.58)
    o=box(building.name+'Body-colonly',((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z+height/2),(size.x*.86,size.y*.78,height),'black','Bounds')
    o.hide_render=True;o.display_type='WIRE'
for tree in list(groups['Vegetation'].objects):
    if not tree.name.startswith('Pine'):continue
    o=box(tree.name+'Trunk-colonly',(tree.location.x,tree.location.y,tree.location.z+1),(.45,.45,2),'black','Bounds')
    o.hide_render=True;o.display_type='WIRE'
for prop in list(groups['Props'].objects):
    if prop.name.startswith(('Fence','FarmFence')):size=(2.6,.28,1.1)
    elif prop.name.startswith('Barrel'):size=(.72,.72,1.15)
    elif prop.name.startswith('Crate'):size=(1,1,1)
    elif prop.name.startswith('Lantern'):size=(.28,.28,2.4)
    else:continue
    size=Vector(size)*prop.scale.x
    o=box(prop.name+'Obstacle-colonly',(prop.location.x,prop.location.y,prop.location.z+size.z/2),size,'black','Bounds')
    o.rotation_euler.z=prop.rotation_euler.z;o.hide_render=True;o.display_type='WIRE'
for name,pos,size in [('MineBack',(0,48.5,12.6),(6.6,.3,5.2)),('MineLeft',(-10,49,15),(13,3,10)),('MineRight',(10,49,15),(13,3,10))]:
    o=box(name+'-colonly',pos,size,'black','Bounds');o.hide_render=True;o.display_type='WIRE'
for name,pos,size in [
    ('BridgeWalkFloor',(27,29,6.04),(16,6.8,.12)),
    ('DockWalkFloor',(23,-17,2.94),(8.4,7,.12)),
    ('DockGangwayFloor',(17.55,-16,2.96),(3.2,3.2,.12)),
    ('DockNorthRim',(23,-13.7,3.55),(8.2,.18,1.1)),
    ('DockSouthRim',(23,-20.3,3.55),(8.2,.18,1.1)),
    ('DockEastRim',(27,-17,3.55),(.18,6.6,1.1)),
    ('GangwayNorthRim',(17.55,-14.4,3.55),(3.2,.18,1.1)),
    ('GangwaySouthRim',(17.55,-17.6,3.55),(3.2,.18,1.1)),
    ('DockShoreSouthRim',(18.9,-18.975,3.55),(.18,2.65,1.1)),
    ('DockShoreNorthRim',(18.9,-14.025,3.55),(.18,.65,1.1))
]:
    o=box(name+'-colonly',pos,size,'black','Bounds');o.hide_render=True;o.display_type='WIRE'

def terrain_height(x,y):
    height=-100
    for poly,h,cuts in SLABS:
        inside=False
        for (ax,ay),(bx,by) in zip(poly,poly[1:]+poly[:1]):
            if (ay>y)!=(by>y) and x<(bx-ax)*(y-ay)/(by-ay)+ax:inside=not inside
        if inside and not any(all(n.dot(Vector((x,y,0)))>=d for n,d in planes) for planes in cuts):height=max(height,h)
    return height
def walk_height(x,y):
    height=terrain_height(x,y);p=Vector((x,y,0))
    for a,b in RAMPS:
        start,end=Vector(a),Vector(b);d=end-start;d.z=0
        t=(p-Vector((a[0],a[1],0))).dot(d)/d.length_squared
        if -.025<=t<=1.025:
            side=abs((p-Vector((a[0],a[1],0))).dot(Vector((-d.y,d.x,0)).normalized()))
            if side<=2.0:height=max(height,a[2]+max(0,min(1,t))*(b[2]-a[2])+.04)
    # Continuous authored bridge, dock and gangway surfaces.
    for lo,hi,h in [((19,25.6),(35,32.4),6.1),((18.8,-20.5),(27.2,-13.5),3),((15.95,-17.6),(19.15,-14.4),3)]:
        if lo[0]<=x<=hi[0] and lo[1]<=y<=hi[1]:height=max(height,h)
    return height
# Editable collision-only edge guards follow actual exposed terrace edges.
# Godot's -colonly import suffix creates physics shapes and removes visual meshes.
guard_count=0
for surface in [o for o in groups['Terrain'].objects if o.name.endswith('_Grass')]:
    # Include the ramp cut boundaries, not only the uncut slab outline.
    edges={}
    for face in surface.data.polygons:
        ids=list(face.vertices)
        for ia,ib in zip(ids,ids[1:]+ids[:1]):
            a=surface.matrix_world@surface.data.vertices[ia].co;b=surface.matrix_world@surface.data.vertices[ib].co
            key=tuple(sorted([tuple(round(v,5) for v in a),tuple(round(v,5) for v in b)]))
            if key not in edges:edges[key]=[a,b,0]
            edges[key][2]+=1
    for a,b,nfaces in edges.values():
        if nfaces!=1:continue
        h=a.z;delta=b-a;length=delta.length
        if length<.1:continue
        direction=delta.normalized();normal=Vector((-direction.y,direction.x,0))
        count=max(1,math.ceil(length/.65))
        for i in range(count):
            p=a+delta*((i+.5)/count)
            one=walk_height(*(p+normal*.35)[:2]);two=walk_height(*(p-normal*.35)[:2])
            if abs(max(one,two)-h)>.15 or abs(one-two)<.8:continue
            o=box(f'EdgeGuard_{guard_count:03d}-colonly',(p.x,p.y,h+.9),(length/count+.12,.40,2.0),'black','Bounds')
            o.rotation_euler.z=math.atan2(direction.y,direction.x);o.hide_render=True;o.display_type='WIRE';guard_count+=1

scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.65,.75,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.light_add(type='SUN',location=(0,-20,50));sun=group(bpy.context.object,'Review');sun.rotation_euler=(.5,-.5,-.3);sun.data.energy=2
bpy.ops.object.light_add(type='AREA',location=(0,-10,45));light=group(bpy.context.object,'Review');light.data.energy=2500;light.data.shape='DISK';light.data.size=60
bpy.ops.object.camera_add(location=(40,-105,100));cam=group(bpy.context.object,'Review');cam.name='ReferenceOverview';cam.data.type='ORTHO';cam.data.ortho_scale=120
cam.rotation_euler=(Vector((0,8,2))-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=1400;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'greystone_master.blend'),compress=True)
scene.render.filepath=str(ART/'overview.png');bpy.ops.render.render(write_still=True)
(DEST/'manifest.json').write_text(json.dumps({'status':'CANDIDATE_BUILT','buildings':'Four Pixal3D designs, five reusable variants, seven placed buildings','ai_sources':{k:str(v.relative_to(ROOT)) for k,v in ai_sources.items()},'collections':list(groups),'building_placements':placements,'same_facing_duplicate_cleanup':cleanup_counts,'edge_guards':guard_count,'coordinate_system':'Blender Z up, north +Y; GLTF exporter handles Y up','original_main_entry_replaced':False,'rpg_candidate':'scenes/main/greystone_blender_integration.tscn'},ensure_ascii=False,indent=2),encoding='utf8')
print('BLENDER_MASTER_ASSEMBLED',str(DEST/'greystone_master.blend'),flush=True)
