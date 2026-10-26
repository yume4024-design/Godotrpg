"""Clean reference timber/plaster facades, preserving authored roof modules.

The generated lower walls have baked black patches and fused props. Rebuild
these defective surfaces inside the established footprint; do not edit atlases,
collision bodies, entrances, anchors or the original AI source files.
"""
import math
import bpy
import bmesh
from mathutils import Vector


def rebuild_facade(data, asset, color_material):
    inn=asset=='inn'
    shop=asset in ('item_shop','weapon_shop')
    # Keep the wall and plinth inside the frozen body proxies (allowing their
    # original 0.32 m player radius to clear shallow window/door furniture).
    width,depth,height=(10.1,5.7,3.65) if inn else ((6.72,4.10 if asset=='weapon_shop' else 4.32,2.65) if shop else (5.86,3.32,2.65))
    bm=bmesh.new();bm.from_mesh(data)
    old=[f for f in bm.faces if not data.materials[f.material_index].name.startswith('ReferenceRoof_')]
    bmesh.ops.delete(bm,geom=old,context='FACES')
    loose=[v for v in bm.verts if not v.link_faces]
    if loose:bmesh.ops.delete(bm,geom=loose,context='VERTS')
    palette={'plaster':(.84,.78,.65),'plaster_shade':(.79,.73,.60),
             'timber':(.36,.25,.15),'timber_light':(.47,.33,.20),
             'stone':(.49,.50,.45),'door':(.43,.29,.16),'iron':(.21,.23,.22),
             'glass':(.98,.69,.30),'awning':(.30,.47,.57) if asset=='item_shop' else (.73,.48,.23),
             'awning_light':(.38,.57,.65) if asset=='item_shop' else (.81,.58,.31)}
    slots={}
    for name,color in palette.items():
        slots[name]=len(data.materials)
        key='ReferenceFacade_'+(asset+'_' if name.startswith('awning') else '')+name
        data.materials.append(color_material(key,color))
    count=0
    def poly(points,faces,mat):
        nonlocal count
        vertices=[bm.verts.new(p) for p in points]
        for f in faces:
            face=bm.faces.new([vertices[i] for i in f]);face.material_index=slots[mat];count+=1
    def box(center,size,mat):
        c=Vector(center);x,y,z=[s/2 for s in size]
        points=[c+Vector(p) for p in [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),
                                    (-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]]
        poly(points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    def beam(a,b,thickness,mat):
        a,b=Vector(a),Vector(b);direction=(b-a).normalized()
        side=direction.cross(Vector((0,0,1)))
        if side.length<.001:side=Vector((1,0,0))
        side.normalize();up=direction.cross(side).normalized()
        points=[p+side*s*thickness/2+up*t*thickness/2 for p in [a,b] for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        poly(points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    # Fully closed foundation and walls, with expressed panels and corner posts.
    box((0,0,height/2),(width,depth,height),'plaster')
    for side in [-1,1]:
        for x in [-width/2,width/2]:box((x,side*depth/2,height/2),(.18,.19,height),'timber')
        for z in [.32,height-.09]:box((0,side*(depth/2+.025),z),(width+.16,.16,.18),'timber')
        for i in range(-2,3):
            x=i*width/5
            box((x,side*(depth/2+.02),height/2),(.13,.13,height-.32),'timber')
        for x in [-width*.36,width*.36]:
            beam((x,side*(depth/2+.1),.42),(x+.65,side*(depth/2+.1),1.12),.10,'timber')
    for side in [-1,1]:
        for y in [-depth*.23,depth*.23]:box((side*(width/2+.025),y,height/2),(.15,.14,height),'timber')
        for z in [.32,height-.09]:box((side*(width/2+.025),0,z),(.16,depth,.18),'timber')
    for side in [-1,1]:
        for i in range(math.ceil(width/.74)):
            x=-width/2+(i+.5)*width/math.ceil(width/.74)
            box((x,side*(depth/2+.035),.16),(width/math.ceil(width/.74)-.025,.20,.30),'stone')
        for i in range(math.ceil(depth/.70)):
            y=-depth/2+(i+.5)*depth/math.ceil(depth/.70)
            box((side*(width/2+.035),y,.16),(.20,depth/math.ceil(depth/.70)-.025,.30),'stone')

    def window(x,y,z,w=.86,h=.94,axis='front'):
        # Transform complete window assembly to a side wall if requested.
        start=set(bm.verts)
        box((x,y,z),(w,.08,h),'glass')
        for dx in [-w/2-.06,w/2+.06]:box((x+dx,y-.05,z),(.11,.14,h+.22),'timber')
        for dz in [-h/2-.06,h/2+.06]:box((x,y-.055,z+dz),(w+.30,.18,.11),'timber')
        box((x,y-.08,z),(.055,.12,h),'timber');box((x,y-.08,z),(w,.12,.055),'timber')
        box((x,y-.09,z-h/2-.15),(w+.45,.30,.13),'stone')
        for sign in [-1,1]:
            sx=x+sign*(w/2+.24)
            box((sx,y+.005,z),(.24,.07,h),'timber_light')
            for dz in [-h*.30,h*.30]:box((sx,y-.04,z+dz),(.25,.045,.05),'timber')
        if axis!='front':
            for v in set(bm.verts)-start:
                px,py,pz=v.co
                if axis=='left':v.co=(-width/2+py+depth/2,px,pz)
                elif axis=='right':v.co=(width/2-py-depth/2,-px,pz)
                else:v.co=(-px,-py,pz)
    front=-depth/2-.055
    for x in [-width*.30,width*.30]:window(x,front,1.52,1.03 if inn else .82,.98)
    for side in ['left','right']:
        for y in [-depth*.22,depth*.22]:window(y,front,1.52,.72,.90,side)
    for x in [-width*.27,width*.27]:window(x,front,1.52,.82,.94,'back')
    if inn:
        for x in [-width*.32,0,width*.32]:window(x,front,2.90,.78,.68)
        for side in [-1,1]:box((0,side*(depth/2+.07),2.36),(width,.16,.16),'timber')
    # A legible plank door; the interaction stays outside, with no fake interior.
    door_width=1.45 if inn else 1.28
    box((0,front-.03,1.13),(door_width,.13,2.10),'door')
    for i in range(7):
        x=-door_width/2+(i+.5)*door_width/7
        box((x,front-.105,1.13),(door_width/7-.018,.045,2.04),'timber_light' if i%3==0 else 'door')
    for x in [-door_width/2-.08,door_width/2+.08]:box((x,front-.06,1.15),(.16,.22,2.3),'timber')
    box((0,front-.06,2.27),(door_width+.32,.23,.18),'timber')
    for z in [.62,1.6]:box((0,front-.14,z),(door_width,.06,.075),'iron')
    box((door_width*.30,front-.20,1.1),(.08,.10,.16),'iron')
    # Porch canopy remains entirely above character head height, no new posts
    # or collision obstacles are placed in existing NPC interaction circles.
    canopy_width=4.4 if inn else (3.2 if shop else 2.0)
    canopy_z=2.48 if not inn else 2.70
    for i in range(8):
        x0=-canopy_width/2+i*canopy_width/8;x1=x0+canopy_width/8-.012
        ya=front+.05;yb=front-(.85 if shop or inn else .52)
        poly([(x0,ya,canopy_z+.28),(x1,ya,canopy_z+.28),(x1,yb,canopy_z),(x0,yb,canopy_z),
              (x0,ya,canopy_z+.22),(x1,ya,canopy_z+.22),(x1,yb,canopy_z-.06),(x0,yb,canopy_z-.06)],
             [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'awning' if i%2 else 'awning_light')
    # Brackets are recessed beside the door, above its lintel.
    for x in [-canopy_width*.43,canopy_width*.43]:
        beam((x,front,2.28),(x,front-.52,canopy_z),.09,'timber')
    bm.normal_update();bm.to_mesh(data);bm.free();data.update()
    return {'revision':'reference_facades_20261026','removed_generated_faces':len(old),
            'authored_faces':count,'body_dimensions_m':[width,depth,height],
            'door_width_m':door_width,'shared_palette':True,'no_new_ground_posts':True}
