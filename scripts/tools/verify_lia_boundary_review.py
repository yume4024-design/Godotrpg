"""Compare source and marked Blender review copy without altering either file."""
import argparse,hashlib,json,struct,sys
from pathlib import Path
import bpy

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--source',type=Path,required=True);p.add_argument('--review',type=Path,required=True);p.add_argument('--receipt',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
if a.output.exists():raise FileExistsError('Output already exists')
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def snapshot(path):
    bpy.ops.wm.open_mainfile(filepath=str(path.resolve()))
    rows={};groups={}
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH':continue
        mesh=obj.data;h=hashlib.sha256()
        for v in mesh.vertices:h.update(struct.pack('<3d',*v.co))
        for p in mesh.polygons:
            h.update(struct.pack('<II',len(p.vertices),p.material_index))
            h.update(struct.pack('<%dI'%len(p.vertices),*p.vertices))
        for layer in mesh.uv_layers:
            h.update(layer.name.encode('utf-8')+b'\0')
            for loop in layer.data:h.update(struct.pack('<2d',*loop.uv))
        for normal in mesh.corner_normals:h.update(struct.pack('<3d',*normal.vector))
        rows[obj.name]={'signature':h.hexdigest(),'vertices':len(mesh.vertices),'faces':len(mesh.polygons),
            'uv_layers':len(mesh.uv_layers),'materials':[m.name if m else None for m in mesh.materials],
            'matrix':[round(float(v),8) for row in obj.matrix_world for v in row]}
        if obj.name=='LiaRetainedAuthoredNeckSurface':
            groups={g.name:sum(1 for v in mesh.vertices if any(assignment.group==g.index for assignment in v.groups)) for g in obj.vertex_groups if g.name.startswith('Review_')}
    images={image.name:{'size':list(image.size),'packed_sha256':hashlib.sha256(bytes(image.packed_file.data)).hexdigest() if image.packed_file else None} for image in bpy.data.images if image.source=='FILE'}
    return rows,groups,images
receipt=json.loads(a.receipt.read_text(encoding='utf-8'))
if sha(a.source)!=receipt['source_blend_sha256'] or sha(a.review)!=receipt['output_sha256']:raise ValueError('File hash mismatch')
before,oldgroups,images_before=snapshot(a.source)
after,groups,images_after=snapshot(a.review)
expected={'Review_'+key:value for key,value in receipt['mapped_counts'].items()}
checks={'source_groups_absent':not oldgroups,'geometry_uv_normals_materials_transforms_equal':before==after,
        'packed_image_hashes_equal':images_before==images_after,'review_groups_match':groups==expected,
        '62_samples_mapped':receipt['sample_count']==62 and receipt['maximum_mapping_error_m']<=.00002}
result={'checks':checks,'source_sha256':receipt['source_blend_sha256'],'review_sha256':receipt['output_sha256'],'groups':groups,'mesh_signatures':after,'images':images_after,'status':'PASS' if all(checks.values()) else 'FAIL','scope':'Geometry, UV, corner normals, material slots, transforms and packed image bytes. Review groups only; no art or animation acceptance.'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('LIA_REVIEW_COPY_VERIFY',result['status'],json.dumps(checks),flush=True)
if result['status']!='PASS':raise RuntimeError('Review copy differs from source')
