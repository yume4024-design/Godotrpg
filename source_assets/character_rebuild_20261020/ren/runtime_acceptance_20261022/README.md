# 雷恩可玩候選：凍結驗收證據

2026-10-22；來源基線252808c，功能分支feature/greystone-g06。完整行為與限制見 [整合報告](../../../../docs/REN_RUNTIME_INTEGRATION_REPORT.md)。

- `evidence.json`：真實最終93／64／84／9、原88、G06十六模式576／0、日誌名稱／SHA與正式原件保留證明。
- `controller/`、`movement/`、`story/`：最終圖形報告與31張實際framebuffer WebP；短邊512，不是生成示意圖。
- `equipment_final_grip.json`：14段270影格、.45rad單組握持、最大邊拉伸／循環端點／刀刃遠端相交檢查；不涵蓋獨立五指與所有blend。
- `preservation_final.json`：原七動作127影格、骨rest、albedo、指定附件面與原表面／UV／法線保留。
- `glb_final.json`、`blender_import.json`：獨立結構檢查與實測角色10655面、短劍330面。
- `g06_regression.json`：對共用控制器及G06接線改動的完整既有回歸；不當作新角色長時間效能測試。
- `failures/`：v1腋下拉伸、v2弱防禦、寬步幅60／2，以及窄腳距卻凍結動作的93／2重現。數值可過而視覺拒用的資料不刪。
- `*_build.json`：三份持劍配方、兩份窄步幅副本及原創短劍來源／輸出SHA。原失敗大模型仍在本機，未重複加入Git。
- `sha256.json`：相對專案根目錄的文字LF／UTF8無BOM、二進位原樣SHA；README與後續清單另由Git提交固定。

必要工作原件為 `../runtime_narrow_motion_20261022/ren_runtime.blend`；遊戲用GLB在 `assets/models/rebuilt_characters/ren_runtime.glb`，二者未合併武器。原縫合Native已由前輪保留，不另複製。Godot自動抽取的兩份貼圖與import設定一併保存。

從同一已驗證縫合原件可重建，所有輸出必須是新資料夾；工具不修改原始模型：

```powershell
$blender = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $blender --background --factory-startup --python-exit-code 1 --python scripts/tools/author_ren_equipment_actions.py -- --input source_assets/character_rebuild_20261020/ren/stitched_waist_20261021/ren_rigged.blend --sword source_assets/character_rebuild_20261020/ren/sword_20261021/bronze_sword.blend --recipe hinge-v3 --output artifacts/ren_reproduce/actions
& $blender --background --factory-startup --python-exit-code 1 --python scripts/tools/author_ren_narrow_gait.py -- --input artifacts/ren_reproduce/actions/ren_runtime.blend --output artifacts/ren_reproduce/narrow
```

候選只透過 `scenes/tools/ren_runtime_game.tscn`注入既有G06；正式main／原角色模型與SaveCodec不替換。沒有新Windows打包長測或人工輸入驗收，沒有手機實機驗收，第一章未完成。
