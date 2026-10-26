"""Additive forest backdrop. Existing playable floor and actors are not rebuilt."""
import bpy, math, random, json, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'source_assets/forest_visual_finish_20261026'
EXPORT = ROOT / 'assets/models/forest_visual_finish'
OUT.mkdir(parents=True, exist_ok=True)
EXPORT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.name = 'Forest_Backdrop_20261026'
rng = random.Random(261026)
sources = {}

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = .95
    return m

earth = material('ForestEarth', (.24,.39,.22))
templates = {}
for key, relative in [('tree','assets/models/cartoon/round_tree.glb'),('bush','assets/models/greystone/props/bush_a.glb')]:
    p = ROOT / relative
    sources[relative] = hashlib.sha256(p.read_bytes()).hexdigest()
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(p))
    imported = set(bpy.data.objects) - before
    meshes = []
    for ob in imported:
        if ob.type == 'MESH':
            mesh = ob.data.copy()
            mesh.transform(ob.matrix_world)
            meshes.append(mesh)
    templates[key] = meshes
    for ob in imported: bpy.data.objects.remove(ob, do_unlink=True)

# glTF-supported base colors for the editable source; Godot adds ground grain.
for mat in bpy.data.materials:
    if mat.name.startswith(('foliage','G04_leaf')):
        color = (.34,.48,.20) if 'light' in mat.name else (.22,.36,.14)
        mat.diffuse_color=(*color,1)
        if mat.use_nodes:
            next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Base Color'].default_value=(*color,1)

def instance(key, x, z, scale):
    for mesh in templates[key]:
        ob = bpy.data.objects.new(key, mesh)
        scene.collection.objects.link(ob)
        ob.location = (x,-z,0)
        ob.scale = (scale,scale,scale)
        ob.rotation_euler.z = rng.uniform(-math.pi, math.pi)

# Trees sit behind the playable north/west border; foreground stays low.
for edge in ('north','west'):
    for depth in (31,36):
        for along in (-30,-18,-6,6,18,30):
            x,z = (along+rng.uniform(-2,2),-depth) if edge=='north' else (-depth,along+rng.uniform(-2,2))
            instance('tree',x,z,rng.uniform(1.1,1.7))
for edge in range(4):
    for along in range(-34,35,4):
        x,z = [(along,-28.8),(-28.8,along),(along,29.4),(29.4,along)][edge]
        instance('bush',x+rng.uniform(-.6,.6),z+rng.uniform(-.6,.6),rng.uniform(1.3,2.4))

# A continuous irregular earth skirt beyond ENV02's existing 28.3m extent.
verts, faces = [], []
for index in range(64):
    angle = math.tau * index/64
    dx,dz = math.cos(angle),math.sin(angle)
    divisor = max(abs(dx),abs(dz))
    for radius, height in [(28.3,0),(39+rng.uniform(-1.3,1.3),-.4),(39+rng.uniform(-1.3,1.3),-3.5)]:
        verts.append((dx/divisor*radius,-dz/divisor*radius,height))
for i in range(64):
    n=(i+1)%64
    faces.extend([(i*3,n*3,n*3+1,i*3+1),(i*3+1,n*3+1,n*3+2,i*3+2)])
mesh=bpy.data.meshes.new('EarthSkirt')
mesh.from_pydata(verts,[],faces)
mesh.materials.append(earth)
ob=bpy.data.objects.new('EarthSkirt',mesh)
scene.collection.objects.link(ob)

# Merge only owned backdrop mesh copies, leaving source meshes untouched.
bpy.ops.object.select_all(action='SELECT')
for ob in bpy.context.selected_objects: ob.data=ob.data.copy()
bpy.context.view_layer.objects.active=ob
bpy.ops.object.join()
backdrop=bpy.context.object
backdrop.name='ForestBorder'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
backdrop.select_set(False)

scene['scope']='Additive backdrop only; original forest and its mine sign remain in Godot.'
camera_data=bpy.data.cameras.new('DressingReviewCamera')
camera=bpy.data.objects.new('DressingReviewCamera',camera_data)
scene.collection.objects.link(camera)
camera.location=(75,-75,100)
camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler()
camera_data.type='ORTHO'
camera_data.ortho_scale=115
scene.camera=camera
light_data=bpy.data.lights.new('DressingReviewSun','SUN')
light=bpy.data.objects.new('DressingReviewSun',light_data)
scene.collection.objects.link(light)
light.rotation_euler=(math.radians(25),math.radians(-30),math.radians(-25))
light_data.energy=2
scene.render.resolution_x=960
scene.render.resolution_y=720
scene.render.resolution_percentage=100
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'forest_dressing.blend'))
stats={}
for ob, filename in [(backdrop,'border')]:
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    ob.data.calc_loop_triangles()
    stats[filename]={'triangles':len(ob.data.loop_triangles),'materials':len(ob.data.materials)}
    bpy.ops.export_scene.gltf(filepath=str(EXPORT/(filename+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
receipt={'seed':261026,'scope':scene['scope'],'sources':sources,'models':stats,'blender':bpy.app.version_string,'builder_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
(OUT/'build_receipt.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print('FOREST_DRESSING_COMPLETE '+json.dumps(stats))
