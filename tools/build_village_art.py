"""Original Graystone village scenery. Blender background, no third-party assets.

Coordinates below use Godot axes. glTF performs the final Z-up -> Y-up conversion.
Solid scenery inside the playable square fits the existing P5 collision footprints.
Roads/plaza are flat overlays; river, bridge and extra houses are outside the walls.
Rebuild: blender --background --factory-startup --python tools/build_village_art.py
"""
import sys, math, random, json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import bpy
import build_cartoon_assets as a

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source_assets/village_v2'
SOURCE.mkdir(parents=True, exist_ok=True)
rng = random.Random(2046)
a.PALETTE.update({
    'wall': ('F2DFC0', .88, 0), 'timber': ('784A35', .85, 0),
    'stone': ('A8ACAE', .92, 0), 'stone_light': ('D6D5C5', .9, 0),
    'roof_blue': ('377DC0', .72, 0), 'roof_blue_light': ('4F94CD', .7, 0),
    'roof_red': ('C96753', .8, 0), 'roof_red_light': ('E28062', .8, 0),
    'paving': ('D5C6A2', .92, 0), 'paving_light': ('E4D6B5', .95, 0),
    'grass': ('83AD68', 1, 0), 'grass_light': ('A3C57B', 1, 0),
    'foliage': ('55965C', .9, 0), 'foliage_light': ('85B365', .9, 0),
    'window': ('FFCA63', .5, 0), 'river': ('48ACC4', .32, .05),
    'foam': ('C1E9DD', .5, 0), 'crystal_blue': ('46C6E4', .28, .1),
    'pink': ('EB9AA2', .8, 0), 'awning': ('4CABA0', .8, 0),
})

def pos(p): return (p[0], -p[2], p[1])
def box(name, p, size, color, bevel=.04):
    return a.rounded(name, pos(p), (size[0], size[2], size[1]), color, bevel)
def ball(name, p, size, color):
    return a.orb(name, pos(p), (size[0], size[2], size[1]), color, 12, 8)
def rod(name, p, q, radius, color): return a.rod(name, pos(p), pos(q), radius, color, 10)
def mesh(name, vertices, faces, color):
    return a.mesh(name, [pos(p) for p in vertices], faces, color, False)
def disc(name, x, y, z, radius, depth, color, sides=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=depth, location=pos((x,y,z)))
    return a.finish(bpy.context.object, name, color, False)
def ring(name, x, y, z, radius, width, color, segments=64):
    vertices=[]
    for r in (radius-width/2, radius+width/2):
        vertices += [(x+r*math.cos(i*math.tau/segments),y,z+r*math.sin(i*math.tau/segments)) for i in range(segments)]
    mesh(name,vertices,[(i,(i+1)%segments,(i+1)%segments+segments,i+segments) for i in range(segments)],color)

def window(x,y,z,w=.65,h=.85):
    box('Carved_window_frame',(x,y,z),(w+.15,h+.15,.12),'timber',.08)
    box('Amber_window',(x,y,z+.075),(w,h,.04),'window',.07)
    box('Window_mullion',(x,y,z+.105),(.055,h,.035),'wall',.01)
    box('Window_crossbar',(x,y,z+.105),(w,.055,.035),'wall',.01)

def planter(x,y,z,width=1):
    box('Flower_box',(x,y,z),(width,.23,.27),'timber')
    for i in range(5):
        px=x-width*.4+width*.2*i
        ball('Planter_leaves',(px,y+.16,z),(.15,.13,.13),'foliage')
        ball('Planter_blossom',(px,y+.25,z+.045),(.065,.06,.065),'pink' if i%2 else 'white')

def lantern(x,y,z):
    box('Lantern_glass',(x,y,z),(.18,.27,.18),'window',.035)
    for dx in (-.10,.10):
        for dz in (-.10,.10): rod('Lantern_frame',(x+dx,y-.14,z+dz),(x+dx,y+.14,z+dz),.014,'timber')
    box('Lantern_cap',(x,y+.19,z),(.29,.10,.29),'timber',.04)
    box('Lantern_foot',(x,y-.17,z),(.25,.08,.25),'gold',.025)

def house(x,z,w=3.5,d=3,h=2.2,blue=False,guild=False):
    roof='roof_blue' if blue else 'roof_red'
    box('Foundation',(x,.14,z),(w,.28,d),'stone',.10)
    box('Plaster',(x,h/2+.1,z),(w-.12,h-.2,d-.12),'wall',.09)
    for dx in (-w/2+.09,w/2-.09):
        for dz in (-d/2+.09,d/2-.09): box('Timber_post',(x+dx,h/2,z+dz),(.15,h,.15),'timber')
    for y in (.35,h-.12):
        box('Front_beam',(x,y,z+d/2-.015),(w,.15,.15),'timber')
        for dx in (-w/2+.015,w/2-.015): box('Side_beam',(x+dx,y,z),(.15,.15,d),'timber')
    rise=w*.36
    for dz in (-d/2+.02,d/2-.02):
        mesh('Plaster_gable',[(x-w/2,h,z+dz),(x+w/2,h,z+dz),(x,h+rise,z+dz)],[(0,1,2)],'wall')
        for s in (-1,1): rod('Gable_trim',(x+s*(w/2+.08),h,z+dz+.035),(x,h+rise,z+dz+.035),.08,'timber')
        rod('Gable_spine',(x,h,z+dz+.05),(x,h+rise,z+dz+.05),.06,'timber')
    rows=max(4,int(w/.8)); cols=max(5,int(d/.5))
    for side in (-1,1):
        for row in range(rows):
            dx=side*(row+.5)*(w/2+.22)/rows
            for col in range(cols):
                tile=box('Overlapping_roof_tile',(x+dx,h+rise-abs(dx)*.72+.05,z-d/2-.22+(col+.5)*(d+.44)/cols),((w/2+.22)/rows+.055,.115,(d+.44)/cols+.025),roof+'_light' if (row+col)%4==0 else roof,.045)
                tile.rotation_euler.y=side*math.atan(.72)
    rod('Roof_ridge',(x,h+rise+.13,z-d/2-.3),(x,h+rise+.13,z+d/2+.3),.10,roof)
    box('Door_frame',(x,.86,z+d/2+.015),(1.05,1.65,.12),'timber',.12)
    box('Door',(x,.80,z+d/2+.085),(.83,1.44,.04),'leather_light',.10)
    for dx in (-.26,0,.26): box('Door_plank',(x+dx,.8,z+d/2+.113),(.023,1.28,.02),'timber',.005)
    ball('Door_knob',(x+.25,.8,z+d/2+.14),(.05,.05,.035),'gold')
    for dx in (-w*.31,w*.31):
        window(x+dx,1.35,z+d/2+.035,.64,.83)
        planter(x+dx,.78,z+d/2+.12,.87)
    # Side window toward the fixed camera.
    side=box('Side_window',(x+w/2+.02,1.35,z),(.06,.75,.65),'window',.08)
    for dz in (-.4,.4): box('Side_window_shutter',(x+w/2+.06,1.35,z+dz),(.10,.87,.15),'timber')
    box('Side_window_divider',(x+w/2+.07,1.35,z),(.06,.75,.05),'wall',.01)
    box('Chimney',(x-w*.29,h+rise*.8,z-d*.2),(.48,1.05,.5),'stone_light',.065)
    box('Chimney_lip',(x-w*.29,h+rise*.8+.55,z-d*.2),(.62,.14,.64),'stone',.04)
    box('Chimney_hollow',(x-w*.29,h+rise*.8+.63,z-d*.2),(.32,.025,.34),'dark',.015)
    for dx in (-.73,.73): lantern(x+dx,1.86,z+d/2+.17)
    if guild:
        # An original star-crystal crest; avoids the reference's heraldry.
        box('Guild_banner',(x,2.85,z+d/2+.12),(1.04,1.1,.07),'roof_blue',.06)
        for dx in (-.53,.53): rod('Banner_border',(x+dx,2.29,z+d/2+.17),(x+dx,3.4,z+d/2+.17),.028,'gold')
        mesh('Crystal_crest',[(x,3.26,z+d/2+.18),(x+.23,2.84,z+d/2+.18),(x,2.47,z+d/2+.18),(x-.23,2.84,z+d/2+.18)],[(0,1,2,3)],'gold')
        box('Bell_tower',(x,h+rise+.42,z-.38),(1.0,.85,.82),'wall',.08)
        window(x,h+rise+.48,z+.06,.37,.44)
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=.83, depth=.82, location=pos((x,h+rise+1.22,z-.38)), rotation=(0,0,math.pi/4))
        a.finish(bpy.context.object,'Bell_tower_roof','roof_blue',False)
        rod('Pennant_pole',(x,h+rise+1.5,z-.38),(x,h+rise+2,z-.38),.028,'gold')
        mesh('Pennant',[(x,h+rise+2,z-.38),(x+.52,h+rise+1.91,z-.38),(x,h+rise+1.74,z-.38)],[(0,1,2)],'gold')
    else:
        # Wall-mounted awning: no new columns intruding on saved walking space.
        for i in range(7):
            obj=box('Canvas_stripe',(x-.72+i*.24,1.99,z+d/2+.28),(.245,.07,.62),'awning' if i%2==0 else 'white',.025)
            obj.rotation_euler.x=-.20
            box('Scalloped_valance',(x-.72+i*.24,1.83,z+d/2+.57),(.245,.19,.065),'awning' if i%2==0 else 'white',.06)

def tree(x,z,y=0,s=1):
    rod('Tree_trunk',(x,y,z),(x,y+2*s,z),.17*s,'timber')
    for dx,dz,dy,size in [(0,0,2.5,.95),(-.6,0,2.15,.72),(.55,.12,2.22,.78),(0,.55,2.34,.71),(0,0,3.1,.58)]:
        ball('Rounded_canopy',(x+dx*s,y+dy*s,z+dz*s),(size*s,size*.86*s,size*.9*s),'foliage_light' if dy>2.4 else 'foliage')

def fence(x,z,length,axis='x'):
    count=max(1,round(length/1.15))
    for i in range(count+1):
        t=i*length/count-length/2
        px,pz=(x+t,z) if axis=='x' else (x,z+t)
        box('Fence_post',(px,.51,pz),(.14,1.0,.14),'leather_light',.035)
        ball('Fence_cap',(px,1.025,pz),(.10,.075,.10),'gold')
    for y in (.36,.75):
        box('Fence_rail',(x,y,z),(length,.09,.075) if axis=='x' else (.075,.09,length),'timber',.025)

def garden(x,z,length):
    box('Garden_bed',(x,.10,z),(length,.20,.75),'stone_light',.1)
    for i in range(int(length*3)):
        px=x-length/2+.16+i/3
        ball('Hedge_cluster',(px,.42,z),(.27,.34,.3),'foliage_light')
        for dx,dz in ((-.1,.17),(.10,-.13)):
            ball('Garden_flower',(px+dx,.63,z+dz),(.075,.07,.075),'pink' if i%2 else 'white')

def guild(): house(0,-6.8,6,3.5,2.6,True,True)
def shop(): house(-7,-4)

def paving():
    # One thin static mesh, visible seams rather than hundreds of Godot nodes.
    disc('Guild_court',0,.011,2,3.4,.018,'paving',64)
    disc('Crystal_plaza',6,.012,7,3.2,.020,'paving',80)
    for radius in (1.22,2.35,3.06): ring('Plaza_inlay',6,.034,7,radius,.085,'stone_light')
    for i in range(40):
        t=i*math.tau/40
        rod('Radial_seam',(6+2.40*math.cos(t),.035,7+2.40*math.sin(t)),(6+3.02*math.cos(t),.035,7+3.02*math.sin(t)),.013,'paving_light')
    # Broad guild approach, chest spur, and forest route share a paving vocabulary.
    for axis,lo,hi,cross,width in [('z',-5.0,5.2,0,2.4),('x',-7.0,11.7,0,2.3),('x',-3.7,2,2.7,1.7),('x',0,6,4.8,2.1),('z',0,7,6,1.7)]:
        n=math.ceil((hi-lo)/.66)
        cols=round(width/.55)
        for i in range(n):
            along=lo+(i+.5)*(hi-lo)/n
            for j in range(cols):
                across=cross-width/2+(j+.5)*width/cols
                px,pz=(across,along) if axis=='z' else (along,across)
                box('Path_paver',(px,.018,pz),(.52,.035,.62) if axis=='z' else (.62,.035,.52),'paving_light' if (i+j)%4==0 else 'paving',.025)
    # Crystal memorial on the former Trunk1 footprint (0.45 x 0.45).
    disc('Flush_memorial_mosaic',6,.037,7,1.05,.018,'stone_light',48)
    box('Memorial_foot',(6,.16,7),(.44,.32,.44),'stone_light',.05)
    box('Memorial_column',(6,.9,7),(.40,1.48,.40),'stone',.035)
    box('Memorial_cap',(6,1.68,7),(.44,.16,.44),'stone_light',.035)
    # Upper crystal overhang starts above the player's capsule, base stays 0.44.
    vertices=[(6,3.12,7),(6,1.78,7)]
    vertices += [(6+.48*math.cos(i*math.tau/6),2.40,7+.48*math.sin(i*math.tau/6)) for i in range(6)]
    mesh('Village_crystal',vertices,[(0,2+i,2+(i+1)%6) for i in range(6)]+[(1,2+(i+1)%6,2+i) for i in range(6)],'crystal_blue')
    for radius in (.85,1.1): ring('Memorial_inlay',6,.035,7,radius,.085,'roof_blue')
    # Low, walk-through groundcover, not new solid obstacles or interactables.
    local_rng=random.Random(77)
    for cx,cz,rx,rz in [(-7,6,3,3),(-5,-9,2,.9),(6,-9,3,.8),(8,-4,1.5,2),(3,9,1.7,1),(-8,.5,1.7,1)]:
        for i in range(24):
            t=local_rng.uniform(0,math.tau); r=local_rng.random()**.5
            x=cx+math.cos(t)*rx*r; z=cz+math.sin(t)*rz*r
            ball('Meadow_cushion',(x,.032,z),(.20,.07,.17),'grass_light' if i%3 else 'grass')
            if i%2==0:
                for dx,dz in [(-.055,0),(.05,.025),(0,-.05)]:
                    ball('Meadow_blossom',(x+dx,.13,z+dz),(.041,.035,.041),'white' if i%3 else 'pink')

def borders():
    # Far bridge landing meets the deck height; scenery only, past the map exit.
    box('Far_bridge_landing',(21.5,-1.10,0),(6,2.14,7),'grass',.32)
    for z in (-3.4,3.4):
        for x in (19.6,21.1,22.6,24.0):
            ball('Landing_cliff',(x,-1.0,z),(.9,1.0,.5),'stone')
    for i in range(10):
        box('Forest_approach_path',(19.1+i*.51,.01,0),(.52,.06,2.3),'paving',.03)
    # Wall bases line up with the P5 boundary colliders; planting is outside.
    for z in (-12,12):
        for i in range(24):
            x=-11.5+i
            box('Village_wall',(x,.32,z),(.98,.64,.52),'stone_light',.07)
            box('Wall_cap',(x,.68,z),(1.02,.14,.59),'stone',.055)
    for x in (-12,12):
        for i in range(23):
            z=-11+i
            box('Village_wall',(x,.32,z),(.52,.64,.98),'stone_light',.07)
            box('Wall_cap',(x,.68,z),(.59,.14,1.02),'stone',.055)
    for x,z in [(-10,-12),(6,-12),(-12,-7),(-12,6),(12,6),(-6,12),(6,12)]:
        box('Wall_pier',(x,.64,z),(.55,1.28,.55),'stone',.08)
        lantern(x,1.57,z)
    # Gate posts fit the old 0.45 square collision proxies.
    for z in (-1.7,1.7):
        box('Forest_gate_pier',(9.9,.79,z),(.44,1.58,.44),'stone_light',.045)
        lantern(9.9,1.8,z)
        rod('Gate_flagpole',(9.9,1.7,z),(9.9,2.8,z),.035,'timber')
        box('Gate_flag',(9.9,2.4,z+.25),(.04,.64,.47),'roof_blue',.02)
    # Flower beds and fences deliberately remain beyond the playable walls.
    for x in (-8,-3,3,8):
        garden(x,-12.8,3.4)
        garden(x,12.8,3.4)
    for x in (-13,13):
        for z in (-8,-3,5,9): tree(x,z,-.1,.7)

def backdrop():
    box('Village_terrace',(0,-1.0,0),(25.1,1.5,25.1),'stone',.24)
    box('River_bed',(0,-2.35,0),(70,.3,66),'grass',.5)
    box('South_river',(0,-1.65,16),(45,.12,6.1),'river',.28)
    box('East_river',(16,-1.66,-2),(6.2,.12,32),'river',.28)
    # Water streaks and rounded cliff blocks: all outside playable bounds.
    for i in range(35):
        x=rng.uniform(-20,20); z=rng.uniform(13.7,18.4)
        box('Water_ripple',(x,-1.575,z),(rng.uniform(.25,.9),.015,.035),'foam',.013)
    for i in range(23):
        x=-12.1+i*1.1
        ball('South_cliff',(x,-.85,12.45),(.8,1.0,.62),'stone' if i%3 else 'stone_light')
        ball('North_cliff',(x,-.4,-12.9),(.8,1.3,.64),'stone')
    for i in range(23):
        z=-12+i*1.1
        ball('East_cliff',(12.5,-.85,z),(.62,1,.8),'stone' if i%3 else 'stone_light')
        ball('West_cliff',(-12.6,-.7,z),(.7,1.1,.8),'stone')
    for i in range(22):
        x=-18+i*1.8
        ball('Far_riverbank',(x,-1.6,19.2),(1.4,.42,.6),'grass_light')
        if i%2==0: ball('Riverbank_rock',(x,-1.55,18.9),(.4,.45,.3),'stone_light')
    # Small spillway and a wooden waterwheel, outside the south wall.
    for i in range(6):
        box('Falling_water',(-6.6+i*.22,-.82,12.97),(.20,1.60,.16),'foam' if i%3==0 else 'river',.045)
        ball('Water_splash',(-6.6+i*.22,-1.55,13.2),(.20,.075,.35),'foam')
    for side in (-.26,.26):
        for i in range(20):
            t=i*math.tau/20; u=(i+1)*math.tau/20
            rod('Wheel_rim',(-7.35+side,-.5+.85*math.cos(t),13+.85*math.sin(t)),(-7.35+side,-.5+.85*math.cos(u),13+.85*math.sin(u)),.055,'timber')
        for i in range(8):
            t=i*math.tau/8
            rod('Wheel_spoke',(-7.35+side,-.5,13),(-7.35+side,-.5+.85*math.cos(t),13+.85*math.sin(t)),.045,'leather_light')
    for i in range(12):
        t=i*math.tau/12
        box('Wheel_paddle',(-7.35,-.5+.85*math.cos(t),13+.85*math.sin(t)),(.63,.16,.24),'leather_light',.025)
    # Scenic bridge beyond the east transition: height meets the village terrace.
    for i in range(17):
        x=12.1+i*.43
        y=-.12+.38*math.sin((i/16)*math.pi)
        box('Bridge_deck',(x,y,0),(.45,.18,2.5),'paving_light',.04)
        for z in (-1.36,1.36):
            box('Bridge_parapet',(x,y+.42,z),(.46,.65,.25),'stone_light',.055)
            box('Bridge_cap',(x,y+.79,z),(.46,.10,.31),'stone',.035)
    # Beyond the playable square, grouped roofs/trees form the valley skyline.
    for x,z,blue in [(-16,-7,False),(-16,2,True),(-8,-17,False),(1,-17,True),(9,-17,False),(22,-7,True)]:
        box('House_terrace',(x,-.15,z),(6,.5,5.8),'grass_light',.3)
        house(x,z,3.5,3,2.2,blue)
        fence(x,z+2.5,5)
        garden(x,z+1.95,2.6)
    for i in range(26):
        x=rng.uniform(-23,23); z=rng.uniform(-28,-20)
        ball('Valley_hill',(x,-.2,z),(rng.uniform(3,5),rng.uniform(2,4),3),'grass')
        tree(x,z,1.3,rng.uniform(.9,1.5))
    for x,z in [(-18,8),(-19,-14),(-23,0),(21,5),(23,-13),(-8,21),(8,21)]:
        tree(x,z,-1.5,1.25)
    # A small windmill silhouette adds a farm landmark without a new location.
    x,z=-17,-17
    box('Mill_tower',(x,1.5,z),(1.9,3,1.9),'wall',.20)
    bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=1.42,depth=1.35,location=pos((x,3.65,z)))
    a.finish(bpy.context.object,'Mill_roof','roof_blue',False)
    ball('Mill_hub',(x,2.95,z+1.2),(.23,.23,.16),'timber')
    for i in range(4):
        t=i*math.pi/2+.4
        end=(x+2*math.cos(t),2.95+2*math.sin(t),z+1.2)
        rod('Mill_spar',(x,2.95,z+1.2),end,.055,'timber')
        sail=box('Mill_sail',(x+1.35*math.cos(t),2.95+1.35*math.sin(t),z+1.21),(.60,1.2,.06),'wall',.045)
        sail.rotation_euler.y=math.pi/2-t

def export(name, build):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.context.preferences.filepaths.file_preview_type='NONE'
    a.materials={}; a.current_parent=None
    a.current_parent=a.empty(name)
    build()
    a.current_parent=None
    a.combine_by_joint()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    triangles=0
    for obj in meshes:
        obj.data.calc_loop_triangles(); triangles+=len(obj.data.loop_triangles)
    report={'asset':name,'triangles':triangles,'meshes':len(meshes),'materials':len(a.materials),'source':'Original Blender geometry; user image used only for visual direction'}
    (SOURCE/(name+'_metrics.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(a.OUT/(name+'.glb')),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
    print('VILLAGE_ASSET',json.dumps(report),flush=True)

if __name__=='__main__':
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for name,build in [('village_guild',guild),('village_shop',shop),('village_plaza',paving),('village_borders',borders),('village_valley',backdrop)]:
        if not requested or name in requested: export(name,build)
