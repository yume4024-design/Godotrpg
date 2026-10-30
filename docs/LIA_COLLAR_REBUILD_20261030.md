# 莉雅立領重建候選 — 2026-10-30

**立領外形、內襯與滾邊已重新建模；整體角色仍 visual FAIL，未換入遊戲。** 沿用最新袖口候選，保留先前手部與前臂進展。上一輪已有已提交、已測試的模型改動，屬有進展。本輪沒有重跑 ComfyUI，也沒有再調整失敗頸部圓柱配方。

## 實際改動

- 比對已核准的莉雅正面參考圖與目前正背近景。原領片有破面、交錯內襯、細長白邊；重建保持紫色開口立領、奶油白滾邊，保留胸前金扣及綁帶。
- 初始選區使用面中心，包含肩部大三角形，不採用。改以完整三角形範圍縮小。最初懷疑髮尾被選中，關閉漫反射反彈後確認橘色主要是反射染色，沒有因此刪髮。[直接光選區圖](evidence/lia_collar_rebuild_20261030/selection_direct.png)。
- 以三個明確近景矩形射線定位舊領內碎片，保留超出保護範圍的面，最終白名單265個原面；[選面清單](evidence/lia_collar_rebuild_20261030/selection.json)、[射線範圍與拒絕面](evidence/lia_collar_rebuild_20261030/fragment_selection.json)。工具鎖定來源與選區SHA，不能任意套到另一個模型。
- 新立領為有厚度的U形封閉網格，外布、滾邊、內襯共3個材質分區，最終132個三角形。以現有紫袖與白袖口材質延續配色，沒有大型新貼圖。
- 初版底緣在背面浮起；使用保留衣身表面的最近點定位9個底部控制點，移動量及座標均列入收據。這不等於整條底緣已焊接，側背部仍可見不平順接縫。
- 10,763個未選原面的座標與UV逐項保留；角落法線最大誤差0.0001064。原頸部幾何沒有改動，頸肩比例及下巴接合仍待。

## 檢查與已修正失敗

| 項目 | 結果 |
| --- | --- |
| Blender 5.2.2 LTS 原生候選 | 12,394／15,000 triangles；新領片封閉、三角化後無退化面 |
| 輸出GLB重新匯入 | PASS、12,394面、UV／材質檢查通過；原身體仍有非流形警告 |
| Godot 4.7.2 Windows Compatibility／RTX3080 | 圖形GLTFDocument靜態匯入56項／0失敗 |
| 原版角色與來源 | SHA256維持不變 |
| 骨架、動作、戰鬥、存讀檔 | 本輪未測試新角色；未修改正式遊戲 |

第一次 fitted 輸出雖通過原生多邊形面積檢查，GLB重匯入仍發現立領端蓋一個退化三角形，**Gate FAIL、不採用**。[失敗結果](evidence/lia_collar_rebuild_20261030/rejected_degenerate_gate.json)。修正六邊端蓋為共用中心的三角扇，並在匯出前實際三角化／檢查，重新匯入才通過。沒有降低面積門檻或忽略失敗。

[生成收據](evidence/lia_collar_rebuild_20261030/receipt.json)、[最終Blender檢查](evidence/lia_collar_rebuild_20261030/blender_gate.json)、[Godot檢查](evidence/lia_collar_rebuild_20261030/godot_report.json)。

## 視覺與未完成

[正面](evidence/lia_collar_rebuild_20261030/neck_front.png)／[背面](evidence/lia_collar_rebuild_20261030/neck_back.png)／[側面](evidence/lia_collar_rebuild_20261030/neck_side.png)／[斜側](evidence/lia_collar_rebuild_20261030/neck_three_quarter.png)／[Godot全身](evidence/lia_collar_rebuild_20261030/godot_front.webp)。

正面領片輪廓和內襯較完整，細長白片與多數破片消除；**斜側仍看到少量舊內領尖片，底緣與肩部仍有接縫，頸部比例、臉側／髮尾與原披肩碎面未完成**。不能以正面或56項靜態檢查宣稱角色美術完成。立領仍與衣身分離，沒有蒙皮或動畫；整體visual_gate=FAIL、rig/animation_gate=NOT_STARTED。

候選位於：

- D:/RPGGAME/artifacts/lia-collar-checked-20261030/lia_collar_trial.blend
- D:/RPGGAME/artifacts/lia-collar-checked-20261030/lia_collar_trial.glb

GLB SHA256：bffab07c98b145a40506af870006bed4fd2e4a4f0dcb0b76f51b88d15b4b2629。
blend SHA256：0409ee2d7c447df2717e71a506d908ccd5cdab5193fa0e1b11459ba7fef50d9b。
來源袖口blend SHA256：8525d65ff7c88fb8357de723598a551e6de9b94ae3644df403fcb85bed045e2b。

正式莉雅GLB仍為 d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4；原material_cleanup blend仍為1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e。未更動角色ID、數值、劇情旗標、存檔、獎勵、正式v0.6.1或RC5。

## 重現

cwd D:/RPGGAME；輸出目錄須為新目錄。本輪較早試作均保留，不被覆蓋。

~~~powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/author_lia_collar.py -- --input artifacts/lia-sleeve-boundary-trial-20261030/lia_forearm_trial.blend --selection docs/evidence/lia_collar_rebuild_20261030/selection.json --output artifacts/lia-collar-replay --fit-base
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-collar-replay/lia_collar_trial.blend --output artifacts/lia-collar-replay-render --view neck_front --view neck_back --view neck_side --view neck_three_quarter
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input artifacts/lia-collar-replay/lia_collar_trial.glb --output artifacts/lia-collar-replay/blender_gate --project-root D:/RPGGAME --category player_character --require-uv
$env:APPDATA='D:/RPGGAME/artifacts/lia-collar-replay/profile'
$env:LOCALAPPDATA=$env:APPDATA
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_collar_rebuild --solid-material=LiaAuthoredSkin --solid-material=LiaForearmLeather --solid-material=LiaForearmTrim --solid-material=LiaForearmCuff --solid-material=LiaMatchedSleeve --solid-material=LiaCollarLining --model=D:/RPGGAME/artifacts/lia-collar-replay/lia_collar_trial.glb --output=D:/RPGGAME/artifacts/lia-collar-replay/godot
~~~

下一步仍需清理斜側可見內領碎片及肩部、修整頸肩接合與衣服配色，再做蒙皮、動作及正式序章回歸。人工終驗依使用者要求暫停；Android／iOS與第一章未開始。效能尖峰仍在序章待辦中，序章尚未最終完成。
