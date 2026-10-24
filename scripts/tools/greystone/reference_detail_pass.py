"""Deterministic visual-only finishing of the owned reference village master.

Run after collision authoring. Terrain, travel lanes, NPC anchors and proxy meshes
are immutable here; the frozen geometry digest is checked before saving.
"""
import hashlib
import json
import math
import random
import bpy
from mathutils import Vector


def protected_digest(groups):
    payload = []
    for group in ('Terrain', 'Paths', 'Bounds'):
        for obj in sorted(groups[group].objects, key=lambda item: item.name):
            if obj.type != 'MESH':
                continue
            payload.append((group, obj.name, [list(row) for row in obj.matrix_world],
                            [list(v.co) for v in obj.data.vertices],
                            [list(p.vertices) for p in obj.data.polygons]))
    return hashlib.sha256(json.dumps(payload, separators=(',', ':')).encode()).hexdigest()


def apply_reference_details(groups, materials):
    rng = random.Random(251025)
    before = protected_digest(groups)
    cliffs = 0
    for obj in list(groups['Cliffs'].objects):
        if '_RockFace' not in obj.name:
            continue
        original = [v.co.copy() for v in obj.data.vertices]
        assert len(original) == 18, obj.name
        points = []
        # Offset fractures and vary the exposed rim; never move the seam against
        # the walkable plateau. Only the outer side of the retaining skirt moves.
        for band, t in enumerate((0.0, .29, .68, 1.0)):
            for k in range(6):
                p = original[k].lerp(original[12+k], t)
                if k in (1, 2, 3):
                    inward = original[17]-original[12+k]
                    inward.z = 0
                    p += inward * rng.uniform(.04, .24) * (1.0 if band in (1, 2) else .3)
                    if band in (1, 2):
                        p.z += rng.uniform(-.65, .65)
                    elif band == 3:
                        p.z -= rng.uniform(.12, .85)
                points.append(p)
        faces = []
        for band in range(3):
            for k in range(6):
                a = band*6+k; b = band*6+(k+1)%6; c = b+6; d = a+6
                faces.extend(((a,b,d),(b,c,d)) if (band+k)%2 else ((a,b,c),(a,c,d)))
        faces += [tuple(range(5,-1,-1)), tuple(range(18,24))]
        data = bpy.data.meshes.new(obj.name+'_Fractured')
        data.from_pydata(points, [], faces)
        data.materials.append(materials['stone'])
        data.update()
        colors = data.color_attributes.new(name='RockFacets', type='FLOAT_COLOR', domain='CORNER')
        for face in data.polygons:
            tint = rng.uniform(.78, 1.12)
            warm = rng.uniform(-.035, .035)
            for loop in face.loop_indices:
                colors.data[loop].color = (tint+warm, tint, tint-warm, 1)
        obj.data = data
        obj['visual_only_revision'] = 'fractured_cliff_20261025'
        cliffs += 1

    # Inlaid paving: one shared mesh, slight bevels and irregular seams. It stays
    # within 5 cm of the existing floor and is decorative, not an extra collider.
    verts, faces, colors = [], [], []

    def stone(points, top, tint):
        center = sum((Vector((x,y)) for x,y in points), Vector((0,0)))/len(points)
        n = len(points); start = len(verts)
        verts.extend((x,y,top-.025) for x,y in points)
        verts.extend((center.x+(x-center.x)*.96, center.y+(y-center.y)*.96, top) for x,y in points)
        faces.append(tuple(start+n+i for i in range(n)))
        colors.append(tint)
        for i in range(n):
            faces.append((start+i,start+(i+1)%n,start+n+(i+1)%n,start+n+i))
            colors.append(tint*.9)

    for row, count in ((0,24),(1,30)):
        inner = 1.9+row*.62; outer = inner+.60
        for i in range(count):
            a = math.tau*(i+.035)/count; b = math.tau*(i+.965)/count
            points = [(r*math.cos(t),r*math.sin(t)) for r,t in ((inner,a),(outer,a),(outer,b),(inner,b))]
            stone(points,3.09+rng.uniform(-.004,.004),rng.uniform(.86,1.12))
    # Small flush flagstones indicate house entrances without filling the square.
    for cx,cy in [(-9,10),(-21,2.5),(9,12),(13,-9),(-15,-17),(5,-22)]:
        for row in range(3):
            for col in range(3):
                x=cx+(col-1)*.57+(row%2)*.16; y=cy-row*.5
                dx=rng.uniform(.22,.27);dy=rng.uniform(.18,.23)
                stone([(x-dx,y-dy),(x+dx,y-dy),(x+dx,y+dy),(x-dx,y+dy)],3.085,rng.uniform(.88,1.1))
    data=bpy.data.meshes.new('CourtyardInlaidStone')
    data.from_pydata(verts,[],faces);data.materials.append(materials['stone']);data.update()
    attribute=data.color_attributes.new(name='StoneVariation',type='FLOAT_COLOR',domain='CORNER')
    for face,tint in zip(data.polygons,colors):
        for loop in face.loop_indices:attribute.data[loop].color=(tint,tint*.98,tint*.94,1)
    obj=bpy.data.objects.new('CourtyardInlaidStone',data);groups['Props'].objects.link(obj)
    obj['visual_only']=True
    after=protected_digest(groups)
    assert before == after, 'Visual pass changed protected navigation geometry'
    return {'revision':'reference_finish_20261025','fractured_cliff_modules':cliffs,
            'inlaid_stones':108,'protected_geometry_sha256_before':before,
            'protected_geometry_sha256_after':after,
            'script_sha256':hashlib.sha256(open(__file__,'rb').read()).hexdigest()}
