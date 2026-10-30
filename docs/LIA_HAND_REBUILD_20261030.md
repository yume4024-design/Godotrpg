# 莉雅五指手部試作 — 2026-10-30

**仍為靜態候選，不可替換遊戲角色。** 原始手部近景呈尖爪狀；沿用此前已製作的背裙修整副本，重新建立左右手掌與五指。第二版手型比原始輪廓清楚，手掌與手指各形成連續封閉網格；但手腕仍有開口和尖片、手指比例與皮膚細節仍需修整，衣袖、領口和裙襬錯色亦未完成。手掌與身體尚未焊接，沒有骨架、權重或動作。

## 實際版本

| 版本 | 結果 |
| --- | --- |
| 原始候選 | [右手正面](evidence/lia_hand_rebuild_20261030/before_right_front.png)呈尖爪狀，不能辨識完整五指。 |
| 第一版 | [右手正面](evidence/lia_hand_rebuild_20261030/v1_right_front.png)有五指，但手指與手掌分離、銜接不自然；不採用。 |
| 第二版 | [右手正面](evidence/lia_hand_rebuild_20261030/v2_right_front.png)、[左手正面](evidence/lia_hand_rebuild_20261030/v2_left_front.png)、[右手背面](evidence/lia_hand_rebuild_20261030/v2_right_back.png)：重建連續手掌及五指，仍有手腕裂口與尖片；暫留待後續拓樸修整。 |
| 第三版 | 參照原設計試作腕帶，[正面](evidence/lia_hand_rebuild_20261030/v3_left_front.png)及[側面](evidence/lia_hand_rebuild_20261030/v3_right_side.png)顯示腕帶過寬，不能視作完成接合；不採用。 |

三版均以獨立 Blender 副本建立，保留原始遊戲資產。根據實際手腕位置僅切除候選身體網格兩側共 254 面，檢查其餘 11,544 面的頂點、UV 與角落法線（最大誤差 0.000135）。每側新手掌與五指共 256 三角形，使用原有皮膚色；這是參考圖的簡化試作，沒有宣稱精確複製手部或可自然持杖。

## 檢查與限制

- Blender 5.2.2 LTS：第二版 GLB 原始資產預檢及重新匯入 evaluated mesh **12,532／15,000 triangles**，無退化面，手部各 256 面且各自 0 非流形邊。身體和頸部仍有非流形／UV 邊界警告；手部局部封閉不代表全身封閉。[Blender 報告](evidence/lia_hand_rebuild_20261030/blender_gate.json)。
- Godot 4.7.2、Windows、Compatibility／RTX 3080：GLTFDocument 靜態圖形載入及重建實例 **28／0**，高度 1.95m，已檢視[全身正面](evidence/lia_hand_rebuild_20261030/v2_godot_front.webp)。這不是動畫或完整遊戲流程驗收。[結果](evidence/lia_hand_rebuild_20261030/godot_report.json)。
- 從原本 `material_cleanup_v2_20261029/lia_material_cleanup.blend` 重跑背裙第二版、再建連續手部，第二次 GLB SHA256 與首次完全相同：`5bc7dc7106a698c6312c66a6f26cd042eb4c54dd3ff1bc787c7b3d998c6f3568`。原始 blend 與現有可玩 `lia_rigged.glb` 雜湊不變。
- 這輪 **visual FAIL；rig／animation NOT_STARTED**。不能把舊可玩莉雅的持杖／動作測試套用到此模型。三個試作已保留；不要繼續用腕帶遮蓋取代手腕的實際拓樸修復。

## 本機候選及重現

第二版工作檔與 GLB 在 `D:/RPGGAME/artifacts/lia-hand-trial-v2-20261030/`，均為未進遊戲的暫存候選；三版收據與畫面已保存在 `docs/evidence/lia_hand_rebuild_20261030/`。請在專案根目錄執行；以下輸出目錄必須不存在。

```powershell
$blender = 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& $blender --background --factory-startup --python-exit-code 1 --python scripts/tools/repair_lia_skirt_fragments.py -- --input source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.blend --output artifacts/lia-hand-replay/skirt --thorough
& $blender --background --factory-startup --python-exit-code 1 --python scripts/tools/repair_lia_hands.py -- --input artifacts/lia-hand-replay/skirt/lia_skirt_repair.blend --source-receipt artifacts/lia-hand-replay/skirt/receipt.json --output artifacts/lia-hand-replay/hands --continuous
& $blender --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-hand-replay/hands/lia_hands_trial.blend --output artifacts/lia-hand-replay/render --hands-only
```

下一步需在 Blender 中精修腕口與前臂拓樸，核對手腕／護腕四面接合，再修袖口、領口與裙面材質；完成後才綁骨並測走跑、持杖和施法。暫不要求恢復人工驗收，也不動 Android／iOS、第一章、序章數值或存檔。
