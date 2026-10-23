"""Independent Blender reimport/evaluated mesh verification, isolated process."""
import bpy
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
manifest=json.loads((ROOT/'source_assets/greystone_reference_20261023/metrics.json').read_text())
results=[]
for entry in manifest:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/f'assets/models/greystone/reference_modules/{entry["name"]}.glb'))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    count=0;zero=0;uv=True
    for obj in meshes:
        evaluated=obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        count+=len(mesh.loop_triangles)
        zero+=sum(t.area<1e-12 for t in mesh.loop_triangles)
        uv=uv and bool(mesh.uv_layers)
        evaluated.to_mesh_clear()
    assert count==entry['triangles'] and zero==0 and uv,(entry['name'],count,zero,uv)
    results.append({'name':entry['name'],'evaluated_triangles':count,'degenerate':zero,'uv':uv})
report={'blender':bpy.app.version_string,'status':'PASS','assets':results}
(ROOT/'source_assets/greystone_reference_20261023/blender_reimport.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('BLENDER_REFERENCE_PASS',len(results))
