"""Plan a face split along manually placed anatomical hem/waist landmarks.

All source faces/UVs remain unchanged. Yellow lines and red faces are diagnostic
materials, not an edited albedo. Do not export a rig from this planning scene.
"""
import argparse
from collections import defaultdict
import heapq
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
assert hashlib.sha256(a.input.read_bytes()).hexdigest() == '93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850'
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene = bpy.context.scene
body = next(o for o in scene.objects if o.type == 'MESH')
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True
for bone in rig.pose.bones:
    bone.matrix_basis.identity()
scene.frame_set(0)
bpy.context.view_layer.update()
mesh = body.data
canonical, ids = {}, {}
for vertex in mesh.vertices:
    canonical[vertex.index] = ids.setdefault(tuple(vertex.co), vertex.index)
positions = {index: mesh.vertices[index].co.copy() for index in ids.values()}
edge_faces, neighbors = defaultdict(list), defaultdict(set)
for face in mesh.polygons:
    for pair in face.edge_keys:
        edge = tuple(sorted(canonical[v] for v in pair))
        edge_faces[edge].append(face.index)
        neighbors[edge[0]].add(edge[1])
        neighbors[edge[1]].add(edge[0])
face_neighbors = defaultdict(set)
for faces in edge_faces.values():
    for face in faces:
        face_neighbors[face].update(set(faces)-{face})
# Restrict landmarks to the main connected surface, excluding floating pouch
# details and importer helpers. Do not modify or discard any component.
seed = max(mesh.polygons, key=lambda f: f.center.z).index
main, todo = set(), [seed]
while todo:
    face = todo.pop()
    if face in main:
        continue
    main.add(face)
    todo.extend(face_neighbors[face]-main)
main_vertices = {canonical[v] for f in main for v in mesh.polygons[f].vertices}

# Viewed front/back/left at .74m orthographic scale. These are physical hem
# landmarks, not a brightness mask. The center notches rise to the belt.
hem = [(-.236,-.085,.954),(-.172,-.139,.935),(-.075,-.158,.915),
       (-.06835,-.12723,1.01872),(0,-.132,1.071),(.031,-.144,1.025),
       (.076,-.154,.912),(.168,-.133,.936),(.18425,-.04821,.98923),
       (.236,0,.965),(.219,.091,.952),(.121,.149,.937),(.031,.153,.943),
       (0,.130,1.043),(-.031,.154,.941),(-.123,.146,.937),
       (-.218,.087,.949),(-.236,0,.965)]
waist = [(-.204,-.069,1.109),(-.120,-.124,1.109),(0,-.131,1.109),
         (.10522,-.10846,1.14205),(.204,-.069,1.109),(.208,0,1.109),
         (.18129,.03568,1.07058),(.112,.128,1.109),(0,.132,1.109),
         (-.112,.128,1.109),(-.198,.071,1.109),(-.208,0,1.109)]

def nearest(point):
    target = Vector(point)
    return min(main_vertices,key=lambda v:(positions[v]-target).length_squared)

def segment_distance(point, start, end):
    delta = end-start
    t = max(0.,min(1.,(point-start).dot(delta)/delta.length_squared))
    return (point-start-delta*t).length

def route(start, end):
    queue, cost, previous = [(0.,start)], {start:0.}, {}
    while queue:
        distance, vertex = heapq.heappop(queue)
        if distance != cost[vertex]:
            continue
        if vertex == end:
            path = [end]
            while path[-1] != start:
                path.append(previous[path[-1]])
            return list(reversed(path))
        for other in neighbors[vertex] & main_vertices:
            midpoint = (positions[vertex]+positions[other])*.5
            # Prefer the visibly inspected landmark segment, not shortcuts
            # through the inner trousers or across an entire notch.
            penalty = segment_distance(midpoint,positions[start],positions[end])
            trial = distance+(positions[other]-positions[vertex]).length*(1+100*penalty)
            if trial < cost.get(other,float('inf')):
                cost[other], previous[other] = trial, vertex
                heapq.heappush(queue,(trial,other))
    raise RuntimeError('Landmarks do not share a connected surface')

loops, cuts, validation_failures = {}, set(), []
for name, anchors in [('hem',hem),('waist',waist)]:
    vertices = [nearest(point) for point in anchors]
    paths = [route(start,end) for start,end in zip(vertices,vertices[1:]+vertices[:1])]
    edges = {tuple(sorted(pair)) for path in paths for pair in zip(path,path[1:])}
    degree = defaultdict(int)
    for first,second in edges:
        degree[first] += 1
        degree[second] += 1
    if not all(value==2 for value in degree.values()):
        print('CUT_DIAGNOSTIC', name, json.dumps({'bad_vertices':[
            {'vertex':v,'degree':d,'point':list(positions[v])} for v,d in degree.items() if d!=2],
            'anchors':[{'target':point,'vertex':v,'point':list(positions[v])} for point,v in zip(anchors,vertices)]}),flush=True)
        validation_failures.append(name+':NON_SIMPLE_CUT')
    if cuts & edges:
        validation_failures.append(name+':INTERSECTING_CUTS')
    cuts.update(edges)
    loops[name] = {'anchors':[{'requested':point,'vertex':v,'actual':list(positions[v])} for point,v in zip(anchors,vertices)],
                   'paths':paths,'edges':[list(edge) for edge in sorted(edges)]}
blocked = defaultdict(set)
for edge in cuts:
    faces = edge_faces[edge]
    for face in faces:
        blocked[face].update(set(faces)-{face})
target = Vector((.16,-.13,1.01))
seed_face = min(main,key=lambda i:(mesh.polygons[i].center-target).length_squared)
selected, todo = set(), [seed_face]
while todo:
    face = todo.pop()
    if face in selected:
        continue
    selected.add(face)
    todo.extend(face_neighbors[face]-blocked[face]-selected)
if not 100 < len(selected) < 4000:
    validation_failures.append('UNEXPECTED_PATCH:'+str(len(selected)))
if validation_failures:
    selected.clear()  # Render rejected cut paths without a misleading red patch.

def material(name,color):
    result=bpy.data.materials.new(name)
    result.diffuse_color=(*color,1)
    return result
gray=material('UnselectedTopology',(.27,.32,.36))
red=material('GarmentFacePlan',(.75,.08,.04))
yellow=material('CutPlan',(.95,.75,.03))
body.data.materials.clear()
for mat in [gray,red]:
    body.data.materials.append(mat)
for face in mesh.polygons:
    face.material_index = 1 if face.index in selected else 0
for index,(first,second) in enumerate(cuts):
    curve=bpy.data.curves.new('CutEdge','CURVE')
    curve.dimensions='3D'
    curve.bevel_depth=.0007
    curve.bevel_resolution=0
    spline=curve.splines.new('POLY')
    spline.points.add(1)
    for point,vertex in zip(spline.points,[first,second]):
        coordinate=positions[vertex]
        point.co=(*coordinate,1)
    obj=bpy.data.objects.new('CutEdge'+str(index),curve)
    scene.collection.objects.link(obj)
    curve.materials.append(yellow)
a.output.mkdir(parents=True)
(a.output/'split_plan.json').write_text(json.dumps({'source_sha256':hashlib.sha256(a.input.read_bytes()).hexdigest(),
    'loops':loops,'selected_faces':sorted(selected),'main_component_faces':len(main),
    'status':'FAIL' if validation_failures else 'PLANNING_REQUIRES_VISUAL_REVIEW',
    'failures':validation_failures,'source_geometry_uv_unchanged':True},indent=2),encoding='utf8')
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO'
scene.display.shading.color_type='MATERIAL'
scene.display.shading.show_shadows=True
scene.display.shading.show_cavity=True
scene.render.resolution_x=scene.render.resolution_y=800
scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
data=bpy.data.cameras.new('SplitPlanCamera')
camera=bpy.data.objects.new(data.name,data)
scene.collection.objects.link(camera)
data.type='ORTHO'
data.ortho_scale=.74
scene.camera=camera
for name,position in [('front',(0,-3,.98)),('back',(0,3,.98)),('left',(3,0,.98))]:
    camera.location=position
    camera.rotation_euler=(Vector((0,0,.98))-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str((a.output/(name+'.png')).resolve())
    bpy.ops.render.render(write_still=True)
print('REN_SPLIT_PLAN',len(selected),'faces;',len(cuts),'cut edges',flush=True)
if validation_failures:
    raise RuntimeError(validation_failures)
