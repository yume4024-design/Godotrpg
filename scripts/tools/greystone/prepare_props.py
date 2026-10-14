"""Build reusable Godot wrappers and asset preview after Blender export."""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[3]
out=ROOT/'scenes/world/greystone/props';out.mkdir(exist_ok=True)
metrics=json.loads((ROOT/'source_assets/greystone_g04/metrics.json').read_text())
collisions={'stone_well':[((0,.7,0),(3.3,1.4,3.3))],
 'wooden_bridge':[((0,-.15,0),(8,.3,6)),((0,.6,-3),(8,1.2,.25)),((0,.6,3),(8,1.2,.25))],
 'wooden_dock':[((0,-.15,0),(4,.3,8)),((2,.6,0),(.25,1.2,8)),((0,.6,-4),(4,1.2,.25)),((0,.6,4),(4,1.2,.25))],
 'wooden_fence':[((0,.65,0),(3,1.3,.2))], 'lamp_post':[((0,1.5,0),(.24,3,.24))],
 'wooden_sign':[((0,.9,0),(.2,1.8,.2))], 'barrel':[((0,.6,0),(1,1.2,1))],
 'crate':[((0,.5,0),(1,1,1))], 'pine_tree_a':[((0,.8,0),(.5,1.6,.5))],
 'pine_tree_b':[((0,.8,0),(.5,1.6,.5))], 'rock_small':[((0,.4,0),(1,.8,.8))],
 'rock_medium':[((0,.9,0),(2,1.8,1.6))], 'rock_cliff':[((0,2,0),(5,4,4))]}
ext=[];nodes=[]
for i,m in enumerate(metrics):
 name=m['name'];resources=[];body=[]
 for j,(pos,size) in enumerate(collisions.get(name,[])):
  resources.append(f'[sub_resource type="BoxShape3D" id="C{j}"]\nsize = Vector3{size}')
  body.append(f'[node name="Body{j}" type="StaticBody3D" parent="."]\nposition = Vector3{pos}\n[node name="Collision" type="CollisionShape3D" parent="Body{j}"]\nshape = SubResource("C{j}")')
 text=f'[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://assets/models/greystone/props/{name}.glb" id="Visual"]\n'+'\n'.join(resources)+f'\n[node name="{name}" type="Node3D"]\n[node name="Visual" parent="." instance=ExtResource("Visual")]\n'+'\n'.join(body)+'\n'
 (out/(name+'.tscn')).write_text(text)
 ext.append(f'[ext_resource type="PackedScene" path="res://scenes/world/greystone/props/{name}.tscn" id="P{i}"]')
 x=(i%5)*12;z=(i//5)*12
 nodes.append(f'[node name="{name}" parent="Assets" instance=ExtResource("P{i}")]\nposition = Vector3({x},0,{z})\n[node name="Label{i}" type="Label3D" parent="."]\nposition = Vector3({x},0.3,{z+5})\ntext = "{name}"\nbillboard = 1\nfont_size = 32\npixel_size = 0.03')
 imp=ROOT/f'assets/models/greystone/props/{name}.glb.import'
 if imp.exists():
  s=imp.read_text();s=re.sub(r'import_script/path="[^"]*"','import_script/path="res://scripts/tools/greystone/prop_import.gd"',s);imp.write_text(s)
preview='[gd_scene format=3]\n'+'\n'.join(ext)+'''\n[sub_resource type="Environment" id="Env"]
background_mode = 1
background_color = Color(0.22,0.29,0.32,1)
ambient_light_source = 3
ambient_light_color = Color(1,1,1,1)
ambient_light_energy = 0.65
[node name="GreystoneAssetPreview" type="Node3D"]
[node name="Assets" type="Node3D" parent="."]
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Env")
[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-55,-25,0)
light_energy = 1.1
[node name="Camera3D" type="Camera3D" parent="."]
position = Vector3(60,58,75)
rotation_degrees = Vector3(-45,32,0)
projection = 1
size = 76.0
current = true
'''+'\n'.join(nodes)+'\n'
(ROOT/'scenes/world/greystone_asset_preview.tscn').write_text(preview)
print('Prepared',len(metrics),'PackedScenes and asset preview')
