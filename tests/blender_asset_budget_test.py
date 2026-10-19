"""Actual Blender modifier evaluation and scene-instance rejection, no source assets."""
import bpy
import importlib.util
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('asset_checker', root/'docs/skills/ai-3d-agent/scripts/check_export.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
results = []


def triangle():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh = bpy.data.meshes.new('BaseTriangle')
    mesh.from_pydata([(0,0,0),(.01,0,0),(0,.01,0)], [], [(0,1,2)])
    mesh.uv_layers.new()
    obj = bpy.data.objects.new('Asset',mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


for cap in [10000,15000]:
    for count in [cap-1,cap,cap+1]:
        obj = triangle()
        mod = obj.modifiers.new('EvaluatedArray','ARRAY')
        mod.count = count
        mod.relative_offset_displace = (2,0,0)
        bpy.context.view_layer.update()
        report = checker.inspect_scene(cap,require_uv=True)
        passed = not report['failures']
        results.append({'case':f'evaluated_{count}','count':report['total_triangles'],
                        'test_passed':report['total_triangles']==count and passed==(count<=cap)})

obj = triangle()
duplicate = bpy.data.objects.new('Duplicate',obj.data)
bpy.context.scene.collection.objects.link(duplicate)
report = checker.inspect_scene(10000)
results.append({'case':'duplicate_mesh_data','test_passed':'DUPLICATE_MESH_INSTANCE' in report['failures']
                and report['total_triangles']==2})

obj = triangle()
collection = bpy.data.collections.new('InstancedCollection')
collection.objects.link(obj)
instancer = bpy.data.objects.new('Instancer',None)
instancer.instance_type = 'COLLECTION'
instancer.instance_collection = collection
bpy.context.scene.collection.objects.link(instancer)
bpy.context.view_layer.update()
report = checker.inspect_scene(10000)
results.append({'case':'collection_instance','test_passed':'UNACCOUNTED_INSTANCES' in report['failures']})

obj = triangle()
obj.data.vertices[0].co.x = float('nan')
report = checker.inspect_scene(10000)
results.append({'case':'evaluated_nonfinite','test_passed':'NONFINITE_POSITION' in report['failures']})

obj = triangle()
rig = bpy.data.objects.new('UnboundRig',bpy.data.armatures.new('UnboundRig'))
bpy.context.scene.collection.objects.link(rig)
report = checker.inspect_scene(10000,require_rig=True)
results.append({'case':'unbound_armature','test_passed':'MISSING_BOUND_ARMATURE' in report['failures']})

(root/'artifacts/asset_a01/blender_evaluated.json').write_text(json.dumps(results,indent=2),encoding='utf8')
print('BLENDER_EVALUATED_TEST',len(results),'cases',sum(not r['test_passed'] for r in results),'failures')
if not all(r['test_passed'] for r in results):
    raise SystemExit(1)
