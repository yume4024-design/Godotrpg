# 莉雅連續衣身與開衩下襬重建 — 2026-11-03

## 完成範圍

依已採用的莉雅正／背／側面設計，重建紫色收腰衣身、象牙白內襯、前開襟與後開衩的雙側下襬、連續白色滾邊、皮腰帶、金色框扣、單一腰包、領口扣與三組交叉皮繩。保留上一版已修的髮尾、立領、披肩、袖口、手與前臂。

量測來源在1.05–1.535m的衣身截面；新下襬從1.21m向下展開，前後尖端約0.90m、側面約0.965m。原圖的配色與服裝部件關係保留；這是人工網格重建，沒有再次執行AI生成，也沒有用Decimate壓低面數。

移除7106個舊衣物／皮帶／重複腰包／殘留外層面，保留2378個來源面的位置和UV；保留面法線最大誤差0.001022。其他五個既有模型逐頂點與UV相同。重建衣物由22個原生封閉組件、2088三角面構成；合併成LiaTailoredOutfit，共用7種材質，blend保留各部位頂點群組供後續蒙皮。全角共6474／15,000三角面，7個Mesh物件。減少的面數來自替換破損疊面，不代表面數減少本身就是美術品質驗收。

## 問題重現及修正

- 首次製作腰包翻蓋時，倒角碰到薄片一半厚度，退化面斷言中止。限制倒角為最薄尺寸的24%以內後重建，沒有跳過檢查。
- 首版腰帶下緣不足以包住展開的衣襬，造成鋸齒狀穿插；加大底圈並使扣框隨腰帶斜面貼合。432條環繞射線在6個高度、每5度檢查外層材質：首版220失敗、修正版0失敗。
- 綁繩改以實際新衣身射線求得表面位置，再保留3.5mm間距；不再用固定深度導致側面浮空。
- 清除殘留舊衣片分層：第一版選取6943面，射線定位10面、外層輪廓134面、最後腰包底片及裙角19面，最終7106面。每輪原候選保留，選取檔包含各輪追加ID。
- 新配件及兩側下襬合併為一個衣物物件，沒有把每條綁繩留成遊戲中的獨立物件。

## 實際驗證

| 項目 | 結果 |
| --- | --- |
| Blender 5.2.2 LTS GLB重新匯入 | PASS，6,474三角面，UV、材質、有限數值與退化面檢查通過 |
| 新衣物原生網格 | 22個組件均為manifold且沒有零面積三角面；不是全身封閉宣告 |
| 腰帶外層射線回歸 | 首版432／220失敗，最終432／0；失敗版exit1、最終exit0 |
| Godot 4.7.2原生圖形模式 | 85項／0失敗，RTX3080 Compatibility，身高1.95m與腳底0m |
| 實際畫面 | 同鏡頭、同光照、900×900四角衣物近照及Godot全身；查看正／背／側／斜側 |
| 正式莉雅／遊戲 | 正式GLB雜湊不變，未改場景入口、角色ID、數值、劇情、獎勵或存檔 |
| 骨架及動作 | 此候選仍無骨架，本輪沒有動畫、戰鬥或存讀檔整合驗收 |

腰帶測試只證明這些靜態環繞射線的第一層是皮帶或扣件，不能證明全身無穿模、所有角度或動作時均安全。GLB保留NONMANIFOLD_OR_BOUNDARY警告（既有表面與UV／材質分割），未放寬檢查以宣稱全身封閉。

衣身和下襬的主要破面、錯色及腰包重影已改善。髮根、臉側原有貼圖切面、腿部金色飾片／靴子細節仍有粗糙處；腰包仍是簡化輪廓，細部造型與參考仍有差異。整體角色visual gate與正式整合仍待，不能以85項靜態檢查宣稱角色完成。下一步為利用保留的衣片區域建立權重、檢查走跑／施法／受擊等代表動作，再決定是否換入候選遊戲。

[修整收據](evidence/lia_coat_rebuild_20261103/receipt.json)、[首版腰帶失敗](evidence/lia_coat_rebuild_20261103/waist_fit_before.json)、[最終腰帶結果](evidence/lia_coat_rebuild_20261103/waist_fit.json)、[Blender結果](evidence/lia_coat_rebuild_20261103/blender_gate.json)、[Godot結果](evidence/lia_coat_rebuild_20261103/godot_report.json)、[全身](evidence/lia_coat_rebuild_20261103/godot_front.webp)。

| 視角 | 修整前 | 修整後 |
| --- | --- | --- |
| 正面 | [前](evidence/lia_coat_rebuild_20261103/before_coat_front.png) | [後](evidence/lia_coat_rebuild_20261103/after_coat_front.png) |
| 背面 | [前](evidence/lia_coat_rebuild_20261103/before_coat_back.png) | [後](evidence/lia_coat_rebuild_20261103/after_coat_back.png) |
| 側面 | [前](evidence/lia_coat_rebuild_20261103/before_coat_side.png) | [後](evidence/lia_coat_rebuild_20261103/after_coat_side.png) |
| 斜側 | [前](evidence/lia_coat_rebuild_20261103/before_coat_three_quarter.png) | [後](evidence/lia_coat_rebuild_20261103/after_coat_three_quarter.png) |

## 檔案與重現

- 輸入：artifacts/lia-hair-final-20261102/lia_hair_repaired.blend，SHA256 d657861cc239bc5b1750a43196f0e63f5b5d8af124e694a53b67f7e4cdb3c2b4。
- 輸出：D:/RPGGAME/artifacts/lia-coat-final-20261103/lia_tailored_coat.blend及.glb。
- 最終GLB SHA256：7d6522d9d6a33f4348c2c94fe41917f7af348ac4c63a86e77ba9ceb2789962de。
- 最終blend SHA256：2254aeb44c49422d9d2ef098f4037a4ffc077044631dc25fb5ed90261efbbdde。
- 正式莉雅SHA256：d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4。
- 工具：scripts/tools/rebuild_lia_coat.py、scripts/tools/check_lia_coat_fit.py；render_lia_repair_inspection.py新增四個衣身視角。

cwd D:/RPGGAME；輸出目錄／報告需使用不存在的新路徑。原始測試使用artifacts中的同內容選取，以下已換成納入版本的選取路徑。

~~~powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/rebuild_lia_coat.py -- --input artifacts/lia-hair-final-20261102/lia_hair_repaired.blend --selection docs/evidence/lia_coat_rebuild_20261103/selection.json --output artifacts/lia-coat-replay-20261103
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/check_lia_coat_fit.py -- --input artifacts/lia-coat-trial-20261103/lia_tailored_coat.blend --output artifacts/lia-coat-trial-20261103/waist_fit.json
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/check_lia_coat_fit.py -- --input artifacts/lia-coat-final-20261103/lia_tailored_coat.blend --output artifacts/lia-coat-final-20261103/waist_fit.json
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-coat-final-20261103/lia_tailored_coat.blend --output artifacts/lia-coat-final-render-20261103 --view coat_front --view coat_back --view coat_side --view coat_three_quarter
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input artifacts/lia-coat-final-20261103/lia_tailored_coat.glb --output artifacts/lia-coat-final-20261103/blender_gate --project-root D:/RPGGAME --category player_character --require-uv
$env:APPDATA='D:/RPGGAME/artifacts/lia-coat-final-20261103/profile'
$env:LOCALAPPDATA=$env:APPDATA
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_coat_final --solid-material=LiaAuthoredSkin --solid-material=LiaForearmLeather --solid-material=LiaForearmTrim --solid-material=LiaForearmCuff --solid-material=LiaMatchedSleeve --solid-material=LiaCollarLining --solid-material=LiaCoatLeather --solid-material=LiaCoatGold --solid-material=LiaCoatUnderlayer --solid-material=LiaCoatLaces --model=D:/RPGGAME/artifacts/lia-coat-final-20261103/lia_tailored_coat.glb --output=D:/RPGGAME/artifacts/lia-coat-final-20261103/godot
~~~

原版v0.6.1與固定RC5保留；人工終驗依指示暫停，Android／iOS與第一章未開始。序章仍須完成新角色動作整合、效能尖峰修正與更新候選包，不能宣稱總目標已完成。

重跑驗證：GLB並非逐位元相同。JSON、位置、索引、法線、材質與圖片緩衝區完全一致；新純色衣物的兩組UV緩衝區共20個float有最多5.96e-8差異（倒角插值）。未宣稱SHA相同。嘗試六位小數正規化仍不能保證相同，因此撤回不必要的UV修改，保留已驗收的final-20261103版本；[詳細比較](evidence/lia_coat_rebuild_20261103/replay.json)。
