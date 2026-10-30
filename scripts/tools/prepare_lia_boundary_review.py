"""Create a non-destructive Blender review copy with diagnosed neck boundary groups.

Run in an independent background Blender process only. No rendering, geometry,
UV, material, rig or in-game asset changes. Never overwrites the input or output.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys


def sha256(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
    return h.hexdigest()


def gltf_to_blender(point):
    # Blender's glTF export converts Z-up (x,y,z) to glTF Y-up (x,z,-y).
    return (float(point[0]),-float(point[2]),float(point[1]))


def band(distance):
    if distance <= .002:return 'within_2mm'
    if distance <= .020:return '2mm_to_20mm'
    return 'over_20mm'


def main():
    import bpy
    from mathutils import Vector
    from mathutils.kdtree import KDTree
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blend',type=Path,required=True)
    parser.add_argument('--glb',type=Path,required=True)
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    report=json.loads(args.report.read_text(encoding='utf-8'))
    if sha256(args.glb)!=report['source_sha256']:raise ValueError('GLB hash differs from the measured model')
    samples=report['region_vertex_comparison']['surface_samples']
    if len(samples)!=report['region_vertex_comparison']['boundary_vertices'] or not samples:
        raise ValueError('Incomplete boundary sample list')
    target=args.output.resolve()
    if target.exists():raise FileExistsError('Output must be a new directory')
    if target==args.blend.resolve() or args.blend.resolve().is_relative_to(target):raise ValueError('Output overlaps source')
    source_sha=sha256(args.blend)
    bpy.ops.wm.open_mainfile(filepath=str(args.blend.resolve()))
    body=bpy.data.objects.get('LiaRetainedAuthoredNeckSurface')
    neck=bpy.data.objects.get('LiaContinuousNeckClavicle')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    if body is None or neck is None or len(meshes)!=2 or body.type!='MESH' or neck.type!='MESH':
        raise ValueError('Unexpected source meshes; stop without modifying the source')
    if any(o.type=='ARMATURE' for o in bpy.context.scene.objects):raise ValueError('Expected static candidate')
    tree=KDTree(len(body.data.vertices))
    for v in body.data.vertices:tree.insert(body.matrix_world @ v.co,v.index)
    tree.balance()
    groups={'within_2mm':set(),'2mm_to_20mm':set(),'over_20mm':set()}
    mismatches=[];max_error=0.0
    for sample in samples:
        point=Vector(gltf_to_blender(sample['position']))
        matches=tree.find_range(point,.00002)
        if not matches:
            mismatches.append(sample['position']);continue
        max_error=max(max_error,max(item[2] for item in matches))
        groups[band(float(sample['distance_m']))].update(item[1] for item in matches)
    if mismatches:raise ValueError('GLB sample positions did not map to source blend: %d' % len(mismatches))
    existing={g.name for g in body.vertex_groups}
    for key in groups:
        if 'Review_'+key in existing:raise ValueError('Review groups already exist; use unmodified source')
    before={o.name:(len(o.data.vertices),len(o.data.polygons),len(o.data.uv_layers)) for o in meshes}
    for name,indices in groups.items():
        group=body.vertex_groups.new(name='Review_'+name)
        if indices:group.add(sorted(indices),1.0,'REPLACE')
    for vertex in body.data.vertices:vertex.select=False
    for index in groups['over_20mm']:body.data.vertices[index].select=True
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True);bpy.context.view_layer.objects.active=body
    target.mkdir(parents=True)
    output_blend=target/'lia_boundary_review.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend),copy=True)
    after={o.name:(len(o.data.vertices),len(o.data.polygons),len(o.data.uv_layers)) for o in meshes}
    if before!=after or sha256(args.blend)!=source_sha:raise RuntimeError('Source or mesh topology unexpectedly changed')
    receipt={'source_blend_sha256':source_sha,'source_glb_sha256':report['source_sha256'],
             'source_report_sha256':sha256(args.report),'sample_count':len(samples),
             'mapped_counts':{key:len(value) for key,value in groups.items()},
             'maximum_mapping_error_m':max_error,'geometry_counts_unchanged':before==after,
             'source_blend_unchanged':True,'output_sha256':sha256(output_blend),
             'limits':['Review groups only; no repair, rig, animation or visual acceptance',
                       'Distances are unsigned point-to-triangle measurements, not gap classification']}
    (target/'receipt.json').write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('LIA_REVIEW_COPY_READY',json.dumps(receipt,ensure_ascii=False),flush=True)

if __name__=='__main__':main()
