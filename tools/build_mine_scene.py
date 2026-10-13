"""Rebuild the original cutaway mine scene; no third-party assets or runtime generation."""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[1]
resources = ['[gd_scene format=3]',
    '[ext_resource type="Script" path="res://scripts/world/exploration_map.gd" id="Map"]',
    '[ext_resource type="Script" path="res://scripts/world/interactable.gd" id="Interact"]',
    '[ext_resource type="PackedScene" path="res://assets/models/cartoon/moss_rock.glb" id="RockArt"]',
    '[ext_resource type="PackedScene" path="res://assets/models/cartoon/path_strip.glb" id="PathArt"]']
nodes = []

def res(kind, name, **props):
    resources.append(f'[sub_resource type="{kind}" id="{name}"]\n' + '\n'.join(f'{k} = {v}' for k,v in props.items()))
    return f'SubResource("{name}")'

def node(name, node_type, parent='.', **props):
    nodes.append(f'[node name="{name}" type="{node_type}"' + (f' parent="{parent}"' if parent is not None else '') + ']\n' + '\n'.join(f'{k} = {v}' for k,v in props.items()))

def vec(x,y,z): return f'Vector3({x}, {y}, {z})'

for name, color in [('Stone','0.25,0.32,0.36,1'),('Earth','0.30,0.29,0.27,1'),('Wood','0.36,0.23,0.13,1'),('Metal','0.13,0.20,0.22,1')]:
    res('StandardMaterial3D', name, albedo_color=f'Color({color})', roughness='0.85')
res('StandardMaterial3D','Crystal',albedo_color='Color(0.2,0.8,0.86,1)', metallic='0.2',roughness='0.25',emission_enabled='true',emission='Color(0.05,0.45,0.55,1)',emission_energy_multiplier='0.8')
res('StandardMaterial3D','Lamp',albedo_color='Color(1,0.8,0.35,1)',emission_enabled='true',emission='Color(1,0.6,0.15,1)',emission_energy_multiplier='1.5')
res('Environment','MineEnvironment',background_mode='1',background_color='Color(0.045,0.065,0.085,1)',ambient_light_source='3',ambient_light_color='Color(0.50,0.65,0.8,1)',ambient_light_energy='0.75',reflected_light_source='2')
res('SystemFont','Font',font_names='PackedStringArray("Microsoft JhengHei")')
res('BoxMesh','Floor',size=vec(27,0.6,19))
res('BoxShape3D','FloorShape',size=vec(27,0.6,19))
res('BoxShape3D','WallX',size=vec(1,5,19))
res('BoxShape3D','WallZ',size=vec(27,5,1))
res('SphereMesh','Boulder',radius='1.0',height='2.0',radial_segments='24',rings='12')
res('CylinderMesh','Timber',top_radius='0.19',bottom_radius='0.22',height='3.8',radial_segments='24')
res('CylinderMesh','Plinth',top_radius='1.15',bottom_radius='1.45',height='0.45',radial_segments='32')
res('CylinderShape3D','CrystalShape',radius='1.0',height='2.6')
res('CylinderMesh','Gem',top_radius='0.0',bottom_radius='0.65',height='1.65',radial_segments='6')
res('BoxMesh','Rail',size=vec(18,0.10,0.08))
res('BoxMesh','Sleeper',size=vec(0.22,0.12,1.2))
res('SphereMesh','LampMesh',radius='0.18',height='0.36',radial_segments='24',rings='12')
nodes.append('[node name="Mine" type="Node3D" node_paths=PackedStringArray("default_spawn", "entrance_spawn", "story_zone", "extra_story_zones", "sequence_target", "sequence_light")]\nscript = ExtResource("Map")\nmap_id = &"mine"\ndisplay_name = "廢棄礦坑 · 星晶回廊"\nenvironment = SubResource("MineEnvironment")\nsunlight = 0.45\ndefault_spawn = NodePath("Entrance")\nentrance_spawn = NodePath("Entrance")\nstory_zone = NodePath("InnerArea")\nstory_trigger = &"mine_inner_area"\nstory_zone_radius = 2.8\nextra_story_zones = [NodePath("BossArea")]\nsequence_target = NodePath("Crystal/Prism")\nsequence_light = NodePath("Crystal/Glow")')
node('Entrance','Marker3D',position=vec(-8,0.1,0))
node('InnerArea','Marker3D',position=vec(-3.5,0,0))
node('BossArea','Marker3D',position=vec(4,0,0),**{'metadata/trigger':'"mine_boss_arena"','metadata/radius':'4.5'})
node('Floor','StaticBody3D',position=vec(0,-0.3,0))
node('Mesh','MeshInstance3D','Floor',mesh='SubResource("Floor")',material_override='SubResource("Earth")')
node('Collision','CollisionShape3D','Floor',shape='SubResource("FloorShape")')
for i,(x,z,shape) in enumerate([(-13.5,0,'WallX'),(13.5,0,'WallX'),(0,-9.5,'WallZ'),(0,9.5,'WallZ')]):
    node(f'Boundary{i}','StaticBody3D',position=vec(x,2,z))
    node('Collision','CollisionShape3D',f'Boundary{i}',shape=f'SubResource("{shape}")')
for i in range(23):
    node(f'Sleeper{i}','MeshInstance3D',position=vec(-10+i*0.7,0.07,-0.6),mesh='SubResource("Sleeper")',material_override='SubResource("Wood")')
for i,z in enumerate([-1.0,-0.2]):
    node(f'Rail{i}','MeshInstance3D',position=vec(-2,0.16,z),mesh='SubResource("Rail")',material_override='SubResource("Metal")')
# Scalloped stone banks keep a clear, walkable central route; foreground remains low.
for i in range(22):
    x=-12+(i%11)*2.4; z=-7 if i<11 else 7.7
    node(f'Bank{i}','MeshInstance3D',position=vec(round(x,2),0.65,z),scale=vec(round(1.7+0.3*math.sin(i*2),2),round((1.7 if i<11 else 0.8)+0.3*math.cos(i),2),1.6),mesh='SubResource("Boulder")',material_override='SubResource("Stone")')
for i in range(8):
    node(f'EastBank{i}','MeshInstance3D',position=vec(11.6,0.6,-6+i*1.8),scale=vec(1.3,1.5,1.4),mesh='SubResource("Boulder")',material_override='SubResource("Stone")')
for i,x in enumerate([-9,-5,0]):
    for j,z in enumerate([-3,3]):
        node(f'Timber{i}_{j}','MeshInstance3D',position=vec(x,1.8,z),mesh='SubResource("Timber")',material_override='SubResource("Wood")')
        node(f'Lamp{i}_{j}','MeshInstance3D',position=vec(x,2.3,z+(-0.25 if j else 0.25)),mesh='SubResource("LampMesh")',material_override='SubResource("Lamp")')
        node(f'Light{i}_{j}','OmniLight3D',position=vec(x,2.5,z),light_color='Color(1,0.72,0.35,1)',light_energy='0.8',omni_range='4.8')
    node(f'Beam{i}','MeshInstance3D',position=vec(x,3.65,0),rotation_degrees=vec(90,0,0),scale=vec(1,1.7,1),mesh='SubResource("Timber")',material_override='SubResource("Wood")')
for i,(x,z) in enumerate([(-6,-5),(-1,-5),(7,5),(9,-4)]):
    nodes.append(f'[node name="Rock{i}" parent="." instance=ExtResource("RockArt")]\nposition = {vec(x,0,z)}\nscale = Vector3(1.3, 1.2, 1.3)')
node('Crystal','Node3D',position=vec(5,0,0),script='ExtResource("Interact")',interaction_id='&"ancient_crystal"',kind='"story"',label='"調查異常星晶"',radius='3.0',required_flag='&"e005_done"')
node('Base','MeshInstance3D','Crystal',position=vec(0,0.23,0),mesh='SubResource("Plinth")',material_override='SubResource("Metal")')
node('Prism','Node3D','Crystal',position=vec(0,1.85,0))
node('Upper','MeshInstance3D','Crystal/Prism',position=vec(0,0.7,0),mesh='SubResource("Gem")',material_override='SubResource("Crystal")')
node('Lower','MeshInstance3D','Crystal/Prism',position=vec(0,-0.7,0),rotation_degrees=vec(180,0,0),mesh='SubResource("Gem")',material_override='SubResource("Crystal")')
node('Body','StaticBody3D','Crystal',position=vec(0,1.3,0))
node('Collision','CollisionShape3D','Crystal/Body',shape='SubResource("CrystalShape")')
node('Glow','OmniLight3D','Crystal',position=vec(0,2,0),light_color='Color(0.25,0.85,1,1)',light_energy='1.2',omni_range='7.0')
node('Exit','Node3D',position=vec(-11,0,0),script='ExtResource("Interact")',interaction_id='&"to_forest"',kind='"exit"',label='"返回低語森林"',destination='&"forest"',spawn_key='&"return"')
for parent,text in [('Crystal','古代星晶'),('Exit','低語森林 ←')]:
    node('Name','Label3D',parent,position=vec(0,3.6 if parent=='Crystal' else 2,0),billboard='1',font='SubResource("Font")',text=f'"{text}"',font_size='40',pixel_size='0.01',outline_size='10')
(ROOT/'scenes/world/mine.tscn').write_text('\n\n'.join(resources+nodes)+'\n',encoding='utf-8')
print('Built scenes/world/mine.tscn')

# A distinct, open battle composition using the same mine materials.
nodes = []
node('BattleMine', 'Node3D', parent=None)
node('Floor','MeshInstance3D',position=vec(0,-0.32,0),mesh='SubResource("Floor")',material_override='SubResource("Earth")')
for i,x in enumerate([-9,-6,-3,0,3,6,9]):
    node(f'BackRock{i}','MeshInstance3D',position=vec(x,0.65,-5.6),scale=vec(1.9,1.2+(i%3)*0.3,1.7),mesh='SubResource("Boulder")',material_override='SubResource("Stone")')
for i,x in enumerate([-7,7]):
    node(f'Post{i}','MeshInstance3D',position=vec(x,1.8,-3.5),mesh='SubResource("Timber")',material_override='SubResource("Wood")')
    node(f'Lamp{i}','MeshInstance3D',position=vec(x,2.5,-3.2),mesh='SubResource("LampMesh")',material_override='SubResource("Lamp")')
    node(f'WarmLight{i}','OmniLight3D',position=vec(x,2.5,-3),light_color='Color(1,0.7,0.3,1)',light_energy='1.8',omni_range='7')
for i,x in enumerate([-4,1,5]):
    node(f'Ore{i}','MeshInstance3D',position=vec(x,1.0,-4.3),rotation_degrees=vec(0,i*20,15),scale=vec(0.5,0.7,0.5),mesh='SubResource("Gem")',material_override='SubResource("Crystal")')
(ROOT/'scenes/battle/battle_mine.tscn').write_text('\n\n'.join(resources+nodes)+'\n',encoding='utf-8')
print('Built scenes/battle/battle_mine.tscn')
