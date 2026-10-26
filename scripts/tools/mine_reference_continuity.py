"""Continuous cutaway strata, joined rails and working bays for the mine."""
import bpy,bmesh,math,random,hashlib
from pathlib import Path
from mathutils import Vector


def refine_continuity(api,clear):
    B=api['B'];box=api['gbox'];beam=api['beam'];stone=api['stone'];mesh=api['mesh']
    layout=api['LAYOUT'];rng=random.Random(261027)
    receipt={'revision':'mine_continuity_20261026','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'strata':[],'rail_curves':[],'work_bays':[]}
    def solid(name,points,faces,group):
        obj=mesh(name,[B(p) for p in points],faces,'Rock',group)
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data);bm.free();obj.data.update();return obj
    def route_ceiling(p):
        p=Vector(p);height=p.y
        for link in layout['links']:
            a,b=Vector(link['a']),Vector(link['b']);d=Vector((b.x-a.x,0,b.z-a.z))
            t=max(0,min(1,Vector((p.x-a.x,0,p.z-a.z)).dot(d)/max(d.length_squared,1e-6)));q=a.lerp(b,t)
            if math.hypot(p.x-q.x,p.z-q.z)<link['width']/2+.4:height=min(height,q.y-.38)
        return height
    # One closed perimeter per platform; no repeated cylinders and no new floors.
    for zone in layout['zones']:
        group=zone['id'];col=api['collection'](group);x0,x1,z0,z1=zone['bounds'];h=zone['height']
        for obj in list(col.objects):
            if obj.name.startswith(('CliffFace','Cliff_'+group,'RockMass_'+group)):
                bpy.data.objects.remove(obj,do_unlink=True)
        outline=[];corners=[(x0,z0),(x1,z0),(x1,z1),(x0,z1)]
        for i,(x,z) in enumerate(corners):
            xx,zz=corners[(i+1)%4];count=math.ceil(math.hypot(xx-x,zz-z)/4.5)
            for j in range(count):outline.append(Vector((x+(xx-x)*j/count,0,z+(zz-z)*j/count)))
        center=Vector(((x0+x1)/2,0,(z0+z1)/2));points=[];n=len(outline)
        pads=[rng.uniform(.65,1.25) for _ in outline]
        for level,y in enumerate([h-.07,h-.85,h-3.3,-9.0]):
            for i,p in enumerate(outline):
                d=(p-center).normalized();pad=0 if level==0 else pads[i]*[0,1,1.4,1.05][level]
                q=p+d*pad;q.y=y
                if level<3:q.y=route_ceiling(q)
                points.append(tuple(q))
        faces=[]
        for row in range(3):
            for i in range(n):faces.append((row*n+i,row*n+(i+1)%n,(row+1)*n+(i+1)%n,(row+1)*n+i))
        points.extend([(center.x,h-.07,center.z),(center.x,-9,center.z)])
        for i in range(n):faces.extend([(4*n,i,(i+1)%n),(4*n+1,3*n+(i+1)%n,3*n+i)])
        solid('ContinuousStrata_'+group,points,faces,group)
        for i,p in enumerate(outline):
            if i%2:continue
            d=(p-center).normalized();q=p+d*.7
            for drop in [2.4,6.0]:
                height=min(h-drop,route_ceiling(Vector((q.x,h-.6,q.z)))-1.2)
                lens=stone('StrataLens',B((q.x,height,q.z)),(rng.uniform(2.0,3.0),rng.uniform(.8,1.2),rng.uniform(.7,1.1)),group)
                lens.rotation_euler.z=math.atan2(-d.z,d.x)+math.pi/2+rng.uniform(-.15,.15)
        receipt['strata'].append({'zone':group,'perimeter_vertices':n,'closed':True})
    # A rock foundation under each wooden stair ties the levels together.
    for link in layout['links']:
        if link['kind']!='stairs':continue
        a,b=Vector(link['a']),Vector(link['b']);n=Vector((-(b.z-a.z),0,b.x-a.x)).normalized()*(link['width']/2+.45)
        points=[tuple(p+n*s+Vector((0,-.40,0))) for p in [a,b] for s in [-1,1]]
        points += [(p[0],-9,p[2]) for p in points]
        solid('StairAbutment_'+link['id'],points,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],'connections')
    # Replace the tiled backdrop and square basement with two continuous cave walls.
    backdrop=api['collection']('backdrop')
    for obj in list(backdrop.objects):
        if obj.name.startswith(('BackCavern','WestCavern','CavernBasement')):bpy.data.objects.remove(obj,do_unlink=True)
    receipt['lowered_pillars']=[]
    bpy.context.view_layer.update()
    for obj in backdrop.objects:
        if not obj.name.startswith('ChasmPillar'):continue
        p=Vector((obj.location.x,obj.location.z,-obj.location.y));limit=route_ceiling(Vector((p.x,3.0,p.z)))
        top=max((obj.matrix_world@v.co).z for v in obj.data.vertices)
        if top>limit:
            obj.location.z-=top-limit
            receipt['lowered_pillars'].append({'name':obj.name,'old_top':top,'new_top':limit})
    def wall(name,front,back):
        points=[];count=len(front)
        for row in range(3):
            for i,(x,z) in enumerate(front):
                height=[-10.5,3.0+math.sin(i*.9),15.0+2.0*math.sin(i*.71)][row]
                retreat=[-.4,0,3.0][row]
                outward=(Vector(back[i])-Vector(front[i])).normalized()
                points.append((x+outward.x*retreat,height,z+outward.y*retreat))
            for i,(x,z) in enumerate(back):points.append((x,[-10.5,3.0+math.sin(i*.9),15.0+2.0*math.sin(i*.71)][row],z))
        faces=[];stride=2*count
        for row in range(2):
            for side in [0,count]:
                for i in range(count-1):
                    a=row*stride+side+i;faces.append((a,a+1,a+stride+1,a+stride))
        for i in range(count-1):
            faces.extend([(i,i+count,i+count+1,i+1),(2*stride+i,2*stride+i+1,2*stride+i+count+1,2*stride+i+count)])
        for i in [0,count-1]:
            for row in range(2):
                a=row*stride+i;faces.append((a,a+count,a+count+stride,a+stride))
        solid(name,points,faces,'backdrop')
    wall('NorthCavernStrata',[(-56+i*5,-46+math.sin(i*.83)*2.0) for i in range(23)],[(-56+i*5,-55) for i in range(23)])
    wall('WestCavernStrata',[(-51+math.sin(i*.67)*1.8,-46+i*5) for i in range(19)],[(-59,-46+i*5) for i in range(19)])
    for i in range(20):
        x=-50+i*5.3
        front=-46+math.sin((x+56)/5*.83)*2.0
        for h in [4.5,10.5]:stone('CaveWallLens',B((x,h+rng.uniform(-.6,.6),front-(h-3)/12*3+.25)),(rng.uniform(2.8,4.5),1.2,rng.uniform(1.7,2.7)),'backdrop')
    for z in range(-36,40,7):
        front=-51+math.sin((z+46)/5*.67)*1.8
        for h in [3.5,8.5]:stone('CaveWestLens',B((front-(h-3)/12*3+.25,h+rng.uniform(-.6,.6),z)),(1.1,rng.uniform(2.8,4.0),rng.uniform(1.6,2.6)),'backdrop')
    # Smooth tracks interpolate all anchors, including the existing cart centres.
    curves={
        'entrance_camp':[(-47,0,28),(-41,0,30),(-34,0,30),(-28,0,30),(-25,0,32)],
        'rail_workings':[(-44,3,-12),(-40,3,-12),(-35,3,-12),(-29,3,-9),(-27,3,-3)],
        'crystal_workings':[(-28,7,-38),(-24,7,-37),(-16,7,-37),(-8,7,-37),(1,7,-34)],
        'waterway':[(41,0,16),(37,0,16),(36,0,20),(36,0,23),(39,0,23),(42,0,23),(42,0,27)],
        'core_cavern':[(33,0,40),(36,0,44),(43,0,45),(47,0,42),(47,0,37)]}
    track_spines={}
    for group,anchors in curves.items():
        for obj in list(api['collection'](group).objects):
            if obj.name.startswith(('IronRail','RailSleeper')):bpy.data.objects.remove(obj,do_unlink=True)
        pts=[Vector(p) for p in anchors];dense=[]
        for i in range(len(pts)-1):
            a,b,c,d=pts[max(i-1,0)],pts[i],pts[i+1],pts[min(i+2,len(pts)-1)]
            for j in range(20):
                t=j/20;dense.append((2*b+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)*.5)
        dense.append(pts[-1]);samples=[dense[0]];distance=.0
        for a,b in zip(dense,dense[1:]):
            length=(b-a).length;distance+=length
            if distance>=.65:samples.append(b);distance=0
        if (samples[-1]-dense[-1]).length>.05:samples.append(dense[-1])
        track_spines[group]=samples
        for a,b in zip(samples,samples[1:]):
            d=(b-a).normalized();n=Vector((-d.z,0,d.x))
            for side in [-1,1]:
                rail=beam('CurvedRail',B(a+n*.65*side+Vector((0,.16,0))),B(b+n*.65*side+Vector((0,.16,0))),.10,.14,'Metal',group)
                rail.modifiers.clear()
        for i,p in enumerate(samples):
            d=(samples[min(i+1,len(samples)-1)]-samples[max(0,i-1)]).normalized();n=Vector((-d.z,0,d.x))
            beam('CurveSleeper',B(p-n*1.05+Vector((0,.04,0))),B(p+n*1.05+Vector((0,.04,0))),.23,.11,'Wood',group)
        receipt['rail_curves'].append({'zone':group,'anchors':[list(p) for p in anchors],'samples':len(samples)})
    # Hand-placed candidates use the existing route/interaction clearance predicate.
    for zone in layout['zones']:
        if zone['id']=='bridge_junction':continue
        x0,x1,z0,z1=zone['bounds'];h=zone['height'];group=zone['id']
        for x,z in [(x0+5,z0+5),(x1-5,z0+5),(x0+5,z1-4),(x1-5,z1-4)]:
            if not clear((x,h,z),2.5):continue
            if group in track_spines and min(math.hypot(x-p.x,z-p.z) for p in track_spines[group])<3.6:continue
            box('BayBench',(x,h+1.0,z),(2.8,.18,1.15),'WoodLight',group)
            for dx in [-1.1,1.1]:box('BayLeg',(x+dx,h+.45,z),(.18,.9,.85),'Wood',group)
            for dx in [-1.4,1.4]:box('ToolRackPost',(x+dx,h+1.3,z-.45),(.12,2.6,.14),'Wood',group)
            box('ToolRackCrossbar',(x,h+2.55,z-.45),(3.0,.14,.18),'WoodLight',group)
            for i in range(3):
                xx=x-.8+i*.8
                beam('PickHandle',B((xx,h+1.25,z-.42)),B((xx,h+2.3,z-.42)),.065,.065,'WoodLight',group)
                beam('PickHead',B((xx-.25,h+2.3,z-.42)),B((xx+.25,h+2.3,z-.42)),.08,.10,'Metal',group)
                ore=stone('BayOre',B((xx,h+1.25,z+.25)),(.22,.19,.22),group)
                ore.data.materials.clear();ore.data.materials.append(api['materials']['Brass'])
            box('OreBin',(x,h+.15,z+1.4),(2.1,.3,.8),'Wood',group)
            for i in range(9):stone('BinOre',B((x+rng.uniform(-.9,.9),h+.40,z+1.4+rng.uniform(-.25,.25))),(.22,.18,.25),group)
            receipt['work_bays'].append({'zone':group,'position':[x,h,z]})
    # Branches meet the old central channel at x=4/17; they do not overlap its
    # surface or add collision floors. The crossing now spans visible water.
    receipt['water_branches']=[]
    for name,bounds in [('CrossingWest',(-24,4,-5,5)),('NorthFork',(-7,4,-28,-5)),('SouthFork',(-7,4,5,32)),('CrossingEast',(17,25,-4,4))]:
        x0,x1,z0,z1=bounds;p=((x0+x1)/2,-7,(z0+z1)/2)
        box('Water_'+name,p,(x1-x0,.025,z1-z0),'Water','water')
        box('BranchBed_'+name,(p[0],-8.2,p[2]),(x1-x0,1,z1-z0),'Rock','water')
        receipt['water_branches'].append({'name':name,'bounds':list(bounds),'surface_height':-7,'collision':False})
    return receipt
