# 莉雅袖口邊界接合 — 2026-10-30

**袖口局部修整完成靜態檢查，整體角色仍未合格，未替換正式莉雅。** 上輪已修復前臂與五指，本輪改正新白袖口和舊紫袖子的中心偏移、重疊尖邊；不是繼續套遮蓋物。上一輪已提交模型生成工具與實測證據，屬有進展。

## 修整

- 新增 `author_lia_forearms.py --match-sleeve`；原有模式保留。從同一五指第二版來源生成，沿手臂軸 -0.32m 量測實際切口，外圈分別11／13頂點，內圈12／13頂點。
- 檢查發現兩側內襯穿出外袖，先前要求完整嵌套的檢查因此拒絕執行。修正僅在切面內襯，依外圈向內3mm重建；最大移動9.716／5.641mm，保持外側輪廓不動。重新檢查內圈頂點位於外圈內，並逐邊確認不相交。這僅證明切面，不證明整條袖管無自交。
- 另一側還有獨立小碎片，檢查中明確辨識為三個原面10139～10141；連通追查確認只有局部小片，才移除。沒有忽略第三個圈或放寬檢查當作通過。
- 新袖管接到實測外圈頂點；使用原紫袖貼圖取樣中位色（sRGB約0.4294／0.2706／0.5843）建立純色材質，保留原款紫色、奶油白袖口及皮革護腕。舊袖子的烘焙色與新區域光影仍可見差異。
- 10,979個未選原面的座標／UV逐項保留，角落法線最大誤差0.000359；前臂至手掌仍各為單一封閉連通表面。

[正面左](evidence/lia_sleeve_join_20261030/sleeve_left_front.png)／[正面右](evidence/lia_sleeve_join_20261030/sleeve_right_front.png)／[背面左](evidence/lia_sleeve_join_20261030/sleeve_left_back.png)／[背面右](evidence/lia_sleeve_join_20261030/sleeve_right_back.png)／[側面](evidence/lia_sleeve_join_20261030/sleeve_right_side.png)／[Godot全身](evidence/lia_sleeve_join_20261030/godot_front.webp)。

## 實際測試

| 項目 | 結果與範圍 |
| --- | --- |
| Blender 5.2.2 LTS GLB預檢及重新匯入 | PASS，12,527／15,000三角形；全身仍有原模型非流形警告 |
| Godot 4.7.2 Windows圖形匯入 | 48項／0失敗，Compatibility／RTX3080；靜態材質與實例，不是動作測試 |
| 輸出GLB袖口邊界對位 | 11／13個唯一外圈頂點，距原袖管頂點最大約6.01e-8／7.17e-8m，容差1e-5m |
| 反例檢查 | 獨立GLB副本將一側邊圈移開1cm，檢查以約0.01m距離拒絕、exit1，沒有產生PASS報告 |
| 同模式重跑 | 新袖口GLB SHA256逐位元一致 |
| 原模式回歸 | 未使用新旗標的GLB仍與上輪12,561面候選SHA256一致 |

[生成收據](evidence/lia_sleeve_join_20261030/receipt.json)、[Blender檢查](evidence/lia_sleeve_join_20261030/blender_gate.json)、[Godot檢查](evidence/lia_sleeve_join_20261030/godot_report.json)、[邊界對位](evidence/lia_sleeve_join_20261030/seam_check.json)、[錯位反例](evidence/lia_sleeve_join_20261030/negative_check.json)、[重跑](evidence/lia_sleeve_join_20261030/reproduced_receipt.json)、[舊模式回歸](evidence/lia_sleeve_join_20261030/default_regression_receipt.json)。

## 未完成與保存

袖口靜態外表接合較完整，但新舊袖管仍是獨立Mesh、沒有焊接，也未統一蒙皮權重；對位檢查不能證明動畫時不裂開。肩部披肩、領口、衣服錯色、裙側及腰包仍需修整，手指抓握與全身骨架／七段動作未完成。整體visual_gate仍FAIL；animation與正式遊戲整合未測試。本輪沒有修改遊戲程式，沒有沿用RC5測試宣稱新模型已通過戰鬥／讀檔。

候選 `D:/RPGGAME/artifacts/lia-sleeve-boundary-trial-20261030/lia_forearm_trial.blend` 及 `.glb`。GLB SHA256 `a2c20807c4c0a8c47a9b052dba2c47189cb296dc1939adc6802207c1b06d03d8`；原生blend SHA256 `8525d65ff7c88fb8357de723598a551e6de9b94ae3644df403fcb85bed045e2b`。重跑blend雜湊可不同，僅GLB逐位元重現。

正式莉雅SHA256仍 `d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4`，原material_cleanup blend仍 `1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e`。正式v0.6.1、RC5、劇情、數值、存檔與獎勵帳本不變。人工終驗仍暫停；Android／iOS與第一章未開始；序章仍未最終完成。

## 重現命令

cwd `D:/RPGGAME`，每個輸出目錄／報告必須是新路徑。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/author_lia_forearms.py -- --input artifacts/lia-hand-trial-v2-20261030/lia_hands_trial.blend --output artifacts/lia-sleeve-replay --match-sleeve
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-sleeve-replay/lia_forearm_trial.blend --output artifacts/lia-sleeve-replay-render --view sleeve_left_front --view sleeve_right_front --view sleeve_left_back --view sleeve_right_back --view sleeve_right_side
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input artifacts/lia-sleeve-replay/lia_forearm_trial.glb --output artifacts/lia-sleeve-replay/blender_gate --project-root D:/RPGGAME --category player_character --require-uv
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/check_lia_sleeve_join.py -- --input artifacts/lia-sleeve-replay/lia_forearm_trial.glb --output artifacts/lia-sleeve-replay/seam_check.json
$env:APPDATA='D:/RPGGAME/artifacts/lia-sleeve-replay/profile'
$env:LOCALAPPDATA=$env:APPDATA
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_sleeve_join --solid-material=LiaAuthoredSkin --solid-material=LiaForearmLeather --solid-material=LiaForearmTrim --solid-material=LiaForearmCuff --solid-material=LiaMatchedSleeve --model=D:/RPGGAME/artifacts/lia-sleeve-replay/lia_forearm_trial.glb --output=D:/RPGGAME/artifacts/lia-sleeve-replay/godot
```

反例生成程式及被拒絕GLB保留於本輪artifacts目錄的 `make_negative.py`／`detached_negative.glb`，不作可用候選。下一步優先修整領口及肩部真實邊界，再處理衣物配色、蒙皮與動作；效能尖峰及人工終驗仍另列待辦。
