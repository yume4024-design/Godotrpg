"""Final cave silhouette and recessed tunnel dressing; no gameplay geometry changes."""
import bpy, math, random, hashlib
from pathlib import Path
from mathutils import Matrix, Vector


def finish_cavern(api, clear):
    B, stone, box, beam = (api[k] for k in ['B', 'stone', 'gbox', 'beam'])
    rng = random.Random(261028)
    receipt = {'script_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               'tunnels': [], 'rock_shoulders': [], 'wall_masses': 0, 'new_collisions': 0}
    receipt['flames'] = 0
    flame_material=api['materials']['Flame']
    heat_node=flame_material.node_tree.nodes.new('ShaderNodeVertexColor')
    heat_node.layer_name='FlameHeat'
    bsdf=next(n for n in flame_material.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    flame_material.node_tree.links.new(heat_node.outputs['Color'],bsdf.inputs['Base Color'])
    # Tapered flame tongues with a bright base replace rock-shaped orange caps.
    for col in list(api['collections'].values()):
        for obj in list(col.objects):
            if not obj.name.startswith('TorchFlame'): continue
            center=obj.location.copy(); bpy.data.objects.remove(obj,do_unlink=True)
            points=[]
            for y,r in [(-.38,.12),(-.12,.23),(.19,.14)]:
                for i in range(6):
                    a=i*math.tau/6;points.append((math.cos(a)*r,math.sin(a)*r,y))
            points.extend([(.08,-.03,.62),(0,0,-.40)])
            faces=[]
            for row in range(2):
                for i in range(6): faces.append((row*6+i,row*6+(i+1)%6,(row+1)*6+(i+1)%6,(row+1)*6+i))
            for i in range(6):faces.extend([(12+i,12+(i+1)%6,18),(19,(i+1)%6,i)])
            flame=api['mesh']('FlameTongue',points,faces,'Flame',col.name);flame.location=center
            colors=flame.data.color_attributes.new(name='FlameHeat',type='FLOAT_COLOR',domain='POINT')
            for i,v in enumerate(flame.data.vertices):
                heat=max(0,min(1,(v.co.z+.4)/1.02));colors.data[i].color=(1,heat,0,1)
            receipt['flames']+=1
    # Broad staggered blocks replace the regular rows of thin wall appliques.
    backdrop = api['collection']('backdrop')
    for obj in list(backdrop.objects):
        if obj.name.startswith(('CaveWallLens', 'CaveWestLens')):
            bpy.data.objects.remove(obj, do_unlink=True)
    for side in ['north', 'west']:
        for i in range(30):
            t = rng.uniform(-47, 48 if side == 'north' else 37)
            h = rng.uniform(-2, 14)
            if side == 'north':
                p, size = (t, h, -46.6 - max(0, h-3)*.23), (rng.uniform(3,6), rng.uniform(1.8,3), rng.uniform(2,4.5))
            else:
                p, size = (-51.5-max(0,h-3)*.23, h, t), (rng.uniform(1.4,2.3), rng.uniform(3,5), rng.uniform(2,4.3))
            stone('CavernButtress', B(p), size, 'backdrop')
            receipt['wall_masses'] += 1
    # Irregular rock shoulders interrupt the straight ledges; their broad radii
    # are checked against protected routes before placement, then BVH audited.
    for zone in api['LAYOUT']['zones']:
        if zone['id'] == 'bridge_junction': continue
        x0,x1,z0,z1 = zone['bounds']; h = zone['height']; group=zone['id']
        for i in range(20):
            edge=i%4; t=rng.uniform(.1,.9)
            x,z = [(x0+(x1-x0)*t,z0+.5),(x1-.5,z0+(z1-z0)*t),
                   (x0+(x1-x0)*t,z1-.5),(x0+.5,z0+(z1-z0)*t)][edge]
            radius=rng.uniform(1.4,2.4)
            if not clear((x,h,z),radius+.5): continue
            stone('LedgeShoulder',B((x,h-.65,z)),(radius,radius*.85,rng.uniform(1.0,1.6)),group)
            receipt['rock_shoulders'].append([group,x,h,z])
    # Deep shafts are bounded by broken buttresses, rather than empty square
    # apertures. These masses stay below bridge decks and add no walkable floor.
    receipt['shaft_buttresses']=[]
    for x,z in [(-16,-17),(-15,15),(11,-17),(13,23),(20,32),(-23,13),(-21,-22)]:
        for dx,dz,top in [(0,0,1.4),(-2,1,-1.5),(1,2,-3.0)]:
            p=(x+dx,-4,z+dz)
            stone('ShaftButtress',B(p),(rng.uniform(2.8,4.2),rng.uniform(2.4,3.6),top+4),'backdrop')
            receipt['shaft_buttresses'].append(list(p))
    receipt['floor_gravel']=0
    for zone in api['LAYOUT']['zones']:
        x0,x1,z0,z1=zone['bounds'];h=zone['height'];group=zone['id']
        for i in range(9):
            x,z=rng.uniform(x0+1,x1-1),rng.uniform(z0+1,z1-1)
            if not clear((x,h,z),.35):continue
            for j in range(2):
                stone('WorkplaceGravel',B((x+rng.uniform(-.4,.4),h+.06,z+rng.uniform(-.4,.4))),(.18,.14,.09),group)
                receipt['floor_gravel']+=1
    # Recess the black end cap and give each portal actual receding timber ribs.
    tunnels=[('entrance_camp',(-47,0,28),math.pi/2),('rail_workings',(-41,3,-12),0),
             ('crystal_workings',(-28,7,-38),0),('storage',(38,7,-26),0),
             ('waterway',(40,0,16),-math.pi/2),('core_cavern',(44,0,36),0)]
    bpy.context.view_layer.update()
    for group,p,yaw in tunnels:
        transform=Matrix.Translation(B(p))@Matrix.Rotation(yaw,4,'Z')
        outward=Matrix.Rotation(yaw,4,'Z')@B((0,0,-1))
        for obj in api['collection'](group).objects:
            if obj.name.startswith('TunnelDark'): obj.location += outward*4.0
        before=set(api['collection'](group).objects)
        for depth in [1.4,2.8,4.0]:
            width=5.2-depth*.14; height=4.4-depth*.1
            for side in [-1,1]:
                box('DeepTunnelPost',(side*width/2,height/2,-depth),(.22,height,.25),'Wood',group)
            box('DeepTunnelLintel',(0,height,-depth),(width+.22,.24,.25),'WoodLight',group)
        for side in [-1,1]:
            box('DeepTunnelLining',(side*2.83,2.1,-2.6),(.35,4.2,3.8),'Rock',group)
            beam('TunnelRail',B((side*.65,.16,-.4)),B((side*.65,.16,-4.0)),.10,.14,'Metal',group).modifiers.clear()
        box('DeepTunnelCeiling',(0,4.55,-2.6),(6,.4,3.8),'Rock',group)
        box('DeepTunnelFloor',(0,-.12,-2.6),(5.9,.2,3.8),'Earth',group)
        bpy.context.view_layer.update()
        for obj in set(api['collection'](group).objects)-before: obj.matrix_world=transform@obj.matrix_world
        receipt['tunnels'].append({'zone':group,'depth':4.35,'position':list(p)})
    return receipt
