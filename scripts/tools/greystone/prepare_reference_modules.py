"""Validate new static GLBs and emit reusable collision scenes, without live changes."""
import json
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'scripts/tools'))
from asset_glb_validation import audit_glb
folder=ROOT/'scenes/world/greystone/reference_modules';folder.mkdir(parents=True,exist_ok=True)
metrics=json.loads((ROOT/'source_assets/greystone_reference_20261023/metrics.json').read_text())
reports=[]
for item in metrics:
    name=item['name']
    report=audit_glb(ROOT/f'assets/models/greystone/reference_modules/{name}.glb',maximum=12000,require_uv=True,require_rig=False)
    reports.append(report)
    assert report['status']=='PASS',(name,report)
    head=f'[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://assets/models/greystone/reference_modules/{name}.glb" id="Model"]\n'
    bodies=[]
    if item['category']=='building':
        w,d,h=(6,4.7,3) if name=='house_a' else (6.5,4.7,3)
        bodies=[((0,h/2,0),(w,h,d))]
        if name=='inn':bodies=[((-1,2.1,0),(7.2,4.2,6)),((3.2,1.6,-.1),(3.6,3.2,5.3))]
        if name=='inn':
            for x in [-3.6,1.6]:bodies.append(((x,1.38,4.28),(.20,2.76,.20)))
        elif name!='house_a':
            for x in [-3.35,3.35]:bodies.append(((x,1.38,3.73),(.20,2.76,.20)))
        if name=='item_shop':bodies.append(((1.6,.7,3.0),(2,1.25,.65)))
        if name=='weapon_shop':bodies += [((2.1,.85,2.6),(1.4,1.7,1.1)),((1.4,.55,3.8),(1.1,1.1,.55))]
    elif name=='wooden_bridge':
        bodies=[((0,-.15,0),(8,.30,3.4)),((0,.65,-1.58),(8,1.3,.16)),((0,.65,1.58),(8,1.3,.16))]
    elif name=='wooden_dock':bodies=[((0,-.15,0),(6,.3,5))]
    elif name=='stone_well':bodies=[((0,.75,0),(2.8,1.5,2.8))]
    elif name=='wooden_fence':bodies=[((0,.65,0),(3,1.3,.22))]
    elif name=='pine_tree_a':bodies=[((0,.7,0),(.45,1.4,.45))]
    elif name=='rock_medium':bodies=[((0,.6,0),(2.1,1.6,1.5))]
    elif name in ['barrel','crate']:bodies=[((0,.5,0),(1,1,1))]
    elif name in ['lamp_post','wooden_sign']:bodies=[((0,1,0),(.25,2,.25))]
    def vec(p):return 'Vector3('+','.join(map(str,p))+')'
    res=[];nodes=[f'[node name="{name}" type="Node3D"]\nmetadata/reference = "20261023 bottom asset strip"', '[node name="Model" parent="." instance=ExtResource("Model")]']
    for i,(pos,size) in enumerate(bodies):
        res.append(f'[sub_resource type="BoxShape3D" id="C{i}"]\nsize = {vec(size)}')
        nodes += [f'[node name="Body{i}" type="StaticBody3D" parent="."]\nposition = {vec(pos)}',f'[node name="Collision" type="CollisionShape3D" parent="Body{i}"]\nshape = SubResource("C{i}")']
    if item['category']=='building':nodes.append('[node name="DoorApproach" type="Marker3D" parent="."]\nposition = Vector3(-1,0.1,4.5)\nmetadata/door_height_m = 2.4\nmetadata/door_width_m = 1.65')
    (folder/f'{name}.tscn').write_text(head+'\n'.join(res+nodes)+'\n',encoding='utf-8')
(ROOT/'source_assets/greystone_reference_20261023/glb_audit.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf-8')
print('MODULE_AUDIT_PASS',len(reports),sum(r['triangles'] for r in reports))
library=['[gd_scene format=3]']
for i,item in enumerate(metrics):library.append(f'[ext_resource type="PackedScene" path="res://scenes/world/greystone/reference_modules/{item["name"]}.tscn" id="A{i}"]')
library += ['[sub_resource type="Environment" id="LibraryEnv"]\nbackground_mode = 1\nbackground_color = Color(0.14,0.19,0.21,1)\nambient_light_source = 3\nambient_light_energy = 0.35\nambient_light_color = Color(0.8,0.85,0.9,1)',
            '[node name="ReferenceAssetLibrary" type="Node3D"]',
            '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]\nenvironment = SubResource("LibraryEnv")',
            '[node name="Sun" type="DirectionalLight3D" parent="."]\nrotation_degrees = Vector3(-50,-30,0)\nlight_energy = 0.75\nshadow_enabled = true']
for i,item in enumerate(metrics):
    x,z=(i*13,0) if i<4 else (((i-4)%5)*10,-13-((i-4)//5)*8)
    library.append(f'[node name="{item["name"]}" parent="." instance=ExtResource("A{i}")]\nposition = Vector3({x},0,{z})')
library.append('[node name="Camera3D" type="Camera3D" parent="."]\nposition = Vector3(32,35,42)\nrotation_degrees = Vector3(-35,12,0)\nprojection = 1\nsize = 58.0\ncurrent = true')
(ROOT/'scenes/tools/greystone_reference_assets.tscn').write_text('\n'.join(library)+'\n',encoding='utf-8')
