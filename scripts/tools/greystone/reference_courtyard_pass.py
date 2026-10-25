"""Reference courtyard additions, shared by live Blender MCP and the master builder.

Only project-owned Courtyard_* meshes are replaced. No file I/O or context-clearing
operators: the same code runs inside Blender MCP safe mode.
"""
import bpy
import math
import random
from mathutils import Vector, Matrix


def apply_courtyards(props, vegetation, roads):
    revision='courtyard_20261025'
    for collection in (props,vegetation):
        for obj in list(collection.objects):
            if obj.get('courtyard_revision')==revision:
                bpy.data.objects.remove(obj,do_unlink=True)
    shrub=next(o for o in bpy.context.scene.objects if o.name=='Shrub')
    flower=next(o for o in bpy.context.scene.objects if o.name=='Flowers')
    rng=random.Random(252610)
    palette={'oak':(.48,.31,.17),'oak_light':(.60,.41,.23),'iron':(.21,.24,.24),
             'gold':(.80,.59,.24),'blue':(.25,.58,.68),'green':(.39,.56,.26),
             'cream':(.85,.78,.57),'soil':(.34,.29,.18)}
    mats={}
    for name,rgb in palette.items():
        key='ReferenceCourtyard_'+name
        mat=bpy.data.materials.get(key)
        if mat is None:
            mat=bpy.data.materials.new(key);mat.use_nodes=True
            rgba=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
            mat.diffuse_color=rgba
            shader=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            shader.inputs['Base Color'].default_value=rgba
            shader.inputs['Roughness'].default_value=.86
        mats[name]=mat

    def batch():
        return {'vertices':[],'faces':[],'slots':[],'materials':[]}
    def poly(b,points,faces,mat):
        if mat not in b['materials']:b['materials'].append(mat)
        slot=b['materials'].index(mat);offset=len(b['vertices'])
        b['vertices'].extend(tuple(p) for p in points)
        for face in faces:
            b['faces'].append(tuple(offset+i for i in face));b['slots'].append(slot)
    def box(b,center,size,mat):
        c=Vector(center);x,y,z=(v/2 for v in size)
        points=[c+Vector(p) for p in [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),
                                    (-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]]
        poly(b,points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    def beam(b,a,c,width,mat):
        a,c=Vector(a),Vector(c);d=(c-a).normalized();side=d.cross(Vector((0,0,1)))
        if side.length<.001:side=Vector((1,0,0))
        side.normalize();up=d.cross(side).normalized()
        points=[p+side*s*width/2+up*t*width/2 for p in [a,c] for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        poly(b,points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    def finish(name,b,collection,kind):
        if not b['faces']:return None
        data=bpy.data.meshes.new(name);data.from_pydata(b['vertices'],[],b['faces']);data.update()
        for mat in b['materials']:data.materials.append(mat)
        for face,slot in zip(data.polygons,b['slots']):face.material_index=slot
        ob=bpy.data.objects.new(name,data);collection.objects.link(ob)
        ob['courtyard_revision']=revision;ob['courtyard_kind']=kind
        return ob
    def plant(b,source,position,height,angle):
        points=[source.matrix_world@p.co for p in source.data.vertices]
        low=Vector([min(p[i] for p in points) for i in range(3)])
        high=Vector([max(p[i] for p in points) for i in range(3)])
        center=Vector(((low.x+high.x)/2,(low.y+high.y)/2,low.z))
        scale=height/(high.z-low.z);rotation=Matrix.Rotation(angle,3,'Z')
        points=[Vector(position)+rotation@((p-center)*scale) for p in points]
        # Preserve existing plant geometry and material assignments.
        for slot,mat in enumerate(source.data.materials):
            faces=[tuple(p.vertices) for p in source.data.polygons if p.material_index==slot]
            poly(b,points,faces,mat)
        return max(math.hypot(p.x-position[0],p.y-position[1]) for p in points)

    npc_positions=[(-9,10.5),(-21,2.5),(13,-9),(9,12.5),(12,12.5),(-14,-16.8)]
    def clear(x,y,radius):
        if any(math.hypot(x-a,y-b)<2.2+radius for a,b in npc_positions):return False
        for road in roads:
            for a,b in zip(road['points'],road['points'][1:]):
                if min(a[2],b[2])>3.5 or max(a[2],b[2])<2.5:continue
                dx=b[0]-a[0];dy=b[1]-a[1];length=dx*dx+dy*dy
                if length<.0001:continue
                t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/length))
                if math.hypot(x-a[0]-t*dx,y-a[1]-t*dy)<road['width']/2+.30+radius:return False
        return True

    # Narrow soft planting beds occupy leftover ground along the walls, never
    # the square, door aprons, stair routes or NPC interaction circles.
    beds=[('InnWest',-17.2,14.9,1.1,3.2),('InnFront',-13.8,10.7,2.8,1.0),
          ('InnEast',-.9,17,1.4,4.2),('ItemEast',-15.7,7.2,1.6,2.5),
          ('ItemRear',-21,10.8,3.0,.9),('GuildEast',15.5,17.5,1.2,3.4),
          ('WeaponEast',18.5,-4.8,1.0,3.2),('WestHouse',-20,-13,1.1,3.5),
          ('WestFront',-18.5,-17.4,1.3,.8),('SouthHouse',10,-18.5,1.2,2.5)]
    accepted=[];rejected=0;bed_objects=[]
    for name,cx,cy,sx,sy in beds:
        b=batch()
        for i in range(9):
            x=cx+rng.uniform(-sx/2,sx/2);y=cy+rng.uniform(-sy/2,sy/2)
            is_flower=i%3!=0;height=rng.uniform(.32,.50) if is_flower else rng.uniform(.56,.82)
            source=flower if is_flower else shrub
            # Conservative radius from the prototype before committing geometry.
            points=[source.matrix_world@p.co for p in source.data.vertices]
            dx=max(p.x for p in points)-min(p.x for p in points);dy=max(p.y for p in points)-min(p.y for p in points)
            dz=max(p.z for p in points)-min(p.z for p in points)
            radius=math.hypot(dx,dy)*.5*height/dz
            if not clear(x,y,radius):rejected+=1;continue
            plant(b,source,(x,y,3.035),height,rng.random()*math.tau)
            accepted.append({'bed':name,'position':[x,y,3.035],'radius':radius,'height':height})
        ob=finish('Courtyard_Bed_'+name,b,vegetation,'soft_planting')
        if ob:bed_objects.append(ob.name)

    # Door canopy and wall brackets stay above 2.2m head clearance. Existing
    # entrance posts/step/body volumes are retained, with no new ground obstacle.
    b=batch()
    box(b,(-8.7,11.65,6.15),(4.65,.24,.22),mats['oak'])
    box(b,(-8.7,11.49,6.18),(4.72,.08,.095),mats['oak_light'])
    for x in [-10.85,-6.55]:
        beam(b,(x,12.35,5.38),(x,11.65,6.12),.16,mats['oak'])
        box(b,(x,12.33,5.72),(.20,.16,.86),mats['oak'])
    finish('Courtyard_InnPorchTrim',b,props,'overhead')

    # Wall-hung pictorial signs are readable without new UI/interaction logic.
    for name,cx,cy,cz,icon in [('Inn',-5.3,11.75,6.0,'mug'),
                               ('Item',-17.6,3.10,5.70,'potion'),
                               ('Weapon',16.5,-9.25,5.75,'anvil')]:
        b=batch()
        box(b,(cx,cy+.36,cz+.75),(.13,1.0,.13),mats['iron'])
        box(b,(cx,cy,cz+.72),(.94,.12,.12),mats['iron'])
        for dx in [-.35,.35]:beam(b,(cx+dx,cy,cz+.70),(cx+dx,cy,cz+.47),.045,mats['iron'])
        box(b,(cx,cy,cz),(1.18,.13,.98),mats['oak'])
        for z in [-.43,.43]:box(b,(cx,cy-.08,cz+z),(1.14,.06,.075),mats['oak_light'])
        if icon=='mug':
            box(b,(cx-.06,cy-.105,cz),(.38,.075,.43),mats['cream'])
            for a,c in [((.14,-.16),(.32,-.16)),((.32,-.16),(.32,.17)),((.32,.17),(.14,.17))]:
                beam(b,(cx+a[0],cy-.11,cz+a[1]),(cx+c[0],cy-.11,cz+c[1]),.06,mats['gold'])
            box(b,(cx-.06,cy-.12,cz+.23),(.43,.08,.08),mats['cream'])
        elif icon=='potion':
            shape=[(-.22,-.29),(.22,-.29),(.28,-.15),(.20,.10),(.09,.19),(.09,.31),(-.09,.31),(-.09,.19),(-.20,.10),(-.28,-.15)]
            poly(b,[(cx+x,cy-.105,cz+z) for x,z in shape],[tuple(range(len(shape)))],mats['blue'])
            box(b,(cx,cy-.13,cz+.33),(.24,.065,.075),mats['cream'])
            box(b,(cx-.08,cy-.14,cz-.02),(.05,.05,.15),mats['cream'])
        else:
            shape=[(-.38,.22),(.38,.22),(.30,.07),(.12,.04),(.12,-.16),(.28,-.24),(.28,-.30),(-.28,-.30),(-.28,-.24),(-.12,-.16),(-.12,.04),(-.30,.07)]
            poly(b,[(cx+x,cy-.105,cz+z) for x,z in reversed(shape)],[tuple(range(len(shape)))],mats['iron'])
            box(b,(cx,cy-.13,cz+.23),(.74,.055,.05),mats['cream'])
        finish('Courtyard_Sign_'+name,b,props,'overhead')

    # Display on the merchant's side wall: bottles are overhead and
    # decorative, not items to pick up or a second inventory system.
    b=batch();cx=-23.5;cy=4.15
    box(b,(cx,cy+.12,5.55),(1.12,.10,.70),mats['oak'])
    for z in [5.28,5.73]:
        box(b,(cx,cy-.08,z),(1.24,.38,.09),mats['oak_light'])
        for i in range(4):
            x=cx-.42+i*.28
            box(b,(x,cy-.11,z+.17),(.16,.16,.24),mats['blue'] if i%2 else mats['green'])
            box(b,(x,cy-.11,z+.315),(.09,.09,.055),mats['cream'])
    # Face west beside the shop rather than covering its front window.
    b['vertices']=[(-25.25+y-cy,8.8-(x-cx),z) for x,y,z in b['vertices']]
    finish('Courtyard_ItemDisplay',b,props,'overhead')
    return {'revision':revision,'beds':bed_objects,'accepted_plants':accepted,
            'rejected_plants':rejected,'plant_count':len(accepted),'signs':3,
            'navigation_changed':False}
