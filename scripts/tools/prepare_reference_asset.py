"""Build one current Pixal3D API copy from live slots and a ready reference set."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
from asset_triangle_budget import resolve_budget

ROOT = Path(__file__).resolve().parents[2]


def prepare(source, slots_file, asset, category, output):
    catalog = json.loads((ROOT / 'source_assets/reference_library_20261020/catalog.json').read_text(encoding='utf8'))
    if not catalog[asset]['ready_for_generation']:
        raise ValueError('Source approval gate not ready')
    if output.exists() and any(output.iterdir()):
        raise FileExistsError('Output must be new or empty')
    raw = source.read_bytes()
    ui = json.loads(raw)
    slots = json.loads(slots_file.read_text(encoding='utf8'))['slots']
    nodes = {str(node['id']): node for node in ui['nodes']}
    links = {link[0]: link for link in ui['links']}
    def origin(link_id):
        link = links[link_id]
        node = nodes[str(link[1])]
        if node.get('mode', 0) == 4:
            kind = node['outputs'][link[2]]['type']
            incoming = [port for port in node['inputs'] if port.get('link') is not None and port['type'] == kind]
            if len(incoming) != 1:
                raise ValueError('Ambiguous bypass; inspect latest UI')
            return origin(incoming[0]['link'])
        return [str(link[1]), link[2]]
    graph = {}
    for key, node in nodes.items():
        if node.get('mode', 0) != 0 or node['type'] in ['Note', 'MarkdownNote']: continue
        inputs = {slot['address'].split('.', 1)[1]: slot['current_value'] for slot in slots if slot['address'].startswith(key + '.')}
        for port in node.get('inputs', []):
            if port.get('link') is not None: inputs[port['name']] = origin(port['link'])
        graph[key] = {'class_type': node['type'], 'inputs': inputs}
    def only(kind):
        found = [key for key, node in graph.items() if node['class_type'] == kind]
        if len(found) != 1: raise ValueError('Changed UI class layout: ' + kind)
        return found[0]
    maximum = resolve_budget(category)
    decimate, upsample, remesh = only('DecimateMesh'), only('Trellis2UpsampleStage'), only('RemeshMesh')
    changes = []
    for node, key, value, reason in [
        (decimate, 'target_face_count', int(maximum * .92), '8% candidate headroom; final mesh still audited'),
        (upsample, 'target_resolution', int(graph[upsample]['inputs']['target_resolution']), 'INT correction from current UI'),
        (remesh, 'smooth_iters', 0, 'Preserve small fingers/hair/clothing facets'),
        (remesh, 'drop_small_components', 0.0, 'Do not delete small garment/hand/accessory components')]:
        previous = graph[node]['inputs'][key]
        graph[node]['inputs'][key] = value
        changes.append({'node': node, 'field': key, 'before': previous, 'after': value, 'reason': reason})
    conditioning = only('Pixal3DMultiViewConditioning')
    views = {}
    preview_roots = []
    def ancestors(roots):
        result = {}
        def visit(key):
            if key in result: return
            result[key] = copy.deepcopy(graph[key])
            for value in graph[key]['inputs'].values():
                if isinstance(value, list) and len(value) == 2 and isinstance(value[0], str) and value[0] in graph:
                    visit(value[0])
        for root in roots: visit(root)
        return result
    for view in ['front', 'left', 'back', 'right']:
        connected = ancestors([graph[conditioning]['inputs'][view][0]])
        loads = [key for key, node in connected.items() if node['class_type'] == 'LoadImage']
        saves = [key for key, node in connected.items() if node['class_type'] == 'SaveImageAdvanced']
        if len(loads) != 1 or len(saves) != 1: raise ValueError('Changed conditioning image chain')
        image_name = 'crystal_' + asset + '_' + view + '.png'
        graph[loads[0]]['inputs']['image'] = image_name
        graph[saves[0]]['inputs']['filename_prefix'] = 'crystal_a05/' + asset + '/' + view
        preview_roots.append(saves[0])
        views[view] = {'load_node': loads[0], 'server_image': image_name, 'preview_node': saves[0],
                       'chain_classes': [node['class_type'] for node in connected.values()]}
    saves = [key for key, node in graph.items() if node['class_type'] == 'Save3DAdvanced']
    if len(saves) != 1: raise ValueError('Inspect current model output before changing it')
    graph[saves[0]]['inputs']['filename_prefix'] = 'crystal_a05/' + asset + '/' + asset + '_textured'
    # Preserve decoded geometry before both remeshing and decimation.
    raw_mesh = graph[remesh]['inputs']['mesh']
    graph['10001'] = {'class_type': 'MeshToFile3D', 'inputs': {'mesh': raw_mesh}}
    graph['10002'] = {'class_type': 'Save3DAdvanced', 'inputs': {'model_3d': ['10001', 0],
        'filename_prefix': 'crystal_a05/' + asset + '/' + asset + '_source', 'viewport_state': '', 'width': 1024, 'height': 1024}}
    output.mkdir(parents=True, exist_ok=True)
    for name, roots in [('inputs.api.json', preview_roots), ('full.api.json', [saves[0], '10002'])]:
        (output / name).write_text(json.dumps(ancestors(roots), ensure_ascii=False, indent=2), encoding='utf8')
    (output / 'workflow_source.json').write_bytes(raw)
    manifest = {'asset': asset, 'category': category, 'maximum_triangles': maximum,
        'candidate_target': int(maximum*.92), 'status': 'IN_PROGRESS', 'generation_submitted': False,
        'source_workflow_sha256': hashlib.sha256(raw).hexdigest(), 'changes': changes,
        'views': views, 'references': catalog[asset],
        'seeds': {slot['address']: slot['current_value'] for slot in slots if slot['address'].endswith('.seed')},
        'unverified': ['Actual conditioning outputs', 'GPU generation', 'Final GLB/rig/animation/visual gates']}
    (output / 'generation_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
    (output.parent / '.gdignore').touch()
    print('PREPARED_SINGLE_ASSET', asset, maximum, views)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--slots', type=Path, required=True)
    parser.add_argument('--asset', required=True)
    parser.add_argument('--category', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.source, args.slots, args.asset, args.category, args.output)
