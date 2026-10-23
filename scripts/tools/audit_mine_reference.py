from pathlib import Path
import sys,json,hashlib
root=Path(__file__).resolve().parents[2];sys.path.insert(0,str(root/'scripts/tools'))
from asset_glb_validation import audit_glb
folder=root/'assets/models/mine_reference'; rows=[]
modules={'mine_cart','rail_segment','mine_portal','hoist_cage'}
for p in sorted(folder.glob('*.glb')):
 r=audit_glb(p,maximum=4096 if p.stem in modules else 200000,require_uv=False,require_rig=False)
 rows.append(r)
print([(Path(r['file']).name,r['triangles'],r['status']) for r in rows])
manifest=json.loads((folder/'manifest.json').read_text(encoding='utf8'))
report={'rows':rows,'scene_triangle_budget':200000,'scene_triangles':manifest['total_triangles'],'source_master':'source_assets/mine_reference_20261024/mine_reference_master.blend','master_sha256':hashlib.sha256((root/'source_assets/mine_reference_20261024/mine_reference_master.blend').read_bytes()).hexdigest(),'reference_sha256':manifest['source_reference_sha256'],'static_assets':True,'uv_note':'World-position shaders and constant-colour materials; UV not required. Not a UV quality pass.','status':'PASS' if all(r['status']=='PASS' for r in rows) and manifest['total_triangles']<=200000 else 'FAIL'}
(root/'source_assets/mine_reference_20261024/asset_audit.json').write_text(json.dumps(report,indent=2,ensure_ascii=False),encoding='utf8')
if report['status']!='PASS':sys.exit(1)
