"""Deterministic G01 whitebox generator. Run with Python 3 from any directory.

Native primitives intentionally validate scale before G03 Blender asset production.
Only writes the named Greystone scene files; never changes the production village.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'scenes/world/greystone'
OUT.mkdir(parents=True, exist_ok=True)


class Scene:
    def __init__(self, name):
        self.resources = []
        self.nodes = [f'[node name="{name}" type="Node3D"]']
        self.index = 0

    def group(self, name):
        self.nodes.append(f'[node name="{name}" type="Node3D" parent="."]')

    def box(self, name, parent, pos, size, color, solid=True, prism=False):
        self.index += 1
        i = self.index
        vec = lambda v: 'Vector3(%s)' % ', '.join(map(str, v))
        self.resources.extend([
            f'[sub_resource type="StandardMaterial3D" id="M{i}"]\nalbedo_color = Color({color}, 1)\nroughness = 0.95',
            f'[sub_resource type="{"PrismMesh" if prism else "BoxMesh"}" id="G{i}"]\nsize = {vec(size)}\nmaterial = SubResource("M{i}")'])
        self.nodes.append(f'[node name="{name}" type="{"StaticBody3D" if solid else "Node3D"}" parent="{parent}"]\nposition = {vec(pos)}')
        path = name if parent == '.' else parent + '/' + name
        self.nodes.append(f'[node name="Mesh" type="MeshInstance3D" parent="{path}"]\nmesh = SubResource("G{i}")')
        if solid:
            self.resources.append(f'[sub_resource type="BoxShape3D" id="C{i}"]\nsize = {vec(size)}')
            self.nodes.append(f'[node name="Collision" type="CollisionShape3D" parent="{path}"]\nshape = SubResource("C{i}")')

    def label(self, name, parent, text, pos):
        self.nodes.append(f'[node name="{name}" type="Label3D" parent="{parent}"]\nposition = Vector3({", ".join(map(str,pos))})\nbillboard = 1\ntext = "{text}"\nfont_size = 48\npixel_size = 0.025\noutline_size = 8')

    def save(self, path, ext=''):
        path.write_text('[gd_scene format=3]\n' + ext + '\n' + '\n'.join(self.resources + self.nodes) + '\n', encoding='utf-8')


buildings = [
    ('inn', '旅館', (-20, 0, -18), (12, 9, 9), '0.62, 0.24, 0.13'),
    ('guild_hall', '冒險者公會', (0, 0, -30), (15, 11, 11), '0.24, 0.34, 0.45'),
    ('item_shop', '道具店', (-23, 0, 0), (8, 7, 7), '0.25, 0.36, 0.47'),
    ('weapon_shop', '武器店', (20, 0, -14), (8, 7, 7), '0.61, 0.31, 0.15'),
    ('house_a', '民宅 A', (-19, 0, 22), (7, 6, 6), '0.65, 0.30, 0.16'),
    ('house_b', '民宅 B', (19, 0, 22), (7, 8, 6), '0.28, 0.38, 0.47'),
    ('farm_house', '農舍', (-39, 0, -35), (7, 6, 6), '0.49, 0.31, 0.18'),
]
world = Scene('GreystoneVillage')
for group in ['Terrain', 'Roads', 'Buildings', 'Water', 'Landmarks', 'Bounds', 'Markers']:
    world.group(group)
world.box('WestGround', 'Terrain', (-15, -1, 0), (90, 2, 120), '0.42, 0.57, 0.28')
world.box('EastGround', 'Terrain', (49, -1, 0), (22, 2, 120), '0.42, 0.57, 0.28')
world.box('River', 'Water', (34, -0.7, 0), (8, 0.2, 120), '0.16, 0.48, 0.65', False)
for name, pos, size in [
    ('Plaza',(0,0.012,0),(28,0.024,28)),
    ('SouthRoad',(0,0.014,36),(6,0.028,48)),
    ('NorthRoad',(0,0.014,-18),(6,0.028,8)),
    ('WestRoad',(-37,0.014,10),(46,0.028,6)),
    ('InnRoad',(-13,0.014,-9),(20,0.028,6)),
    ('ShopRoad',(-17,0.014,5),(14,0.028,3)),
    ('MineRoad',(24,0.014,-35),(6,0.028,44)),
    ('BridgeRoad',(20,0.014,-28),(20,0.028,6)),
    ('EastRoad',(24,0.014,0),(6,0.028,38)),
    ('EastLink',(19,0.014,10),(14,0.028,6)),
    ('SouthCross',(0,0.014,29),(46,0.028,3)),
    ('DockRoad',(25,0.014,32),(10,0.028,4)),
    ('FarmRoad',(-34,0.014,-27),(24,0.028,3))]:
    world.box(name,'Roads',pos,size,'0.72, 0.62, 0.43',False)
world.box('Bridge','Terrain',(34,-0.15,-28),(8,0.3,6),'0.45, 0.28, 0.14')
world.box('Dock','Terrain',(32,-0.15,32),(4,0.3,8),'0.45, 0.28, 0.14')
# Rails leave the bridge and dock access open. They are visible safety boundaries.
for side in [30,38]:
    for n,z,length in [('North',-45.5,29),('Middle',1.5,53),('South',48,24)]:
        world.box(f'Bank{side}{n}','Bounds',(side,0.6,z),(0.35,1.2,length),'0.43, 0.44, 0.39')
    if side == 38:
        world.box('EastDockBank','Bounds',(38,0.6,32),(0.35,1.2,8),'0.43, 0.44, 0.39')
for z in [-31,-25]:
    world.box('BridgeRail'+str(abs(z)),'Bounds',(34,0.6,z),(8,1.2,0.25),'0.45, 0.28, 0.14')
for name,pos,size in [('DockEnd',(34,0.6,32),(0.25,1.2,8)),('DockN',(32,0.6,28),(4,1.2,0.25)),('DockS',(32,0.6,36),(4,1.2,0.25)),('North',(0,1,-60),(120,2,1)),('South',(0,1,60),(120,2,1)),('West',(-60,1,0),(1,2,120)),('East',(60,1,0),(1,2,120))]:
    world.box(name,'Bounds',pos,size,'0.43, 0.44, 0.39')
ext = ''
for ident, title, pos, (width,height,depth), roof in buildings:
    module = Scene('Building')
    module.box('Walls','.',(0,height*0.34,0),(width,height*0.68,depth),'0.80, 0.73, 0.57')
    module.box('Roof','.',(0,height*0.84,0),(width+0.6,height*0.32,depth+0.6),roof,False,True)
    module.box('DoorMarker','.',(0,1,depth/2+0.035),(1.6,2,0.07),'0.29, 0.20, 0.13',False)
    module.label('Name','.',title,(0,height+1,0))
    module.save(OUT/(ident+'_blockout.tscn'))
    ext += f'[ext_resource type="PackedScene" path="res://scenes/world/greystone/{ident}_blockout.tscn" id="{ident}"]\n'
    world.nodes.append(f'[node name="{ident.title().replace("_","")}" parent="Buildings" instance=ExtResource("{ident}")]\nposition = Vector3({", ".join(map(str,pos))})')
    world.nodes.append(f'[node name="{ident}" type="Marker3D" parent="Markers"]\nposition = Vector3({pos[0]}, 0.1, {pos[2]+depth/2+2})')
world.box('WellBlock','Landmarks',(0,0.8,0),(2.8,1.6,2.8),'0.55, 0.56, 0.51')
for name,title,pos in [('Spawn','村口',(0,0.1,48)),('Mine','礦坑入口',(24,0.1,-52)),('WorldExit','世界地圖出口',(-53,0.1,10)),('Dock','碼頭',(32,0.1,32)),('Bridge','上游木橋',(42,0.1,-28)),('Farm','農田',(-42,0.1,-24))]:
    world.nodes.append(f'[node name="{name}" type="Marker3D" parent="Markers"]\nposition = Vector3({", ".join(map(str,pos))})')
    world.label(name+'Label','Landmarks',title,(pos[0],3,pos[2]))
world.save(ROOT/'scenes/world/greystone_village.tscn',ext)
print('Generated Greystone G01: 120m bounds, 7 reusable building blocks, roads, river barriers.')
