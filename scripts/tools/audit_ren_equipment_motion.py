"""Read-only body preservation, worst-edge diagnosis and distal sword intersections.

Triangle intersections exclude the hilt intentionally held by the hand. These
numeric tests supplement native renders; they do not certify five-finger grip.
"""
import argparse, hashlib, json, sys
from pathlib import Path
import bpy
import numpy as np
from mathutils import Matrix, Vector, Quaternion
from mathutils.bvhtree import BVHTree
from mathutils.geometry import intersect_ray_tri

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--source', type=Path, required=True)
p.add_argument('--input', type=Path, required=True)
p.add_argument('--sword', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--runtime-grip', action='store_true', help='Apply the controller-equivalent .45 rad finger-group curl')
a = p.parse_args(sys.argv[sys.argv.index('--')+1:])

def mesh_digest(obj):
    mesh = obj.data
    values = {'vertices': [tuple(v.co) for v in mesh.vertices],
              'faces': [tuple(face.vertices) for face in mesh.polygons],
              'uv': [[tuple(item.uv) for item in uv.data] for uv in mesh.uv_layers],
              'weights': [[(obj.vertex_groups[g.group].name, g.weight) for g in v.groups] for v in mesh.vertices],
              'normals': [tuple(item.vector) for item in mesh.corner_normals]}
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()

bpy.ops.wm.open_mainfile(filepath=str(a.source.resolve()))
before = {o.name: mesh_digest(o) for o in bpy.context.scene.objects if o.type == 'MESH'}
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
meshes = [o for o in scene.objects if o.type == 'MESH']
after = {o.name: mesh_digest(o) for o in meshes}
failures = []
if before != after: failures.append('BODY_GEOMETRY_UV_NORMALS_WEIGHTS_CHANGED')
for track in rig.animation_data.nla_tracks: track.mute = True
with bpy.data.libraries.load(str(a.sword.resolve()), link=False) as (src, dst):
    dst.meshes = ['BronzeBlade']
sword = dst.meshes[0]
sword.calc_loop_triangles()
distal = [tuple(tri.vertices) for tri in sword.loop_triangles if sword.attributes['DistalBlade'].data[tri.polygon_index].value]
sword_rest = Matrix.Translation(Vector((-.43, .01, .94))) @ Vector((0,0,1)).rotation_difference(Vector((-.65,-.25,-.70)).normalized()).to_matrix().to_4x4()
hand_inverse = rig.data.bones['HandRight'].matrix_local.inverted()
baseline = {}
for obj in meshes:
    points = np.array([tuple(v.co) for v in obj.data.vertices])
    edges = np.array([tuple(e.vertices) for e in obj.data.edges])
    lengths = np.linalg.norm(points[edges[:,0]]-points[edges[:,1]], axis=1)
    baseline[obj.name] = (edges, lengths, lengths > max(np.ptp(points[:,2])*.004, 1e-6))

def crosses(points_a, points_b):
    for source, target in [(points_a, points_b), (points_b, points_a)]:
        for lo, hi in [(0,1),(1,2),(2,0)]:
            delta = source[hi]-source[lo]
            hit = intersect_ray_tri(*target, delta.normalized(), source[lo], True)
            if hit is not None and .00001 < (hit-source[lo]).dot(delta.normalized()) < delta.length-.00001:
                return True
    return False

actions = {}
for action in bpy.data.actions:
    rig.animation_data.action = action
    if action.slots: rig.animation_data.action_slot = action.slots[0]
    maximum, worst, intersections, floors = 0., None, [], []
    first_points, last_points = {}, {}
    sampled_frames = 0
    for frame in range(int(action.frame_range[0]), int(action.frame_range[1])+1):
        scene.frame_set(frame); bpy.context.view_layer.update()
        sampled_frames += 1
        if a.runtime_grip:
            basis = rig.data.bones['FingersRight'].matrix_local.to_3x3()
            axis = basis.inverted() @ basis.col[1].cross(Vector((0,-1,0))).normalized()
            rig.pose.bones['FingersRight'].rotation_euler = Quaternion(axis.normalized(), .45).to_euler('XYZ')
            bpy.context.view_layer.update()
        transform = rig.pose.bones['HandRight'].matrix @ hand_inverse @ sword_rest
        sword_points = [transform @ v.co for v in sword.vertices]
        sword_bvh = BVHTree.FromPolygons(sword_points, distal, all_triangles=True)
        floor = float('inf')
        for obj in meshes:
            evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()); mesh = evaluated.to_mesh()
            points = [v.co.copy() for v in mesh.vertices]
            array = np.array([tuple(v) for v in points])
            if obj.name not in first_points: first_points[obj.name] = array.copy()
            last_points[obj.name] = array.copy()
            floor = min(floor, float(array[:,2].min()))
            edges, lengths, valid = baseline[obj.name]
            ratios = np.divide(np.linalg.norm(array[edges[:,0]]-array[edges[:,1]],axis=1), lengths, out=np.zeros(len(lengths)), where=valid)
            index = int(ratios.argmax())
            if ratios[index] > maximum:
                maximum = float(ratios[index])
                vertices = [int(i) for i in edges[index]]
                worst = {'mesh':obj.name,'frame':frame,'edge':index,'vertices':vertices,
                         'rest_length':float(lengths[index]),
                         'rest_points':[list(obj.data.vertices[i].co) for i in vertices],
                         'weights':[{obj.vertex_groups[g.group].name:g.weight for g in obj.data.vertices[i].groups} for i in vertices]}
            mesh.calc_loop_triangles()
            triangles = [tuple(tri.vertices) for tri in mesh.loop_triangles]
            body_bvh = BVHTree.FromPolygons(points, triangles, all_triangles=True)
            pairs = body_bvh.overlap(sword_bvh)
            count = sum(crosses([points[i] for i in triangles[body]], [sword_points[i] for i in distal[blade]]) for body,blade in pairs)
            if count: intersections.append({'frame':frame,'mesh':obj.name,'triangle_pairs':count})
            evaluated.to_mesh_clear()
        floors.append(floor)
    if maximum >= 2.5: failures.append(action.name+':EXCESSIVE_EDGE_STRETCH')
    if intersections: failures.append(action.name+':DISTAL_BLADE_BODY_INTERSECTION')
    seam = max(float(np.abs(last_points[name]-values).max()) for name,values in first_points.items())
    if action.name in ['idle','sword_idle','walk','run','walk_narrow','run_narrow'] and seam > 1e-4:
        failures.append(action.name+':LOOP_SEAM')
    actions[action.name] = {'maximum_stretch':maximum,'worst_edge':worst,'distal_intersections':intersections,
                            'sampled_frames':sampled_frames,'whole_body_floor_range':[min(floors),max(floors)],'endpoint_vertex_difference':seam}
report = {'status':'FAIL' if failures else 'PASS','failures':failures,'source':str(a.source),'input':str(a.input),
          'body_mesh_digests_unchanged':before==after,'runtime_finger_curl_rad':.45 if a.runtime_grip else 0,
          'total_sampled_frames':sum(row['sampled_frames'] for row in actions.values()),'actions':actions,
          'limits':['Excludes intentional hilt/hand contact','Not an artistic or individual-finger grip certification']}
a.output.parent.mkdir(parents=True,exist_ok=True)
a.output.write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print('REN_EQUIPMENT_MOTION',report['status'],failures,flush=True)
if failures: raise RuntimeError(failures)
