"""Repeatable procedural materials for the owned master, never the live Blender.

Used by the full builder, or run with --background --factory-startup --python
to update only materials and non-colliding underwater beds in the saved master.
Godot uses matching shared shaders because glTF cannot encode these node graphs.
"""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def linear(rgb):
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in rgb) + (1,)

def apply_surfaces():
    for material in list(bpy.data.materials):
        name = material.name
        is_stone = name.lower().startswith('stone') or '_stone' in name.lower()
        if not is_stone and name not in ('grass', 'grass_light', 'grass_shade', 'earth', 'water', 'foam'):
            continue
        material.use_nodes = True
        tree = material.node_tree
        tree.nodes.clear()
        def node(kind, label):
            result = tree.nodes.new(kind); result.label = label
            return result
        def link(output, target): tree.links.new(output, target)
        shader = node('ShaderNodeBsdfPrincipled', 'Stylized shared surface')
        output = node('ShaderNodeOutputMaterial', 'Output')
        link(shader.outputs['BSDF'], output.inputs['Surface'])
        position = node('ShaderNodeNewGeometry', 'World-space seamless coordinates')
        coarse = node('ShaderNodeTexNoise', 'Broad mineral / soil variation')
        fine = node('ShaderNodeTexNoise', 'Fine surface grain')
        for texture, scale in [(coarse, .9 if is_stone else .38), (fine, 13 if is_stone else 24)]:
            link(position.outputs['Position'], texture.inputs['Vector'])
            texture.inputs['Scale'].default_value = scale
            texture.inputs['Detail'].default_value = 1
        palette = node('ShaderNodeValToRGB', 'Soft cohesive palette')
        colors = ((.42,.44,.40),(.53,.54,.49)) if is_stone else (((.59,.45,.28),(.72,.58,.39)) if name == 'earth' else ((.34,.45,.19),(.44,.56,.25)))
        for stop, color in zip(palette.color_ramp.elements, colors): stop.color = linear(color)
        link(coarse.outputs['Fac'], palette.inputs['Fac'])
        link(palette.outputs['Color'], shader.inputs['Base Color'])
        bump = node('ShaderNodeBump', 'Subtle grain, preserve polygon silhouettes')
        bump.inputs['Strength'].default_value = .12
        bump.inputs['Distance'].default_value = .045 if is_stone else .025
        link(fine.outputs['Fac'], bump.inputs['Height']); link(bump.outputs['Normal'], shader.inputs['Normal'])
        shader.inputs['Roughness'].default_value = .94
        if is_stone:
            wave = node('ShaderNodeTexWave', 'Mineral strata')
            wave.bands_direction = 'Z'
            wave.inputs['Scale'].default_value = .15
            wave.inputs['Distortion'].default_value = 3
            link(position.outputs['Position'], wave.inputs['Vector'])
            mix = node('ShaderNodeMixRGB', 'Subtle strata shading'); mix.blend_type = 'MULTIPLY'
            mix.inputs[0].default_value = .09
            link(palette.outputs['Color'], mix.inputs[1]); link(wave.outputs['Color'], mix.inputs[2])
            link(mix.outputs[0], shader.inputs['Base Color'])
        if name in ('water', 'foam'):
            falling = name == 'foam'
            fine.noise_dimensions = '4D'
            fine.inputs['Scale'].default_value = 1.3
            fine.inputs['W'].driver_add('default_value').driver.expression = 'frame * .018'
            wave = node('ShaderNodeTexWave', 'Animated water flow')
            wave.bands_direction = 'Z' if falling else 'Y'
            wave.inputs['Scale'].default_value = .10
            wave.inputs['Distortion'].default_value = 3.0
            wave.inputs['Phase Offset'].driver_add('default_value').driver.expression = 'frame * -.12' if falling else 'frame * .025'
            link(position.outputs['Position'], wave.inputs['Vector'])
            link(wave.outputs['Color'], bump.inputs['Height'])
            bump.inputs['Strength'].default_value = .22; bump.inputs['Distance'].default_value = .08
            palette.color_ramp.elements[0].color = linear((.10,.43,.52))
            palette.color_ramp.elements[1].color = linear((.30,.66,.67) if not falling else (.67,.84,.82))
            link(fine.outputs['Fac'], palette.inputs['Fac'])
            shader.inputs['Roughness'].default_value = .22
            shader.inputs['IOR'].default_value = 1.333
            shader.inputs['Transmission Weight'].default_value = .12
            shader.inputs['Metallic'].default_value = .10
    water = bpy.data.collections.get('Water')
    if water:
        for item in list(water.objects):
            if item.name.endswith('_Bed'):
                data = item.data
                bpy.data.objects.remove(item, do_unlink=True)
                if data.users == 0: bpy.data.meshes.remove(data)
        for name, depth in [('River', 1.6), ('Lake', 1.6)]:
            surface = bpy.data.objects.get(name)
            if not surface: continue
            bed = surface.copy(); bed.data = surface.data.copy(); bed.name = name + '_Bed'
            bed.data.name = name + '_Bed'
            bed.location.z -= depth
            bed.data.materials.clear(); bed.data.materials.append(bpy.data.materials['stone'])
            water.objects.link(bed)
            bed['visual_only'] = True
    bpy.context.scene['surface_revision'] = 'procedural_grain_water_v1'
    bpy.context.scene.frame_set(48)

if __name__ == '__main__':
    source = ROOT / 'source_assets/greystone_blender_20261023/greystone_master.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source))
    apply_surfaces()
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    print('BLENDER_SURFACES_SAVED', source.stat().st_size, flush=True)
