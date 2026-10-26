"""Build the complete cutaway mine in an owned background Blender process."""
import bpy, bmesh, json, math, random, hashlib, sys
from pathlib import Path
from mathutils import Vector,Matrix

ROOT=Path(__file__).resolve().parents[2]
LAYOUT=json.loads((ROOT/'data/world/mine_reference_layout.json').read_text(encoding='utf8'))
OUT=ROOT/'assets/models/mine_reference'
SOURCE=ROOT/'source_assets/mine_reference_20261024'
OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').touch()
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene;scene.name='Crystal_Mine_Reference_Master'
bpy.context.preferences.filepaths.file_preview_type='NONE'
rng=random.Random(241024)
collections={};materials={};colliders=[];sources=[]
def collection(name):
    if name not in collections:
        c=bpy.data.collections.new(name);scene.collection.children.link(c);collections[name]=c
    return collections[name]
def link(obj,group):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    collection(group).objects.link(obj);return obj
def linear(c):return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
for name,color in {'Rock':(.32,.35,.40),'Earth':(.65,.49,.29),'Wood':(.40,.25,.12),'WoodLight':(.56,.36,.18),'Metal':(.19,.21,.22),'Brass':(.62,.42,.19),'Crystal':(.12,.61,.95),'Flame':(1,.52,.08),'Canvas':(.77,.65,.43),'Water':(.08,.43,.69),'Fall':(.20,.65,.92),'Rope':(.49,.37,.22)}.items():
    m=bpy.data.materials.new('Mine_'+name);m.diffuse_color=tuple(linear(v) for v in color)+(1,);m.use_nodes=True
    bsdf=m.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=m.diffuse_color;bsdf.inputs['Roughness'].default_value=.82
    if name in ['Crystal','Flame','Water','Fall']:
        bsdf.inputs['Emission Color'].default_value=m.diffuse_color;bsdf.inputs['Emission Strength'].default_value=2 if name in ['Crystal','Flame'] else .18
    if name in ['Rock','Earth','Wood','WoodLight']:
        n=m.node_tree.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=9 if name=='Rock' else 24
        mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.22;mix.inputs[1].default_value=m.diffuse_color
        m.node_tree.links.new(n.outputs['Fac'],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],bsdf.inputs['Base Color'])
    materials[name]=m
def B(p):return Vector((p[0],-p[2],p[1]))
def mesh(name,points,faces,material,group):
    data=bpy.data.meshes.new(name);data.from_pydata(points,[],faces);data.update()
    o=bpy.data.objects.new(name,data);collection(group).objects.link(o);o.data.materials.append(materials[material]);return o
def box(name,p,size,material,group,bevel=0):
    x,y,z=[v*.5 for v in size]
    o=mesh(name,[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material,group)
    o.location=p
    if bevel:
        mod=o.modifiers.new('Soft timber edges','BEVEL');mod.width=bevel;mod.segments=1
    return o
def gbox(name,p,size,material,group,bevel=0):
    return box(name,B(p),(size[0],size[2],size[1]),material,group,bevel)
def beam(name,a,b,width,depth,material,group):
    a,b=Vector(a),Vector(b);o=box(name,(a+b)*.5,(width,depth,(b-a).length),material,group,.025)
    direction=(b-a).normalized();side=Vector((0,0,1)).cross(direction)
    if side.length<.01:side=Vector((1,0,0))
    side.normalize();up=direction.cross(side).normalized()
    o.rotation_euler=Matrix((side,up,direction)).transposed().to_euler();return o
def cylinder(name,p,radius,depth,material,group,vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=p)
    o=bpy.context.object;o.name=name;link(o,group);o.data.materials.append(materials[material]);return o
def stone(name,p,size,group):
    # Closed, flat-crowned convex blocks instead of stretched pointed spheres.
    rock_rng=random.Random();rock_rng.setstate(rng.getstate())
    # Preserve the old 42-vertex rock's 126 draws: later rubble collider
    # placement must not change merely because this visual topology changed.
    for unused in range(126):rng.random()
    bm=bmesh.new()
    for z,r in [(-.92,.72),(-.12,1.0),(.91,.77)]:
        for i in range(8):
            angle=math.tau*(i/8+.0625)
            bm.verts.new((math.cos(angle)*r*rock_rng.uniform(.94,1.06),math.sin(angle)*r*rock_rng.uniform(.94,1.06),z+rock_rng.uniform(-.035,.035)))
    hull=bmesh.ops.convex_hull(bm,input=list(bm.verts))
    unused=[v for v in bm.verts if not v.link_faces]
    if unused:bmesh.ops.delete(bm,geom=unused,context='VERTS')
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bmesh.ops.triangulate(bm,faces=list(bm.faces))
    data=bpy.data.meshes.new(name);bm.to_mesh(data);bm.free()
    o=bpy.data.objects.new(name,data);collection(group).objects.link(o)
    o.location=p;o.scale=tuple(s*rock_rng.uniform(.94,1.06) for s in size)
    o.rotation_euler.z=rock_rng.uniform(-.28,.28)
    o.data.materials.append(materials['Rock']);return o
def collider_box(name,p,size,rotation=0):colliders.append({'name':name,'type':'box','position':list(p),'size':list(size),'rotation':rotation})
def slope_points(a,b,width,bottom=-.45,top=0):
    a,b=Vector(a),Vector(b);d=Vector((b.x-a.x,0,b.z-a.z)).normalized();n=Vector((-d.z,0,d.x))*width*.5
    return [list(p+n*sign+Vector((0,h,0))) for h in [bottom,top] for p in [a,b] for sign in [-1,1]]
def slope(name,a,b,width,group,kind):
    pts=slope_points(a,b,width)
    faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    if kind=='bridge':
        a,b=Vector(a),Vector(b);length=(b-a).length;n=Vector((-(b.z-a.z),0,b.x-a.x)).normalized()
        count=math.ceil(length/.48)
        for i in range(count):
            # Keep the timber landing 3cm above the earthen platform. The
            # authored bridge hull remains unchanged; coplanar top faces flicker.
            p=a.lerp(b,(i+.5)/count)+Vector((0,-.085,0));run=.44
            if name=='north_bridge':
                # Cross bridge already supplies the junction deck. Trim the
                # north planks at its edge instead of layering coplanar boards.
                crossing=next(v for v in LAYOUT['links'] if v['id']=='cross_bridge')
                center=crossing['a'][2];half=crossing['width']*.5
                offset=p.z-center;outside=abs(offset)-half
                if outside<=-.22:continue
                if outside<.22:
                    run=outside+.22;p.z=center+math.copysign(half+run*.5,offset)
            beam(name+'_Plank',B(p-n*width*.5),B(p+n*width*.5),run,.23,'WoodLight',group)
        for side in [-1,1]:
            beam(name+'_Girder',B(a+n*(width*.38*side)+Vector((0,-.55,0))),B(b+n*(width*.38*side)+Vector((0,-.55,0))),.36,.4,'Wood',group)
    else:
        a,b=Vector(a),Vector(b);count=max(1,math.ceil(abs(b.y-a.y)/.14))
        d=Vector((b.x-a.x,0,b.z-a.z)).normalized();n=Vector((-d.z,0,d.x))
        for side in [-1,1]:
            beam(name+'_Stringer',B(a+n*width*.40*side+Vector((0,-.25,0))),B(b+n*width*.40*side+Vector((0,-.25,0))),.25,.3,'Wood',group)
        for i in range(count):
            p=a.lerp(b,(i+.5)/count)
            beam(name+'_Tread',B(p-n*width*.5+Vector((0,.015,0))),B(p+n*width*.5+Vector((0,.015,0))),max(.2,Vector((b.x-a.x,0,b.z-a.z)).length/count),.12,'WoodLight',group)
    colliders.append({'name':name,'type':'hull','points':pts})
    return pts
def fence(name,a,b,group,solid=True):
    a,b=Vector(a),Vector(b);length=(b-a).length
    for f in [.46,.94]:beam(name+'_Rail',B(a+Vector((0,f,0))),B(b+Vector((0,f,0))),.15,.16,'WoodLight',group)
    for i in range(max(2,math.ceil(length/2.4)+1)):
        t=i/max(1,math.ceil(length/2.4));p=a.lerp(b,min(t,1))
        gbox(name+'_Post',p+Vector((0,.6,0)),(.24,1.35,.24),'Wood',group,.02)
    if solid:
        pts=slope_points(a,b,.20,0,1.10);colliders.append({'name':name,'type':'hull','points':pts})

# Reuse already approved assets as Blender linked mesh templates.
templates={}
for name,relative in {'crate':'assets/models/greystone/props/crate.glb','barrel':'assets/models/greystone/props/barrel.glb','crystal':'assets/models/greystone/props/crystal_blue.glb','support':'assets/models/environment/mine_support_frame.glb'}.items():
    before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(ROOT/relative));objects=list(set(bpy.data.objects)-before)
    meshes=[o for o in objects if o.type=='MESH'];templates[name]=[]
    for o in meshes:
        data=o.data.copy()
        if name in ['crate','barrel']:
            for i,m in enumerate(data.materials):
                if m and 'iron' in m.name.lower():data.materials[i]=materials['Metal']
                elif m:data.materials[i]=materials['WoodLight' if 'gold' in m.name.lower() else 'Wood']
        templates[name].append((data,o.matrix_world.copy()))
    for o in objects:bpy.data.objects.remove(o,do_unlink=True)
    sources.append({'asset':name,'source':relative,'sha256':hashlib.sha256((ROOT/relative).read_bytes()).hexdigest()})
def instance(name,p,group,scale=1,yaw=0):
    from mathutils import Matrix
    scaling=Matrix.Diagonal(Vector((*scale,1.0))) if isinstance(scale,(tuple,list)) else Matrix.Scale(scale,4)
    placement=Matrix.Translation(B(p))@Matrix.Rotation(yaw,4,'Z')@scaling
    for data,matrix in templates[name]:
        o=bpy.data.objects.new(name,data);collection(group).objects.link(o)
        o.matrix_world=placement@matrix
    if name=='crate':
        details=[]
        for x in [-.3,-.1,.1,.3]:
            details.append(gbox('CrateTopSeam',(x,1.008,0),(.014,.012,.9),'Wood',group))
            for z in [-.567,.567]:details.append(gbox('CrateSeam',(x,.5,z),(.014,.9,.012),'Wood',group))
        for z in [-.574,.574]:
            for sign in [-1,1]:details.append(beam('CrateDiagonal',B((-.38,.18 if sign>0 else .84,z)),B((.38,.84 if sign>0 else .18,z)),.075,.055,'WoodLight',group))
        bpy.context.view_layer.update()
        for detail in details:detail.matrix_world=placement@detail.matrix_world
    return o
def crystal(p,group,scale=1):
    instance('crystal',p,group,scale)
    for dx,dz,f in [(-.9,.3,.55),(.7,.65,.7),(.35,-.6,.4)]:instance('crystal',(p[0]+dx*scale,p[1],p[2]+dz*scale),group,scale*f)
def portal(p,group,width=6,height=5,yaw=0):
    before=set(collection(group).objects)
    x,h,z=p
    # Reuse the approved ENV02 frame, scaled in this independent module.
    instance('support',p,group,(width/4.7,2,height/2.625))
    post=width*2.2/4.7
    for dx in [-post,post]:
        for hh in [.3,height-.6]:gbox('IronBand',(x+dx,h+hh,z),(.66,.18,.71),'Metal',group)
    for side in [-1,1]:beam('PortalBrace',B((x+side*width*.5,h+height-1.6,z)),B((x+side*(width*.5-1.5),h+height,z)),.3,.3,'Wood',group)
    gbox('TunnelDark',(x,h+height*.46,z-.35),(width, height*.88,.15),'Metal',group)
    if yaw:
        bpy.context.view_layer.update()
        transform=Matrix.Translation(B(p))@Matrix.Rotation(yaw,4,'Z')@Matrix.Translation(-B(p))
        for o in set(collection(group).objects)-before:o.matrix_world=transform@o.matrix_world
def rail(a,b,group):
    a,b=Vector(a),Vector(b);d=(b-a).normalized();n=Vector((-d.z,0,d.x));length=(b-a).length
    for side in [-1,1]:beam('IronRail',B(a+n*.65*side+Vector((0,.16,0))),B(b+n*.65*side+Vector((0,.16,0))),.10,.14,'Metal',group)
    for i in range(math.ceil(length/.85)):
        p=a.lerp(b,(i+.3)/max(1,math.ceil(length/.85)));beam('RailSleeper',B(p-n*1.05+Vector((0,.04,0))),B(p+n*1.05+Vector((0,.04,0))),.23,.11,'Wood',group)
def cart(p,group,yaw=0,loaded=True):
    from mathutils import Matrix
    before=set(collection(group).objects);x,h,z=p
    gbox('CartBed',(0,.6,0),(1.65,.2,2.2),'Wood',group,.04)
    for side in [-1,1]:
        gbox('CartSide',(side*.84,1.1,0),(.13,1.0,2.2),'WoodLight',group,.02)
        for zz in [-1,1]:gbox('CartBracket',(side*.92,1.1,zz*.9),(.12,1.1,.15),'Metal',group)
    for zz in [-1,1]:gbox('CartEnd',(0,1.1,zz*1.04),(1.75,1,.12),'WoodLight',group,.02)
    for side in [-1,1]:
        for zz in [-.72,.72]:
            o=cylinder('CartWheel',B((side*.96,.4,zz)),.34,.18,'Metal',group,12);o.rotation_euler.y=math.pi/2
    if loaded:
        for i in range(10):stone('OreInCart',B((rng.uniform(-.6,.6),rng.uniform(1.2,1.8),rng.uniform(-.75,.75))),(.38,.35,.3),group)
    bpy.context.view_layer.update()
    matrix=Matrix.Translation(B(p))@Matrix.Rotation(yaw,4,'Z')
    for o in set(collection(group).objects)-before:o.matrix_world=matrix@o.matrix_world
def crane(p,group):
    x,h,z=p
    for dx in [-1.5,1.5]:gbox('HoistUpright',(x+dx,h+3,z),(.42,6,.45),'Wood',group,.04)
    gbox('HoistCrossbar',(x,h+6,z),(4.2,.48,.55),'WoodLight',group,.04)
    for dx in [-1.5,1.5]:beam('HoistBrace',B((x+dx,h+4.7,z)),B((x+dx*.35,h+6,z)),.24,.24,'Wood',group)
    beam('LiftRope',B((x,h+5.8,z)),B((x,h-3,z)),.07,.07,'Rope',group)
    for xx in [-.9,.9]:
        for zz in [-.8,.8]:gbox('CagePost',(x+xx,h-2,z+zz),(.12,2.4,.12),'WoodLight',group)
    gbox('CageFloor',(x,h-3.2,z),(2,.2,1.8),'Wood',group)
    for yy in [-2.8,-2.0,-1.2]:
        for xx in [-.9,.9]:gbox('CageSlat',(x+xx,h+yy,z),(.12,.12,1.7),'WoodLight',group)
def torch(p,group):
    x,h,z=p;gbox('TorchPole',(x,h+1.1,z),(.14,2.2,.14),'Wood',group)
    cylinder('TorchBasket',B((x,h+2.15,z)),.23,.38,'Metal',group,8)
    o=stone('TorchFlame',B((x,h+2.52,z)),(.2,.2,.5),group);o.data.materials.clear();o.data.materials.append(materials['Flame'])

# Platforms are solid in the authored collision manifest, not a floor under water.
for zone in LAYOUT['zones']:
    key=zone['id'];x0,x1,z0,z1=zone['bounds'];h=zone['height'];bottom=-9
    gbox('Earth_'+key,((x0+x1)/2,h-.24,(z0+z1)/2),(x1-x0,.48,z1-z0),'Earth',key)
    gbox('RockMass_'+key,((x0+x1)/2,(h+bottom)/2-.25,(z0+z1)/2),(x1-x0,h-bottom-.5,z1-z0),'Rock',key)
    collider_box(key+'_Ground',((x0+x1)/2,(bottom+h)/2,(z0+z1)/2),(x1-x0,h-bottom,z1-z0))
    # Faceted cliff slabs and ledge outcrops, with no noisy geometry on the route.
    for x,z in [(x0,z0),(x1,z0),(x0,z1),(x1,z1)]:stone('Cliff_'+key,B((x,h-3,z)),(3.2,3.2,6),key)
    for a,b in [((x0,h,z0),(x1,h,z0)),((x1,h,z0),(x1,h,z1)),((x1,h,z1),(x0,h,z1)),((x0,h,z1),(x0,h,z0))]:
        a,b=Vector(a),Vector(b);length=(b-a).length;n=Vector((b.z-a.z,0,-(b.x-a.x))).normalized()
        for i in range(max(1,math.ceil(length/5))):
            p=a.lerp(b,(i+.5)/math.ceil(length/5))+n*.8
            stone('CliffFace',B(p+Vector((0,-4.4,0))),(2.8,2.2,5),key)
        # Split each ledge fence where an authored connecting corridor joins it.
        segments=[];count=math.ceil(length/1.5)
        for i in range(count):
            p=a.lerp(b,(i+.5)/count);near=False
            for connection in LAYOUT['links']:
                aa,bb=Vector(connection['a']),Vector(connection['b'])
                delta=Vector((bb.x-aa.x,0,bb.z-aa.z));offset=Vector((p.x-aa.x,0,p.z-aa.z))
                t=max(0,min(1,offset.dot(delta)/delta.length_squared))
                q=aa.lerp(bb,t)
                if abs(q.y-h)<.65 and math.hypot(p.x-q.x,p.z-q.z)<connection['width']*.5+1.1:near=True
            if not near:segments.append((a.lerp(b,i/count),a.lerp(b,(i+1)/count)))
        for aa,bb in segments:fence('LedgeFence',aa,bb,key)

for item in LAYOUT['links']:
    key='connections';a,b=Vector(item['a']),Vector(item['b']);d=Vector((b.x-a.x,0,b.z-a.z)).normalized();n=Vector((-d.z,0,d.x))
    slope(item['id'],a,b,item['width'],key,item['kind'])
    for side in [-1,1]:
        # Keep the central crossing open; its perpendicular bridge is a route.
        if item['id'] in ['cross_bridge','north_bridge']:
            length=(b-a).length
            for i in range(math.ceil(length/2)):
                aa=a.lerp(b,i/math.ceil(length/2));bb=a.lerp(b,(i+1)/math.ceil(length/2));mid=(aa+bb)/2
                if abs(mid.x+4)<3.7 and abs(mid.z)<3.7:continue
                fence('BridgeRails',aa+n*item['width']*.5*side,bb+n*item['width']*.5*side,key)
        else:fence('LinkRail',a+n*item['width']*.5*side,b+n*item['width']*.5*side,key)
    if item['kind']=='bridge':
        length=(b-a).length
        for i in range(1,max(2,int(length/5))):
            p=a.lerp(b,i/max(2,int(length/5)))
            for side in [-1,1]:beam('BridgePillar',B(p+n*(item['width']*.39*side)+Vector((0,-.3,0))),B(p+n*(item['width']*.39*side)+Vector((0,-7,0))),.36,.4,'Wood',key)

# Distinct readable workplace dressing, keeping the declared routes clear.
for group,p in [('entrance_camp',(-42,0,36)),('rail_workings',(-41,3,-12)),('crystal_workings',(-28,7,-38)),('storage',(38,7,-26)),('waterway',(38,0,26)),('core_cavern',(44,0,36))]:
    portal_p=(-47,0,28) if group=='entrance_camp' else ((40,0,16) if group=='waterway' else p)
    portal_yaw=math.pi/2 if group=='entrance_camp' else (-math.pi/2 if group=='waterway' else 0)
    portal(portal_p,group,6,5,portal_yaw)
    for side in [-1,1]:torch((p[0]+side*3.5,p[1],p[2]+1),group)
    for i in range(3):
        pos=(p[0]+1+i*1.1,p[1],p[2]-2+(i%2)*1.1) if group=='waterway' else (p[0]-4+i*1.2,p[1],p[2]+1.4+(i%2)*1.1)
        instance('crate' if i%2==0 else 'barrel',pos,group,.8)
        collider_box('StoredGoods', (pos[0],pos[1]+.5,pos[2]),(.9,1,.9))
rail((-44,0,30),(-25,0,30),'entrance_camp')
rail((-43,3,-12),(-27,3,-12),'rail_workings')
rail((-24,3,-1.5),(20,3,-1.5),'connections')
rail((-26,7,-37),(-7,7,-37),'crystal_workings')
rail((28,0,23),(41,0,23),'waterway')
for p,g in [((-28,0,30),'entrance_camp'),((-40,3,-12),'rail_workings'),((-16,3,-1.5),'connections'),((-16,7,-37),'crystal_workings'),((39,0,23),'waterway')]:
    cart(p,g,math.pi/2);collider_box('MineCart',(p[0],p[1]+1,p[2]),(2.5,1.8,1.9))
crane((2,3,4),'connections')
crane((42,7,-14),'storage')
for p,g,s in [((-18,7,-35),'crystal_workings',2),((-10,7,-39),'crystal_workings',2.5),((1,7,-38),'crystal_workings',1.5),((42,0,36),'core_cavern',3.6),((45,0,38),'core_cavern',1.8),((29,0,46),'core_cavern',1.5)]:crystal(p,g,s)
for p,g,s in [((-18,7,-35),'crystal_workings',2),((-10,7,-39),'crystal_workings',2.5),((1,7,-38),'crystal_workings',1.5),((42,0,36),'core_cavern',3.6),((45,0,38),'core_cavern',1.8),((29,0,46),'core_cavern',1.5)]:
    collider_box('CrystalCluster',(p[0],p[1]+s,p[2]),(s*1.1,s*2,s*1.1))
for p,group in [((-44,3,-14),'rail_workings'),((-29,7,-39),'crystal_workings'),((41,7,-25),'storage')]:
    x,h,z=p;gbox('WorkbenchTop',(x,h+1.1,z),(3.2,.18,1.1),'WoodLight',group,.03)
    for dx in [-1.2,1.2]:gbox('BenchLeg',(x+dx,h+.5,z),(.2,1,.8),'Wood',group)
    for i in range(5):
        o=stone('GoldOre',B((x-1+i*.45,h+1.4,z)),(.23,.24,.27),group);o.data.materials.clear();o.data.materials.append(materials['Brass'])
    gbox('ToolRack',(x,h+2.5,z-.45),(3.2,.15,.12),'Wood',group)
    for i in range(4):
        xx=x-1+i*.65;gbox('ToolHandle',(xx,h+2.1,z-.48),(.07,.85,.07),'WoodLight',group)
        beam('PickaxeHead',B((xx-.22,h+2.5,z-.48)),B((xx+.22,h+2.5,z-.48)),.08,.12,'Metal',group)
for x in [32,35,38,41]:
    for z in [-23,-20]:
        instance('crate',(x,7,z),'storage',1.1)
        if x>35:instance('crate',(x,8.1,z),'storage',1)
        collider_box('StorageStack',(x,8,z),(1.2,2,1.2))
# Canvas tent at the camp, rubble and tilted beams in the collapse pocket.
mesh('CampTent',[B(p) for p in [(-43,0,39),(-43,0,34),(-40,2.8,39),(-40,2.8,34),(-37,0,39),(-37,0,34)]],[(0,1,3,2),(2,3,5,4)],'Canvas','entrance_camp')
for i in range(15):
    p=(rng.uniform(4,10),0,rng.uniform(39,43));stone('CollapsedRock',B((p[0],.6,p[2])),(rng.uniform(.5,1.4),rng.uniform(.6,1.3),rng.uniform(.5,1.7)),'collapse')
    collider_box('Rubble',(p[0],.7,p[2]),(.9,1.4,.9))
for i in range(4):beam('BrokenTimber',B((4+i,0,41)),B((7+i,2,39)),.35,.4,'Wood','collapse')
gbox('DangerPlacard',(1,1.4,40),(2.5,1,.18),'WoodLight','collapse')
for i in range(3):gbox('WarningSlat',(1+i*.6-.6,1.4,39.85),(.18,.65,.07),'Flame','collapse')
for p in [(-47,0,25),(-26,0,38),(-45,3,-3),(-27,7,-30),(-2,7,-29),(23,7,-18),(21,0,24),(29,0,36)]:torch(p,'details')
for p in [(-46,0,25),(-46,0,31)]:torch(p,'details')

# Blue water is below the walkways, with visible beds and two falling curtains.
for water in LAYOUT['water']:
    x0,x1,z0,z1=water['bounds'];h=water['height']
    gbox('Water_'+water['name'],((x0+x1)/2,h,(z0+z1)/2),(x1-x0,.025,z1-z0),'Water','water')
    gbox('RiverBed',((x0+x1)/2,h-1.2,(z0+z1)/2),(x1-x0,1,z1-z0),'Rock','water')
for x,z,bottom,top in [(10,-28,-7,5),(19,15,-5.5,1)]:
    gbox('FallingWater',(x,(bottom+top)/2,z),(4,top-bottom,.08),'Fall','water')
    crystal((x-2,bottom+1,z+2),'water',1.4)
# Far cave envelope and layered rock formations; front remains an open cutaway.
for row in range(3):
    for i in range(18):
        x=-51+i*6+(row%2)*2+rng.uniform(-.6,.6)
        stone('BackCavern',B((x,1+row*5+rng.uniform(-.5,.5),-47-row*.4+rng.uniform(-.6,.6))),(rng.uniform(3.8,4.8),4.0,rng.uniform(3.6,4.7)),'backdrop')
for row in range(2):
    for z in range(-38,44,7):stone('WestCavern',B((-52-row*.6,1+row*5.5,z)),(4,4.5,3.7),'backdrop')
for x,z in [(-22,-22),(13,-20),(12,26),(19,37),(-20,16)]:stone('ChasmPillar',B((x,-3,z)),(3,3,6),'backdrop')
gbox('CavernBasement',(0,-11.8,0),(112,1,112),'Rock','backdrop')

# Reference-specific art remains separate from the frozen gameplay layout.
sys.path.insert(0,str(ROOT/'scripts/tools'))
from mine_reference_art import refine_mine
art_receipt=refine_mine(globals())

# Reusable new machinery modules, independently exportable without the world.
for name,build in [('mine_cart',lambda:cart((0,0,0),'module_mine_cart')),('rail_segment',lambda:rail((0,0,-2),(0,0,2),'module_rail_segment')),('mine_portal',lambda:portal((0,0,0),'module_mine_portal')),('hoist_cage',lambda:crane((0,0,0),'module_hoist_cage'))]:
    build()
    col=collection('module_'+name);bpy.ops.object.select_all(action='DESELECT')
    for o in col.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    for o in col.objects:o.select_set(False)
    col.hide_render=True;col.hide_viewport=True

# Merge within each zone/material to reduce renderer calls, keeping zone modules.
manifest=[]
for name,col in list(collections.items()):
    if name.startswith('module_'):continue
    meshes=[o for o in col.objects if o.type=='MESH']
    by_material={}
    for o in meshes:
        key=tuple(m.name if m else '' for m in o.data.materials);by_material.setdefault(key,[]).append(o)
    for objects in by_material.values():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:
            # Joining an active linked mesh would mutate every other zone's
            # template. Make the geometry local before converting or joining.
            o.data=o.data.copy();o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.convert(target='MESH')
        bpy.ops.object.join()
        bpy.context.object.name=name+'_'+(objects[0].data.materials[0].name if objects[0].data.materials else 'mesh')
    bpy.ops.object.select_all(action='DESELECT')
    meshes=[o for o in col.objects if o.type=='MESH']
    for o in meshes:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    triangles=0
    for o in meshes:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    manifest.append({'zone':name,'path':'res://assets/models/mine_reference/'+name+'.glb','meshes':len(meshes),'triangles':triangles})

# Authored overview lighting and orthographic camera remain editable in .blend.
review=collection('Review')
for index,p in enumerate(LAYOUT['lights']):
    light=bpy.data.lights.new('WarmTorch'+str(index),'POINT');light.energy=450;light.color=(1,.48,.12);light.shadow_soft_size=1
    obj=bpy.data.objects.new(light.name,light);review.objects.link(obj);obj.location=B(p)
for p in [(-12,10,-35),(40,5,42),(10,-2,0)]:
    light=bpy.data.lights.new('CrystalBlue','POINT');light.energy=850;light.color=(.10,.5,1);light.shadow_soft_size=2
    obj=bpy.data.objects.new(light.name,light);review.objects.link(obj);obj.location=B(p)
sun=bpy.data.lights.new('SoftCaveFill','AREA');sun.energy=90000;sun.shape='DISK';sun.size=70
obj=bpy.data.objects.new('SoftCaveFill',sun);review.objects.link(obj);obj.location=(0,-15,90)
obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.cameras.new('ReferenceOverview');cam=bpy.data.objects.new(camera.name,camera);review.objects.link(cam)
cam.location=(105,-138,138);cam.rotation_euler=(Vector((0,-2,0))-cam.location).to_track_quat('-Z','Y').to_euler();camera.type='ORTHO';camera.ortho_scale=151;scene.camera=cam
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.23,.32,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=1440;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'mine_reference_master.blend'),compress=True)
report={'layout_version':4,'builder_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'layout_sha256':hashlib.sha256((ROOT/'data/world/mine_reference_layout.json').read_bytes()).hexdigest(),'source_reference_sha256':hashlib.sha256((ROOT/LAYOUT['reference']).read_bytes()).hexdigest(),'zones':manifest,'collisions':colliders,'reused_sources':sources,'master':'source_assets/mine_reference_20261024/mine_reference_master.blend','total_triangles':sum(v['triangles'] for v in manifest)}
report['art_refinement']=art_receipt
(OUT/'manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
if '--skip-render' not in sys.argv:
    scene.render.filepath=str(SOURCE/'overview.png');bpy.ops.render.render(write_still=True)
print('MINE_MASTER_COMPLETE',report['total_triangles'],len(colliders))
