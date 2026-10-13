"""Deterministic G02 terrain and layout generator. Run with Python 3 from any directory.

Native primitives intentionally validate scale before G03 Blender asset production.
Only writes the named Greystone scene files; never changes the production village.
"""
from pathlib import Path
import math
import json

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'scenes/world/greystone'
OUT.mkdir(parents=True, exist_ok=True)
TERRAIN = ROOT / 'source_assets/greystone_g02'
TERRAIN.mkdir(parents=True, exist_ok=True)
(TERRAIN / '.gdignore').write_text('',encoding='utf-8')


def height_at(x, z):
    """Continuous terraces. Slopes remain below CharacterBody3D's 45-degree limit."""
    clamp = lambda a: max(0, min(1, a))
    farm = 4 * clamp((-x-22)/12) * clamp((-z-20)/8)
    mine = 6 * clamp((x-8)/8) * clamp((-z-34)/14)
    inn = 2 * clamp((-x-10)/4) * clamp((-z-8)/4)
    return max(farm, mine, inn)


def bank_at(side, z):
    knots = [(-60,30),(-50,30),(-40,31),(-28,30),(-20,31),(0,30),(20,30),(36,30),(48,27),(60,25)] if side==30 else [(-60,38),(-50,38),(-40,40),(-28,38),(-20,39),(0,41),(20,46),(32,48),(48,52),(60,55)]
    for (a,x0),(b,x1) in zip(knots,knots[1:]):
        if a <= z <= b:
            return x0+(x1-x0)*(z-a)/(b-a)
    return knots[-1][1]


def warped_x(x, z):
    if x < -48:
        knots=[(-60,-50),(-48,-58),(-30,-55),(-14,-59),(10,-60),(28,-54),(42,-51),(60,-50)]
        edge=-50
        for (a,e0),(b,e1) in zip(knots,knots[1:]):
            if a <= z <= b:
                edge=e0+(e1-e0)*(z-a)/(b-a)
                break
        return edge+(x+60)*(-48-edge)/12
    if 22 < x <= 30:
        return x+(bank_at(30,z)-30)*(x-22)/8
    if x >= 38:
        return bank_at(38,z)+(x-38)*(60-bank_at(38,z))/22
    return x



class Scene:
    def __init__(self, name):
        self.resources = []
        self.nodes = [f'[node name="{name}" type="Node3D"]']
        self.index = 0
        self.external = ''
        self.assets = []
        self.boxes = []

    def group(self, name):
        self.nodes.append(f'[node name="{name}" type="Node3D" parent="."]')

    def box(self, name, parent, pos, size, color, solid=True, prism=False):
        self.boxes.append({'name':name,'position':pos,'size':size,'color':[float(c) for c in color.split(',')],'prism':prism})
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

    def surface(self, name, parent, triangles, color, solid=True, pos=(0,0,0)):
        """OBJ uses CCW; Godot collision arrays use the reversed, clockwise order."""
        self.index += 1
        i = self.index
        filename = name.lower() + '.obj'
        lines = ['# Original procedural Greystone G02 mesh; meters, Y up.']
        for tri in triangles:
            for v in tri:
                lines.append('v ' + ' '.join(f'{a:.5f}' for a in v))
        for t in range(len(triangles)):
            lines.append('f %d %d %d' % (t*3+1,t*3+2,t*3+3))
        (TERRAIN / filename).write_text('\n'.join(lines)+'\n',encoding='utf-8')
        self.assets.append({'file':filename,'color':[float(c) for c in color.split(',')],'position':pos})
        self.external += f'[ext_resource type="PackedScene" path="res://assets/models/greystone/terrain/{name.lower()}.glb" id="Mesh{i}"]\n'
        self.nodes.append(f'[node name="{name}" type="{"StaticBody3D" if solid else "Node3D"}" parent="{parent}"]\nposition = Vector3({", ".join(map(str,pos))})')
        path = parent + '/' + name
        self.nodes.append(f'[node name="Mesh" parent="{path}" instance=ExtResource("Mesh{i}")]')
        if parent == 'Roads':
            self.nodes.append(f'[node name="{name.lower()}" parent="{path}/Mesh" index="0"]\ncast_shadow = 0')
        if solid:
            points = ', '.join(f'{a:.5f}' for tri in triangles for v in [tri[0],tri[2],tri[1]] for a in v)
            self.resources.append(f'[sub_resource type="ConcavePolygonShape3D" id="C{i}"]\ndata = PackedVector3Array({points})')
            self.nodes.append(f'[node name="Collision" type="CollisionShape3D" parent="{path}"]\nshape = SubResource("C{i}")')

    def patch(self, name, parent, xmin, xmax, zmin, zmax, color, solid=True, offset=0):
        if parent=='Roads':
            # Clip the original terrain triangles; all generated road vertices stay
            # exactly on their supporting triangle even across a slope transition.
            def clip(poly,axis,bound,keep_greater):
                result=[]
                if not poly:return result
                for a,b in zip(poly,poly[1:]+poly[:1]):
                    ia=(a[axis]>=bound) if keep_greater else (a[axis]<=bound)
                    ib=(b[axis]>=bound) if keep_greater else (b[axis]<=bound)
                    if ia:result.append(a)
                    if ia != ib:
                        t=(bound-a[axis])/(b[axis]-a[axis])
                        result.append(tuple(a[j]+t*(b[j]-a[j]) for j in range(5)))
                return result
            triangles=[]
            for x in range(math.floor(xmin/2)*2,math.ceil(xmax/2)*2,2):
                for z in range(math.floor(zmin/2)*2,math.ceil(zmax/2)*2,2):
                    v=[(px,pz,warped_x(px,pz),height_at(warped_x(px,pz),pz),pz) for px,pz in [(x,z),(x,z+2),(x+2,z),(x+2,z+2)]]
                    for poly in [[v[0],v[1],v[2]],[v[2],v[1],v[3]]]:
                        for axis,bound,greater in [(0,xmin,True),(0,xmax,False),(1,zmin,True),(1,zmax,False)]:
                            poly=clip(poly,axis,bound,greater)
                        for n in range(1,len(poly)-1):
                            triangles.append(tuple((p[2],p[3]+offset,p[4]) for p in [poly[0],poly[n],poly[n+1]]))
            self.surface(name,parent,triangles,color,False)
            return
        xs = sorted(set([xmin,xmax]+[float(x) for x in range(math.ceil(xmin),math.floor(xmax)+1,2)]))
        zs = sorted(set([zmin,zmax]+[float(z) for z in range(math.ceil(zmin),math.floor(zmax)+1,2)]))
        triangles=[]
        for x0,x1 in zip(xs,xs[1:]):
            for z0,z1 in zip(zs,zs[1:]):
                a,b,c,d=[(warped_x(x,z),height_at(warped_x(x,z),z)+offset,z) for x,z in [(x0,z0),(x0,z1),(x1,z0),(x1,z1)]]
                triangles.extend([(a,b,c),(c,b,d)])
        self.surface(name,parent,triangles,color,solid)

    def rock(self, name, pos, size):
        x,y,z=pos
        w,h,d=size
        bottom=[(x+math.cos(n*math.tau/7)*w/2,y,z+math.sin(n*math.tau/7)*d/2) for n in range(7)]
        top=[(x+math.cos(n*math.tau/7)*w*.32,y+h*(.88+.12*(n%2)),z+math.sin(n*math.tau/7)*d*.32) for n in range(7)]
        triangles=[]
        for n in range(7):
            k=(n+1)%7
            triangles.extend([(bottom[n],top[n],bottom[k]),(bottom[k],top[n],top[k]),(top[n],(x,y+h,z),top[k])])
        self.surface(name,'Terrain',triangles,'0.42, 0.45, 0.43')

    def save(self, path, ext=''):
        path.write_text('[gd_scene format=3]\n' + ext + self.external + '\n' + '\n'.join(self.resources + self.nodes) + '\n', encoding='utf-8')


buildings = [
    ('inn', '旅館', (-20, 2, -18), (12, 9, 9), '0.62, 0.24, 0.13'),
    ('guild_hall', '冒險者公會', (0, 0, -30), (15, 11, 11), '0.24, 0.34, 0.45'),
    ('item_shop', '道具店', (-23, 0, 0), (8, 7, 7), '0.25, 0.36, 0.47'),
    ('weapon_shop', '武器店', (20, 0, -14), (8, 7, 7), '0.61, 0.31, 0.15'),
    ('house_a', '民宅 A', (-19, 0, 22), (7, 6, 6), '0.65, 0.30, 0.16'),
    ('house_b', '民宅 B', (19, 0, 22), (7, 8, 6), '0.28, 0.38, 0.47'),
    ('farm_house', '農舍', (-39, 4, -35), (7, 6, 6), '0.49, 0.31, 0.18'),
]
world = Scene('GreystoneVillage')
for group in ['Terrain', 'Roads', 'Buildings', 'Water', 'Landmarks', 'Bounds', 'Markers']:
    world.group(group)
world.patch('WestGround', 'Terrain', -60,30,-60,60,'0.42, 0.57, 0.28')
world.patch('EastGround', 'Terrain', 38,60,-60,60,'0.42, 0.57, 0.28')
triangles=[]
for z in range(-50,60,2):
    a,b,c,d=[(bank_at(side,pz),-3.6,pz) for side,pz in [(30,z),(30,z+2),(38,z),(38,z+2)]]
    triangles.extend([(a,b,c),(c,b,d)])
world.surface('River','Water',triangles,'0.16, 0.48, 0.65',False)
world.box('UpperRiver', 'Water', (34,5.3,-55),(8,0.2,10),'0.18, 0.51, 0.66',False)
world.box('Waterfall', 'Water', (34,0.9,-49.9),(8,9,0.2),'0.40, 0.72, 0.79',False)
world.box('Foam', 'Water', (34,-3.54,-48),(8,0.1,3),'0.65, 0.83, 0.83',False)
# Closed skirts below the shared terrain edge vertices; visible faceted river cliffs.
for name,x,zmin,zmax in [('WestBankCliff',30,-60,60),('EastBankCliff',38,-60,60),('WestOuterCliff',-60,-60,60),('EastOuterCliff',60,-60,60)]:
    triangles=[]
    for z in range(zmin,zmax,2):
        px=bank_at(x,z) if x in [30,38] else warped_x(x,z)
        nx=bank_at(x,z+2) if x in [30,38] else warped_x(x,z+2)
        a=(px,height_at(px,z),z); b=(nx,height_at(nx,z+2),z+2)
        c=(px,-6,z); d=(nx,-6,z+2)
        triangles.extend([(a,c,b),(b,c,d),(b,c,a),(d,c,b)])
    world.surface(name,'Terrain',triangles,'0.40, 0.43, 0.42',False)
for name,z in [('NorthSkirt',-60),('SouthSkirt',60)]:
    triangles=[]
    for xmin,xmax in [(-60,30),(38,60)]:
        for x in range(xmin,xmax,2):
            a=(warped_x(x,z),height_at(warped_x(x,z),z),z)
            b=(warped_x(x+2,z),height_at(warped_x(x+2,z),z),z)
            c=(a[0],-6,z);d=(b[0],-6,z)
            triangles.extend([(a,c,b),(b,c,d),(b,c,a),(d,c,b)])
    world.surface(name,'Terrain',triangles,'0.40, 0.43, 0.42',False)
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
    ('FarmRoad',(-29,0.014,-27),(34,0.028,3)),
    ('FarmLink',(-12,0.014,-18),(3,0.028,18))]:
    x,_,z=pos; w,_,d=size
    if name=='Plaza':
        rim=[(14*math.cos(n*math.tau/48),.045,14*math.sin(n*math.tau/48)) for n in range(48)]
        world.surface(name,'Roads',[((0,.045,0),rim[(n+1)%48],rim[n]) for n in range(48)],'0.72, 0.62, 0.43',False)
    else:
        world.patch(name,'Roads',x-w/2,x+w/2,z-d/2,z+d/2,'0.72, 0.62, 0.43',False,0.045)
# Farm beds on the flat upper terrace; no detailed crop assets in G02.
for n in range(4):
    world.box(f'FarmBed{n}','Landmarks',(-47+n*2.5,4.05,-46),(1.8,0.1,9),'0.34, 0.25, 0.14',False)
world.box('Bridge','Terrain',(34,-0.15,-28),(8,0.3,6),'0.45, 0.28, 0.14')
world.box('Dock','Terrain',(32,-0.15,32),(4,0.3,8),'0.45, 0.28, 0.14')
for x in [30.4,33.6]:
    for z in [28.4,35.6]:
        world.box(f'DockPier{int(x)}{int(z)}','Terrain',(x,-2,z),(0.4,4,0.4),'0.32, 0.22, 0.13')
# Rails leave the bridge and dock access open. They are visible safety boundaries.
for side in [30,38]:
    triangles=[]
    for z in range(-60,60):
        if -31 <= z < -25 or (side==30 and 28 <= z < 36):continue
        x0,x1=bank_at(side,z),bank_at(side,z+1)
        a=(x0,height_at(x0,z)-0.1,z);b=(x1,height_at(x1,z+1)-0.1,z+1)
        c=(x0,a[1]+1.3,z);d=(x1,b[1]+1.3,z+1)
        triangles.extend([(a,b,c),(c,b,d),(c,b,a),(d,b,c)])
    world.surface(f'RiverRim{side}','Bounds',triangles,'0.40, 0.43, 0.42')
for z in [-31,-25]:
    world.box('BridgeRail'+str(abs(z)),'Bounds',(34,0.6,z),(8,1.2,0.25),'0.45, 0.28, 0.14')
for name,pos,size in [('DockEnd',(34,0.6,32),(0.25,1.2,8)),('DockN',(32,0.6,28),(4,1.2,0.25)),('DockS',(32,0.6,36),(4,1.2,0.25))]:
    world.box(name,'Bounds',pos,size,'0.43, 0.44, 0.39')
# Perimeter follows terrain elevation instead of a tall box enclosing the map.
for edge in ['North','South','West','East']:
    triangles=[]
    for q in range(-60,60,2):
        x0,z0 = (q,-60 if edge=='North' else 60) if edge in ['North','South'] else (-60 if edge=='West' else 60,q)
        x1,z1 = (q+2,z0) if edge in ['North','South'] else (x0,q+2)
        x0,x1=warped_x(x0,z0),warped_x(x1,z1)
        a=(x0,height_at(x0,z0)-0.2,z0);b=(x1,height_at(x1,z1)-0.2,z1)
        c=(x0,a[1]+1.6,z0);d=(x1,b[1]+1.6,z1)
        triangles.extend([(a,b,c),(c,b,d),(c,b,a),(d,b,c)])
    world.surface(edge+'Boundary','Bounds',triangles,'0.40, 0.43, 0.42')
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
    world.nodes.append(f'[node name="{ident}" type="Marker3D" parent="Markers"]\nposition = Vector3({pos[0]}, {pos[1]+0.1}, {pos[2]+depth/2+2})')
world.box('WellBlock','Landmarks',(0,0.8,0),(2.8,1.6,2.8),'0.55, 0.56, 0.51')
for n,(x,z,w,h,d) in enumerate([(-52,-30,7,5,6),(-48,-24,7,3,5),(-36,-22,6,3,5),(-29,-38,4,3,7),(17,-51,5,5,7),(28,-53,3,6,6),(23,-57,12,6,5),(41,-52,6,6,7),(47,-45,6,4,8),(-51,-54,16,8,12),(-34,-55,17,9,10),(-17,-55,15,11,10),(1,-55,13,13,10),(-54,-12,7,5,9),(-52,27,10,6,12),(53,-30,10,8,12),(54,-12,9,6,11)]):
    world.rock(f'Cliff{n}',(x,height_at(x,z)-0.4,z),(w,h,d))
# Faceted boulders break up the river's engineered outline without occupying roads.
for n,z in enumerate([-44,-37,-16,-5,14,44,53]):
    x=bank_at(30,z)+0.9
    world.rock(f'RiverRock{n}',(x,-4,z),(3.0,height_at(x,z)+4.7,4.0))
for n,z in enumerate([-43,-12,6,25,43]):
    x=bank_at(38,z)-0.8
    world.rock(f'EastRiverRock{n}',(x,-4,z),(3.5,height_at(x,z)+5.2,5.0))
# Reused, deliberately simple pine silhouettes provide reference-image scale/context.
# G04 will deliver the full prop library; these are not detailed foliage assets.
pine=[]
for base,tip,radius in [(1.0,6.0,2.1),(3.6,8.0,1.65)]:
    rim=[(radius*math.cos(n*math.tau/7),base,radius*math.sin(n*math.tau/7)) for n in range(7)]
    pine.extend([(rim[n],(0,tip,0),rim[(n+1)%7]) for n in range(7)])
tree_places=[(-50,-40),(-48,-32),(-32,-48),(-26,-44),(-16,-46),(-9,-48),(6,-46),(12,-43),(9,-36),(-48,-17),(-44,-6),(-36,17),(-31,33),(-23,40),(-10,44),(12,44),(25,41),(48,-38),(48,-25),(52,-5),(55,16),(-43,40),(-40,50)]
first_x,first_z=tree_places[0]
world.surface('PineContext','Landmarks',pine,'0.15, 0.34, 0.22',False,(first_x,height_at(first_x,first_z),first_z))
pine_id=world.index
for n,(x,z) in enumerate(tree_places):
    y=height_at(x,z)
    if n:
        world.nodes.append(f'[node name="Pine{n}" parent="Landmarks" instance=ExtResource("Mesh{pine_id}")]\nposition = Vector3({x}, {y}, {z})')
    world.box(f'Trunk{n}','Landmarks',(x,y+0.8,z),(0.5,1.6,0.5),'0.32, 0.23, 0.14')
world.box('MineOpening','Landmarks',(23,8,-54.4),(4,4,0.2),'0.08, 0.10, 0.10',False)
for x in [20.7,25.3]:
    world.box('MinePost'+str(int(x)),'Landmarks',(x,8,-54),(0.5,4,0.6),'0.31, 0.21, 0.13')
world.box('MineLintel','Landmarks',(23,10,-54),(5.2,0.5,0.6),'0.31, 0.21, 0.13')
for name,title,pos in [('Spawn','村口',(0,0.1,48)),('Mine','礦坑入口',(24,6.1,-52)),('WorldExit','世界地圖出口',(-53,0.1,10)),('Dock','碼頭',(32,0.1,32)),('Bridge','上游木橋',(42,0.1,-28)),('Farm','農田',(-42,4.1,-29))]:
    world.nodes.append(f'[node name="{name}" type="Marker3D" parent="Markers"]\nposition = Vector3({", ".join(map(str,pos))})')
    world.label(name+'Label','Landmarks',title,(pos[0],pos[1]+3,pos[2]))
world.save(ROOT/'scenes/world/greystone_village.tscn',ext)
(TERRAIN/'manifest.json').write_text(json.dumps(world.assets,indent=2),encoding='utf-8')
(TERRAIN/'layout.json').write_text(json.dumps({'boxes':world.boxes,'buildings':buildings,'trees':[(x,height_at(x,z),z) for x,z in tree_places]},indent=2),encoding='utf-8')
print('Generated Greystone G02: 4m farm, 6m mine, continuous ramps, river cliffs and waterfall.')
