"""Assemble authored mine chunks, story hooks and lights as editable PackedScenes."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
layout=json.loads((ROOT/'data/world/mine_reference_layout.json').read_text(encoding='utf8'))
manifest=json.loads((ROOT/'assets/models/mine_reference/manifest.json').read_text(encoding='utf8'))
out=ROOT/'scenes/world/mine_reference';out.mkdir(parents=True,exist_ok=True)
def v(p):return 'Vector3('+', '.join(str(x) for x in p)+')'
lines=['[gd_scene format=3]','[ext_resource type="Script" path="res://scripts/world/mine_reference_geometry.gd" id="Geometry"]']
for i,zone in enumerate(manifest['zones']):lines.append(f'[ext_resource type="PackedScene" path="{zone["path"]}" id="{i}"]')
lines+=['[node name="MineReferenceMaster" type="Node3D"]','script = ExtResource("Geometry")']
for i,zone in enumerate(manifest['zones']):lines += [f'[node name="{zone["zone"]}" parent="." instance=ExtResource("{i}")]']
(out/'geometry.tscn').write_text('\n'.join(lines)+'\n',encoding='utf8')
lines=['[gd_scene format=3]',
'[ext_resource type="Script" path="res://scripts/world/exploration_map.gd" id="Map"]',
'[ext_resource type="Script" path="res://scripts/world/interactable.gd" id="Interact"]',
'[ext_resource type="PackedScene" path="res://scenes/world/mine_reference/geometry.tscn" id="Geometry"]',
'[ext_resource type="PackedScene" path="res://scenes/world/greystone/props/crystal_blue.tscn" id="CrystalArt"]',
'[ext_resource type="PackedScene" path="res://scenes/characters/crystal_bat_visual.tscn" id="Bat"]',
'[ext_resource type="PackedScene" path="res://scenes/characters/ore_beetle_visual.tscn" id="Beetle"]',
'[sub_resource type="CylinderShape3D" id="CrystalCollision"]','radius = 0.7','height = 3.2',
'[sub_resource type="Environment" id="Environment"]','background_mode = 1','background_color = Color(0.035,0.055,0.09,1)','ambient_light_source = 3','ambient_light_color = Color(0.54,0.60,0.70,1)','ambient_light_energy = 0.38','reflected_light_source = 2',
'[node name="Mine" type="Node3D" node_paths=PackedStringArray("default_spawn","entrance_spawn","story_zone","extra_story_zones","sequence_target","sequence_light")]','script = ExtResource("Map")','map_id = &"mine"','display_name = "廢棄礦坑 · 地底星晶坑道"','environment = SubResource("Environment")','sunlight = 0.14','default_camera_size = 22.0','default_spawn = NodePath("Entrance")','entrance_spawn = NodePath("Entrance")','story_zone = NodePath("InnerArea")','story_zone_radius = 6.5','story_trigger = &"mine_inner_area"','extra_story_zones = [NodePath("BossArea"), NodePath("CampNorthArea"), NodePath("CampEastArea")]','sequence_target = NodePath("Crystal/Prism")','sequence_light = NodePath("Crystal/Glow")','[node name="Geometry" parent="." instance=ExtResource("Geometry")]']
for name,p,extras in [('Entrance',layout['story']['entrance'],[]),('InnerArea',layout['story']['inner'],[]),('BossArea',layout['story']['boss'],['metadata/trigger = "mine_boss_arena"','metadata/radius = 4.5']),('CampNorthArea',[-36,0,24],['metadata/trigger = "mine_inner_area"','metadata/radius = 4.0']),('CampEastArea',[-26,0,32],['metadata/trigger = "mine_inner_area"','metadata/radius = 4.0'])]:
    lines += [f'[node name="{name}" type="Marker3D" parent="."]','position = '+v(p)]+extras
lines += ['[node name="Crystal" type="Node3D" parent="."]','script = ExtResource("Interact")','position = '+v(layout['story']['crystal']),'interaction_id = &"ancient_crystal"','kind = "story"','label = "調查核心古代星晶"','radius = 3.0','required_flag = &"e005_done"','[node name="Prism" parent="Crystal" instance=ExtResource("CrystalArt")]','scale = Vector3(2.2,2.2,2.2)','[node name="Glow" type="OmniLight3D" parent="Crystal"]','position = Vector3(0,3,0)','light_color = Color(0.12,0.55,1,1)','light_energy = 2.2','omni_range = 12.0',
'[node name="Exit" type="Node3D" parent="."]','script = ExtResource("Interact")','position = '+v(layout['story']['exit']),'interaction_id = &"to_forest"','kind = "exit"','label = "返回低語森林"','destination = &"forest"','spawn_key = &"return"','radius = 2.6']
lines += ['[node name="Solid" type="StaticBody3D" parent="Crystal"]','[node name="Shape" type="CollisionShape3D" parent="Crystal/Solid"]','position = Vector3(0,1.6,0)','shape = SubResource("CrystalCollision")']
for i,p in enumerate(layout['lights']):lines += [f'[node name="WarmLight{i}" type="OmniLight3D" parent="."]','position = '+v(p),'light_color = Color(1,0.51,0.16,1)','light_energy = 3.8','omni_range = 13.0','shadow_enabled = false','light_bake_mode = 0']
for i,p in enumerate([[-12,10,-35],[10,-2,0],[42,4,42]]):lines += [f'[node name="BlueLight{i}" type="OmniLight3D" parent="."]','position = '+v(p),'light_color = Color(0.12,0.55,1,1)','light_energy = 1.6','omni_range = 11.0','shadow_enabled = false']
for name,identity,battle,p,art in [('CrystalBat','crystal_bat','X003',[-41,3,-5],'Bat'),('OreBeetle','ore_beetle','X004',[37,7,-17],'Beetle')]:
    lines += [f'[node name="{name}" type="Node3D" parent="."]','script = ExtResource("Interact")','position = '+v(p),f'interaction_id = &"wild_{identity}"','kind = "battle"',f'battle_id = &"{battle}"','required_flag = &"e004_done"','label = "坑道魔物 · 挑戰（無獎勵）"',f'[node name="Appearance" parent="{name}" instance=ExtResource("{art}")]']
lines.insert(1,'[ext_resource type="Script" path="res://scripts/world/mine_reference_geometry.gd" id="CrystalSurface"]')
prism_index=lines.index('[node name="Prism" parent="Crystal" instance=ExtResource("CrystalArt")]')
lines[prism_index+1:prism_index+1]=['script = ExtResource("CrystalSurface")','build_collisions = false']
for name,p,energy,radius in [('CampFireLight',[-34,1.5,36],1.5,7),('CoreTorchLeft',[34,3,43],2.0,10),('CoreTorchRight',[48,3,46],2.0,10)]:
    lines += [f'[node name="{name}" type="OmniLight3D" parent="."]','position = '+v(p),'light_color = Color(1,0.51,0.16,1)',f'light_energy = {energy}',f'omni_range = {radius}','shadow_enabled = false']
(out/'mine.tscn').write_text('\n'.join(lines)+'\n',encoding='utf8')
print('MINE_SCENE_WRITTEN',len(manifest['zones']),len(manifest['collisions']))
