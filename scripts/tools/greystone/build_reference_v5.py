"""Owned Blender master scene with four Pixal3D designs and reusable modules.
Run in background factory startup; never edits the user's live Blender scene.
"""
import bpy, bmesh, math, random, json, hashlib, sys
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.geometry import tessellate_polygon

ROOT=Path(__file__).resolve().parents[3]
DEST=ROOT/'source_assets/greystone_reference_20261024'
ART=ROOT/'artifacts/village_repair/build'
DEST.mkdir(parents=True,exist_ok=True);ART.mkdir(parents=True,exist_ok=True)
(DEST/'.gdignore').touch()
bpy.context.preferences.filepaths.file_preview_type='NONE'
sys.path.insert(0,str(Path(__file__).parent))
from reference_art_pass import repair_roof, color_material
roof_repairs={}
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.name='Greystone_Master_Candidate'
rng=random.Random(231023)
groups={}
for name in ['Terrain','Paths','Buildings_Candidate','Water','Cliffs','Vegetation','Props','Mine','Bounds','Review']:
    c=bpy.data.collections.new(name);scene.collection.children.link(c);groups[name]=c
materials={}
for name,col in {'grass':(.35,.44,.22,1),'earth':(.67,.54,.35,1),'stone':(.43,.44,.41,1),'water':(.12,.52,.64,1),'foam':(.48,.78,.81,1),'wood':(.26,.15,.065,1),'black':(.025,.03,.025,1)}.items():
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
RAMPS=[((-7,-29,0),(-7,-23,3)),((-27,1,3),(-33,1,5)),((-19,19,3),(-24,25,6)),((3,36,6),(0,43,10)),((40,10,3),(40,17,6))]
SLABS=[]
ROAD_PATHS=[]
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
            # Broad faceted retaining blocks stay outside the walking footprint.
            tangent=Vector(((q[0]-x)/length,(q[1]-y)/length,0));outer=Vector((tangent.y,-tangent.x,0))
            half=length/max(1,int(length/4))*.57;depth=rng.uniform(1.2,2.0)
            ring=[(-half,-.12),(-half*.78,depth),(-half*.15,depth*1.12),(half*.82,depth),(half,-.10),(0,-.18)]
            verts=[]
            for band,level in enumerate([bottom,h-(h-bottom)*.48,h-.06]):
                for k,(u,v) in enumerate(ring):
                    jitter=rng.uniform(-.8,.6) if k not in [0,4,5] else 0
                    spread=[1.20,1.12,1.0][band]
                    zz=level+(rng.uniform(-.6,.4) if band==1 else (-rng.uniform(0,.24) if band==2 and k in [1,2,3] else 0))
                    verts.append(Vector((px,py,zz))+tangent*(u+jitter)+outer*(v*spread))
            faces=[];nring=len(ring)
            for band in range(2):
                for k in range(nring):
                    j=(k+1)%nring;a=band*nring+k;b=band*nring+j;c=(band+1)*nring+j;d=(band+1)*nring+k
                    faces.extend([(a,b,c),(a,c,d)])
            faces.extend([tuple(range(nring-1,-1,-1)),tuple(range(2*nring,3*nring))])
            cliff=mesh(name+'_RockFace',verts,faces,'stone','Cliffs')
            colors=cliff.data.color_attributes.new(name='RockFacets',type='FLOAT_COLOR',domain='CORNER')
            for face in cliff.data.polygons:
                tint=rng.uniform(.81,1.08)
                for loop in face.loop_indices:colors.data[loop].color=(tint,tint*.99,tint*.97,1)

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
    result=mesh(name,vs,[(i,i+1,i+3,i+2) for i in range(0,len(vs)-2,2)],'stone' if 'RampCollisionGuide' in name else 'earth','Paths')
    uv=result.data.uv_layers.new(name='RoadWidth')
    for face in result.data.polygons:
        for loop in face.loop_indices:
            index=result.data.loops[loop].vertex_index
            uv.data[loop].uv=(float(index%2),index//2*.2)
    if name!='River':ROAD_PATHS.append({'name':name,'points':[list(p) for p in points],'width':width})
    return result
def stairs(name,start,end,width=4):
    a,b=Vector(start),Vector(end)
    if a.z>b.z:a,b=b,a
    delta=b-a;n=max(2,round(delta.z/.18));length=Vector((delta.x,delta.y,0)).length
    # Full masonry treads close the underside and side seams of the clipped flight.
    for i in range(n):
        p=a+delta*((i+.5)/n);top=a.z+delta.z*(i+1)/n+.025;bottom=a.z-.20
        p.z=(top+bottom)/2
        o=box(name+str(i),p,(width+.34,length/n+.055,top-bottom),'stone','Paths')
        o.rotation_euler.z=-math.atan2(delta.x,delta.y)
    path(name+'_RampCollisionGuide',[start,end],width+.3)

# North is +Y in Blender; GLTF export maps it to Godot -Z.
slab('VillageCore',[(-28,-23),(-13,-28),(4,-24),(17,-17),(23,-4),(20,13),(11,23),(-8,25),(-26,17),(-33,1)],3)
slab('NorthTerrace',[(-30,13),(-20,24),(-4,23),(11,19),(23,25),(24,39),(5,46),(-14,43),(-34,30)],6)
slab('MineRidge',[(-19,35),(-10,43),(11,39),(23,40),(22,51),(-9,53),(-25,46)],10)
slab('WesternApproach',[(-45,-18),(-33,-23),(-26,-13),(-31,0),(-29,15),(-36,27),(-46,20),(-49,3)],5)
slab('SouthEntry',[(-24,-38),(-5,-43),(12,-35),(16,-24),(2,-21),(-12,-27),(-29,-22)],0)
slab('EastLowerBank',[(34,-24),(48,-20),(50,10),(47,16),(35,14),(33,-2)],3)
slab('EastUpperBank',[(35,14),(47,16),(48,27),(44,43),(32,40),(33,25)],6)
slab('WaterfallCliff',[(20,43),(31,39),(44,43),(45,55),(20,56)],14)
plaza=[(0,0,3.035)]+[(8.2*math.cos(i*math.tau/24)*(1+.025*math.sin(i*2.3)),7.2*math.sin(i*math.tau/24),3.035) for i in range(24)]
plaza_obj=mesh('VillagePlaza',plaza,[(0,i+1,(i+1)%24+1) for i in range(24)],'earth','Paths')
# A connected irregular village clearing, rather than isolated radial path ribbons.
clearing=[(-22,-2,3.03),(-22,2,3.03),(-14,6,3.03),(-4,12,3.03),(2,11,3.03),(4,8,3.03),(12,10,3.03),(16,1,3.03),(13,-7,3.03),(7,-11,3.03),(0,-18,3.03),(-8,-18,3.03),(-9,-6,3.03),(-17,-5,3.03)]
points=[Vector(p) for p in clearing]
triangles=tessellate_polygon([list(reversed(points))])
faces=[tuple(points.index(v) if not isinstance(v,int) else len(points)-1-v for v in tri) for tri in triangles]
o=mesh('VillageClearing',points,faces,'earth','Paths')
uv_clear=o.data.uv_layers.new(name='Clearing')
for loop in uv_clear.data:loop.uv=(.5,.5)
uv=plaza_obj.data.uv_layers.new(name='Plaza')
for item in uv.data:item.uv=(.5,.5)
for name,pts,w in [
 ('InnRoad',[(0,-2,3),(-5,7,3),(-9,10.5,3)],4),
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
 ('EastUpperTrail',[(32,29,6),(39,23,6),(40,17,6)],3.2),
 ('EastLowerTrail',[(40,10,3),(39,6,3),(35,6,3),(36,-4,3),(39,-14,3)],3.2),
 ('NorthStepsApproach',[(-26,1,3),(-26,14,3),(-19,19,3)],3.2),
 ('CentralBridgeRoad',[(3,1,3),(12,2,3),(19.5,6,3)],3.8),
 ('MineUpperApron',[(0,43,10),(0,47,10)],4.3),
 ('SouthHouseDoor',[(0,-21,3),(5,-21,3)],3),
 ('WestHouseDoor',[(-3,-12,3),(-8,-18,3),(-15,-16,3)],3)]:path(name,pts,w)
stairs('WestSteps',(-27,1,3),(-33,1,5),4)
stairs('NorthSteps',(-19,19,3),(-24,25,6),4)
stairs('MineSteps',(3,36,6),(0,43,10),4)
stairs('EntrySteps',(-7,-23,3),(-7,-29,0),4)
stairs('EastSteps',(40,10,3),(40,17,6),4)
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
box('Waterfall',(28,37.6,8),(7,.3,12),'foam','Water')
mesh('UpperRiver',[(24.5,37.45,14.03),(31.5,37.45,14.03),(32,56,14.03),(24,56,14.03)],[(0,1,2,3)],'water','Water')
for i in range(9):
    x=25+i*.73
    mesh('WaterfallStream',[(x,37.39,14.0),(x+.22,37.39,14.0),(x+.40,37.39,2.02),(x-.08,37.39,2.02)],[(0,3,2,1)],'water' if i%3==0 else 'foam','Water')

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
        data,transform=library['house_a'];data=data.copy();roof_repairs[asset]=repair_roof(data,asset);library[asset]=(data,transform.copy())
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
            roof_repairs[asset]=repair_roof(data,asset)
            library[asset]=(data,Matrix.Identity(4))
            imported=list(set(bpy.data.objects)-before)
        else:
            if len(meshes)!=1:raise ValueError((asset,len(meshes)))
            proto=meshes[0];bpy.context.view_layer.update();library[asset]=(proto.data.copy(),proto.matrix_world.copy())
        for o in imported:bpy.data.objects.remove(o,do_unlink=True)
    data,transform=library[asset];o=bpy.data.objects.new(name,data);groups[key].objects.link(o)
    o.matrix_world=transform;o.location=pos;o.scale=(scale,)*3;o.rotation_euler.z=angle;return o
placements=[('inn','Inn',(-9,16,3),1.25,0),('item_shop','ItemShop',(-21,7,3),1.15,0),('weapon_shop','WeaponShop',(13,-5,3),1.3,0),('house_a','WestHouse',(-15,-13,3),1.18,0),('house_a_blue','SouthHouse',(5,-18,3),1.18,0),('house_a_blue','GuildHall',(9,17,3),1.4,0)]
for a,n,p,s,r in placements:instance(a,n,p,s,r,'Buildings_Candidate')
instance('stone_well','CentralWell',(0,0,3),1.35)
upper_bridge=instance('wooden_bridge','UpstreamBridge',(27,29,6.10),2.0)
upper_bridge.scale=(2.0,1.18,1.0)
instance('wooden_dock','LakesideDock',(23,-17,3),1.4)
# Central river crossing in the new reference, distinct from the upstream bridge.
bridge_stations=[]
for i in range(33):
    x=19+i*.5;h=3.08+.62*math.sin(math.pi*i/32)
    bridge_stations.append((x,6,h))
    box('CentralBridgeDeck',(x,6,h-.06),(.49,3.6,.12),'wood','Props')
for side in [-1,1]:
    for i in range(0,33,4):
        x,y,h=bridge_stations[i]
        box('CentralBridgePost',(x,6+side*1.9,h+.5),(.20,.20,1.25),'wood','Props')
    for i in range(32):
        x,y,h=bridge_stations[i];x2,_,h2=bridge_stations[i+1]
        for lift in [.45,.98]:
            o=box('CentralBridgeRail',((x+x2)/2,6+side*1.9,(h+h2)/2+lift),(.52,.12,.14),'wood','Props')
            o.rotation_euler.y=-math.atan2(h2-h,x2-x)
    for x in [20,24,28,32,35]:box('CentralBridgePier',(x,6+side*1.65,1.3),(.32,.32,4.5),'wood','Props')
mesh('CentralBridge_RampCollisionGuide',[(x,y+side*1.8,h) for x,y,h in bridge_stations for side in [-1,1]],[(i,i+1,i+3,i+2) for i in range(0,64,2)],'wood','Paths')
ROAD_PATHS.append({'name':'CentralBridge','points':[list(v) for v in bridge_stations],'width':3.6})
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
    instance('rock_medium','CliffRock',(x,y,z),rng.uniform(1.1,1.8),rng.random()*6,'Cliffs')
box('MineDark',(0,48.7,12.5),(6.6,.3,5),'black','Mine')
for x in [-3,3]:box('MinePost',(x,46.5,12.4),(.65,.65,4.8),'wood','Mine')
box('MineLintel',(0,46.5,15),(7,.8,.65),'wood','Mine')
for x in [-5,5]:instance('rock_medium','MineRock',(x,47,10),1.35,0,'Mine')
def portal_rock(name,profile,front=48,depth=4):
    n=len(profile);vs=[(x,front,z) for x,z in profile]+[(x,front+depth,z) for x,z in profile]
    faces=[tuple(range(n)),tuple(range(n*2-1,n-1,-1))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,faces,'stone','Mine')
# One connected mountain face around a real portal opening; no black crown cracks.
xs=[-18,-12,-7,-3.4,0,3.4,7,12,18]
heights=[14,16,18,19,19.5,19,18,16,14]
verts=[]
for row in range(4):
    for col,x in enumerate(xs):
        z=[10,15.5,15.5+(heights[col]-15.5)*.65,heights[col]][row]
        verts.append((x,48+(rng.uniform(-1.1,.8) if row else 0),z))
faces=[]
for row in range(3):
    for col in range(len(xs)-1):
        if row==0 and -3.4<=xs[col] and xs[col+1]<=3.4:continue
        a=row*len(xs)+col;b=a+1;c=b+len(xs);d=a+len(xs)
        faces.extend([(a,b,c),(a,c,d)])
front_count=len(verts)
verts.extend([(x,56,z) for x,_,z in verts])
for col in range(len(xs)-1):
    a=3*len(xs)+col;b=a+1
    faces.append((a,b,b+front_count,a+front_count))
faces.extend([(0,front_count,front_count+3*len(xs),3*len(xs)),(len(xs)-1,4*len(xs)-1,front_count+4*len(xs)-1,front_count+len(xs)-1)])
mesh('MineCliffMountain',verts,faces,'stone','Mine')
for x in [-15,-10,-5,0,5,10,15]:
    top=next(heights[i]+(heights[i+1]-heights[i])*(x-xs[i])/(xs[i+1]-xs[i]) for i in range(len(xs)-1) if xs[i]<=x<=xs[i+1])
    instance('pine_tree_a','MineRimPine',(x,52.5,top),rng.uniform(.6,.9),rng.random()*6,'Vegetation')
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
for item in groups['Props'].objects:
    if item.name.startswith(('Wheel','Waterwheel')):
        pivot=Vector((34,8,4));rotation=Matrix.Rotation(-.65,4,'Z')
        item.matrix_world=Matrix.Translation(Vector((34,0,4)))@rotation@Matrix.Translation(-pivot)@item.matrix_world
# Closed double-skin hull, with the cabin floor above the undisturbed waterline.
outline=[(-.9,-1.8),(.9,-1.8),(1.1,1.1),(0,2.3),(-1.1,1.1)];n=len(outline)
vs=[(30+x,-22+y,2.64) for x,y in outline]+[(30+x*.68,-22+y*.82,1.7) for x,y in outline]+[(30+x*.86,-22+y*.93,2.61) for x,y in outline]+[(30+x*.64,-22+y*.80,2.16) for x,y in outline]
faces=[]
for i in range(n):
    j=(i+1)%n
    faces.extend([(i,n+i,n+j,j),(i,j,2*n+j,2*n+i),(2*n+i,2*n+j,3*n+j,3*n+i)])
faces.extend([tuple(range(2*n-1,n-1,-1)),tuple(range(3*n,4*n))])
boat=mesh('BoatHull',vs,faces,'wood','Props');boat['closed_hull']=True;boat['interior_floor_m']=2.16
for y in [-22.8,-21.4]:box('BoatSeat',(30,y,2.47),(1.6,.29,.14),'wood','Props')
for i in range(n):
    a=Vector(vs[i]);b=Vector(vs[(i+1)%n]);delta=b-a
    rim=box('BoatGunwale',(a+b)/2,(delta.length+.05,.12,.13),'wood','Props');rim.rotation_euler.z=math.atan2(delta.y,delta.x)
for y in [-23,-22.6,-22.2,-21.8,-21.4]:box('BoatFloorPlank',(30,y,2.19),(1.15,.37,.05),'wood','Props')
# Garden clusters stay beside houses rather than on their approach paths.
for x,y,z in [(-23,-12,3),(-20,-17,3),(-12,-18,3),(-20,4,3),(-16,8,3),(-4,19,3),(16,8,3),(17,-8,3),(9,-20,3),(-10,34,6),(36,30,6)]:
    instance('bush_a','Shrub',(x,y,z),.8,rng.random()*6,'Vegetation')
    instance('flower_a','Flowers',(x+.8,y-.6,z),.65,rng.random()*6,'Vegetation')
    for j in range(4):instance('grass_a','GrassTuft',(x+rng.uniform(-1.5,1.5),y+rng.uniform(-1.5,1.5),z),rng.uniform(.5,.9),rng.random()*6,'Vegetation')
for x,y,z in [(-43,11,5),(-44,22,5),(-37,23,5),(-32,39,6),(-24,38,6),(-17,41,6),(-13,48,10),(-9,49,10),(9,48,10),(14,47,10),(37,43,14),(41,48,14),(45,27,6),(44,5,6),(39,-15,6)]:
    instance('pine_tree_a','PineContext',(x,y,z),rng.uniform(1.1,1.7),rng.random()*math.tau,'Vegetation')

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
    for lo,hi,h in [((19,27),(35,31),6.1),((18.8,-20.5),(27.2,-13.5),3),((15.95,-17.6),(19.15,-14.4),3)]:
        if lo[0]<=x<=hi[0] and lo[1]<=y<=hi[1]:height=max(height,h)
    if 19<=x<=35 and abs(y-6)<=1.8:height=max(height,3.08+.62*math.sin(math.pi*(x-19)/16))
    return height
# Canopy clearance uses the entire foliage footprint, not only its trunk.
def road_clear(x,y,h,radius):
    if h==3 and (x*x/(9+radius)**2+y*y/(8+radius)**2)<1:return False
    for road in ROAD_PATHS:
        for av,bv in zip(road['points'],road['points'][1:]):
            a,b=Vector(av),Vector(bv);delta=b-a;delta.z=0
            if delta.length_squared<1e-9:continue
            t=max(0,min(1,Vector((x-a.x,y-a.y,0)).dot(delta)/delta.length_squared))
            nearest=a+(b-a)*t
            if abs(nearest.z-h)>1.0:continue
            if math.hypot(x-nearest.x,y-nearest.y)<road['width']/2+radius+.35:return False
    return True
vegetation_repairs=[]
for o in list(groups['Vegetation'].objects):
    if not o.name.startswith('Pine'):continue
    height=terrain_height(o.location.x,o.location.y)
    if height<-1 or (height>12 and 23<o.location.x<33):
        vegetation_repairs.append({'name':o.name,'reason':'outside terrain or in upper river','position':list(o.location)})
        bpy.data.objects.remove(o,do_unlink=True);continue
    o.location.z=height
    bpy.context.view_layer.update()
    factor=min(1.0,4.9/max(.1,o.dimensions.z),2.8/max(.1,o.dimensions.x,o.dimensions.y))
    o.scale*=factor
    bpy.context.view_layer.update()
    r=max(o.dimensions.x,o.dimensions.y)/2
    if not road_clear(o.location.x,o.location.y,o.location.z,r):
        vegetation_repairs.append({'name':o.name,'reason':'canopy overlaps authored road','position':list(o.location)})
        bpy.data.objects.remove(o,do_unlink=True);continue
    # Shared local palette; the approved original asset is left untouched.
    if not o.data.get('reference_pine_palette'):
        o.data=o.data.copy()
        for i,material in enumerate(o.data.materials):
            token=material.name.lower()
            if any(x in token for x in ['pine','leaf','foliage','green']):
                o.data.materials[i]=color_material('ReferenceNeedles_'+str(i),[(.24,.36,.18),(.18,.30,.16),(.28,.40,.20)][i%3])
        o.data['reference_pine_palette']=True
# Pine groves fill the outer slopes seen in the updated reference, off every road.
for i in range(650):
    x=rng.uniform(-44,44);y=rng.uniform(-30,47);h=terrain_height(x,y)
    if h<5 or not (x<-27 or y>25 or x>34) or (h>12 and 23<x<33):continue
    if not road_clear(x,y,h,1.3):continue
    if any(math.hypot(x-o.location.x,y-o.location.y)<2.6 for o in groups['Vegetation'].objects if o.name.startswith('Pine')):continue
    o=instance('pine_tree_a','PineGrove',(x,y,h),rng.uniform(.65,.9),rng.random()*6,'Vegetation')
    template=next(t for t in groups['Vegetation'].objects if t.name.startswith('Pine') and t.data.get('reference_pine_palette'))
    o.data=template.data
# White low-poly froth and inset river stones break the waterfall's straight sheet.
for i in range(15):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(rng.uniform(24.2,31.6),rng.uniform(36.5,38.0),2.09))
    o=bpy.context.object;o.name='FoamSplash';o.scale=(rng.uniform(.35,.85),rng.uniform(.2,.6),rng.uniform(.05,.15));o.data.materials.append(materials['foam']);group(o,'Water')
for x,y,scale in [(25,24,.8),(31,17,.9),(26,13,.55),(30,1,.7),(25,-6,.65),(30,-14,.55),(26,33,.6)]:
    instance('rock_medium','RiverStone',(x,y,1.55),scale,rng.random()*6,'Cliffs')
for x in [-2.8,2.8]:
    box('MineTorchStem',(x,46.15,12.9),(.13,.18,.9),'wood','Mine')
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,46.15,13.45))
    o=bpy.context.object;o.name='MineTorchFlame';o.scale=(.15,.15,.35);o.data.materials.append(color_material('ReferenceFlame',(.98,.55,.12)));group(o,'Mine')
# Yard borders repeat the supplied layout; clear roads and NPC forecourts stay open.
for x,y,angle in [(-17,14,math.pi/2),(-17,17,math.pi/2),(-14,20,0),(-10,20,0),(-6,20,0),
                    (-21,-12,math.pi/2),(-21,-15,math.pi/2),(-18,-9,0),(-14,-9,0),
                    (10,-18,math.pi/2),(10,-21,math.pi/2),(3,-15,0),(6,-15,0),
                    (19,-8,math.pi/2),(19,-4,math.pi/2),(7,-3,math.pi/2),
                    (15,16,math.pi/2),(15,19,math.pi/2),(-15,7,math.pi/2),
                    (-29,24,math.pi/2),(-27,29,0),(-22,29,0),(-13,29,0),(-6,29,0),
                    (-3,44,math.pi/2),(3,44,math.pi/2),(6,44,0),(-6,44,0)]:
    h=terrain_height(x,y)
    if h<0 or not road_clear(x,y,h,.2):continue
    if any(abs(x-o.location.x)<o.dimensions.x/2+.35 and abs(y-o.location.y)<o.dimensions.y/2+.35 for o in groups['Buildings_Candidate'].objects):continue
    instance('wooden_fence','ReferenceYardFence',(x,y,h),1,angle)
# Dense small undergrowth and stone accents sit off roads, like the supplied image.
for i in range(850):
    x=rng.uniform(-43,43);y=rng.uniform(-32,47);h=terrain_height(x,y)
    if h<-1 or not road_clear(x,y,h,.5) or (h>12 and 23<x<33):continue
    if any(math.hypot(x-o.location.x,y-o.location.y)<max(o.dimensions.x,o.dimensions.y)*.65+1 for o in groups['Buildings_Candidate'].objects):continue
    if i%3==0:instance('rock_medium','GardenStone',(x,y,h),rng.uniform(.25,.50),rng.random()*6,'Vegetation')
    elif i%3==1:instance('bush_a','GroundShrub',(x,y,h),rng.uniform(.5,1.05),rng.random()*6,'Vegetation')
    else:instance('grass_a','GroundGrass',(x,y,h),rng.uniform(.45,.8),rng.random()*6,'Vegetation')

# Reference-style planted cliff rims, fitted only outside walkable road corridors.
for x,y in [(-30,22),(-26,31),(-17,26),(-11,26),(-5,25),(8,22),(15,24),(20,34),(35,33),(43,20),(-37,1),(-40,-10),(-18,-29),(0,-26)]:
    h=terrain_height(x,y)
    if h<0 or not road_clear(x,y,h,1):continue
    instance('rock_medium','RimBoulder',(x,y,h-.1),rng.uniform(.65,1.2),rng.random()*6,'Cliffs')
    instance('bush_a','RimShrub',(x+.7,y,h),rng.uniform(.7,1),rng.random()*6,'Vegetation')
# Small stone pavers break up the dusty square without becoming walking obstacles.
for i in range(65):
    x=rng.uniform(-17,16);y=rng.uniform(-18,13)
    if x*x+y*y<9 or road_clear(x,y,3,.0):continue
    if any(abs(x-o.location.x)<o.dimensions.x/2+.4 and abs(y-o.location.y)<o.dimensions.y/2+.4 for o in groups['Buildings_Candidate'].objects):continue
    o=box('InsetPathStone',(x,y,3.065),(rng.uniform(.22,.55),rng.uniform(.18,.40),.03),'stone','Props');o.rotation_euler.z=rng.uniform(-.3,.3)
# Continuous small fences on the upper shelf frame the river route like the reference.
for x in [-15,-12,-9,-6,-3,0,3,6,9,12,15,18]:
    y=24.0 if x<5 else 22.6+x*.12;h=terrain_height(x,y)
    if h==6 and road_clear(x,y,h,.4):instance('wooden_fence','ReferenceYardFence',(x,y,h),1,0)

# Broken high crags behind the playable terraces frame the mine and waterfall.
for x,y,z,scale in [(-18,54,13,3.0),(-9,55,16,2.6),(3,55,17,2.9),(13,53,14,3.1),(22,52,14,2.2),(35,50,14,2.8),(42,51,14,3.0)]:
    instance('rock_medium','BackdropCrag',(x,y,z),scale,rng.random()*6,'Cliffs')

# Imported upstream bridge was absent from the soil-strip exclusion list. A
# background stone could therefore sit on its deck despite routes being walkable.
# Audit actual world bounds after all placement, before creating any trunk bodies.
bpy.context.view_layer.update()
bridge_clearance_removed=[]
for collection in ['Vegetation','Cliffs']:
    for obj in list(groups[collection].objects):
        corners=[obj.matrix_world@Vector(corner) for corner in obj.bound_box]
        lo=Vector([min(p[i] for p in corners) for i in range(3)])
        hi=Vector([max(p[i] for p in corners) for i in range(3)])
        if hi.x>18.65 and lo.x<35.35 and hi.y>26.65 and lo.y<31.35 and hi.z>6.05 and lo.z<8.6:
            bridge_clearance_removed.append({'collection':collection,'name':obj.name,'position':list(obj.location)})
            bpy.data.objects.remove(obj,do_unlink=True)

# Freeze the validated layout-4 bodies independently of visual roof extents.
# Editing a window or eave must not silently move a wall into an NPC lane.
body_file=Path(__file__).with_name('reference_building_collisions_v4.json')
body_contract=json.loads(body_file.read_text(encoding='utf8'))
assert body_contract['layout_version']==4
assert {row['name'] for row in body_contract['bodies']}=={o.name+'Body-colonly' for o in groups['Buildings_Candidate'].objects}
for row in body_contract['bodies']:
    o=mesh(row['name'],row['vertices'],row['faces'],'black','Bounds')
    o.matrix_world=Matrix(row['matrix_world'])
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
    ('BridgeWalkFloor',(27,29,6.04),(16,4.0,.12)),
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

from reference_detail_pass import apply_reference_details
detail_receipt=apply_reference_details(groups,materials)
from reference_courtyard_pass import apply_courtyards
courtyard_receipt=apply_courtyards(groups['Props'],groups['Vegetation'],ROAD_PATHS)
from reference_natural_edges import apply_natural_edges
natural_edges_receipt=apply_natural_edges(groups,materials,ROAD_PATHS,RAMPS,terrain_height)
from reference_water_pass import apply_water_details
water_details_receipt=apply_water_details(groups,materials)

scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.65,.75,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
bpy.ops.object.light_add(type='SUN',location=(0,-20,50));sun=group(bpy.context.object,'Review');sun.rotation_euler=(.5,-.5,-.3);sun.data.energy=3;sun.data.angle=.12;sun.data.color=(1,.9,.75)
bpy.ops.object.light_add(type='AREA',location=(0,-10,45));light=group(bpy.context.object,'Review');light.data.energy=2500;light.data.shape='DISK';light.data.size=60
bpy.ops.object.camera_add(location=(20,-94,105));cam=group(bpy.context.object,'Review');cam.name='ReferenceOverview';cam.data.type='ORTHO';cam.data.ortho_scale=98
cam.rotation_euler=(Vector((0,8,2))-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1400;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
import sys
sys.path.insert(0,str(Path(__file__).parent))
from polish_blender_surfaces import apply_surfaces
apply_surfaces()
# New export textures are capped at 1k for the actual on-screen building size.
# Only this factory process's packed image datablocks change; source GLBs stay intact.
bpy.data.orphans_purge(do_recursive=True)
for image in bpy.data.images:
    if image.source=='FILE' and max(image.size)>1024:
        w,h=image.size;factor=1024/max(w,h);image.scale(round(w*factor),round(h*factor));image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'greystone_master.blend'),compress=True)
scene.render.filepath=str(ART/'overview.png');bpy.ops.render.render(write_still=True)
(DEST/'manifest.json').write_text(json.dumps({'status':'CANDIDATE_BUILT','buildings':'Authored timber/plaster facades and closed roofs; six existing placements from the updated reference','ai_sources':{k:str(v.relative_to(ROOT)) for k,v in ai_sources.items()},'collections':list(groups),'building_placements':placements,'layout_version':4,'reference':'docs/references/greystone_reference_20261024.png','roof_repairs':roof_repairs,'vegetation_removed':vegetation_repairs,'roads':ROAD_PATHS,'builder_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'same_facing_duplicate_cleanup':cleanup_counts,'edge_guards':guard_count,'coordinate_system':'Blender Z up, north +Y; GLTF exporter handles Y up','original_main_entry_replaced':False,'rpg_candidate':'scenes/main/greystone_reference_integration.tscn'},ensure_ascii=False,indent=2),encoding='utf8')
layout={'layout_version':4,'reference':'docs/references/greystone_reference_20261024.png','reference_sha256':hashlib.sha256((ROOT/'docs/references/greystone_reference_20261024.png').read_bytes()).hexdigest(),'blender_axes':'x east, y north, z up; Godot x,y,z = x,z,-y','building_placements':placements,'roads':ROAD_PATHS,'ramps':RAMPS,'bridge_centers':[[27,29,6.1],[27,6,3.7]],'landmarks':{'well':[0,0,3],'mine':[0,46.5,10],'dock':[23,-17,3],'forest_exit':[-44,18,5]},'builder_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
(ROOT/'data/world/greystone_reference_layout_v4.json').write_text(json.dumps(layout,indent=2),encoding='utf-8')
receipt=json.loads((DEST/'manifest.json').read_text(encoding='utf8'))
receipt['bridge_clearance_removed']=bridge_clearance_removed
receipt['detail_pass']=detail_receipt
receipt['courtyard_pass']=courtyard_receipt
receipt['courtyard_script_sha256']=hashlib.sha256(Path(__file__).with_name('reference_courtyard_pass.py').read_bytes()).hexdigest()
receipt['natural_edges']=natural_edges_receipt
receipt['natural_edges_script_sha256']=hashlib.sha256(Path(__file__).with_name('reference_natural_edges.py').read_bytes()).hexdigest()
receipt['water_details']=water_details_receipt
receipt['water_details_script_sha256']=hashlib.sha256(Path(__file__).with_name('reference_water_pass.py').read_bytes()).hexdigest()
receipt['facade_script_sha256']=hashlib.sha256(Path(__file__).with_name('reference_facades.py').read_bytes()).hexdigest()
receipt['architectural_sources_sha256']={name:hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest() for name in ['reference_art_pass.py','reference_building_collisions_v4.json']}
(DEST/'manifest.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2),encoding='utf8')
print('REFERENCE_V5_MASTER_ASSEMBLED',str(DEST/'greystone_master.blend'),flush=True)
