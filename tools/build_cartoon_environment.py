"""Original rounded environment props; run with isolated background Blender."""
import sys
import math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import build_cartoon_assets as a
import bpy

a.PALETTE.update({
    'foliage': ('5AA774', .85, 0), 'foliage_light': ('8EC57A', .85, 0),
    'moss': ('8DAB78', .95, 0), 'rock': ('929C96', .95, 0),
    'plaster': ('ECD7AF', .9, 0), 'tile': ('518E8E', .8, 0),
    'flower': ('EFAB9D', .8, 0),
})

def tree():
    a.rod('Curved_trunk', (0,0,0), (.04,0,2.5), .225, 'leather', 14)
    for x,y in [(-.6,0),(.6,.15),(0,-.6)]:
        a.rod('Branch',(0,0,1.45),(x,y,2.6),.10,'leather',10)
    for i,(x,y,z,s) in enumerate([(0,0,3.0,1),(-.65,0,2.65,.76),(.65,.1,2.7,.8),(0,-.6,2.8,.8),(0,.5,2.9,.78),(0,0,3.6,.62)]):
        a.orb('Leaf_cloud',(x,y,z),(s,s*.85,s*.8),'foliage_light' if i%3==0 else 'foliage',16,10)
    for i in range(4):
        t=i*math.pi/2
        a.rod('Root',(0,0,.22),(.34*math.cos(t),.34*math.sin(t),.04),.07,'leather',8)

def cottage(guild=False):
    a.rounded('Plaster_walls',(0,0,1.1),(3.5,3,2.2),'plaster',.12)
    a.rounded('Stone_foundation',(0,0,.17),(3.55,3.05,.34),'rock',.10)
    for x in (-1.68,1.68):
        for y in (-1.46,1.46):
            a.rounded('Corner_beam',(x,y,1.17),(.16,.17,2.16),'leather',.035)
    a.rounded('Front_crossbeam',(0,-1.52,2.03),(3.5,.12,.17),'leather',.035)
    # Closed gable and two rounded roof slopes, individual overlapping tile courses.
    a.mesh('Gable',[(-1.75,-1.5,2.1),(1.75,-1.5,2.1),(1.75,0,3.1),(-1.75,0,3.1),(-1.75,1.5,2.1),(1.75,1.5,2.1)],[(0,1,2,3),(3,2,5,4),(0,4,5,1),(0,3,4),(1,5,2)],'plaster',False)
    roof='tile' if guild else 'orange'
    for side in (-1,1):
        for row in range(4):
            y=side*(.23+row*.46)
            z=3.15-abs(y)*.58
            for col in range(6):
                obj=a.rounded('Roof_tile',(-1.65+col*.66,y,z),(.7,.61,.13),roof,.05)
                obj.rotation_euler.x=-side*.526
    a.rod('Ridge_cap',(-2.05,0,3.23),(2.05,0,3.23),.11,roof,12)
    a.rounded('Door_frame',(0,-1.535,.83),(1.05,.16,1.56),'leather_light',.14)
    a.rounded('Wooden_door',(0,-1.63,.82),(.82,.08,1.39),'leather',.14)
    for x in (-.23,0,.23):
        a.rod('Door_plank',(x,-1.684,.22),(x,-1.684,1.35),.012,'leather_light',6)
    a.orb('Door_handle',(.25,-1.72,.8),(.044,.03,.044),'gold',10,6)
    for x in (-1.12,1.12):
        a.rounded('Window_frame',(x,-1.53,1.27),(.69,.15,.83),'leather_light',.13)
        a.rounded('Window_glass',(x,-1.63,1.27),(.50,.06,.63),'gold',.09)
        a.rod('Window_mullion',(x,-1.67,.99),(x,-1.67,1.56),.025,'cream',8)
        a.rod('Window_crossbar',(x-.24,-1.67,1.27),(x+.24,-1.67,1.27),.025,'cream',8)
        a.rounded('Window_box',(x,-1.67,.84),(.8,.3,.22),'leather',.05)
        for dx in (-.22,0,.22):
            a.orb('Planter_leaf',(x+dx,-1.68,.98),(.13,.12,.11),'foliage',10,6)
    a.rounded('Chimney',(.95,.55,3.05),(.48,.52,.95),'rock',.07)
    a.rounded('Chimney_cap',(.95,.55,3.52),(.61,.65,.16),'cream',.05)
    a.rounded('Chimney_opening',(.95,.55,3.61),(.34,.37,.03),'dark',.025)

def rock():
    a.rounded('Weathered_stone',(0,0,.53),(1.18,1.18,1.05),'rock',.26)
    a.orb('Moss_cap',(-.14,.04,1.03),(.52,.49,.09),'moss',16,8)
    a.rod('Stone_seam',(-.59,-.35,.46),(-.59,.35,.59),.012,'stone',8)

def flowers():
    for i,(x,y) in enumerate([(-.25,0),(.16,.12),(0,-.22)]):
        a.rod('Stem',(x,y,0),(x,y,.28+i*.05),.022,'leaf',6)
        for s in (-1,1):
            leaf=a.orb('Leaf',(x+s*.10,y,.12),(.13,.05,.045),'foliage',8,5)
            leaf.rotation_euler.y=s*.4
        for j in range(5):
            t=j*math.tau/5
            a.orb('Petal',(x+.078*math.cos(t),y+.078*math.sin(t),.29+i*.05),(.077,.064,.035),'flower' if i%2 else 'cream',8,5)
        a.orb('Pollen',(x,y,.32+i*.05),(.049,.047,.027),'gold',8,5)

def chest_base():
    a.rounded('Chest_wood',(0,0,.35),(1.1,.7,.7),'leather',.07)
    for x in (-.44,.44):
        a.rounded('Iron_band',(x,0,.35),(.10,.735,.71),'gold',.025)
    for z in (.2,.43):
        a.rounded('Plank_seam',(0,-.358,z),(.97,.012,.014),'leather_light',.004)
    a.rounded('Lock',(0,-.385,.57),(.18,.07,.22),'gold',.035)
    a.orb('Keyhole',(0,-.43,.57),(.024,.009,.037),'dark',8,5)

def chest_lid():
    # Origin matches the gameplay Lid pivot at y=.75 in Godot.
    a.rounded('Domed_lid',(0,0,.05),(1.15,.75,.30),'leather_light',.13)
    for x in (-.44,.44):
        a.rounded('Lid_band',(x,0,.055),(.10,.77,.315),'gold',.043)

def camp():
    for i in range(9):
        t=i*math.tau/9
        a.orb('Hearth_stone',(.51*math.cos(t),.51*math.sin(t),.10),(.17,.14,.11),'rock',12,6)
    for side in (-1,1):
        a.rod('Firewood',(-.32,side*.23,.14),(.32,-side*.23,.14),.10,'leather',10)
    for x,y,z,s in [(0,0,.39,.28),(-.15,.05,.32,.19),(.17,0,.34,.18)]:
        a.orb('Warm_flame',(x,y,z),(s,s*.7,s*1.55),'orange_light',12,8)
    a.orb('Flame_heart',(0,-.15,.30),(.12,.12,.22),'gold',12,8)

def sign():
    a.rod('Post',(0,0,0),(0,0,1.65),.09,'leather',12)
    a.rounded('Carved_board',(0,-.04,1.35),(1.2,.15,.5),'leather_light',.1)
    a.rod('Arrow_shaft',(-.35,-.135,1.35),(.36,-.135,1.35),.027,'cream',8)
    for z in (1.21,1.49):
        a.rod('Arrow_tip',(.36,-.135,1.35),(.19,-.135,z),.027,'cream',8)

def path_strip():
    # Flat capsule-ended road: rounded plan outline, no height obstruction.
    points=[]
    for cx,start in [(7.75,-math.pi/2),(-7.75,math.pi/2)]:
        for i in range(13):
            t=start+i*math.pi/12
            points.append((cx+1.25*math.cos(t),1.25*math.sin(t)))
    vertices=[(x,y,z) for z in (0,.025) for x,y in points]
    n=len(points)
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    a.PALETTE['path']=('CABB86',.95,0)
    a.mesh('Rounded_path',vertices,faces,'path',False)

BUILDERS={'round_tree':tree,'guild_house':lambda:cottage(True),'cottage':cottage,
          'moss_rock':rock,'flower_patch':flowers,'chest_base':chest_base,
          'chest_lid':chest_lid,'campfire':camp,'signpost':sign,'path_strip':path_strip}

requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for name,build in BUILDERS.items():
    if requested and name not in requested: continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.context.preferences.filepaths.file_preview_type='NONE'
    a.materials={}
    a.current_parent=None
    a.current_parent=a.empty(name)
    build()
    a.current_parent=None
    bpy.context.view_layer.update()
    a.optimize_asset(name)
    a.combine_by_joint()
    a.inspect_asset(name)
    bpy.ops.wm.save_as_mainfile(filepath=str(a.SOURCE/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(a.OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
