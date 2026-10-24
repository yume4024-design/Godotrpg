"""Reference-specific mesh repairs, retaining the approved textured lower walls.

Clean roof geometry replaces damaged generated roof/stack triangles. No live scene,
external service or source character is modified by this module.
"""
import bpy
import bmesh
import math
from mathutils import Vector


def color_material(name, rgb):
    material = bpy.data.materials.get(name)
    if material is None:
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        linear = tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb) + (1,)
        material.diffuse_color = linear
        material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = linear
        material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .88
    return material


def repair_roof(data, asset):
    """Retain wall UVs below the eave; build closed, clean, softly colored roofs."""
    inn = asset == 'inn'
    eave, rise = (3.65, 2.2) if inn else (2.65, 1.45)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.bisect_plane(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                          dist=.00001, plane_co=(0, 0, eave), plane_no=(0, 0, 1), clear_outer=True)
    indices = {}
    palette = {'plaster':(.79,.74,.61), 'timber':(.30,.21,.13), 'stack':(.45,.45,.40),
               'cap':(.36,.33,.28), 'glass':(.95,.60,.21)}
    tiles = [(.67,.32,.20),(.69,.34,.22),(.70,.35,.23)]
    if asset in ('item_shop','house_a_blue'):
        tiles = [(.29,.36,.42),(.30,.37,.43),(.31,.38,.44)]
    palette.update({'tile'+str(i):color for i,color in enumerate(tiles)})
    for name, color in palette.items():
        indices[name] = len(data.materials)
        data.materials.append(color_material('ReferenceRoof_'+asset+'_'+name, color))

    def poly(points, faces, material):
        verts = [bm.verts.new(p) for p in points]
        for face in faces:
            f = bm.faces.new([verts[i] for i in face])
            f.material_index = indices[material]
    def box(center, size, material):
        c=Vector(center);x,y,z=(v/2 for v in size)
        points=[c+Vector(v) for v in [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),
                                     (-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]]
        poly(points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material)
    def beam(a,b,width,depth,material='timber'):
        a,b=Vector(a),Vector(b);d=(b-a).normalized()
        normal=d.cross(Vector((0,0,1)))
        if normal.length<.001: normal=Vector((1,0,0))
        normal.normalize();v=d.cross(normal).normalized()
        points=[p+normal*s*width/2+v*t*depth/2 for p in [a,b] for s,t in [(-1,-1),(1,-1),(1,1),(-1,1)]]
        poly(points,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material)

    # The approved original footprints remain unchanged. Roofs are inside their
    # old bounds, including the projecting front awnings retained below the cut.
    width = 12.0 if inn else (8.0 if asset in ('item_shop','weapon_shop') else 7.0)
    depth = 7.5 if inn else (5.5 if asset in ('item_shop','weapon_shop') else 4.5)
    # Local roof coordinates: u follows the ridge, v points down either slope.
    swap = inn
    along = width if swap else depth
    across = depth if swap else width
    def p(u,v,z): return (u,v,z) if swap else (v,u,z)
    half=across/2; ridge=eave+rise
    for u in [-along/2,along/2]:
        poly([p(u,-half,eave),p(u,half,eave),p(u,0,ridge)],[(0,2,1)] if (u<0)==swap else [(0,1,2)],'plaster')
        for side in [-1,1]: beam(p(u,side*half,eave),p(u,0,ridge),.14,.14)
        beam(p(u,0,eave),p(u,0,ridge),.15,.15)
        beam(p(u,-half,eave),p(u,half,eave),.15,.15)
    rows=7 if inn else 6
    columns=12 if inn else 8
    for side in [-1,1]:
        for row in range(rows):
            v0=half*row/rows;v1=half*(row+1)/rows
            for col in range(columns):
                u0=-along/2+along*col/columns+.006
                u1=-along/2+along*(col+1)/columns-.006
                corners=[p(u0,side*v0,ridge-rise*v0/half+.035),p(u1,side*v0,ridge-rise*v0/half+.035),
                         p(u1,side*v1,ridge-rise*v1/half+.035),p(u0,side*v1,ridge-rise*v1/half+.035)]
                top=corners if side==(1 if swap else -1) else list(reversed(corners))
                bottom=[(x,y,z-.10) for x,y,z in top]
                poly(top+bottom,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'tile'+str((row*2+col)%3))
        beam(p(-along/2,side*half,eave),p(along/2,side*half,eave),.16,.18)
    beam(p(-along/2-.05,0,ridge+.09),p(along/2+.05,0,ridge+.09),.23,.16,'tile1')
    # Solid stone stack with a clearly open dark flue, avoiding floating AI caps.
    cx=-width*.27;cy=depth*.20
    stack_top=ridge+.65
    box((cx,cy,(eave+stack_top)/2),(.65,.64,stack_top-eave),'stack')
    box((cx,cy,stack_top+.05),(.82,.80,.16),'cap')
    box((cx,cy,stack_top+.14),(.41,.39,.04),'timber')
    if inn:
        # Two small front dormers repeat the reference's welcoming inn facade.
        for x in [-3.1,2.8]:
            y=-depth*.24;z=ridge-rise*.48
            box((x,y,z+.23),(.85,.48,.78),'plaster')
            box((x,y-.255,z+.24),(.48,.035,.42),'glass')
            beam((x-.58,y-.36,z+.65),(x,y-.36,z+1.0),.12,.13)
            beam((x,y-.36,z+1.0),(x+.58,y-.36,z+.65),.12,.13)
            # Closed dormer slopes and a front gable, not two floating rafters.
            for side in [-1,1]:
                corners=[(x,y-.40,z+1.03),(x+side*.62,y-.40,z+.65),
                         (x+side*.62,y+.44,z+.65),(x,y+.44,z+1.03)]
                if side<0:corners.reverse()
                bottom=[(a,b,c-.08) for a,b,c in corners]
                poly(corners+bottom,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'tile1')
            poly([(x-.43,y-.27,z+.62),(x+.43,y-.27,z+.62),(x,y-.27,z+.94)],[(0,1,2)],'plaster')
            for dx in [-.28,.28]:box((x+dx,y-.29,z+.24),(.065,.08,.5),'timber')
            box((x,y-.29,z+.01),(.63,.1,.075),'timber')
            box((x,y-.29,z+.47),(.63,.1,.075),'timber')
            box((x,y-.29,z+.24),(.045,.07,.42),'timber')
    bm.to_mesh(data);bm.free();data.update()
    data.calc_loop_triangles()
    return {'retained_wall_uvs':True,'eave_m':eave,'ridge_m':ridge,'triangles':len(data.loop_triangles)}
