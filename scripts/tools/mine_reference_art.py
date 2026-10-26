"""Reference-led mine dressing, using the existing modules and protected routes."""
import math,random,hashlib
from pathlib import Path
from mathutils import Vector,Matrix


def refine_mine(api):
    layout=api['LAYOUT'];B=api['B'];box=api['gbox'];beam=api['beam']
    stone=api['stone'];instance=api['instance'];crystal=api['crystal'];mesh=api['mesh']
    rng=random.Random(261026)
    routes=[]
    for name in ['route','cross_route','north_route']:
        pts=layout[name]
        routes.extend((Vector(a),Vector(b)) for a,b in zip(pts,pts[1:]))
    story=[Vector(v) for v in [layout['story']['crystal'],layout['story']['boss'],layout['story']['exit'],[-41,3,-5],[37,7,-17]]]
    def clear(p,radius=.7):
        p=Vector(p)
        for a,b in routes:
            d=b-a;t=max(0,min(1,(p-a).dot(d)/max(d.length_squared,1e-6)))
            q=a.lerp(b,t)
            if abs(p.y-q.y)<2.4 and math.hypot(p.x-q.x,p.z-q.z)<radius+1.15:return False
        return all(abs(p.y-q.y)>2.4 or math.hypot(p.x-q.x,p.z-q.z)>radius+2.0 for q in story)
    receipt={'revision':'mine_reference_art_20261026','script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             'new_dressing':[],'protected_layout_version':layout['layout_version'],'new_collisions':0}
    # Recessed dark passages are framed by solid rock and a deep wooden lining.
    # Their rear wall is decorative: current story exits stay at existing anchors.
    tunnels=[('rail_workings',(-41,3,-12),0),('crystal_workings',(-28,7,-38),0),
             ('storage',(38,7,-26),0),('waterway',(40,0,16),-math.pi/2),('core_cavern',(44,0,36),0)]
    for group,p,yaw in tunnels:
        before=set(api['collection'](group).objects)
        x,h,z=p
        # Behind the existing portal, rock cheeks conceal the flat black card.
        for side in [-1,1]:
            for level in range(2):stone('PortalRockCheek',B((x+side*4.8,h+1.7+level*2.8,z-1.0)),(1.5,2.4,1.9),group)
            box('TunnelSide',(x+side*2.8,h+2.1,z-1.4),(.65,4.2,2.8),'Wood',group)
        for dx in [-2.7,0,2.7]:stone('PortalRockCrown',B((x+dx,h+6.45,z-1.0)),(2.0,2.8,1.30),group)
        box('TunnelRoof',(x,h+4.65,z-1.4),(6.1,.55,2.8),'Wood',group)
        for dx in [-2.7,2.7]:
            for zz in [-.4,-1.8]:box('TunnelRib',(x+dx,h+2.2,z+zz),(.22,4.4,.25),'WoodLight',group)
        if yaw:
            transform=Matrix.Translation(B(p))@Matrix.Rotation(yaw,4,'Z')@Matrix.Translation(-B(p))
            for obj in set(api['collection'](group).objects)-before:obj.matrix_world=transform@obj.matrix_world
        receipt['new_dressing'].append({'kind':'recessed_portal','zone':group,'position':list(p)})
    for side in [-1,1]:
        for level in range(2):stone('CampPortalCheek',B((-48,1.7+level*2.8,28+side*4.8)),(2.4,1.5,1.9),'entrance_camp')
    for dz in [-2.7,0,2.7]:stone('CampPortalCrown',B((-48,6.45,28+dz)),(2.8,2.0,1.30),'entrance_camp')
    # Working platforms against the rear wall, away from the protected walk lane.
    shelves=[('rail_workings',(-45,3,-8)),('storage',(41,7,-15)),('crystal_workings',(-23,7,-39)),('entrance_camp',(-29,0,39))]
    for group,(x,h,z) in shelves:
        if not clear((x,h,z),1.5):continue
        for dx in [-1.65,1.65]:box('ShelfUpright',(x+dx,h+1.45,z),(.18,2.9,.28),'Wood',group)
        for level in [.25,1.25,2.25]:
            box('ShelfDeck',(x,h+level,z),(3.6,.16,1.05),'WoodLight',group)
            for i in range(3):
                instance('crate' if i%2==0 else 'barrel',(x-1.1+i*1.05,h+level+.08,z),group,.48)
        receipt['new_dressing'].append({'kind':'stock_shelf','zone':group,'position':[x,h,z]})
    # Rock shoulders and clusters reduce the isolated rectangular-island feel.
    # Small props are chosen by route distance; the full collision manifest stays intact.
    for zone in layout['zones']:
        x0,x1,z0,z1=zone['bounds'];h=zone['height'];group=zone['id']
        for i in range(28):
            x=rng.uniform(x0+1.1,x1-1.1);z=rng.uniform(z0+1.1,z1-1.1)
            edge=min(x-x0,x1-x,z-z0,z1-z)
            radius=.65 if i%5 else 1.15
            if edge>3.8 or not clear((x,h,z),radius):continue
            if i%5==0:
                stone('LedgeBoulder',B((x,h+.55,z)),(radius,radius*.8,1.0),group)
            elif i%4==0:
                instance('crate' if i%2 else 'barrel',(x,h,z),group,.68)
            else:
                for j in range(3):
                    stone('FloorRubble',B((x+rng.uniform(-.4,.4),h+.12,z+rng.uniform(-.4,.4))),(.25,.23,.19),group)
            receipt['new_dressing'].append({'kind':'edge_dressing','zone':group,'position':[x,h,z],'radius':radius})
        # Narrow wooden staging decks along suitable rear edges, no walkway posts.
        for x in [x0+4,x1-4]:
            z=z0+3.0
            if not clear((x,h,z),2):continue
            for i in range(8):box('WorkDeckBoard',(x-1.8+i*.5,h+.025,z),(.46,.05,2.2),'WoodLight',group)
            receipt['new_dressing'].append({'kind':'work_deck','zone':group,'position':[x,h,z]})
    # Central crossing gains the tall diagonal bracing seen in the reference.
    # Braces stay below the existing deck, not across the player's lane.
    for item in layout['links']:
        if item['kind']!='bridge':continue
        a,b=Vector(item['a']),Vector(item['b']);length=(b-a).length
        d=(b-a).normalized();n=Vector((-d.z,0,d.x))
        for i in range(1,int(length/6)):
            p=a.lerp(b,i/max(1,int(length/6)))
            for side in [-1,1]:
                q=p+n*item['width']*.38*side
                beam('UnderDeckBrace',B(q+Vector((0,-.45,0))-d*2),B(q+Vector((0,-4,0))),.23,.24,'Wood','connections')
    # Continuous falling sheets and impact foam replace the old straight cards.
    water=api['collection']('water')
    import bpy
    for obj in list(water.objects):
        if obj.name.startswith('FallingWater'):bpy.data.objects.remove(obj,do_unlink=True)
    foam_mat=bpy.data.materials.new('Mine_Foam');foam_mat.diffuse_color=(.53,.83,.91,1)
    foam_mat.use_nodes=True
    bsdf=next(n for n in foam_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=foam_mat.diffuse_color
    for index,(x,z,bottom,top) in enumerate([(10,-28,-7,5),(19,15,-5.5,1)]):
        points=[];faces=[]
        profile=[(-2.0,top),(-.8,top),(-.15,top-.15),(.20,top-.8),(.30,(top+bottom)/2),(.48,bottom+.35),(1.0,bottom+.05)]
        for zz,hh in profile:
            for i in range(9):points.append(B((x-2.0+i*.5,hh,z+zz)))
        for row in range(len(profile)-1):
            for i in range(8):
                a=row*9+i;faces.extend([(a,a+1,a+10),(a,a+10,a+9)])
        obj=mesh('CascadeSheet'+str(index),points,faces,'Fall','water')
        uv=obj.data.uv_layers.new(name='Flow')
        for poly in obj.data.polygons:
            for loop in poly.loop_indices:
                vi=obj.data.loops[loop].vertex_index
                uv.data[loop].uv=(vi%9/8,vi//9/(len(profile)-1))
        for i in range(9):
            o=stone('FoamImpact',B((x+rng.uniform(-2.2,2.2),bottom+.12,z+rng.uniform(.4,1.8))),(.45,.5,.18),'water')
            o.data.materials.clear();o.data.materials.append(foam_mat)
        receipt['new_dressing'].append({'kind':'continuous_cascade','index':index,'triangles':96})
    return receipt
