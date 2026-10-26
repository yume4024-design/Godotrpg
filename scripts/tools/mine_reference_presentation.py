"""Reference-led finishing: organic ledges, supported props and readable water."""
import bpy,bmesh,math,random,hashlib
from pathlib import Path
from mathutils import Vector


def finish_presentation(api,clear):
    B,box,beam,stone,mesh=(api[k] for k in ['B','gbox','beam','stone','mesh'])
    rng=random.Random(261029)
    receipt={'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
             'organic_ledges':[],'workplace_details':[],'water_foam':[],
             'removed_small_bevels':0,'new_collisions':0}
    def timber(name,a,b,w=.16,d=.18,material='Wood',group='connections'):
        obj=beam(name,B(a),B(b),w,d,material,group);obj.modifiers.clear();return obj
    # Thin rails and sleepers do not need three additional bevel faces per edge.
    # Reinvest that geometry in visible structures; hero portal beams stay bevelled.
    for col in list(api['collections'].values()):
        for obj in col.objects:
            if any(k in obj.name for k in ['Fence_Rail','BridgeRails_Rail','LinkRail_Rail','CurveSleeper','RailSleeper']):
                for mod in list(obj.modifiers):
                    if mod.type=='BEVEL':obj.modifiers.remove(mod);receipt['removed_small_bevels']+=1
    # The playable rectangle remains completely covered. Only the fenced outer
    # verge expands; entries retain their original edge at every connecting route.
    for zone in api['LAYOUT']['zones']:
        group=zone['id'];col=api['collection'](group);h=zone['height'];x0,x1,z0,z1=zone['bounds']
        shell=next(o for o in col.objects if o.name.startswith('ContinuousStrata_'))
        n=next(v['perimeter_vertices'] for v in api['art_receipt_pending']['continuity']['strata'] if v['zone']==group)
        center=Vector(((x0+x1)/2,0,(z0+z1)/2));outline=[]
        for i in range(n):
            p=shell.data.vertices[i].co;v=Vector((p.x,p.z,-p.y));direction=Vector((v.x-center.x,0,v.z-center.z)).normalized()
            pad=(.35+.75*(.5+.5*math.sin(i*1.73))) if clear((v.x,h,v.z),2.5) else 0
            q=v+direction*pad;q.y=h;outline.append(q)
            shell.data.vertices[i].co=B((q.x,h-.30,q.z))
        shell.data.vertices[5*n].co=B((center.x,h-.30,center.z))
        bm=bmesh.new();bm.from_mesh(shell.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(shell.data);bm.free()
        for obj in list(col.objects):
            if obj.name.startswith('Earth_'+group):bpy.data.objects.remove(obj,do_unlink=True)
        points=[B(v) for v in outline]+[B(v+Vector((0,-.30,0))) for v in outline]
        points += [B((center.x,h,center.z)),B((center.x,h-.30,center.z))]
        faces=[]
        for i in range(n):
            j=(i+1)%n;faces.extend([(2*n,i,j),(2*n+1,n+j,n+i),(i,n+i,n+j,j)])
        obj=mesh('OrganicEarth_'+group,points,faces,'Earth',group)
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
        receipt['organic_ledges'].append({'zone':group,'rim_vertices':n,'maximum_verge_m':1.10,'walkable_bounds':zone['bounds']})
        # Timber retaining works below the foreground cliff, never through lanes.
        for x in [x0+3.0,x1-3.0]:
            z=max(-v.co.y for v in shell.data.vertices if abs(v.co.x-x)<3.5)+.30
            if not clear((x,h,z),1.5):continue
            for dx in [-1.4,1.4]:timber('CliffShoringPost',(x+dx,-7.8,z),(x+dx,h-.6,z),.24,.26,group=group)
            timber('CliffShoringCross',(x-1.6,h-1.0,z),(x+1.6,h-1.0,z),.24,.26,'WoodLight',group)
            timber('CliffShoringBrace',(x-1.4,h-4,z),(x+1.4,h-1.1,z),.18,.2,group=group)
            for dx in [-1.4,1.4]:timber('CliffShoringTie',(x+dx,h-.6,z1-.2),(x+dx,h-.6,z),.18,.2,group=group)
    # Nail heads and iron straps make repeated structural modules readable close up.
    for link in api['LAYOUT']['links']:
        if link['kind']!='bridge':continue
        a,b=Vector(link['a']),Vector(link['b']);direction=(b-a).normalized();normal=Vector((-direction.z,0,direction.x))
        for i in range(1,max(2,int((b-a).length/3))):
            p=a.lerp(b,i/max(2,int((b-a).length/3)))
            for side in [-1,1]:
                q=p+normal*link['width']*.42*side
                box('BridgeIronStud',q+Vector((0,.035,0)),(.075,.045,.075),'Metal','connections')
    # Camp canvas now has poles, seams, guy ropes and a small supply/fire area.
    for z in [34,39]:
        timber('TentRidgePost',(-40,0,z),(-40,2.8,z),.12,.12,group='entrance_camp')
        for x in [-43,-37]:
            stake=x+(-1 if x<-40 else 1)
            timber('TentGuy',(-40,2.8,z),(stake,.15,z),.035,.035,'Rope','entrance_camp')
            box('TentStake',(stake,.2,z),(.10,.4,.1),'Wood','entrance_camp')
    timber('TentRidge',(-40,2.8,33.8),(-40,2.8,39.2),.12,.12,group='entrance_camp')
    mesh('TentBack',[B(p) for p in [(-43,0,39),(-40,2.8,39),(-37,0,39)]],[(0,1,2)],'Canvas','entrance_camp')
    for side in [-1,1]:
        x=-40+side*2.7
        timber('CanvasSeam',(x,.22,34),(-40+side*.15,2.65,34),.025,.025,'Rope','entrance_camp')
    for x in [-41.5,-38.5]:box('CampBedroll',(x,.13,37),(1,.22,2.2),'Canvas','entrance_camp')
    for i in range(8):
        a=math.tau*i/8;stone('CampFireRing',B((-30+math.cos(a)*.85,.16,37+math.sin(a)*.85)),(.32,.27,.23),'entrance_camp')
    for side in [-1,1]:timber('CampFireLog',(-30.5,.18,37+side*.3),(-29.5,.18,37-side*.3),.18,.20,group='entrance_camp')
    flame_template=next(o for o in api['collection']('entrance_camp').objects if o.name.startswith('FlameTongue'))
    for dx,scale in [(-.12,.85),(.15,.65)]:
        flame=bpy.data.objects.new('CampFireTongue',flame_template.data.copy())
        api['collection']('entrance_camp').objects.link(flame);flame.location=B((-30+dx,.58,37));flame.scale=(scale,scale,scale)
    for obj in api['collection']('entrance_camp').objects:
        if obj.name.startswith('CampFire'):obj.location+=B((-4,0,-1))
    box('CampSupplyBench',(-29,.65,40),(3,.16,1),'WoodLight','entrance_camp')
    for x in [-30,-28]:box('CampBenchLeg',(x,.3,40),(.16,.6,.8),'Wood','entrance_camp')
    receipt['workplace_details'].append('supported camp canvas, bedrolls, stone fire ring and supply bench')
    for obj in api['collection']('entrance_camp').objects:
        if obj.name.startswith(('TorchPole','TorchBasket','FlameTongue')) and abs(obj.location.x+38.5)<.1:
            obj.location+=B((5.5,0,1))
    receipt['workplace_details'].append('camp torch moved outside canvas')
    # The warning board had no posts. Repair it and add a broken support behind rubble.
    for x in [.05,1.95]:box('WarningPost',(x,.72,40),(.14,1.44,.14),'Wood','collapse')
    timber('WarningCrossBrace',(.05,.2,40.12),(1.95,1.0,40.12),.10,.10,group='collapse')
    for x in [5,10]:timber('BrokenSupport',(x,0,42),(x-.6,3.7,42),.32,.34,group='collapse')
    timber('BrokenHeader',(4.5,3.5,42),(7.2,3.3,42),.35,.38,group='collapse')
    timber('BrokenHeader',(8.4,3.1,42),(10,3.7,42),.35,.38,group='collapse')
    receipt['workplace_details'].append('supported warning sign and fractured mine frame')
    # Roof-level stock bay and cargo rope, clear of the existing storage path.
    for x in [27.5,31]:
        timber('StockCanopyPost',(x,7,-17.5),(x,10.2,-17.5),.18,.2,group='storage')
    box('StockCanopy',(29.25,10.3,-17),(4.2,.2,2.2),'WoodLight','storage')
    for i in range(4):
        box('LumberStock',(28+i*.45,7.2,-17),( .32,.32,2.7),'Wood','storage')
    receipt['workplace_details'].append('storage canopy and lumber stock')
    # Move the core's two torch assemblies out of the large blue crystal meshes.
    for obj in api['collection']('core_cavern').objects:
        if not obj.name.startswith(('TorchPole','TorchBasket','FlameTongue')):continue
        if abs(obj.location.x-40.5)<.1:obj.location+=B((-6.5,0,6))
        elif abs(obj.location.x-47.5)<.1:obj.location+=B((.5,0,9))
    receipt['workplace_details'].append('two core torches moved clear of crystal faces')
    for obj in api['collection']('details').objects:
        if obj.name.startswith(('TorchPole','TorchBasket','FlameTongue')) and abs(obj.location.x-29)<.1 and abs(obj.location.y+36)<.1:
            obj.location+=B((-2,0,4))
    receipt['workplace_details'].append('core approach torch moved outside the walking lane')
    # Lower the one foreground pillar that concealed the north impact pool.
    for obj in api['collection']('backdrop').objects:
        if obj.name.startswith('ChasmPillar') and abs(obj.location.x-13)<.1 and abs(obj.location.y-20)<.1:
            obj.scale*=.78;obj.location.z-=2.0
    # Explicit shore foam and impact rings replace depth-texture triangle artifacts.
    ripple_mat=bpy.data.materials.new('Mine_Ripple');ripple_mat.use_nodes=True
    bsdf=next(n for n in ripple_mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value=(.55,.79,.85,1)
    def foam_ring(name,x,h,z,rx,rz,group='water'):
        points=[];segments=28
        for i in range(segments):
            a=i*math.tau/segments;w=1.0+.05*math.sin(i*.7)
            for r in [.78,1.0]:points.append(B((x+math.cos(a)*rx*r*w,h,z+math.sin(a)*rz*r*w)))
        faces=[(i*2,((i+1)%segments)*2,((i+1)%segments)*2+1,i*2+1) for i in range(segments)]
        obj=mesh(name,points,faces,'Water',group);obj.data.materials.clear();obj.data.materials.append(ripple_mat)
        uv=obj.data.uv_layers.new(name='FoamFade')
        for poly in obj.data.polygons:
            for loop in poly.loop_indices:
                vi=obj.data.loops[loop].vertex_index;uv.data[loop].uv=(vi//2/segments,float(vi%2))
        receipt['water_foam'].append({'name':name,'position':[x,h,z]})
    for x,h,z in [(10,-6.94,-25.7),(19,-5.44,17.0)]:
        for radius in [1.0,1.6,2.2]:foam_ring('CascadeRipple',x,h,z,2.0*radius,.8*radius)
    for x,h,z in [(6,-6.94,-16),(15,-6.94,3),(21,-5.44,21),(40,-5.44,29)]:foam_ring('RockWaterWake',x,h,z,1.2,.65)
    receipt['flame_centers']=[]
    for group in list(api['collections']):
        for obj in api['collection'](group).objects:
            if obj.name.startswith(('FlameTongue','CampFireTongue')):
                p=obj.location;receipt['flame_centers'].append({'zone':group,'position':[p.x,p.z,-p.y]})
    return receipt
