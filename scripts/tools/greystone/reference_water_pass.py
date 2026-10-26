"""Reference cascade, impact foam and riverbank rocks; visual-only Blender pass."""
import math
import random
import bpy
import bmesh
from mathutils import Vector


def apply_water_details(groups, materials):
    rng=random.Random(261026)
    water=groups['Water']
    for obj in list(water.objects):
        if obj.name.startswith(('Waterfall','UpperRiver','FoamSplash')):
            bpy.data.objects.remove(obj,do_unlink=True)

    def mesh(name,points,faces,material,collection,uvs=None):
        data=bpy.data.meshes.new(name)
        data.from_pydata(points,[],faces);data.materials.append(material);data.update()
        if uvs:
            layer=data.uv_layers.new(name='Flow')
            for face in data.polygons:
                for loop in face.loop_indices:layer.data[loop].uv=uvs[data.loops[loop].vertex_index]
        obj=bpy.data.objects.new(name,data);collection.objects.link(obj)
        obj['visual_only_revision']='river_cascade_20261026'
        return obj

    # Upstream bed rolls over a rounded lip and fans into the plunge pool.
    # Every row belongs to one mesh: no box corners or overlapping stream cards.
    rows=[(55,14.265,5.2),(49,14.265,5.2),(45,14.265,5.1),(42,14.28,5.0),
          (40.1,14.28,5.2),(38.7,14.18,5.35),(37.5,13.65,5.5),(37.1,12.65,5.6),
          (36.9,10.6,5.7),(36.7,7.5,6.0),(36.45,4.3,6.5),(36.1,2.12,7.6)]
    points=[];faces=[];uvs=[];distance=0.0;last=None;columns=12
    lengths=[]
    for y,z,width in rows:
        if last:distance+=math.hypot(y-last[0],z-last[1])
        lengths.append(distance);last=(y,z)
    for row,(y,z,width) in enumerate(rows):
        for column in range(columns+1):
            u=column/columns
            sway=math.sin(u*math.tau*3+row*.36)*.075*math.sin(math.pi*row/(len(rows)-1))
            points.append((28+(u-.5)*width,y+sway,z+(.045*math.sin(u*math.tau*4) if row<4 else 0)))
            uvs.append((u,lengths[row]/distance))
    for row in range(len(rows)-1):
        for column in range(columns):
            a=row*(columns+1)+column;b=a+1;c=b+columns+1;d=a+columns+1
            faces.extend([(a,d,c),(a,c,b)])
    cascade=mesh('WaterfallCascade',points,faces,materials['water'],water,uvs)
    # Regression from the first native capture: the old waterfall placement
    # intersected the protruding convex cliff and its thin grass cap. Sample
    # the actual new triangles against the actual waterfall cliff surface.
    from mathutils.bvhtree import BVHTree
    cliff_points=[];cliff_faces=[]
    for collection in [groups['Terrain'],groups['Cliffs']]:
        for obj in collection.objects:
            if obj.type!='MESH' or not obj.name.startswith('WaterfallCliff'):continue
            offset=len(cliff_points)
            cliff_points.extend(obj.matrix_world@v.co for v in obj.data.vertices)
            cliff_faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
    cliff_bvh=BVHTree.FromPolygons(cliff_points,cliff_faces)
    clearance=[]
    for face in faces:
        verts=[Vector(points[i]) for i in face]
        for point in verts+[sum(verts,Vector())/3]:
            if point.z>14.1:
                hit=cliff_bvh.ray_cast(point+Vector((0,0,20)),Vector((0,0,-1)),30)[0]
                if hit is not None:clearance.append(point.z-hit.z)
            else:
                hit=cliff_bvh.ray_cast(Vector((point.x,20,point.z)),Vector((0,1,0)),40)[0]
                if hit is not None:clearance.append(hit.y-point.y)
    assert clearance and min(clearance)>.10, ('Waterfall intersects cliff',min(clearance))
    cascade['min_cliff_clearance_m']=min(clearance)

    # Foam is opaque/discard in Godot, avoiding stacked transparent cards.
    def disk(name,cx,cy,rx,ry,z):
        pts=[(cx,cy,z)];uv=[(.5,.5)]
        for i in range(40):
            angle=math.tau*i/40;r=1+.045*math.sin(angle*7)
            pts.append((cx+math.cos(angle)*rx*r,cy+math.sin(angle)*ry*r,z))
            uv.append((.5+.5*math.cos(angle),.5+.5*math.sin(angle)))
        return mesh(name,pts,[(0,i+1,(i+1)%40+1) for i in range(40)],materials['foam'],water,uv)
    disk('CascadeFoamPool',28,35.8,4.15,2.0,2.085)

    bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=1,radius=1)
    bm.verts.index_update();stone_points=[v.co.copy() for v in bm.verts]
    stone_faces=[tuple(v.index for v in f.verts) for f in bm.faces];bm.free()
    def append_stone(batch,center,scale,angle):
        pts,fs=batch;offset=len(pts)
        for p in stone_points:
            q=Vector((p.x*scale[0],p.y*scale[1],p.z*scale[2]))
            pts.append((center[0]+q.x*math.cos(angle)-q.y*math.sin(angle),
                        center[1]+q.x*math.sin(angle)+q.y*math.cos(angle),center[2]+q.z))
        fs.extend(tuple(offset+i for i in face) for face in stone_faces)
    billows=([],[])
    for i in range(17):
        append_stone(billows,(24.4+i*.45,36.4+rng.uniform(-.25,.3),2.18),
                     (rng.uniform(.28,.50),rng.uniform(.30,.55),rng.uniform(.25,.72)),rng.random()*6)
    mesh('CascadeFoamBillows',*billows,materials['foam'],water)

    # Individual rock wakes share a single low mesh and the same flow material.
    wakes=([],[]);wake_uv=[]
    for x,y,radius in [(25,24,.8),(31,17,.9),(26,13,.55),(30,1,.7),(25,-6,.65),(30,-14,.55),(26,33,.6)]:
        for band in range(2):
            begin=len(wakes[0]);r=radius*(1.0+band*.65)
            for i in range(15):
                a=math.pi*.08+i/14*math.pi*.84
                for edge in [0,.085]:
                    wakes[0].append((x+math.cos(a)*(r+edge),y-math.sin(a)*(r*.6+edge)-.2,2.045))
                    wake_uv.append((i/14,band))
            for i in range(14):
                a=begin+i*2;wakes[1].extend([(a,a+1,a+3),(a,a+3,a+2)])
    mesh('RiverStoneWakes',*wakes,materials['foam'],water,wake_uv)

    boulders=([],[])
    placements=[]
    # Submerged lower rocks stay beneath both bridge decks and off walkable land.
    for x,y,s in [(22.2,35.0,1.1),(33.0,34.4,1.0),(22.3,22.1,1.15),(33.7,21.0,.9),
                  (21.0,14.2,.9),(33.1,12.7,.9),(20.1,-2.1,1.0),(33.0,-5.1,1.0),
                  (21.2,-10.0,.8),(32.5,-18.4,1.0),(18.0,-27.0,1.1),(33.3,-25.2,1.0)]:
        append_stone(boulders,(x,y,1.60),(s*1.25,s*.95,s*.75),rng.random()*6)
        placements.append([x,y,1.60,s])
    mesh('RiverbankBoulders',*boulders,materials['stone'],groups['Cliffs'])
    framing=([],[])
    for x,y,s in [(23.3,40.8,1.4),(23.8,44.0,1.2),(24.2,47.4,1.1),
                  (32.8,40.6,1.5),(32.5,44.1,1.25),(32.2,47.5,1.1)]:
        append_stone(framing,(x,y,14.0),(s*.7,s,s*.9),rng.random()*6)
    mesh('CascadeLipBoulders',*framing,materials['stone'],groups['Cliffs'])
    return {'revision':'river_cascade_20261026','cascade_rows':len(rows),
            'cascade_triangles':len(faces),'flow_distance_m':distance,
            'foam_billows':17,'rock_wakes':14,'riverbank_boulders':placements,
            'lip_boulders':6,'cliff_clearance_samples':len(clearance),
            'minimum_cliff_clearance_m':min(clearance),'navigation_changed':False}
