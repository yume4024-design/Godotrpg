"""Original stylized monsters; run in a separate Blender background process."""
import bpy, math, json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/models/expansion'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'assets/source/expansion'
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE/'.gdignore').write_text('')
reports = {}
def material(name, color):
    m=bpy.data.materials.new(name); m.use_nodes=True; m.diffuse_color=(*color,1)
    shader=m.node_tree.nodes.get('Principled BSDF'); shader.inputs['Base Color'].default_value=(*color,1); shader.inputs['Roughness'].default_value=.8
    return m
def orb(name, pos, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,location=pos)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat)
    for f in o.data.polygons:f.use_smooth=True
    return o
def cone(name,pos,scale,mat):
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=1,depth=2,location=pos)
    o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(mat)
def eyes(z, y, spacing, white, black):
    for x in [-spacing,spacing]:
        orb('Eye',(x,y,z),(.14,.10,.17),white)
        orb('Pupil',(x,y-.08,z),(.065,.045,.09),black)
for kind in ['spore_sprite','thorn_boar','crystal_bat','ore_beetle']:
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    white=material('Cream',(.95,.91,.72));black=material('Eyes',(.035,.045,.06))
    green=material('Leaf',(.31,.55,.27));purple=material('Violet',(.43,.29,.62))
    blue=material('Crystal',(.12,.7,.85));brown=material('Earth',(.47,.29,.18))
    if kind=='spore_sprite':
        orb('Torso',(0,0,.65),(.38,.35,.6),white)
        orb('Head',(0,0,1.2),(.85,.65,.35),purple)
        for x,y in [(-.35,-.25),(.3,-.3),(0,.25)]:orb('CapSpot',(x,y,1.49),(.15,.14,.05),white)
        eyes(.78,-.34,.16,white,black)
        for x in [-.3,.3]:orb('Foot',(x,-.12,.13),(.22,.32,.13),green)
    elif kind=='thorn_boar':
        orb('Torso',(0,.15,.66),(.56,.78,.5),brown)
        orb('Head',(0,-.53,.75),(.46,.43,.4),brown)
        orb('Snout',(0,-.88,.61),(.3,.15,.22),white)
        eyes(.91,-.84,.23,white,black)
        for x in [-.38,.38]:
            for y in [-.4,.5]:orb('Leg',(x,y,.22),(.16,.17,.24),brown)
            cone('Ear',(x,-.42,1.17),(.17,.16,.28),green)
        for y in [0,.3,.6]:cone('Thorn',(0,y,1.2),(.16,.16,.3),green)
    elif kind=='crystal_bat':
        orb('Torso',(0,0,.95),(.32,.3,.46),purple)
        eyes(1.07,-.27,.17,white,black)
        for side in [-1,1]:
            cone('Ear',(side*.21,0,1.48),(.16,.13,.27),blue)
            verts=[(side*.23,0,1.15),(side*1.25,0,1.45),(side*1.05,0,.65),(side*.7,0,.9),(side*.48,0,.55)]
            mesh=bpy.data.meshes.new('Wing');mesh.from_pydata(verts,[],[(0,1,2),(0,2,3),(0,3,4)]);mesh.materials.append(purple)
            o=bpy.data.objects.new('Wing',mesh);bpy.context.collection.objects.link(o)
            mod=o.modifiers.new('Thickness','SOLIDIFY');mod.thickness=.06
        cone('Star',(0,-.29,.75),(.1,.08,.18),blue)
    else:
        orb('Torso',(0,.15,.52),(.65,.75,.44),brown)
        for x in [-.32,.32]:orb('Shell',(x,.13,.72),(.32,.65,.28),purple)
        orb('Head',(0,-.58,.48),(.38,.32,.3),brown)
        eyes(.58,-.84,.18,white,black)
        for side in [-1,1]:
            for y in [-.4,.1,.55]:orb('Leg',(side*.64,y,.2),(.3,.12,.12),brown)
            cone('Crystal',(side*.24,.25,1.04),(.18,.16,.34),blue)
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH':
            bpy.context.view_layer.objects.active=o;o.select_set(True)
            for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
            o.select_set(False)
    triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
    assert triangles<=5000,(kind,triangles)
    reports[kind]={'triangles':triangles,'rigged':False,'source':'Original Blender primitives'}
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/f'{kind}.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{kind}.glb'),export_format='GLB',export_yup=True)
(OUT/'model_report.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
