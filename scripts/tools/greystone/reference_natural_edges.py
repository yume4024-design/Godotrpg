"""Faceted rock shoulders and broken turf rims, outside the tested walking floor.

Runs after reference_detail_pass; never modifies Terrain, Paths or Bounds.
"""
import math
import random
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def apply_natural_edges(groups, materials, roads, ramps, terrain_height):
    rng = random.Random(251026)
    rock_count = 0
    caps = []
    skipped = 0
    batches = {}

    def new_batch():
        return {'verts': [], 'faces': [], 'tints': []}

    def emit(batch, points, faces, tint):
        start = len(batch['verts'])
        batch['verts'].extend(points)
        batch['faces'].extend(tuple(start + i for i in face) for face in faces)
        batch['tints'].extend([tint] * len(faces))

    def mesh_data(name, points, faces, mat, tints):
        data = bpy.data.meshes.new(name)
        data.from_pydata(points, [], faces)
        data.materials.append(mat)
        data.update()
        uv=data.uv_layers.new(name='SurfaceInterior')
        for loop in uv.data:
            loop.uv=(.5,.5)
        colors = data.color_attributes.new(name='RockFacets', type='FLOAT_COLOR', domain='CORNER')
        for face, tint in zip(data.polygons, tints):
            for index in face.loop_indices:
                colors.data[index].color = (tint, tint*.995, tint*.98, 1)
        return data

    def route_clear(point, radius):
        # Full corridor footprint, including stair landings, not just center lines.
        for road in roads:
            for av, bv in zip(road['points'], road['points'][1:]):
                a, b = Vector(av), Vector(bv)
                direction = b - a
                direction.z = 0
                if direction.length_squared < .0001:
                    continue
                t = max(0, min(1, (point-a).dot(direction)/direction.length_squared))
                nearest = a.lerp(b, t)
                if abs(nearest.z-point.z) < 1.5 and math.hypot(point.x-nearest.x, point.y-nearest.y) < road['width']/2+radius+.4:
                    return False
        for av, bv in ramps:
            a, b = Vector(av), Vector(bv)
            direction = b - a
            direction.z = 0
            t = max(0, min(1, (point-a).dot(direction)/direction.length_squared))
            nearest = a.lerp(b, t)
            if abs(nearest.z-point.z)<2 and math.hypot(point.x-nearest.x, point.y-nearest.y)<2.6+radius:
                return False
        return True

    for obj in sorted(groups['Cliffs'].objects, key=lambda item: item.name):
        if '_RockFace' not in obj.name:
            continue
        original = [v.co.copy() for v in obj.data.vertices]
        assert len(original) == 24, obj.name
        a, b = original[18], original[22]
        tangent = b-a
        tangent.z = 0
        width = tangent.length
        tangent.normalize()
        outer = Vector((tangent.y, -tangent.x, 0))
        center = (a+b)/2
        top = max(a.z, b.z) + .06
        bottom = min(v.z for v in original)
        depth = max((v-center).dot(outer) for v in original)
        shoulder = min(1.45, (top-bottom)*.23)
        half = width*.5
        # A broad, asymmetric heptagonal rock rather than a straight prism.
        ring = [(-half, -.13), (-half*.92, depth*.24), (-half*.57, depth*.79),
                (half*.08, depth*.96), (half*.72, depth*.73), (half, -.13), (0, -.20)]
        points = []
        upper = []
        for band in range(4):
            for k, (u, v) in enumerate(ring):
                if k in (0, 5, 6):
                    z = [bottom, bottom+(top-bottom)*.45, top-shoulder, top-.03][band]
                    p = Vector((center.x, center.y, z))+tangent*u+outer*v
                else:
                    z = [bottom, bottom+(top-bottom)*rng.uniform(.38,.51),
                         top-shoulder*rng.uniform(1.0,1.40), top-rng.uniform(.20,.65)][band]
                    spread = [1.0, rng.uniform(.94,1.08), .95, rng.uniform(.65,.83)][band]
                    p = Vector((center.x, center.y, z))+tangent*(u+rng.uniform(-.16,.16))+outer*(v*spread)
                points.append(p)
                if band == 3:
                    upper.append(p)
        faces, tints = [], []
        stone_tint = rng.uniform(.82,1.10)
        for band in range(3):
            for k in range(7):
                j=(k+1)%7
                faces.append((band*7+k,band*7+j,(band+1)*7+j,(band+1)*7+k))
                tints.append(stone_tint*rng.uniform(.94,1.06))
        faces.extend([tuple(range(6,-1,-1)),tuple(range(21,28))])
        tints.extend([stone_tint*.8,stone_tint*1.07])
        obj.data = mesh_data(obj.name+'_Shouldered', points, faces, materials['stone'], tints)
        obj['visual_only_revision'] = 'natural_edges_20261025'
        rock_count += 1
        rock_surface = BVHTree.FromPolygons(points, faces, all_triangles=False)

        # Exposed rims only. Grass grows over the rock shoulder, not across a
        # bridge/stair landing or buried below another terrain level.
        inner_probe = center-outer*.35
        outer_probe = center+outer*.85
        if abs(terrain_height(inner_probe.x,inner_probe.y)-top)>.10 or terrain_height(outer_probe.x,outer_probe.y)>top-.8:
            skipped += 1
            continue
        radius = width*.45+1.0
        if not route_clear(Vector((center.x,center.y,top)),radius):
            skipped += 1
            continue
        if rng.random() < .17:
            continue
        # Narrow irregular turf cap partly inside the rock. Every outer vertex
        # remains over its shoulder; the original continuous floor is retained.
        extent = half*rng.uniform(.60,.88)
        front = depth*rng.uniform(.29,.50)
        outline = [(-extent,-.09), (extent,-.09), (extent*.93,front*.35),
                   (extent*.58,front), (extent*.05,front*.84),
                   (-extent*.38,front*1.06), (-extent*.88,front*.58)]
        cap_top=[]
        for k,(u,v) in enumerate(outline):
            p=Vector((center.x,center.y,top+1))+tangent*u+outer*v
            hit=rock_surface.ray_cast(p,Vector((0,0,-1)),top-bottom+2)[0]
            assert hit is not None, (obj.name,k)
            p.z=max(hit.z,terrain_height(p.x,p.y))+.018
            cap_top.append(p)
        if max(p.z for p in cap_top)>top+.05:
            # A corner can enter a higher neighbouring plateau even if the
            # center probes were clear; do not stretch turf between elevations.
            skipped+=1
            continue
        # Thin brown root layer provides a readable material transition.
        cap_bottom=[p-Vector((0,0,.075)) for p in cap_top]
        sector=obj.name.split('_RockFace')[0]
        grass_batch=batches.setdefault((sector,'Grass'),new_batch())
        earth_batch=batches.setdefault((sector,'Soil'),new_batch())
        emit(grass_batch,cap_top,[tuple(range(6,-1,-1))],rng.uniform(.9,1.06))
        emit(earth_batch,cap_top+cap_bottom,[(k,(k+1)%7,(k+1)%7+7,k+7) for k in range(7)]+[tuple(range(7,14))],1)
        caps.append({'rock':obj.name,'center':list(center),'terrain_height':top,'width':extent*2,'depth':front})

    # Neighbouring rock shoulders overlap at corners. Resolve the turf against
    # the completed surface, not only the individual block that authored it.
    support_points=[];support_faces=[]
    support_objects=[o for o in groups['Cliffs'].objects if '_RockFace' in o.name]
    support_objects+=list(groups['Terrain'].objects)
    for support in support_objects:
        if support.type!='MESH':continue
        offset=len(support_points)
        support_points.extend(support.matrix_world@v.co for v in support.data.vertices)
        support_faces.extend(tuple(offset+i for i in f.vertices) for f in support.data.polygons)
    support_tree=BVHTree.FromPolygons(support_points,support_faces,all_triangles=False)
    for (sector,kind),batch in batches.items():
        if kind!='Grass':continue
        for point in batch['verts']:
            hit=support_tree.ray_cast(point+Vector((0,0,.5)),Vector((0,0,-1)),2)[0]
            assert hit is not None,sector
            point.z=hit.z+.018
    for (sector,kind),batch in batches.items():
        name='NaturalRim'+kind+'_'+sector
        data=mesh_data(name,batch['verts'],batch['faces'],materials['grass' if kind=='Grass' else 'earth'],batch['tints'])
        obj=bpy.data.objects.new(name,data)
        groups['Cliffs'].objects.link(obj)
        obj['visual_only_revision']='natural_edges_20261025'
    return {'revision':'natural_edges_20261025','rock_modules':rock_count,
            'turf_caps':len(caps),'batched_rim_meshes':len(batches),'caps':caps,
            'skipped_hidden_or_routes':skipped,'navigation_changed':False}
