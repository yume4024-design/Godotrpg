"""Create environment-only Pixal copies with explicit 40k budget; keep live graph intact."""
import argparse,copy,hashlib,json,shutil
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'source_assets/greystone_ai_20261023'
parser=argparse.ArgumentParser()
parser.add_argument('--asset',default='inn',choices=['inn','house_a','item_shop','weapon_shop'])
parser.add_argument('--budget',type=int,default=40000)
args=parser.parse_args()
if args.budget<=0:raise ValueError('Explicit positive environment budget required')
OUT=BASE/args.asset/'pixal_candidate_01'
OUT.mkdir(exist_ok=True)
SOURCE=Path('D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/user/default/workflows/3d_pixal3d_multi_views.json')
raw=SOURCE.read_bytes()
snapshot=(BASE/'workflow_source.json').read_bytes()
if raw!=snapshot:raise RuntimeError('Workflow changed; refresh slots before preparing')
ui=json.loads(raw);slots=json.loads((BASE/'workflow_slots.json').read_text(encoding='utf8'))['slots']
sheet=Image.open(BASE/args.asset/('turnaround_ortho_v3_review.png' if args.asset=='inn' else 'turnaround.png')).convert('RGBA')
assert sheet.size==(1536,1024)
rects={'front':(0,0,900,525),'left':(900,0,1536,525),'back':(0,525,900,1024),'right':(900,525,1536,1024)}
refs={};uploads=OUT/'uploads';uploads.mkdir(exist_ok=True)
for view,rect in rects.items():
    a=np.array(sheet.crop(rect));mask=a[:,:,3]>=128
    labels,count=ndimage.label(mask);areas=np.bincount(labels.ravel());areas[0]=0
    keep=np.flatnonzero(areas>=max(24,areas.max()*.002));valid=np.isin(labels,keep)
    a[:,:,3]=np.where(valid,a[:,:,3],0)
    ys,xs=np.nonzero(valid);bbox=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1))
    im=Image.fromarray(a).crop(bbox)
    # Same pixels per meter across the four views; no per-view stretch/fit.
    canvas=Image.new('RGBA',(1024,1024));canvas.alpha_composite(im,((1024-im.width)//2,850-im.height))
    path=uploads/f'greystone_{args.asset}_ortho_v3_{view}.png';canvas.save(path)
    refs[view]={'file':str(path.relative_to(ROOT)),'sheet_rect':rect,'bbox':bbox,'scale':1,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
nodes={str(n['id']):n for n in ui['nodes']};links={l[0]:l for l in ui['links']}
def origin(lid):
    l=links[lid];n=nodes[str(l[1])]
    if n.get('mode',0)==4:
        inputs=[p for p in n['inputs'] if p.get('link') is not None and p['type']==n['outputs'][l[2]]['type']]
        if len(inputs)!=1:raise ValueError('Ambiguous bypass')
        return origin(inputs[0]['link'])
    return [str(l[1]),l[2]]
graph={}
for key,n in nodes.items():
    if n.get('mode',0)!=0 or n['type'] in ['Note','MarkdownNote']:continue
    inp={s['address'].split('.',1)[1]:s['current_value'] for s in slots if s['address'].startswith(key+'.')}
    for p in n.get('inputs',[]):
        if p.get('link') is not None:inp[p['name']]=origin(p['link'])
    graph[key]={'class_type':n['type'],'inputs':inp}
def only(kind):
    found=[k for k,n in graph.items() if n['class_type']==kind]
    if len(found)!=1:raise ValueError((kind,found))
    return found[0]
def ancestors(roots):
    result={}
    def visit(k):
        if k in result:return
        result[k]=copy.deepcopy(graph[k])
        for v in graph[k]['inputs'].values():
            if isinstance(v,list) and len(v)==2 and isinstance(v[0],str) and v[0] in graph:visit(v[0])
    for k in roots:visit(k)
    return result
graph[only('Trellis2UpsampleStage')]['inputs']['target_resolution']=1536
graph[only('DecimateMesh')]['inputs']['target_face_count']=int(args.budget*.92)
remesh=only('RemeshMesh');graph[remesh]['inputs']['smooth_iters']=0;graph[remesh]['inputs']['drop_small_components']=0.0
cond=only('Pixal3DMultiViewConditioning');preview=[]
prefix=f'greystone_20261023/{args.asset}_candidate01'
for view in refs:
    chain=ancestors([graph[cond]['inputs'][view][0]])
    loads=[k for k,n in chain.items() if n['class_type']=='LoadImage'];saves=[k for k,n in chain.items() if n['class_type']=='SaveImageAdvanced']
    assert len(loads)==len(saves)==1
    graph[loads[0]]['inputs']['image']=f'greystone_{args.asset}_ortho_v3_{view}.png'
    graph[saves[0]]['inputs']['filename_prefix']=prefix+'/'+view
    # The stock graph fits every elevation independently. Compensate its padding
    # so narrower side elevations retain the same apparent height as front/back.
    crops=[k for k,n in chain.items() if n['class_type']=='ImageCropToMask']
    assert len(crops)==1
    largest=max(max(r['bbox'][2]-r['bbox'][0],r['bbox'][3]-r['bbox'][1]) for r in refs.values())
    b=refs[view]['bbox'];extent=max(b[2]-b[0],b[3]-b[1])
    graph[crops[0]]['inputs']['pad_factor']=1.1*largest/extent
    refs[view]['crop_pad_factor']=1.1*largest/extent
    preview.append(saves[0]);refs[view]['chain']={k:n['class_type'] for k,n in chain.items()}
save=only('Save3DAdvanced');graph[save]['inputs']['filename_prefix']=prefix+'/'+args.asset+'_textured'
graph['10001']={'class_type':'MeshToFile3D','inputs':{'mesh':graph[remesh]['inputs']['mesh']}}
graph['10002']={'class_type':'Save3DAdvanced','inputs':{'model_3d':['10001',0],'filename_prefix':prefix+'/'+args.asset+'_source','viewport_state':'','width':1024,'height':1024}}
for name,roots in [('inputs.api.json',preview),('full.api.json',[save,'10002'])]:
    (OUT/name).write_text(json.dumps(ancestors(roots),ensure_ascii=False,indent=2),encoding='utf8')
shutil.copy2(SOURCE,OUT/'workflow_source.json')
(OUT/'manifest.json').write_text(json.dumps({'status':'INPUTS_PREPARED_NOT_SUBMITTED','asset':args.asset,'budget':args.budget,'candidate_target':int(args.budget*.92),'source_workflow_sha256':hashlib.sha256(raw).hexdigest(),'views':refs,'visual_review':'Orthographic elevation candidate; small window/decor inconsistencies to inspect on generated model. Not production approved.'},ensure_ascii=False,indent=2),encoding='utf8')
print('Prepared',OUT)
