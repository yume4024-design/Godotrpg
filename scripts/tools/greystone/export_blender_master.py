"""Export an existing master .blend by collections; retain each mesh as a node."""
import bpy,json,sys,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
SOURCE=ROOT/'source_assets/greystone_blender_20261023/greystone_master.blend'
OUT=ROOT/'assets/models/greystone/blender_master'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
parser=argparse.ArgumentParser()
parser.add_argument('--only',nargs='+',default=[])
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf8')) if args.only else []
def record(row):
    for i,previous in enumerate(manifest):
        if previous['collection']==row['collection']:
            manifest[i]=row;return
    manifest.append(row)
placements=json.loads((ROOT/'source_assets/greystone_blender_20261023/manifest.json').read_text(encoding='utf8'))['building_placements']
asset_for_name={row[1]:row[0] for row in placements}
for collection in list(bpy.context.scene.collection.children):
    if collection.name=='Review':continue
    if args.only and collection.name not in args.only:continue
    meshes=[o for o in collection.all_objects if o.type=='MESH']
    if not meshes:continue
    if collection.name=='Buildings_Candidate':
        # Keep large textured modules in separate reusable files, sharing one
        # PackedScene per asset instead of one 100+ MB building bundle.
        modules=OUT/'buildings';modules.mkdir(exist_ok=True);exported={}
        for source in meshes:
            asset=asset_for_name[source.name]
            if asset in exported:continue
            bpy.ops.object.select_all(action='DESELECT')
            temp=source.copy();bpy.context.scene.collection.objects.link(temp)
            temp.name=asset;temp.location=(0,0,0);temp.rotation_euler=(0,0,0);temp.scale=(1,1,1);temp.select_set(True)
            bpy.ops.export_scene.gltf(filepath=str(modules/f'{asset}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
            bpy.data.objects.remove(temp,do_unlink=True);exported[asset]=f'res://assets/models/greystone/blender_master/buildings/{asset}.glb'
        lines=['[gd_scene load_steps='+str(len(exported)+1)+' format=3]','']
        for asset,path in exported.items():lines.append(f'[ext_resource type="PackedScene" path="{path}" id="{asset}"]')
        lines.extend(['','[node name="Buildings_Candidate" type="Node3D"]'])
        for source in meshes:
            asset=asset_for_name[source.name];x,y,z=source.location;s=source.scale.x
            lines.extend(['',f'[node name="{source.name}" parent="." instance=ExtResource("{asset}")]',f'position = Vector3({x:.6f}, {z:.6f}, {-y:.6f})',f'scale = Vector3({s:.6f}, {s:.6f}, {s:.6f})'])
        dest=ROOT/'scenes/world/greystone/blender_master';dest.mkdir(exist_ok=True)
        (dest/'buildings.tscn').write_text('\n'.join(lines)+'\n',encoding='utf8')
        triangles=0
        for o in meshes:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
        record({'collection':collection.name,'path':'res://scenes/world/greystone/blender_master/buildings.tscn','mesh_nodes':len(meshes),'instanced_triangles':triangles,'shared_modules':exported})
        continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:o.select_set(True)
    name=collection.name.lower()
    bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
    triangles=0
    for o in meshes:o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    record({'collection':collection.name,'path':f'res://assets/models/greystone/blender_master/{name}.glb','mesh_nodes':len(meshes),'instanced_triangles':triangles})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
lines=['[gd_scene load_steps='+str(len(manifest)+3)+' format=3]','', '[ext_resource type="Script" path="res://scripts/world/blender_village_geometry.gd" id="Geometry"]', '[ext_resource type="Script" path="res://scripts/world/blender_village_surfaces.gd" id="Surfaces"]']
for i,row in enumerate(manifest):lines.append(f'[ext_resource type="PackedScene" path="{row["path"]}" id="{i+1}"]')
lines.extend(['','[node name="GreystoneBlenderMaster" type="Node3D"]','script = ExtResource("Geometry")','metadata/status = "candidate_rpg_opt_in"'])
for i,row in enumerate(manifest):lines.extend(['',f'[node name="{row["collection"]}" parent="." instance=ExtResource("{i+1}")]'])
lines.extend(['','[node name="SurfaceTreatment" type="Node" parent="." node_paths=PackedStringArray("village")]','script = ExtResource("Surfaces")','village = NodePath("..")'])
(ROOT/'scenes/world/greystone_blender_master.tscn').write_text('\n'.join(lines)+'\n',encoding='utf8')
print('EXPORTED_BLENDER_MASTER',json.dumps(manifest))
