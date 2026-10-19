"""Record one completed agent visual review alongside executable QA evidence."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]


def finalize(name, visual_notes):
    folder = ROOT / 'source_assets/asset_production_a03' / name
    evidence = ROOT / 'artifacts/asset_a03' / name
    deformation = json.loads((evidence / 'deformation.json').read_text(encoding='utf8'))
    graphical = json.loads((evidence / 'godot/report.json').read_text(encoding='utf8'))
    triangle = json.loads((folder / 'triangle_report.json').read_text(encoding='utf8'))
    if deformation['status'] != 'PASS' or graphical['failures'] or triangle['status'] != 'PASS':
        raise ValueError('Do not finalize a failing candidate')
    if graphical['triangles'] != triangle['triangles']:
        raise ValueError('Engine/export triangle mismatch')
    runtime = ROOT / triangle['file']
    current_sha = hashlib.sha256(runtime.read_bytes()).hexdigest()
    if current_sha != triangle['sha256'] or current_sha != graphical.get('model_sha256'):
        raise ValueError('GLB changed since executable QA; rerun against the selected export')
    if hashlib.sha256((folder / 'optimized.glb').read_bytes()).hexdigest() != current_sha:
        raise ValueError('Review/runtime GLB mismatch')
    if hashlib.sha256((folder / 'optimized.blend').read_bytes()).hexdigest() != deformation['sha256']:
        raise ValueError('Blend changed since evaluated motion QA')
    required = {'idle', 'walk', 'attack', 'hit', 'death'}
    if name == 'thorn_boar': required |= {'run', 'charge'}
    if name == 'corrupted_guardian': required |= {'heavy_attack', 'special_attack', 'stagger'}
    if not required <= {clip['name'] for clip in graphical['clips']}:
        raise ValueError('Missing species-specific clips')
    for source, target in [('view_0.webp', 'preview_front.webp'), ('view_1.webp', 'preview_side.webp'),
                           ('view_2.webp', 'preview_back.webp'), ('view_0.webp', 'preview_in_godot.webp')]:
        shutil.copy2(evidence / 'godot' / source, folder / target)
    for source, target in [(evidence / 'deformation.json', 'deformation_report.json'),
                           (evidence / 'godot/report.json', 'godot_report.json')]:
        shutil.copy2(source, folder / target)
    manifest_path = folder / 'generation_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf8'))
    master = next(iter(sorted((ROOT / 'source_assets/monster_rebuild_20261019' / name / 'outputs').glob(name + '_source_*.glb'))), None)
    if master:
        manifest['high_density_master'] = {'path': master.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(master.read_bytes()).hexdigest(), 'bytes': master.stat().st_size,
            'git_policy': 'Original preserved locally; giant binary excluded from commit'}
    manifest['status'] = 'PASS'
    manifest['acceptance_scope'] = 'A03 model/rig/representative animation candidate; A04 gameplay integration pending'
    manifest['gates'] = {'triangle': 'PASS', 'structure_weights_uv': 'PASS',
                         'deformation': 'PASS', 'graphical_import_motion': 'PASS',
                         'agent_visual_review': 'PASS', 'formal_battle': 'NOT_STARTED'}
    manifest['visual_notes'] = visual_notes
    manifest['limitations'] = ['Nonmanifold intersections remain; not certified watertight',
                               'No new physical player playthrough or performance benchmark',
                               'A04 formal battle/exploration regression remains required']
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
    text = f'''# {name} — A03 候選驗收

2026-10-20；Godot 4.7.2.stable.official.ed1daf0bf／Blender 5.2.2 LTS／Windows RTX 3080。
狀態 PASS，範圍僅模型、骨架、代表性動畫與圖形匯入；A04 正式戰鬥／探索整合未執行。

- 分類 {triangle['category']}，上限 {triangle['maximum_triangles']}；GLB／Godot {triangle['triangles']} triangles。
- 骨架 {deformation['bones']} 骨，{len(graphical['clips'])} 片段；Blender {deformation['total_frames']} 影格數值檢查 PASS。
- Godot 圖形 {graphical['checks']} checks，0 failures；UV／貼圖／Skin、動作切換、循環／單次、四面與重新實例化驗證。
- 實際視覺檢查：{visual_notes}
- 拓樸警告：{json.dumps(deformation['topology_warnings'], ensure_ascii=False)}。沒有宣稱全封閉或完美自碰撞。
- 舊 Pixal3D 原始及高密度來源保留；本輪重用選定候選，沒有重複提交生成工作。雜湊、歷史 prompt_id、參數見 generation_manifest.json。

可重現：tools/review_enemy_asset.ps1 -Asset {name}；離線數值工具 scripts/tools/audit_asset_motion.py；嚴格 GLB 工具 audit_character_glb.py。
產生的 4 張 WebP 為真實 Godot 畫面，不是模型示意。動畫／物理／戰鬥功能需在 A04 接線後重新驗證；數值、技能、旗標及存檔未改。
'''
    (folder / 'validation_report.md').write_text(text, encoding='utf8')
    manifest['outputs'] = [{'file': path.relative_to(folder).as_posix(),
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
                           for path in sorted(folder.glob('*'))
                           if path.is_file() and path.name != 'generation_manifest.json']
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
    print('A03_CANDIDATE_PASS', name, graphical['checks'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--asset', required=True)
    parser.add_argument('--visual-notes', required=True, help='Only after actually viewing representative graphical captures')
    args = parser.parse_args()
    finalize(args.asset, args.visual_notes)
