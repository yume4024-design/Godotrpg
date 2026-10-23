"""Native Blender inspection of generated inn, preserving original file."""
import bpy,json,argparse,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
parser=argparse.ArgumentParser();parser.add_argument('--asset',default='inn');parser.add_argument('--width',type=float,default=12)
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT=ROOT/'source_assets/greystone_ai_20261023'/args.asset/'pixal_candidate_01'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT/f'{args.asset}_textured.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in corners) for i in range(3)]);hi=Vector([max(v[i] for v in corners) for i in range(3)])
scale=args.width/(hi.x-lo.x)
for o in meshes:
    o.location*=scale;o.scale*=scale
bpy.context.view_layer.update()
corners=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
lo=Vector([min(v[i] for v in corners) for i in range(3)]);hi=Vector([max(v[i] for v in corners) for i in range(3)])
offset=Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z))
for o in meshes:o.location+=offset
center=(lo+hi)/2+offset
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1000;scene.render.resolution_y=850;scene.render.resolution_percentage=100
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.55,.58,.63,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
bpy.ops.object.light_add(type='AREA',location=(5,-10,18));o=bpy.context.object;o.data.energy=1000;o.data.size=12;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=args.width*1.33;scene.camera=cam
report={'dimensions_blender':list(hi-lo),'triangles':0,'uv':True,'zero_area':0,'status':'visual review pending'}
for o in meshes:
    m=o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh();m.calc_loop_triangles();report['triangles']+=len(m.loop_triangles)
    report['uv']=report['uv'] and bool(m.uv_layers);report['zero_area']+=sum(p.area<1e-12 for p in m.polygons)
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/f'{args.asset}_normalized.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{args.asset}_review.blend'))
for name,vec in [('front',(0,-28,0)),('back',(0,28,0)),('left',(-28,0,0)),('right',(28,0,0)),('overview',(15,-20,15))]:
    cam.location=center+Vector(vec);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/f'render_{name}.png');bpy.ops.render.render(write_still=True)
(OUT/'blender_audit.json').write_text(json.dumps(report,indent=2),encoding='utf8')
