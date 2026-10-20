# ENV02 水車 — 獨立模型候選

後續：G06 灰石村現已使用帶 A 架的 1372 面變體，修正穿岩／入水與田邊支路；153／0 及 G06 576／0，見 [場景整合](ENV02_VILLAGE_INTEGRATION_REPORT.md)。原 1212 面模組仍保留。以下為獨立建模當時的範圍，不作目前未整合的結論。

2026-10-20，**PASS（僅獨立模組）**；正式村莊替換、探索碰撞與效能未驗收。Windows／Blender 5.2.2 LTS／Godot 4.7.2.stable.official.ed1daf0bf。

## 實際交付

- `assets/models/greystone/props/waterwheel.glb`：1212／2500 triangles；Wheel 1128、FixedAxle 84，2 個 Mesh、4 surfaces、共用既有 G04 wood／iron／stone 三材質。
- 24 邊輪框、兩組八輻條、12 片水斗、輪轂、16 顆鐵栓與固定軸承，為本輪原創 Blender 建模，不是把原 BoxMesh 佔位改名。
- 外徑 4.70m、含固定軸寬 2.05m；原點在軸心、Godot X 軸旋轉，與舊佔位軸心／方向相容。厚度比舊佔位增加，正式配置仍須確認河岸及道路淨空。
- `scenes/world/greystone/props/waterwheel.tscn` 注入 GLB；`scripts/world/greystone_waterwheel.gd` 只轉動輪體，預設 7.5rpm，可停止，不修改位置／固定軸承或遊戲狀態。
- 原生／來源／SHA／失敗與最終證據在 `source_assets/environment_rebuild_20261020/`。第一版輪框和輻條外表面共面，實際畫面有閃線；第二版把輻條軸向厚度由 .14 改為 .10m，面數不變。未降低材質／幾何檢查。
- 不使用貼圖，不要求 UV 展開；不是 UV Gate 已通過。沒有骨架／GLB 動作，旋轉由模組共用腳本執行。作為河邊裝飾不另加碰撞，與原佔位契約一致。

## 實際測試

| 項目 | 結果 |
|---|---|
| 嚴格 GLB 靜態預檢 | PASS，明確 `--budget 2500 --allow-static --allow-missing-uv` |
| Blender GLB 重匯入 evaluated | PASS，1212 triangles，原件及輸出 SHA 綁定 |
| Godot 載入／材質後處理 | PASS，沿用 prop_import.gd，三個外部共享材質資源 |
| 圖形操作與旋轉 | 26 checks／0 failures；轉動、停止、8 秒模擬完整一圈、固定軸／位置、雙實例獨立、重建及六張畫面 |
| 實際畫面查看 | 三分之四、內／外側、邊緣與旋轉兩個時點；第二版閃線消失 |
| 村莊探索／碰撞／LOD 效果／FPS | NOT_STARTED；Comfy 同時生成，因此不把本次預覽當作效能測試 |

圖形微檢查：COMP-SAFE-EDGE 2、COMP-NEG-SPACE 2、COMP-BALANCE 2、COMP-DEPTH-LAYERS 1、LIGHT-KEY-FILL 1（正側面偏平）、LIGHT-SPEC-LOT 2、MOT-VOL 2，12／14，僅獨立模型畫面 B。沒有 UI／文字／戰鬥特效；不以此評分宣稱整村藝術還原或正式遊戲體驗合格。

可重現：`tools/review_waterwheel.ps1`，會使用獨立 APPDATA，圖形啟動並記錄 `artifacts/environment_rebuild_20261020/waterwheel/`。旋轉時間為測試主動給定 delta 的模擬時間，不是 10 秒實體遊玩或長時間效能驗收。

Blender 建模：`--background --factory-startup --python-exit-code 1 --python scripts/tools/greystone/build_waterwheel.py -- --output <新目錄>`；原件不覆蓋。GLB SHA／Godot 報告與預覽存於 waterwheel_v2，首版失敗另保留於 waterwheel。

## 保留事項

正式 `greystone_village.tscn` 仍引用舊佔位水車；沒有修改其入口、道路、碰撞、NPC、角色數值、存檔或 v0.6.1。28 組作物佔位、森林／礦坑／物品完整盤點、其他需要的 3D 模組及正式場景驗收仍未完成。Android／iOS 暫停，A03／A04／A05／Windows Gate／第一章仍依原依賴繼續。
