"""Manual local wing retopology, retaining the owned bat's head/body/feet.

The rejected generated volumetric membranes are replaced by thin, continuous
panels, structural ribs and six faceted blue crystals. Three articulated panels
per side fold by joint rotation; no wing scale/collapse or amplitude reduction.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector

p = argparse.ArgumentParser()
p.add_argument('--input', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
p.add_argument('--render', action='store_true')
a = p.parse_args(sys.argv[sys.argv.index('--') + 1:])
source_sha = hashlib.sha256(a.input.read_bytes()).hexdigest()
assert source_sha == '6f2a43b1cb59ebc4b41525bdf1245e3d66eb1e9b79f8111ee0a3312d0c847026'
assert not a.output.exists()
bpy.ops.wm.open_mainfile(filepath=str(a.input.resolve()))
scene = bpy.context.scene
rig = next(o for o in scene.objects if o.type == 'ARMATURE')
body = next(o for o in scene.objects if o.type == 'MESH')
assert len(body.data.polygons) == 8712
rig.animation_data.action = None
for track in rig.animation_data.nla_tracks:
    track.mute = True


def smooth(low, high, value):
    t = max(0., min(1., (value - low) / (high - low)))
    return t * t * (3 - 2 * t)


def wing_point(point):
    x, y, z = point
    # Reviewed front/side anatomy: ears start above the wing crest (.831m),
    # and the projecting face lies in front of y=-.18. Keep those intact.
    return .18 < z < .84 and (abs(x) > .35 or (abs(x) > .265 and y > -.18))


mesh = body.data
source_loop = {}
removed = []
for face in mesh.polygons:
    positions = [mesh.vertices[i].co for i in face.vertices]
    center = sum(positions, Vector()) / 3
    if wing_point(center):
        removed.append(face.index)
    else:
        source_loop[face.index] = [(tuple(mesh.vertices[mesh.loops[li].vertex_index].co),
                                    tuple(mesh.uv_layers.active.data[li].uv),
                                    tuple(mesh.corner_normals[li].vector)) for li in face.loop_indices]
assert 2500 < len(removed) < 5500
attribute = mesh.attributes.new('BatSourceFace', 'INT', 'FACE')
for i, item in enumerate(attribute.data):
    item.value = i
bm = bmesh.new()
bm.from_mesh(mesh)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.faces[i] for i in removed], context='FACES')
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(mesh)
bm.free()
mesh.update()
normals = []
for face in mesh.polygons:
    old = mesh.attributes['BatSourceFace'].data[face.index].value
    original = source_loop[old]
    current = [(tuple(mesh.vertices[mesh.loops[li].vertex_index].co),
                tuple(mesh.uv_layers.active.data[li].uv)) for li in face.loop_indices]
    assert current == [(row[0], row[1]) for row in original]
    normals.extend(row[2] for row in original)
mesh.normals_split_custom_set(normals)
mesh.attributes.remove(mesh.attributes['BatSourceFace'])

# Fully remove accidental Wing/WingTip influence from the retained anatomy.
# Proportionally preserve the established Head/Ear/Body/Foot relationships.
wing_groups = [g for g in body.vertex_groups if g.name.startswith('Wing')]
nonwing_groups = [g for g in body.vertex_groups if not g.name.startswith('Wing')]
original_groups = {g.index: g for g in body.vertex_groups}
rebound = 0
for v in mesh.vertices:
    values = {original_groups[g.group].name: g.weight for g in v.groups
              if not original_groups[g.group].name.startswith('Wing')}
    total = sum(values.values())
    if sum(g.weight for g in v.groups if original_groups[g.group].name.startswith('Wing')) > 1e-8:
        rebound += 1
    for group in body.vertex_groups:
        group.remove([v.index])
    if total < 1e-8:
        values = {'Head' if v.co.z > .64 else 'Body': 1.}
        total = 1.
    for name, weight in values.items():
        if weight > 1e-8:
            body.vertex_groups[name].add([v.index], weight / total, 'REPLACE')

knots = [.265, .43, .59, .763]
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for side, sign in [('Left', 1), ('Right', -1)]:
    parent = rig.data.edit_bones['Wing' + side]
    for i in range(3):
        bone = rig.data.edit_bones.new(f'WingPanel{i}{side}')
        bone.head, bone.tail = (sign * knots[i], 0, .6), (sign * knots[i+1], 0, .6)
        bone.parent = parent
        parent = bone
bpy.ops.object.mode_set(mode='OBJECT')

# A small shared palette is sufficient for the new surfaces. Original body
# albedo/normal images are untouched; generated geometry has a real UV channel.
colors = [( .31, .20, .47, 1), (.37, .24, .55, 1), (.43, .29, .61, 1),
          (.22, .19, .33, 1), (.26, .23, .38, 1), (.20, .61, .90, 1),
          (.33, .80, .98, 1), (.58, .91, 1., 1), (.15, .45, .73, 1)]
image = bpy.data.images.new('BatWingPalette', width=64, height=64, alpha=True)
pixels = np.ones((64, 64, 4), dtype=np.float32)
for index, color in enumerate(colors):
    pixels[:, index*7:min(64, index*7+7)] = color
image.pixels = pixels.ravel()
image.pack()
material = bpy.data.materials.new('BatWingSharedPalette')
material.use_nodes = True
texture = material.node_tree.nodes.new('ShaderNodeTexImage')
texture.image = image
texture.interpolation = 'Closest'
shader = material.node_tree.nodes.get('Principled BSDF')
shader.inputs['Roughness'].default_value = .75
material.node_tree.links.new(texture.outputs['Color'], shader.inputs['Base Color'])
verts, faces, groups, palette = [], [], [], []
discarded_zero_area = 0


def panel_weights(x, side):
    # A shared hinge line is continuous. Its small thickness receives a smooth
    # 2cm blend rather than tearing front/back surfaces apart on sharp folds.
    x = abs(x)
    if x < knots[1] - .01:
        return {f'WingPanel0{side}': 1.}
    if x < knots[1] + .01:
        t = smooth(knots[1]-.01, knots[1]+.01, x)
        return {f'WingPanel0{side}': 1-t, f'WingPanel1{side}': t}
    if x < knots[2] - .01:
        return {f'WingPanel1{side}': 1.}
    if x < knots[2] + .01:
        t = smooth(knots[2]-.01, knots[2]+.01, x)
        return {f'WingPanel1{side}': 1-t, f'WingPanel2{side}': t}
    return {f'WingPanel2{side}': 1.}


def vertex(co, weights):
    index = len(verts)
    verts.append(tuple(co))
    groups.append(weights)
    return index


def face(indices, color):
    global discarded_zero_area
    p0, p1, p2 = (Vector(verts[i]) for i in indices)
    # Clipping an outline corner exactly on a hinge can produce two float32
    # points only 3e-8m apart. Remove that construction sliver before export;
    # Blender's unchanged 1e-12 reimport gate still applies to the result.
    if min((p1-p0).length, (p2-p0).length, (p2-p1).length) < 1e-6 or (p1-p0).cross(p2-p0).length * .5 < 1e-10:
        discarded_zero_area += 1
        return
    faces.append(tuple(indices))
    palette.append(color)


def clip(poly, axis, edge, positive):
    result = []
    for i, current in enumerate(poly):
        previous = poly[i-1]
        inside = (current[axis] >= edge) if positive else (current[axis] <= edge)
        old_inside = (previous[axis] >= edge) if positive else (previous[axis] <= edge)
        if inside != old_inside:
            t = (edge - previous[axis]) / (current[axis] - previous[axis])
            result.append(previous.lerp(current, t))
        if inside:
            result.append(current)
    clean = []
    for point in result:
        if not clean or (point-clean[-1]).length > 1e-6:
            clean.append(point)
    if len(clean)>1 and (clean[0]-clean[-1]).length < 1e-6:
        clean.pop()
    return clean


# Hand-authored outline follows the reviewed 1.526m front silhouette. The
# scallops and three crystal landmarks are preserved; no imaginary hind wing.
outline = [(.245, .53), (.30, .67), (.365, .755), (.435, .79),
           (.53, .745), (.625, .66), (.71, .56), (.745, .475),
           (.665, .47), (.59, .385), (.535, .355), (.495, .27),
           (.455, .355), (.385, .385), (.325, .295), (.275, .37), (.245, .39)]
for side, sign in [('Left', 1), ('Right', -1)]:
    # Slices are bounded by explicit hinges; no triangle can bridge several
    # oppositely rotating panels. Row subdivisions keep the ribs aligned.
    for strip, (low, high) in enumerate(zip([.245, .34, .42, .43, .44, .51, .58, .59, .60, .68],
                                            [.34, .42, .43, .44, .51, .58, .59, .60, .68, .763])):
        poly = [Vector(v) for v in outline]
        poly = clip(clip(poly, 0, low, True), 0, high, False)
        if len(poly) < 3:
            continue
        for row in range(4):
            segment = clip(clip(poly, 1, .2+row*.16, True), 1, .36+row*.16, False)
            if len(segment) < 3:
                continue
            front, back = [], []
            for x, z in segment:
                weight = panel_weights(x, side)
                front.append(vertex((sign*x, -.005, z), weight))
                back.append(vertex((sign*x, .005, z), weight))
            for j in range(1, len(segment)-1):
                triangle = [front[0], front[j], front[j+1]]
                reverse = [back[0], back[j+1], back[j]]
                face(triangle if sign > 0 else triangle[::-1], (strip+row) % 3)
                face(reverse if sign > 0 else reverse[::-1], (strip+row+1) % 3)
            # Thin closed borders are regular geometry, not transparency.
            for j in range(len(segment)):
                k = (j+1) % len(segment)
                face((front[j], back[j], back[k]), 3)
                face((front[j], back[k], front[k]), 3)

    def tube(path, radius):
        rings = []
        for i, (x, z) in enumerate(path):
            tangent = Vector((path[min(i+1,len(path)-1)][0]-path[max(0,i-1)][0],
                              0, path[min(i+1,len(path)-1)][1]-path[max(0,i-1)][1])).normalized()
            lateral = Vector((-tangent.z, 0, tangent.x))
            ring = []
            for j in range(6):
                angle = j * math.tau / 6
                point = Vector((x, 0, z)) + radius * (math.cos(angle)*lateral + Vector((0, math.sin(angle), 0)))
                ring.append(vertex((sign*point.x, point.y, point.z), panel_weights(point.x, side)))
            rings.append(ring)
        for first, second in zip(rings, rings[1:]):
            for j in range(6):
                k = (j+1)%6
                face((first[j], second[j], second[k]), 4)
                face((first[j], second[k], first[k]), 4)
        for ring in [rings[0], rings[-1]]:
            for j in range(1,5):
                face((ring[0],ring[j],ring[j+1]),4)

    # Curved leading edge plus two long fingers split at every fold hinge.
    tube([(.235,.515),(.30,.67),(.365,.755),(.42,.785),(.43,.79),(.44,.788),
          (.51,.755),(.58,.70),(.59,.692),(.60,.685),(.68,.60),(.745,.49)], .018)
    tube([(.425,.775),(.43,.765),(.44,.74),(.49,.58),(.51,.40),(.495,.28)], .010)
    tube([(.425,.775),(.42,.74),(.39,.59),(.35,.43),(.325,.30)], .009)

    def crystal(center, length, width, tilt):
        cx, cy, cz = center
        # Fixed crystal is rigid on a single anatomical panel, not split at a
        # hinge. Its attachment overlaps the 18mm leading or 10mm finger rib.
        owner = 0 if cx < knots[1] else 1 if cx < knots[2] else 2
        weight = {f'WingPanel{owner}{side}': 1.}
        axis = Vector((math.sin(tilt), 0, math.cos(tilt)))
        right = Vector((axis.z, 0, -axis.x))
        origin = Vector(center)
        ring = []
        for j in range(5):
            t = j * math.tau / 5
            point = origin + width * (math.cos(t)*right + Vector((0, math.sin(t), 0)))
            ring.append(vertex((sign*point.x, point.y, point.z), weight))
        top = origin + axis*length*.72
        bottom = origin - axis*length*.28
        top_id = vertex((sign*top.x,top.y,top.z),weight)
        bottom_id = vertex((sign*bottom.x,bottom.y,bottom.z),weight)
        for j in range(5):
            k = (j+1)%5
            face((top_id,ring[j],ring[k]),5+j%3)
            face((bottom_id,ring[k],ring[j]),8-j%3)

    crystal((.412,-.008,.795), .13, .04, .85)
    crystal((.725,-.012,.50), .18, .057, -.3)
    crystal((.493,-.012,.315), .16, .043, -.30)

wing_mesh = bpy.data.meshes.new('BatManualWingMesh')
wing_mesh.from_pydata(verts, [], faces)
wing_mesh.update()
wing = bpy.data.objects.new('BatManualWings', wing_mesh)
scene.collection.objects.link(wing)
wing_mesh.materials.append(material)
uv = wing_mesh.uv_layers.new(name='UVMap')
for polygon, color in zip(wing_mesh.polygons, palette):
    for loop in polygon.loop_indices:
        uv.data[loop].uv = ((color*7+3.5)/64, .5)
for bone in rig.data.bones:
    wing.vertex_groups.new(name=bone.name)
for i, weights in enumerate(groups):
    for name, value in weights.items():
        if value > 1e-8:
            wing.vertex_groups[name].add([i], value, 'REPLACE')
wing.parent = rig
wing.modifiers.new('BatWingSkin','ARMATURE').object = rig

old_fold = bpy.data.actions['fold_wings']
bpy.data.actions.remove(old_fold)
fold = bpy.data.actions.new('fold_wings')
fold.use_fake_user = True
rig.animation_data.action = fold
scene.render.fps = 24


def reset():
    for bone in rig.pose.bones:
        bone.rotation_mode = 'QUATERNION'
        bone.rotation_quaternion = (1,0,0,0)
        bone.location = (0,0,0)
        bone.scale = (1,1,1)


def rotate(name, angles):
    basis = rig.data.bones[name].matrix_local.to_quaternion()
    rig.pose.bones[name].rotation_quaternion = basis.inverted() @ Euler(angles,'XYZ').to_quaternion() @ basis


for frame in range(61):
    scene.frame_set(frame)
    reset()
    t = frame/60
    amount = smooth(0,.4,t)*(1-smooth(.6,1,t))
    for side, sign in [('Left',1),('Right',-1)]:
        for i, angle in enumerate([math.radians(82), math.radians(-164), math.radians(164)]):
            rotate(f'WingPanel{i}{side}',(0,0,sign*angle*amount))
    # Use the preserved body floor only: folded wing never goes below feet.
    bpy.context.view_layer.update()
    evaluated = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    evaluated_mesh = evaluated.to_mesh()
    floor = min(v.co.z for v in evaluated_mesh.vertices)
    evaluated.to_mesh_clear()
    rig.pose.bones['Root'].location = rig.data.bones['Root'].matrix_local.to_3x3().inverted() @ Vector((0,0,.147-floor))
    for bone in rig.pose.bones:
        bone.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=bone.name)
        bone.keyframe_insert(data_path='scale',frame=frame,group=bone.name)
    rig.pose.bones['Root'].keyframe_insert(data_path='location',frame=frame,group='Root')
rig.animation_data.action = None
reset()
scene.frame_set(0)
bpy.context.view_layer.update()
a.output.mkdir(parents=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in [body,wing,rig]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.file.pack_all()
native = a.output/'bat_manual_wings.blend'
glb = a.output/'bat_manual_wings.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(native.resolve()))
bpy.ops.export_scene.gltf(filepath=str(glb.resolve()),export_format='GLB',use_selection=True,
                         export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False)
wing_mesh.calc_loop_triangles()
report = {'source':str(a.input),'source_sha256':source_sha,
          'removed_generated_wing_faces':removed,'retained_source_faces':len(mesh.polygons),
          'retained_positions_uv_exact':True,'retained_corner_normals_restored':True,
          'anatomy_wing_influence_removed_vertices':rebound,
          'new_wing_triangles':len(wing_mesh.loop_triangles),
          'discarded_zero_area_construction_triangles':discarded_zero_area,
          'total_triangles':len(mesh.polygons)+len(wing_mesh.loop_triangles),
          'bones':len(rig.data.bones),'joint_fold_degrees':[82,-164,164],
          'wing_scale_animated':False,'clips_preserved':['idle','walk','attack','hit','death'],
          'full_fold_gate':'HUMAN_REVIEW','formal_integration':'NOT_STARTED',
          'limitations':['Local wing/crystal geometry is manually rebuilt, not exact source geometry',
                         'Visual and motion acceptance must inspect all poses before selection']}
(a.output/'repair_report.json').write_text(json.dumps(report,indent=2),encoding='utf8',newline='\n')
print('BAT_MANUAL_WINGS', report['total_triangles'], 'triangles',len(rig.data.bones),'bones',flush=True)

if a.render:
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 16
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'Standard'
    scene.world = bpy.data.worlds.new('BatManualReviewWorld')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value = (.12,.16,.2,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value = .6
    camera_data = bpy.data.cameras.new('BatManualReviewCamera')
    camera = bpy.data.objects.new(camera_data.name,camera_data)
    scene.collection.objects.link(camera)
    camera_data.type, camera_data.ortho_scale = 'ORTHO', 1.85
    scene.camera = camera
    for i,(pos,energy) in enumerate([((2,-4,4),450),((-3,-1,2),250),((0,3,3),350)]):
        data = bpy.data.lights.new('BatManualReviewLight'+str(i),'AREA')
        data.energy,data.shape,data.size = energy,'DISK',3
        light = bpy.data.objects.new(data.name,data)
        scene.collection.objects.link(light)
        light.location = pos
        light.rotation_euler = (Vector((0,0,.6))-light.location).to_track_quat('-Z','Y').to_euler()
    rig.animation_data.action = fold
    if fold.slots: rig.animation_data.action_slot = fold.slots[0]
    for frame in [0,12,30]:
        scene.frame_set(frame)
        for view,pos in [('front',(0,-4,.65)),('right',(4,0,.65)),('back',(0,4,.65)),('left',(-4,0,.65))]:
            camera.location = pos
            camera.rotation_euler = (Vector((0,0,.65))-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.render.filepath = str((a.output/f'fold_{frame}_{view}.png').resolve())
            bpy.ops.render.render(write_still=True)
