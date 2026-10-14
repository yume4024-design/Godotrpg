"""G03 licensed building adaptation. Run in Blender or through MCP.

Only replaces the owned Crystal_G03_Buildings scene; source meshes are retained
on disk. No network, credentials, user-scene changes or external dependencies.
"""
import bpy
import bmesh
import math
import json
from mathutils import Vector

ROOT = 'D:/RPGGAME/'
SCENE = 'Crystal_G03_Buildings'
scene = bpy.data.scenes.get(SCENE)
if scene is None:
    scene = bpy.data.scenes.new(SCENE)
    scene['crystal_owned'] = True
assert scene.get('crystal_owned'), 'Refuse to alter an unowned scene'
bpy.context.window.scene = scene
for obj in list(scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

def linear(v):
    return v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4

def material(name, color):
    name = 'CrystalG03_' + name
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    rgba = tuple(linear(v) for v in color) + (1,)
    m.diffuse_color = rgba
    shader = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    shader.inputs['Base Color'].default_value = rgba
    shader.inputs['Roughness'].default_value = .88
    m.use_backface_culling = True
    return m

palette = {
    'Plaster': material('Plaster',(.86,.80,.65)),
    'Wood': material('Timber',(.34,.23,.14)),
    'Wood_Light': material('Oak',(.52,.36,.20)),
    'Stone_Dark': material('StoneDark',(.39,.42,.41)),
    'Stone_Light': material('Stone',(.57,.59,.54)),
    'Windows': material('WarmGlass',(.86,.66,.32)),
}
roofs = {
    'rust': material('RoofRust',(.65,.29,.16)),
    'slate': material('RoofSlate',(.35,.42,.47)),
    'clay': material('RoofClay',(.73,.38,.19)),
}

def box(name, location, size, mat):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    o=bpy.context.object
    o.name=name
    o.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    return o

def beam(name, a, b, thickness, mat):
    a,b=Vector(a),Vector(b)
    o=box(name,(a+b)/2,(thickness,thickness,(b-a).length),mat)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def solid(name, verts, faces, mat):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts,[],faces)
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh)
    scene.collection.objects.link(obj)
    mesh.materials.append(mat)
    return obj

def gable(parts, center, w, d, eave, peak, roofmat):
    """Front-facing triangular gable and thick roof slopes, no textures."""
    x,y=center
    verts=[(x+s*w/2,y+t*d/2,eave) for t in [-1,1] for s in [-1,1]]
    verts += [(x,y-d/2,peak),(x,y+d/2,peak)]
    parts.append(solid('GablePlaster',verts,[(0,1,4),(2,5,3),(0,4,5,2),(1,3,5,4),(0,2,3,1)],palette['Plaster']))
    for side in [-1,1]:
        verts=[(x,y-d/2-.22,peak+.12),(x+side*(w/2+.28),y-d/2-.22,eave),
               (x+side*(w/2+.28),y+d/2+.22,eave),(x,y+d/2+.22,peak+.12)]
        verts += [(a,b,c-.16) for a,b,c in verts]
        parts.append(solid('RoofSlope',verts,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],roofmat))
        for yy in [y-d/2-.23,y+d/2+.23]:
            parts.append(beam('Bargeboard',(x,yy,peak+.16),(x+side*(w/2+.3),yy,eave),.16,palette['Wood']))
        for ratio in [.25,.5,.75]:
            xx=x+side*(w/2+.28)*ratio
            zz=(peak+.12)*(1-ratio)+eave*ratio+.035
            parts.append(beam('RoofSeam',(xx,y-d/2-.21,zz),(xx,y+d/2+.21,zz),.035,roofmat))
    parts.append(beam('Ridge',(x,y-d/2-.3,peak+.16),(x,y+d/2+.3,peak+.16),.18,palette['Wood']))
    parts.append(beam('GableTie',(x-w/2,y-d/2-.025,eave),(x+w/2,y-d/2-.025,eave),.16,palette['Wood']))
    parts.append(beam('GableKingPost',(x,y-d/2-.03,eave),(x,y-d/2-.03,peak),.14,palette['Wood']))

def window(parts,x,y,z,w=.85,h=1.1):
    parts.append(box('WindowFrame',(x,y,z),(w+.18,.16,h+.18),palette['Wood']))
    parts.append(box('WindowGlass',(x,y-.10,z),(w,.045,h),palette['Windows']))
    parts.append(box('WindowMullion',(x,y-.14,z),(.08,.06,h),palette['Wood']))
    parts.append(box('WindowTransom',(x,y-.14,z),(w,.06,.08),palette['Wood']))

def entrance(parts,x,y):
    # Closed facade, with a 1.8 m clear panel reserved for the future G06 trigger.
    parts.append(box('DoorPanel',(x,y,1.2),(1.8,.18,2.4),palette['Wood_Light']))
    for dx in [-.99,.99]:
        parts.append(box('DoorPost',(x+dx,y-.02,1.3),(.18,.25,2.6),palette['Wood']))
    parts.append(box('DoorLintel',(x,y-.02,2.57),(2.16,.25,.18),palette['Wood']))
    for dx in [-.45,0,.45]:
        parts.append(box('DoorSeam',(x+dx,y-.10,1.2),(.025,.025,2.3),palette['Wood']))
    parts.append(box('DoorHandle',(x+.6,y-.14,1.13),(.12,.08,.15),palette['Windows']))

specs = [
    ('inn','fantasy_inn',(12,9,9),'rust','bed'),
    ('guild_hall','fantasy_inn',(15,11,11),'slate','guild'),
    ('item_shop','fantasy_inn',(8,7,7),'slate','bottle'),
    ('weapon_shop','fantasy_inn',(8,7,7),'clay','sword'),
    ('house_a','fantasy_inn',(7,6,6),'clay',''),
    ('house_b','house',(7,8,6),'slate',''),
    ('farm_house','fantasy_inn',(7,6,6),'rust',''),
]
metrics=[]
for index,(ident,source,(width,height,depth),roof,sign) in enumerate(specs):
    before=set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=ROOT+'source_assets/greystone_g03/vendor/quaternius_'+source+'.glb')
    imported=[o for o in scene.objects if o not in before]
    meshes=[o for o in imported if o.type=='MESH']
    assert len(meshes)==1
    original=meshes[0]
    coords=[original.matrix_world@v.co for v in original.data.vertices]
    low=Vector([min(v[i] for v in coords) for i in range(3)])
    high=Vector([max(v[i] for v in coords) for i in range(3)])
    center=(low+high)/2
    scale=Vector((width/(high.x-low.x),depth/(high.y-low.y),height/(high.z-low.z)))
    vertices=[((v.x-center.x)*scale.x,(v.y-center.y)*scale.y,(v.z-low.z)*scale.z) for v in coords]
    mesh=bpy.data.meshes.new(ident+'_mesh')
    mesh.from_pydata(vertices,[],[list(p.vertices) for p in original.data.polygons])
    for slot in original.material_slots:
        key=slot.material.name.split('.')[0]
        key={'Wood_Side':'Wood','Stone':'Stone_Light'}.get(key,key)
        mesh.materials.append(roofs[roof] if key.startswith('RoofTiles') else palette[key])
    for p,src in zip(mesh.polygons,original.data.polygons):
        p.material_index=src.material_index
        p.use_smooth=False
    body=bpy.data.objects.new(ident,mesh)
    scene.collection.objects.link(body)
    for o in imported:
        bpy.data.objects.remove(o,do_unlink=True)
    parts=[body]
    door_x=0.0
    door_y=-depth*.32-.10
    if ident in ['house_a','farm_house','item_shop','weapon_shop']:
        # Retain the licensed lower facade, stonework and timber. Remove its tall
        # tavern roof/dormers, then build an individually proportioned single-storey roof.
        bm=bmesh.new();bm.from_mesh(mesh)
        roof_indices=[i for i,m in enumerate(mesh.materials) if m==roofs[roof]]
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index in roof_indices],context='FACES')
        bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.0001,
                              plane_co=(0,0,height*.44),plane_no=(0,0,1),clear_outer=True)
        # Remove the old tavern porch and the severed ends of its broad roof beams.
        # New shallow porches below provide complete geometry and matching colliders.
        for side in [-1,1]:
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.0001,
                                  plane_co=(0,side*depth*.35,0),plane_no=(0,side,0),clear_outer=True)
            bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.0001,
                                  plane_co=(side*width*.40,0,0),plane_no=(side,0,0),clear_outer=True)
        fragments=[f for f in bm.faces if all(v.co.z>height*.36 for v in f.verts)
                   and any(abs(v.co.x)>width*.40 for v in f.verts)]
        bmesh.ops.delete(bm,geom=fragments,context='FACES')
        bm.to_mesh(mesh);bm.free()
        wall_h=height*.53
        core_w=width*.76;core_d=depth*.62
        parts.append(box('UpperWallBand',(0,0,(height*.43+wall_h)/2),(core_w,core_d,wall_h-height*.43),palette['Plaster']))
        gable(parts,(0,0),core_w,core_d,wall_h,height*.83,roofs[roof])
        chimney_h=height*.34
        parts.append(box('Chimney',(width*.22,depth*.16,height-chimney_h/2),(.58,.65,chimney_h),palette['Stone_Light']))
        parts.append(box('ChimneyCap',(width*.22,depth*.16,height-.10),(.76,.81,.20),palette['Stone_Dark']))
        for xx in [-width*.25,width*.25]: window(parts,xx,door_y+.025,1.5,w=.7)
        if ident=='item_shop':
            # Compact blue-roof storefront, with an open counter beside the door.
            parts.append(box('Counter',(width*.28,-depth*.40,.8),(1.65,.6,.85),palette['Wood_Light']))
            for dx in [-.5,0,.5]:
                parts.append(box('DisplayJar',(width*.28+dx,-depth*.40,1.38),(.26,.3,.3),palette['Windows']))
        if ident=='weapon_shop':
            parts.append(box('ForgeHood',(width*.31,-depth*.23,1.6),(1.2,.9,2.6),palette['Stone_Dark']))
            parts.append(box('ForgeMouth',(width*.31,-depth*.70/2,1.25),(.85,.08,.7),palette['Wood']))
            parts.append(box('AnvilBase',(width*.29,-depth*.40,.45),(.65,.65,.9),palette['Wood']))
            parts.append(box('AnvilTop',(width*.29,-depth*.40,.95),(1.1,.45,.22),palette['Stone_Dark']))
        # Shallow porch with a clear central approach instead of an oversized tavern awning.
        porch_z=2.9 if ident!='farm_house' else 2.75
        parts.append(box('PorchRoof',(0,-depth*.405,porch_z),(core_w+.2,depth*.19,.16),roofs[roof]))
        for xx in [-core_w/2,core_w/2]:
            parts.append(box('PorchPost',(xx,-depth*.48,porch_z/2),(.18,.18,porch_z),palette['Wood']))
        if ident=='farm_house':
            for xx in [-width*.25,width*.25]:
                parts.append(box('Shutter',(xx,-depth*.34,1.5),(.68,.12,.9),palette['Wood_Light']))
    elif ident=='inn':
        # Asymmetric main hall + lower side wing, matching the reference inn's massing.
        for v in mesh.vertices:
            v.co.x=v.co.x*.70-width*.12
            if v.co.z>height*.44: v.co.z=height*.44+(v.co.z-height*.44)*.82
        door_x=-width*.12
        wx=width*.29;ww=width*.34;wd=depth*.64;wh=height*.46
        parts.append(box('InnWing',(wx,0,wh/2),(ww,wd,wh),palette['Plaster']))
        gable(parts,(wx,0),ww,wd,wh,height*.72,roofs[roof])
        for xx in [wx-ww*.32,wx+ww*.32]: window(parts,xx,-wd/2-.04,2.1,w=.7,h=1.25)
        for xx in [wx-ww/2,wx+ww/2]:
            parts.append(box('WingFrontPost',(xx,-wd/2-.04,wh/2),(.17,.18,wh),palette['Wood']))
        for zz in [.25,wh]:
            parts.append(box('WingFrontTie',(wx,-wd/2-.04,zz),(ww,.18,.16),palette['Wood']))
            parts.append(box('WingSideTie',(wx+ww/2+.03,0,zz),(.17,wd,.16),palette['Wood']))
        for yy in [-wd/2,0,wd/2]:
            parts.append(box('WingSidePost',(wx+ww/2+.03,yy,wh/2),(.17,.16,wh),palette['Wood']))
        parts.append(box('InnChimney',(-width*.25,depth*.14,height*.79),(.7,.75,height*.42),palette['Stone_Light']))
    elif ident=='guild_hall':
        # A projecting gabled entrance and heraldic board distinguish the public hall.
        gable(parts,(0,-depth*.23),4.3,depth*.40,height*.43,height*.65,roofs[roof])
        door_y=-depth*.43-.10
        for xx in [-2.0,2.0]:parts.append(box('GuildPillar',(xx,door_y,2.25),(.35,.4,4.5),palette['Stone_Light']))
        parts.append(box('GuildCrest',(0,door_y-.08,height*.48),(1.4,.15,1.2),roofs['slate']))
    elif ident=='house_b':
        door_y=-depth*.44-.10
    entrance(parts,door_x,door_y)
    # Chunky signboard and a readable relief pictogram face Godot +Z (Blender -Y).
    # Kept inside the building footprint; the road and interaction marker stay free.
    if sign:
        sx=width*.29
        sy=-depth*.47
        sz=height*.30
        parts.append(box(ident+'_sign',(sx,sy,sz),(1.45,.16,1.05),palette['Wood']))
        gold=palette['Windows']
        if sign=='bed':
            for pos,size in [((sx,sy-.10,sz-.1),(1,.08,.18)),((sx-.46,sy-.1,sz),(.12,.08,.52)),((sx+.44,sy-.1,sz-.13),(.12,.08,.3)),((sx-.25,sy-.11,sz+.08),(.27,.08,.2))]:
                parts.append(box('BedIcon',pos,size,gold))
        elif sign=='bottle':
            parts.append(box('BottleBody',(sx,sy-.11,sz-.08),(.45,.09,.5),gold))
            parts.append(box('BottleNeck',(sx,sy-.11,sz+.23),(.2,.09,.22),gold))
        else:
            for angle in ([0] if sign=='sword' else [-.55,.55]):
                blade=box('SwordBlade',(sx,sy-.11,sz+.06),(.13,.09,.7),gold)
                blade.rotation_euler.y=angle
                parts.append(blade)
            parts.append(box('SwordGuard',(sx,sy-.12,sz-.22),(.55,.09,.12),gold))
    # Ground-centered root, applied geometry dimensions, native glTF axis conversion.
    obstacles=[]
    bpy.context.view_layer.update()
    for o in parts:
        if o.name.startswith(('PorchPost','GuildPillar','Counter','ForgeHood','AnvilBase','AnvilTop','InnWing')):
            points=[o.matrix_world@v.co for v in o.data.vertices]
            a=Vector([min(v[i] for v in points) for i in range(3)])
            b=Vector([max(v[i] for v in points) for i in range(3)])
            obstacles.append((o.name,a,b))
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=body
    if len(parts)>1:
        bpy.ops.object.join()
    body.name=ident
    # Fit the final assembly (including new wings) to its specified footprint.
    # Propagate the exact transformation to entrance/collision metadata.
    lo=Vector([min(v.co[i] for v in body.data.vertices) for i in range(3)])
    hi=Vector([max(v.co[i] for v in body.data.vertices) for i in range(3)])
    middle=(lo+hi)/2
    fit=Vector((width/(hi.x-lo.x),depth/(hi.y-lo.y),height/(hi.z-lo.z)))
    for v in body.data.vertices:
        v.co=((v.co.x-middle.x)*fit.x,(v.co.y-middle.y)*fit.y,(v.co.z-lo.z)*fit.z)
    body['door_width_m']=1.8*fit.x
    body['door_center_x_m']=(door_x-middle.x)*fit.x
    body['door_front_z_m']=-(door_y-.09-middle.y)*fit.y
    body['door_height_m']=2.4*fit.z
    body['wall_back_z_m']=-((depth*(.40 if ident=='house_b' else .31))-middle.y)*fit.y
    body['wall_width_m']=width*(.525 if ident=='inn' else .76)*fit.x
    boxes=[]
    for name,a,b in obstacles:
        c=(a+b)/2
        boxes.append({'name':name,'position':[(c.x-middle.x)*fit.x,(c.z-lo.z)*fit.z,-(c.y-middle.y)*fit.y],
                      'size':[(b.x-a.x)*fit.x,(b.z-a.z)*fit.z,(b.y-a.y)*fit.y]})
    body['obstacle_boxes_json']=json.dumps(boxes)
    body['source_author']='Quaternius'
    body['source_license']='CC0 1.0'
    body.data.calc_loop_triangles()
    triangles=len(body.data.loop_triangles)
    metrics.append({'id':ident,'source':source,'triangles':triangles,'dimensions_xyz_godot':[width,height,depth],'materials':len(body.data.materials),'textures':0})
    bpy.ops.export_scene.gltf(filepath=ROOT+'assets/models/greystone/buildings/'+ident+'.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_extras=True,export_animations=False,export_cameras=False,export_lights=False)
    body.location=(index%4*19,index//4*17,0)
    body['source_author']='Quaternius'
    body['source_license']='CC0 1.0'
scene['crystal_g03_metrics']=json.dumps(metrics)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'source_assets/greystone_g03/greystone_buildings.blend',copy=True)
print('G03_METRICS '+json.dumps(metrics))
