# 莉雅前臂與五指連續拓樸重建 — 2026-10-30

狀態：**局部修整有進展，整體角色仍未驗收，不替換正式遊戲。** 本輪承接上一輪已提交的護腕試作；上一輪產出模型及實測證據，屬有進展，但局部護腕遮蓋未解決原前臂裂片。改以手掌根部的真實頂點延伸，重建整段袖口、露出皮膚、皮革護腕與細腕帶。

## 實際改動

- 來源為五指第二版 `artifacts/lia-hand-trial-v2-20261030/lia_hands_trial.blend`，SHA256 `e8ad4df994e4eb63daf6068a5a9a331a043c1c26d6ba9cd8b07bc9af2101a19a`。不以舊護腕試作疊加新補片。
- 量測手臂軸 -0.26～-0.10m 的實際截面，以 -0.255m 平面裁切損壞區。局部處理左右276／226個原面；區域外11,042個面的座標、UV逐項不變，角落法線最大誤差0.000359。
- 刪去手掌根部四個封口面，沿原10頂點邊界延伸前臂；每側前臂／五指是**同一連通封閉表面**，各235個多邊形，生成時檢查零非流形邊、零退化面。這是候選原生網格檢查，不代表全身封閉或已蒙皮；GLB因材質／UV可拆頂點。
- 掌面由平板調整為微弧截面。薄腕帶直接使用連續表面的材質分區，沒有另套方形遮蓋物。
- 最初切割誤傷相鄰面，被斷言中止；隔離選區邊界後修復。切割角落法線也曾超標，被中止；將新增切面設為平面著色後，保留區法線檢查通過。兩次中止均未輸出候選。
- 第一個輸出仍殘留內側舊袖口尖片；擴充已觀察到的內側切割區後，最新正面尖片消除。初版保留於 `artifacts/lia-forearm-authored-20261030/`，沒有改寫。

## 畫面及限制

[左側袖口](evidence/lia_forearm_retopology_20261030/sleeve_left_front.png)／[右側袖口](evidence/lia_forearm_retopology_20261030/sleeve_right_front.png)／[手背](evidence/lia_forearm_retopology_20261030/hand_left_back.png)／[手側](evidence/lia_forearm_retopology_20261030/hand_right_side.png)。[Godot全身正面](evidence/lia_forearm_retopology_20261030/godot_front.webp)／[背面](evidence/lia_forearm_retopology_20261030/godot_back.webp)。

前臂不再有原先黑色裂片或手腕重疊接縫；但新袖口與舊紫色袖子仍有重疊／不整齊的上緣，尚未接成整體。手指關節、握杖變形未驗證。原模型領口、上袖、衣服錯色及背裙接縫仍不合格。**整體 visual_gate=FAIL；rig/animation_gate=NOT_STARTED；formal_gameplay=未測試。** 人工驗收繼續暫停；Android／iOS及第一章未開始。

## 實測

| 檢查 | 實際結果 |
| --- | --- |
| GLB 靜態結構／UV／面數 | PASS，12,561／15,000 triangles |
| Blender 5.2.2 LTS 重新匯入及 evaluated mesh | PASS，12,561 triangles；原身體仍有非流形警告，不是全身封閉驗收 |
| Godot 4.7.2 Windows 圖形 GLTFDocument 匯入、材質、重建實例 | 43項／0失敗；RTX3080 Compatibility |
| 前臂與手掌連通性 | 每側單一連通組件、零非流形邊／退化面；來源blend層級 |
| 動作、戰鬥、存讀檔 | 本輪未執行；沒有修改正式模型或遊戲程式 |

[收據](evidence/lia_forearm_retopology_20261030/receipt.json)、[GLB預檢](evidence/lia_forearm_retopology_20261030/static_audit.json)、[Blender匯入](evidence/lia_forearm_retopology_20261030/blender_gate.json)、[Godot結果](evidence/lia_forearm_retopology_20261030/godot_report.json)。

候選保存在 `D:/RPGGAME/artifacts/lia-forearm-authored-final-20261030/lia_forearm_trial.blend` 及同名 `.glb`；final僅為本輪最後輸出目錄名稱，不是正式完工狀態。GLB SHA256 `5f1774321fd11d29bd5079ee9ad8291794baa998c7ab6e7691f48ac3ff7c4ccc`，blend SHA256 `fff277d5b12abf9002f5c2ac0a6245f25ddb3a42cfd1f75cc4d0f1663feb7d24`。

原始 material_cleanup blend SHA256仍為 `1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e`；正式莉雅GLB仍為 `d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4`。未改角色ID、戰鬥數值、旗標、獎勵、存檔、正式入口或RC5包。

## 重現

專案cwd `D:/RPGGAME`，輸出目錄須為新目錄。來源不匹配時拒絕執行。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/author_lia_forearms.py -- --input artifacts/lia-hand-trial-v2-20261030/lia_hands_trial.blend --output artifacts/lia-forearm-replay
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-forearm-replay/lia_forearm_trial.blend --output artifacts/lia-forearm-replay-render
& 'C:/Users/yume4/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' scripts/tools/audit_character_glb.py --input artifacts/lia-forearm-replay/lia_forearm_trial.glb --category player_character --allow-static --output artifacts/lia-forearm-replay/static_audit.json
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input artifacts/lia-forearm-replay/lia_forearm_trial.glb --output artifacts/lia-forearm-replay/blender_gate --project-root D:/RPGGAME --category player_character --require-uv
$env:APPDATA='D:/RPGGAME/artifacts/lia-forearm-replay/profile'
$env:LOCALAPPDATA=$env:APPDATA
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_forearm_authored --solid-material=LiaAuthoredSkin --solid-material=LiaForearmLeather --solid-material=LiaForearmTrim --solid-material=LiaForearmCuff --model=D:/RPGGAME/artifacts/lia-forearm-replay/lia_forearm_trial.glb --output=D:/RPGGAME/artifacts/lia-forearm-replay/godot
```

下一步需整修上袖口及領口的真實邊界、修正衣物配色，然後才綁骨、權重／七段動作及遊戲回歸。RC5已完成的自動序章結果不等於新候選角色驗收；效能尖峰及暫停的人工終驗仍待。
