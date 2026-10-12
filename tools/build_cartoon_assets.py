"""Original Project Crystal models. Run in an isolated Blender background process.

Blender Z-up, characters face -Y; glTF converts this to Godot +Z.
No external models, textures, fonts, generators or paid services are used.
"""
import bpy
import bmesh
import json
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/cartoon'
SOURCE = ROOT / 'source_assets/cartoon_v1'
EVIDENCE = ROOT / 'artifacts/cartoon'
for folder in (OUT, SOURCE, EVIDENCE):
    folder.mkdir(parents=True, exist_ok=True)

PALETTE = {
    'skin': ('F2BE94', .72, 0), 'blush': ('D97C72', .8, 0),
    'hair': ('352E39', .7, 0), 'hair_light': ('564151', .65, 0),
    'orange': ('C65C30', .72, 0), 'orange_light': ('E99851', .7, 0),
    'gold': ('F5C765', .48, .12), 'cream': ('F2E4C5', .8, 0),
    'dark': ('263D4A', .7, 0), 'leather': ('754831', .78, 0),
    'leather_light': ('AA7046', .74, 0), 'teal': ('39878E', .7, 0),
    'teal_light': ('77B6B6', .7, 0), 'blue': ('395F83', .68, 0),
    'silver': ('AFBCC6', .36, .55), 'white': ('FFF6DF', .35, 0),
    'eye': ('20252C', .32, 0), 'iris': ('805C35', .4, 0),
    'mint': ('73CDAB', .3, 0), 'mint_light': ('A9E5BE', .35, 0),
    'leaf': ('348B68', .6, 0), 'stone': ('525B76', .78, .12),
    'stone_light': ('79869A', .7, .12), 'joint': ('30374F', .8, 0),
    'crystal': ('C17EEB', .22, .22), 'glow': ('DCC0FF', .28, .05),
    'gray_hair': ('A6A5A1', .8, 0),
}
materials = {}
current_parent = None

def linear(v):
    return v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4

def material(key):
    if key not in materials:
        hx, rough, metal = PALETTE[key]
        rgb = [linear(int(hx[i:i+2], 16) / 255) for i in (0, 2, 4)]
        mat = bpy.data.materials.new(key)
        mat.diffuse_color = (*rgb, 1)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        bsdf.inputs['Base Color'].default_value = (*rgb, 1)
        bsdf.inputs['Roughness'].default_value = rough
        bsdf.inputs['Metallic'].default_value = metal
        if key == 'glow':
            bsdf.inputs['Emission Color'].default_value = (*rgb, 1)
            bsdf.inputs['Emission Strength'].default_value = .3
        materials[key] = mat
    return materials[key]

def parent(obj):
    if current_parent:
        world = obj.matrix_world.copy()
        obj.parent = current_parent
        obj.matrix_world = world
    return obj

def empty(name, location=(0,0,0)):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    bpy.context.view_layer.update()
    return parent(obj)

def finish(obj, name, color, smooth=True):
    obj.name = name
    obj.data.materials.append(material(color))
    for face in obj.data.polygons:
        face.use_smooth = smooth
    if not obj.data.uv_layers:
        uv = obj.data.uv_layers.new(name='UVMap')
        for loop in obj.data.loops:
            co = obj.data.vertices[loop.vertex_index].co
            uv.data[loop.index].uv = (co.x * .4 + .5, co.z * .4 + .5)
    bpy.context.view_layer.update()
    return parent(obj)

def orb(name, loc, scale, color, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, color)

def rounded(name, loc, size, color, bevel=.06):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mod = obj.modifiers.new('Rounded_edges', 'BEVEL')
    mod.width = bevel
    mod.segments = 2
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, color)

def mesh(name, vertices, faces, color, smooth=True):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, color, smooth)

def loft(name, rows, color, segments=16):
    # Closed rounded garment with elliptical cross-sections.
    vertices=[]
    for x,y,z,rx,ry in rows:
        for i in range(segments):
            angle=2*math.pi*i/segments
            vertices.append((x+rx*math.cos(angle), y+ry*math.sin(angle), z))
    faces=[tuple(reversed(range(segments)))]
    for row in range(len(rows)-1):
        for i in range(segments):
            j=(i+1)%segments
            a=row*segments
            b=a+segments
            faces.append((a+i,a+j,b+j,b+i))
    faces.append(tuple((len(rows)-1)*segments+i for i in range(segments)))
    return mesh(name,vertices,faces,color)

def rod(name, a, b, radius, color, vertices=10):
    direction=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius*.82,
                                  depth=direction.length, location=(Vector(a)+Vector(b))*.5)
    obj=bpy.context.object
    obj.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
    return finish(obj,name,color)

def face(hair='hair', beard=False):
    orb('Head_shape',(0,0,1.58),(.32,.265,.34),'skin',20,12)
    for side in (-1,1):
        orb('Ear',(.305*side,.005,1.57),(.064,.059,.09),'skin',10,6)
        orb('Ear_inner',(.33*side,-.028,1.57),(.025,.018,.048),'blush',8,5)
        orb('Eye_white',(.115*side,-.240,1.6),(.079,.027,.091),'white',12,7)
        orb('Eye_iris',(.113*side,-.264,1.599),(.046,.018,.069),'iris',12,7)
        orb('Eye_pupil',(.112*side,-.279,1.598),(.024,.009,.049),'eye',10,6)
        orb('Eye_spark',(.1*side-.012,-.288,1.631),(.015,.007,.019),'white',8,5)
        orb('Cheek',(.211*side,-.210,1.51),(.046,.012,.024),'blush',10,5)
        brow=orb('Eyebrow',(.115*side,-.232,1.717),(.073,.025,.022),hair,10,5)
        brow.rotation_euler.y=side*.1
    orb('Nose',(0,-.268,1.531),(.043,.045,.04),'skin',10,6)
    orb('Smile',(0,-.250,1.44),(.05,.012,.014),'leather',10,5)
    orb('Hair_cap',(0,.026,1.756),(.337,.279,.223),hair,20,10)
    for i in range(5):
        x=(i-2)*.102
        lock=orb('Fringe',(x,-.20,1.77-abs(i-2)*.018),(.092,.083,.155),hair,10,7)
        lock.rotation_euler.y=(i-2)*-.16
    for side in (-1,1):
        orb('Side_lock',(.292*side,.006,1.65),(.058,.14,.152),hair,10,7)
    if beard:
        for side in (-1,1):
            obj=orb('Moustache',(.061*side,-.265,1.478),(.071,.037,.035),hair,10,6)
            obj.rotation_euler.y=side*.2
        orb('Beard',(0,-.17,1.35),(.177,.133,.13),hair,12,7)

def person(name):
    global current_parent
    root=empty(name)
    current_parent=root
    is_lia=name=='lia'
    elder=name=='guildmaster'
    coat='teal' if is_lia else ('leather' if elder else 'orange')
    trim='cream' if is_lia else 'gold'
    # Short broad silhouette, large expressive head, full feet and hands.
    torso=empty('Torso',(0,0,.82))
    current_parent=torso
    loft('Tailored_coat',[(0,0,.68,.28,.195),(0,0,.74,.30,.21),(0,0,.91,.245,.17),
                         (0,0,1.14,.285,.18),(0,0,1.22,.21,.15)],coat)
    loft('Coat_hem',[(0,0,.67,.28,.196),(0,0,.73,.302,.212)],trim)
    rounded('Vest_front',(0,-.182,.995),(.255,.048,.38),'cream',.035)
    for x in (-.092,.092):
        rod('Coat_piping',(x,-.222,.8),(x,-.198,1.13),.012,trim,8)
    loft('Waist_belt',[(0,0,.78,.278,.213),(0,0,.854,.258,.192)],'leather',16)
    rounded('Buckle',(0,-.216,.816),(.113,.04,.087),'gold',.018)
    rounded('Buckle_inset',(0,-.241,.816),(.060,.015,.04),'leather',.008)
    for z in (.946,1.028,1.107):
        orb('Vest_button',(0,-.211,z),(.023,.014,.023),'gold',8,5)
    for x in (-.3,.3):
        rounded('Belt_pouch',(x,-.02,.75),(.14,.16,.17),'leather_light',.04)
        rounded('Pouch_flap',(x,-.107,.79),(.15,.029,.085),'leather',.02)
        orb('Pouch_clasp',(x,-.13,.77),(.018,.009,.018),'gold',8,5)
    orb('Neck',(0,0,1.26),(.10,.095,.13),'skin',12,6)
    loft('Collar',[(0,0,1.19,.155,.13),(0,0,1.28,.17,.14),(0,0,1.31,.15,.12)],trim,16)
    if not is_lia:
        scarf=rounded('Scarf_tail',(.155,.206,1.01),(.14,.048,.36),'gold',.045)
        scarf.rotation_euler.y=-.2
        rounded('Travel_pack',(0,.23,1.0),(.34,.18,.38),'leather',.07)
        rounded('Pack_flap',(0,.332,1.095),(.35,.045,.16),'leather_light',.036)
        for x in (-.16,.16):
            rod('Pack_strap',(x,-.15,1.19),(x,-.20,.89),.022,'leather',8)
    else:
        loft('Shoulder_mantle',[(0,.025,1.09,.32,.21),(0,.01,1.20,.29,.18),(0,0,1.26,.16,.135)],'blue',16)
        orb('Star_brooch',(0,-.198,1.19),(.045,.023,.05),'gold',10,6)
        rounded('Spellbook',(.33,-.1,.8),(.13,.21,.27),'blue',.02)
        rounded('Book_pages',(.335,-.108,.8),(.135,.17,.23),'cream',.01)
        rounded('Book_cover',(.335,-.21,.8),(.145,.025,.28),'teal_light',.01)
    current_parent=root
    head=empty('Head',(0,0,1.27))
    current_parent=head
    face('gray_hair' if elder else 'hair',elder)
    if is_lia:
        for side in (-1,1):
            orb('Long_hair',(.257*side,.13,1.44),(.112,.145,.30),'hair',12,8)
            orb('Hair_ribbon',(.3*side,-.003,1.43),(.091,.04,.038),'teal_light',10,5)
        orb('Beret',(0,.055,1.917),(.375,.285,.13),'blue',20,8)
        orb('Beret_button',(.02,.065,2.04),(.055,.045,.028),'gold',10,5)
        orb('Hat_gem',(-.245,-.15,1.95),(.06,.03,.055),'teal_light',10,6)
    elif elder:
        for x in (-.115,.115):
            # Small brow scar and silver sideburns distinguish the guildmaster.
            rod('Brow_line',(x-.05,-.257,1.69),(x+.05,-.257,1.69),.014,'gray_hair',8)
    else:
        orb('Hair_cowlick',(.095,.03,1.946),(.11,.07,.087),'hair',12,6)
    current_parent=root
    for side,label in ((-1,'Left'),(1,'Right')):
        leg=empty('Leg'+label,(side*.143,0,.7))
        current_parent=leg
        orb('Trouser',(side*.143,.01,.51),(.126,.13,.24),'dark',12,8)
        loft('Boot_cuff',[(side*.143,0,.32,.142,.14),(side*.143,0,.4,.14,.137)],'leather_light',12)
        orb('Boot',(side*.143,-.065,.173),(.153,.22,.165),'leather',14,8)
        rounded('Boot_sole',(side*.143,-.072,.067),(.295,.405,.095),'dark',.04)
        rounded('Boot_buckle',(side*.143,-.225,.24),(.095,.025,.043),'gold',.012)
        current_parent=root
        arm=empty('Arm'+label,(side*.265,0,1.14))
        current_parent=arm
        sleeve=orb('Sleeve',(side*.335,0,1.065),(.14,.155,.213),coat,12,8)
        sleeve.rotation_euler.y=side*.28
        orb('Elbow',(side*.38,-.015,.915),(.10,.105,.12),coat,12,6)
        loft('Wrist_cuff',[(side*.405,-.034,.79,.105,.108),(side*.399,-.03,.88,.11,.112)],trim,12)
        orb('Hand',(side*.414,-.042,.727),(.104,.092,.12),'skin',12,7)
        orb('Thumb',(side*.337,-.102,.746),(.037,.049,.059),'skin',8,5)
        if is_lia and side==1:
            rod('Staff_shaft',(.49,-.035,.11),(.49,-.035,1.60),.031,'leather',12)
            orb('Staff_collar',(.49,-.035,1.48),(.079,.075,.051),'gold',12,6)
            orb('Staff_orb',(.49,-.035,1.70),(.10,.095,.14),'teal_light',14,9)
            for s in (-1,1):
                rod('Staff_crown',(.49+s*.066,-.03,1.52),(.49+s*.095,-.03,1.73),.024,'gold',8)
        current_parent=root
    if not is_lia and not elder:
        # Sheathed short sword behind the left hip, readable from the rear.
        current_parent=torso
        rod('Scabbard',(-.29,.18,.44),(-.39,.16,1.02),.052,'dark',10)
        rod('Sword_grip',(-.39,.16,1.02),(-.42,.155,1.19),.029,'leather',10)
        rod('Sword_guard',(-.50,.15,1.02),(-.29,.15,1.057),.024,'gold',8)
    current_parent=None
    return root

def slime():
    global current_parent
    root=empty('forest_slime')
    current_parent=root
    loft('Jelly_body',[(0,0,.06,.58,.48),(0,0,.14,.76,.60),(0,0,.38,.74,.59),
                      (0,0,.66,.58,.49),(0,0,.87,.35,.31),(0,0,.98,.10,.11)],'mint',24)
    orb('Soft_base',(0,-.035,.13),(.76,.62,.14),'mint_light',20,8)
    for side in (-1,1):
        orb('Eye',(.215*side,-.515,.53),(.085,.046,.121),'eye',14,8)
        orb('Eye_spark',(.215*side-.02,-.557,.575),(.027,.015,.034),'white',10,6)
        orb('Blush',(.39*side,-.487,.40),(.096,.021,.036),'blush',12,6)
    orb('Mouth',(0,-.573,.375),(.061,.026,.035),'eye',12,6)
    orb('Cheek_highlight',(-.39,-.39,.735),(.10,.025,.07),'mint_light',12,6)
    rod('Sprout_stem',(0,.03,.92),(.07,.04,1.18),.035,'leaf',10)
    leaf=orb('Sprout_leaf_left',(-.125,.03,1.16),(.215,.075,.06),'leaf',12,6)
    leaf.rotation_euler.y=-.32
    leaf=orb('Sprout_leaf_right',(.21,.055,1.21),(.22,.084,.06),'mint_light',12,6)
    leaf.rotation_euler.y=.32
    current_parent=None
    return root

def guardian():
    global current_parent
    root=empty('corrupted_guardian')
    current_parent=root
    # Ancient stone automaton: floating segmented armor, recessed visor, crystal crown.
    torso=empty('Torso',(0,0,1.1))
    current_parent=torso
    orb('Core_housing',(0,.025,1.30),(.55,.34,.57),'joint',16,10)
    rounded('Chest_plate',(0,-.14,1.49),(.91,.43,.56),'stone_light',.14)
    loft('Waist_armor',[(0,0,.84,.43,.31),(0,0,1.04,.48,.34),(0,0,1.23,.42,.30)],'stone',12)
    for x in (-.24,0,.24):
        rounded('Belt_plate',(x,-.3,1.03),(.215,.11,.20),'stone_light',.045)
    orb('Crystal_socket',(0,-.374,1.48),(.18,.067,.21),'joint',16,8)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(0,-.43,1.49))
    obj=bpy.context.object
    obj.scale=(.12,.085,.18)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    finish(obj,'Heart_crystal','crystal',False)
    for side in (-1,1):
        rod('Chest_rune',(side*.28,-.364,1.38),(side*.32,-.351,1.62),.015,'glow',6)
    current_parent=root
    head=empty('Head',(0,0,1.86))
    current_parent=head
    rounded('Helmet',(0,0,2.02),(.66,.55,.58),'stone',.14)
    rounded('Visor',(0,-.281,2.03),(.48,.059,.135),'joint',.035)
    for side in (-1,1):
        rounded('Eye_rune',(side*.129,-.319,2.035),(.126,.035,.043),'glow',.014)
        rounded('Cheek_armor',(side*.255,-.20,1.89),(.145,.16,.19),'stone_light',.045)
    rounded('Helmet_ridge',(0,-.10,2.23),(.12,.51,.085),'stone_light',.027)
    for x,z,r in [(-.21,2.36,.10),(.05,2.45,.13),(.23,2.31,.08)]:
        bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=r,radius2=0,depth=.28,location=(x,.045,z))
        finish(bpy.context.object,'Crown_crystal','crystal',False)
    current_parent=root
    for side,label in ((-1,'Left'),(1,'Right')):
        leg=empty('Leg'+label,(side*.275,0,.97))
        current_parent=leg
        orb('Leg_joint',(side*.275,0,.76),(.19,.20,.24),'joint',12,7)
        rounded('Shin_armor',(side*.285,-.075,.53),(.40,.40,.51),'stone',.105)
        rounded('Knee_plate',(side*.285,-.29,.76),(.33,.14,.27),'stone_light',.07)
        rounded('Stone_foot',(side*.285,-.12,.175),(.46,.65,.31),'stone_light',.10)
        current_parent=root
        arm=empty('Arm'+label,(side*.50,0,1.73))
        current_parent=arm
        rounded('Pauldron',(side*.60,0,1.73),(.46,.58,.43),'stone_light',.12)
        orb('Arm_joint',(side*.70,0,1.37),(.15,.17,.29),'joint',12,7)
        rounded('Bracer',(side*.745,-.02,1.16),(.35,.42,.43),'stone',.095)
        rounded('Fist',(side*.765,-.075,.865),(.34,.35,.30),'stone_light',.1)
        for dx in (-.09,0,.09):
            rounded('Knuckle',(side*.765+dx,-.249,.91),(.075,.065,.10),'stone',.02)
        rod('Bracer_rune',(side*.755,-.24,1.08),(side*.755,-.24,1.27),.018,'glow',6)
        current_parent=root
    current_parent=None
    return root

def inspect_asset(name):
    total=0
    rows=[]
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH': continue
        obj.data.calc_loop_triangles()
        bm=bmesh.new(); bm.from_mesh(obj.data)
        bad=sum(f.calc_area()<1e-12 for f in bm.faces)
        boundary=sum(not e.is_manifold for e in bm.edges)
        bm.free()
        count=len(obj.data.loop_triangles)
        total+=count
        rows.append({'name':obj.name,'triangles':count,'degenerate':bad,'nonmanifold':boundary})
    report={'asset':name,'triangles':total,'budget':5000,'meshes':rows,'source':'Original procedural Blender geometry',
            'uv':'Simple generated UV; palette materials only, no texture images',
            'rig':'Transform hierarchy; no skinned skeleton', 'blender':bpy.app.version_string}
    if total>5000 or any(row['degenerate'] for row in rows):
        raise RuntimeError(json.dumps(report))
    (SOURCE/(name+'_metrics.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('ASSET_METRICS',name,total,flush=True)

def optimize_asset(name):
    # Preserve the authored surfaces, then simplify copies to the target budget.
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'_authoring.blend')))
    objects=[obj for obj in bpy.context.scene.objects if obj.type=='MESH']
    total=0
    for obj in objects:
        obj.data.calc_loop_triangles()
        total+=len(obj.data.loop_triangles)
    if total<=5000: return
    ratio=4750/total
    for obj in objects:
        obj.data=obj.data.copy()
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Game_mesh_budget','DECIMATE')
        mod.ratio=ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)

def combine_by_joint():
    groups={}
    for obj in list(bpy.context.scene.objects):
        if obj.type=='MESH': groups.setdefault(obj.parent,[]).append(obj)
    for joint, objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        bpy.context.object.name=(joint.name if joint else 'Model')+'_mesh'

        bm=bmesh.new()
        bm.from_mesh(bpy.context.object.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(bpy.context.object.data)
        bm.free()

def light(name, loc, energy, size):
    data=bpy.data.lights.new(name,'AREA'); data.energy=energy; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj); obj.location=loc
    obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()

def render_asset(name):
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=640; scene.render.resolution_y=640; scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='WEBP'
    scene.world=bpy.data.worlds.new('Studio_world')
    scene.world.color=(.20,.20,.20)
    light('Key',(-3,-4,6),450,4)
    light('Fill',(4,-2,3),300,3)
    light('Rim',(1,3,4),550,3)
    bpy.ops.object.camera_add(location=(3.5,-6,3.0))
    camera=bpy.context.object; scene.camera=camera; camera.data.type='ORTHO'
    target=Vector((0,0,1.18 if name=='corrupted_guardian' else (.6 if name=='forest_slime' else 1.0)))
    camera.data.ortho_scale=3.2 if name=='corrupted_guardian' else 2.65
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX'
    scene.render.filepath=str(EVIDENCE/(name+'_front.webp'))
    bpy.ops.render.render(write_still=True)
    camera.location=(3.5,6,2.8)
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(EVIDENCE/(name+'_back.webp'))
    bpy.ops.render.render(write_still=True)

def main():
    import sys
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    names=[arg for arg in args if not arg.startswith('--')] or ['ren','lia','guildmaster','forest_slime','corrupted_guardian']
    for name in names:
        global materials,current_parent
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.preferences.filepaths.save_version=0
        preview=bpy.context.preferences.filepaths.bl_rna.properties.get('file_preview_type')
        if preview and 'NONE' in [item.identifier for item in preview.enum_items]:
            bpy.context.preferences.filepaths.file_preview_type='NONE'
        materials={}; current_parent=None
        if name=='forest_slime': slime()
        elif name=='corrupted_guardian': guardian()
        else: person(name)
        bpy.context.view_layer.update()
        optimize_asset(name)
        combine_by_joint()
        inspect_asset(name)
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
        bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True,
                                 export_animations=False,export_cameras=False,export_lights=False)
        if '--render' in args: render_asset(name)

if __name__=='__main__': main()
