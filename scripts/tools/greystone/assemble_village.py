"""G05 assembly of existing buildings and replaceable G04 prop placeholders.

Called by build_layout.py; static PackedScenes remain editable in Godot.
No production map, gameplay state, or save resource is touched.
"""
import math


def assemble(world, scene_type, out, height_at):
    props = out / 'placeholders'
    props.mkdir(exist_ok=True)
    wood = '0.43, 0.29, 0.16'
    stone = '0.60, 0.59, 0.51'
    world.group('Props')
    world.group('ActivitySpaces')

    def module(name):
        s = scene_type(name.title().replace('_', ''))
        s.nodes[0] += '\nmetadata/stage = "G04 replaceable placeholder"'
        return s

    def cylinder(s, name, pos, radius, height, color, top=None):
        s.index += 1
        i = s.index
        s.resources += [
            f'[sub_resource type="StandardMaterial3D" id="M{i}"]\nalbedo_color = Color({color}, 1)',
            f'[sub_resource type="CylinderMesh" id="G{i}"]\nmaterial = SubResource("M{i}")\ntop_radius = {radius if top is None else top}\nbottom_radius = {radius}\nheight = {height}\nradial_segments = 12']
        s.nodes.append(f'[node name="{name}" type="MeshInstance3D" parent="."]\nposition = Vector3({pos[0]}, {pos[1]}, {pos[2]})\nmesh = SubResource("G{i}")')

    def register(name, s):
        s.save(props / (name + '.tscn'))
        world.external += f'[ext_resource type="PackedScene" path="res://scenes/world/greystone/placeholders/{name}.tscn" id="Prop_{name}"]\n'

    def place(name, ident, x, y, z, angle=0):
        world.nodes.append(f'[node name="{name}" parent="Props" instance=ExtResource("Prop_{ident}")]\nposition = Vector3({x}, {y}, {z})\nrotation = Vector3(0, {angle}, 0)')

    s = module('well')
    cylinder(s, 'Foundation', (0,.12,0), 2.3,.24,stone)
    cylinder(s, 'DarkWater', (0,.45,0), 1.1,.05,'0.12, 0.24, 0.28')
    for n in range(12):
        a=n*math.tau/12
        s.box(f'Stone{n}', '.', (1.35*math.cos(a),.65,1.35*math.sin(a)),(.68,1.0,.68),stone,False)
    for x in [-1.35,1.35]:
        s.box('Post'+str(x),'.',(x,1.8,0),(.22,2.4,.22),wood,False)
    s.box('Crossbar','.',(0,2.95,0),(3.2,.25,.3),wood,False)
    s.box('Rope','.',(0,1.8,0),(.06,1.9,.06),wood,False)
    s.collider('WellBody',(0,.7,0),(3.3,1.4,3.3))
    register('well',s)
    place('CentralWell','well',0,0,0)

    # Decks reuse G02 supporting collision. These modules contain only visuals.
    for ident,width,depth in [('bridge_deck',8,6),('dock_deck',4,8)]:
        s=module(ident)
        for n in range(int(width*2)):
            s.box(f'Plank{n}','.',(-width/2+.25+n*.5,.025,0),(.47,.05,depth),wood,False)
        for x in [-width/2+.15,width/2-.15]:
            for z in [-depth/2+.2,depth/2-.2]:
                s.box(f'Post{x}_{z}','.',(x,.7,z),(.25,1.4,.25),wood,False)
        register(ident,s)
    place('UpstreamBridge','bridge_deck',34,0,-28)
    place('LakesideDock','dock_deck',32,0,32)

    s=module('fence')
    for x in [-1.4,1.4]:
        s.box('Post'+str(x),'.',(x,.65,0),(.18,1.3,.18),wood,False)
    for y in [.45,.95]:
        s.box('Rail'+str(y),'.',(0,y,0),(3,.12,.12),wood,False)
    s.collider('Barrier',(0,.65,0),(3,1.3,.2))
    register('fence',s)
    # Gardens remain outside door approaches and main paths.
    for n,(x,z,angle) in enumerate([(-25,20,0),(-22,20,0),(-16,20,0),(-13,20,0),(14,20,0),(20,18,0),(-48,-48,0),(-45,-48,0),(-42,-48,0),(-39,-48,0),(-49,-43,math.pi/2),(-49,-40,math.pi/2)]):
        place(f'GardenFence{n}','fence',x,height_at(x,z),z,angle)

    s=module('lamp')
    s.box('Pole','.',(0,1.5,0),(.16,3,.16),wood,False)
    s.box('Lantern','.',(0,3.1,0),(.45,.55,.45),'0.95, 0.72, 0.30',False)
    s.box('Cap','.',(0,3.45,0),(.6,.2,.6),wood,False,True)
    s.collider('PoleBody',(0,1.5,0),(.24,3,.24))
    register('lamp',s)
    for n,(x,z) in enumerate([(-5,15),(5,15),(-9,-6),(9,-6),(-25,-11),(6,-19),(28,-32),(28,-24),(27,37),(-5,45),(5,45)]):
        place(f'Lamp{n}','lamp',x,height_at(x,z),z)

    s=module('crop')
    cylinder(s,'Leaves',(0,.3,0),.35,.6,'0.30, 0.48, 0.18',.05)
    register('crop',s)
    for row in range(4):
        for col in range(7):
            place(f'Crop{row}_{col}','crop',-47+row*2.5,4.1,-49+col)

    s=module('sign')
    s.box('Post','.',(0,.9,0),(.18,1.8,.18),wood,False)
    s.box('Board','.',(0,1.65,0),(1.6,.65,.15),wood,False)
    s.collider('PostBody',(0,.9,0),(.2,1.8,.2))
    register('sign',s)
    for name,x,z,title in [('EntranceSign',-4,48,'灰石村'),('ExitSign',-51,14,'世界道路'),('MineSign',27,-49,'礦坑'),('FarmSign',-33,-30,'農田')]:
        place(name,'sign',x,height_at(x,z),z)
        world.label(name+'Text','Props',title,(x,height_at(x,z)+2.2,z))

    s=module('waterwheel')
    # Vertical wheel on the eastern bank-facing side; decorative, no traversal.
    for n in range(12):
        a=n*math.tau/12
        s.box(f'Paddle{n}','.',(0,math.cos(a)*2.3,math.sin(a)*2.3),(.9,.48,.48),wood,False)
    s.box('VerticalSpoke','.',(0,0,0),(.28,4.7,.25),wood,False)
    s.box('HorizontalSpoke','.',(0,0,0),(.28,.25,4.7),wood,False)
    register('waterwheel',s)
    place('RiverWaterwheel','waterwheel',31.0,-.8,-4)

    # Flat road links complete the visible loop and building forecourts.
    for name,pos,size in [
        ('NorthCross',(12,.05,-22),(24,.02,3)),
        ('GuildForecourt',(0,.05,-21),(10,.02,5)),
        ('WestHousingApproach',(-19,.05,27),(4,.02,5)),
        ('EastHousingApproach',(19,.05,27),(4,.02,5)),
        ('FarmCourtyard',(-39,4.05,-30),(10,.02,4)),
        ('FarmBedAccess',(-36,4.05,-40),(3,.02,18))]:
        world.box(name,'Roads',pos,size,'0.72, 0.62, 0.43',False)

    for name,x,y,z in [('Inn',-20,2,-11),('Guild',0,0,-22),('Items',-23,0,6),('Weapons',20,0,-8),('HouseA',-19,0,28),('HouseB',19,0,28),('Farm',-39,4,-30)]:
        y = height_at(x,z)
        world.nodes.append(f'[node name="{name}" type="Marker3D" parent="ActivitySpaces"]\nposition = Vector3({x}, {y}, {z})\nmetadata/clear_radius_m = 1.0\nmetadata/purpose = "G06 NPC forecourt reserve; no NPC logic"')
