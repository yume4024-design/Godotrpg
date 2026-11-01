# 莉雅髮尾材質與高領接觸修整 — 2026-11-02

## 實際完成

沿用最新頭頸比例候選，沒有重新生成角色。檢查336個髮尾面，調整294個頂點；側髮向外讓開立領，後髮稍向後，四個藏在領內的髮束頂點提高到1.675m。最大局部位移0.072392m。四個頂點中的5901與三個後腦底面4223／4224／4990共用，這三個面的幾何也受影響；並非只有336個髮尾面發生幾何變化。

臉部正面、眼睛、嘴、上部髮根及未選頂點保持；其他五個模型的頂點完全相同，原有UV保持。局部變形以反轉置法線變換維持髮束平滑，內側四點採面方向差異旋轉，避免直接全改平面法線造成橫向分層。

在Blender把指定髮尾的金色材質與原色過渡烘焙成獨立2048×2048材質，再以GLB輸出。保留原貼圖及臉部材質；新增一個材質表面與一張貼圖，沒有將不可匯出的程序節點當作Godot可用材質。這會增加貼圖記憶體，未進行整體效能驗收。

## 測試與限制

| 檢查 | 實際結果 |
| --- | --- |
| 指定髮尾與高領的三角面穿越檢查 | 來源117組相交面對，第一版20組，最終0組 |
| 保護條件 | 第一次提高內髮點時被共用頂點保護攔下；檢查三個後腦底面後明確納入幾何影響範圍，沒有全域關閉保護 |
| Blender 5.2.2 LTS重新匯入 | PASS，11,492／15,000三角面，UV及材質通過 |
| Godot 4.7.2原生圖形模式 | 66項／0失敗，1.95m、腳底0m，RTX3080 Compatibility |
| 視覺 | 查看同鏡頭正／側／背／斜側及Godot全身；髮尾白紫錯色及穿過領緣的問題減少，保留金色層次 |
| 正式模型 | 原lia_rigged.glb SHA未變，未換入遊戲 |
| 骨架、動畫、戰鬥、讀檔 | 新候選無骨架，本輪未驗收；不是正式角色完成 |

相交檢查用有限線段與三角面測試，排除端點1e-6m；117與0是指定面集合的**相交面對**，不是117個獨立穿模區域。沒有檢查共面貼合、全身自交或動作時的安全距離，不宣稱全身無穿模。既有NONMANIFOLD_OR_BOUNDARY警告仍保留。

側面髮束仍有低面數尖角及根部色差；臉側貼圖切面、衣身／裙襬錯色及碎面、骨架動作、序章效能尖峰仍待修。整體visual gate與正式角色整合未通過。人工終驗繼續暫停，Android／iOS與第一章未開始。

[修整收據](evidence/lia_hair_repair_20261102/receipt.json)、[第一版剩餘20組](evidence/lia_hair_repair_20261102/first_trial.json)、[Blender結果](evidence/lia_hair_repair_20261102/blender_gate.json)、[Godot結果](evidence/lia_hair_repair_20261102/godot_report.json)、[全身畫面](evidence/lia_hair_repair_20261102/godot_front.webp)。

| 視角 | 修整前 | 修整後 |
| --- | --- | --- |
| 正面 | [前](evidence/lia_hair_repair_20261102/before_neck_front.png) | [後](evidence/lia_hair_repair_20261102/after_neck_front.png) |
| 側面 | [前](evidence/lia_hair_repair_20261102/before_neck_side.png) | [後](evidence/lia_hair_repair_20261102/after_neck_side.png) |
| 背面 | [前](evidence/lia_hair_repair_20261102/before_neck_back.png) | [後](evidence/lia_hair_repair_20261102/after_neck_back.png) |
| 斜側 | [前](evidence/lia_hair_repair_20261102/before_neck_three_quarter.png) | [後](evidence/lia_hair_repair_20261102/after_neck_three_quarter.png) |

## 檔案與重現

- 工具：scripts/tools/repair_lia_hair_tips.py。
- 輸入：artifacts/lia-neck-normalized-20261102/lia_neck_fit.blend；SHA256 9d0a72d8642bef5799e691a1c5e64aa33ac87bf4e6853cd439b26c92cb4cfe98。
- 選取：docs/evidence/lia_hair_repair_20261102/selection.json。
- 輸出：D:/RPGGAME/artifacts/lia-hair-final-20261102/lia_hair_repaired.blend 與.glb；髮尾貼圖同目錄。
- 最終GLB SHA256：842a29186333cfe82f5158fd38420e7023601d3b2cc36b905436f1de47d9d61b。
- 最終blend SHA256：d657861cc239bc5b1750a43196f0e63f5b5d8af124e694a53b67f7e4cdb3c2b4。
- 正式莉雅 SHA256：d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4。

在D:/RPGGAME執行，下列新輸出目錄必須尚不存在。選取內容與實際執行的artifacts版本相同。

~~~powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/repair_lia_hair_tips.py -- --input artifacts/lia-neck-normalized-20261102/lia_neck_fit.blend --selection docs/evidence/lia_hair_repair_20261102/selection.json --output artifacts/lia-hair-replay-20261102
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-hair-final-20261102/lia_hair_repaired.blend --output artifacts/lia-hair-final-render-20261102 --view neck_front --view neck_side --view neck_back --view neck_three_quarter
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input artifacts/lia-hair-final-20261102/lia_hair_repaired.glb --output artifacts/lia-hair-final-20261102/blender_gate --project-root D:/RPGGAME --category player_character --require-uv
$env:APPDATA='D:/RPGGAME/artifacts/lia-hair-final-20261102/profile'
$env:LOCALAPPDATA=$env:APPDATA
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_hair_final --solid-material=LiaAuthoredSkin --solid-material=LiaForearmLeather --solid-material=LiaForearmTrim --solid-material=LiaForearmCuff --solid-material=LiaMatchedSleeve --solid-material=LiaCollarLining --model=D:/RPGGAME/artifacts/lia-hair-final-20261102/lia_hair_repaired.glb --output=D:/RPGGAME/artifacts/lia-hair-final-20261102/godot
~~~

未改角色ID、戰鬥數值、技能、旗標、獎勵、存檔或正式主遊戲入口；Windows RC5保留。本輪僅提交工具、選取及驗收證據，生成的blend／GLB保持在本機候選目錄。

使用已入版選取重跑至lia-hair-replay-20261102，GLB SHA256完全相同；[重現結果](evidence/lia_hair_repair_20261102/replay.json)。
