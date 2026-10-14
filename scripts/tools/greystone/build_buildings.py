"""G03 licensed building adaptation. Run in Blender or through MCP.

Only replaces the owned Crystal_G03_Buildings scene; source meshes are retained
on disk. No network, credentials, user-scene changes or external dependencies.
"""
import bpy
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
    # Chunky signboard and a readable relief pictogram face Godot +Z (Blender -Y).
    # Kept inside the building footprint; the road and interaction marker stay free.
    if sign:
        sx=width*.29
        sy=-depth*.39
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
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active=body
    if len(parts)>1:
        bpy.ops.object.join()
    body.name=ident
    body.data.calc_loop_triangles()
    triangles=len(body.data.loop_triangles)
    metrics.append({'id':ident,'source':source,'triangles':triangles,'dimensions_xyz_godot':[width,height,depth],'materials':len(body.data.materials),'textures':0})
    bpy.ops.export_scene.gltf(filepath=ROOT+'assets/models/greystone/buildings/'+ident+'.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    body.location=(index%4*19,index//4*17,0)
    body['source_author']='Quaternius'
    body['source_license']='CC0 1.0'
scene['crystal_g03_metrics']=json.dumps(metrics)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'source_assets/greystone_g03/greystone_buildings.blend',copy=True)
print('G03_METRICS '+json.dumps(metrics))
