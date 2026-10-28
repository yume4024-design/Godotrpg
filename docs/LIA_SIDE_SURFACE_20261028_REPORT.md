# 莉雅側臉表面修整與旅館老闆覆核

日期：2026-10-28；分支feature/greystone-g06；來源基線1d7c62a。只修改獨立靜態候選、開發檢查器與證據，遊戲模型／入口／數值／存檔契約保持原狀。

## 實際修整

沿用authored_neck_v3_20261028候選，將真實網格兩側以正交相機、無光照albedo渲染，再用內建imagegen修正側臉粉色三角片上的黑線及部分側髮繪線。四視圖及角色原設計未重製；新圖只作貼圖輸入，不冒充實際3D驗收畫面。

回投影限制在可見面與同側頰部；眼、眉、鼻、嘴沿用來源像素。第一版以面法線／深度遮罩選取，側臉重疊層未完整修到。實際診斷發現局部面法線與自訂角法線差異，因此第二版使用角法線及明確界定的同側皮膚區，沒有全域放寬遮擋或把髮色塗到臉上。

| 版本 | 三角面 | 選中色圖像素 | 實際視覺 |
| --- | ---: | ---: | --- |
| v1 | 12,554 | 430,182 | 黑線仍明顯，拒用 |
| v2 | 12,554 | 528,686／16,777,216 | 側臉黑線大部分清除、側髮較連續；整體仍不合格 |

兩版保留幾何、UV、面索引及角法線的相同雜湊；頸部未修改。未選中的atlas像素在記憶體中相同，PNG重新編碼不宣稱與原檔位元完全相同。v2 GLB SHA256：`634ebdb699d086b676aedee5d2f3b1622162b6c4e4ff0921c08879f117b449b1`。

## 已執行驗證

Blender 5.2.2 LTS；Godot 4.7.2.stable.official.ed1daf0bf，Windows Compatibility／RTX3080。

| 驗證 | 實際結果 | 範圍 |
| --- | --- | --- |
| GLB嚴格靜態稽核 | PASS，12554／15000、2材質、UV／索引／有限值 | 明確allow-static，沒有骨架或動畫 |
| Godot候選原生圖形 | 22／0 | GLTFDocument讀取GLB、4K貼圖、純色頸部、地面0／高度1.950000m、九視角及重建實例 |
| 原PackedScene靜態預覽回歸 | 18／0 | 保留原ren預設路徑；不是新角色戰鬥測試 |
| 錯誤材質宣告反例 | 原生exit1，22項／2個預期失敗 | 不存在的純色名稱與未宣告缺貼圖均被拒絕 |
| 旅館老闆現有GLB覆核 | 225／0 | 原生四面、Idle／Talk、重載；並非本次重建NPC |

首次Godot候選檢查21項／1失敗，原因是舊檢查器要求每件模型都有貼圖。實際GLB頸部為明確LiaAuthoredSkin純色，故新增可選的具名純色宣告並驗證該材質確實存在、顏色有限及不透明；未宣告的身體仍須有貼圖。擴充時曾有Color.is_finite語法錯誤，修正為逐分量檢查後才重跑成功。首次結果與反例保留，沒有抹除失敗。

已檢視Blender原生正／側／背與Godot正面、側面、背面、斜側及全身。領口黑縫、後髮／紫色衣物的網格線和碎片狀邊緣仍明顯，**visual FAIL**。靜態匯入PASS不能代表全角色完成、editor匯入設定驗收或可用動畫；本輪未建立新骨架、動作、持杖、村莊移動、戰鬥、存讀檔或效能證據。

## 旅館老闆狀態更正

目前runtime使用的12785面模型SHA256為`3baeda38ab638039aa01e9b2a4333f118a4df277c89e683ee8b26e70ea9c111d`，就是2026-10-21已重建圍裙的版本。本輪原生正／背／Talk側面未重現舊黑色裂口。RC3報告沿用歷史失敗將其列為未修，是紀錄錯誤，現已更正。細小腰線接縫等生成限制仍保留，不宣稱任意角度零瑕疵，也沒有再次替換模型。

旅館老闆Draw Calls=2、引擎記憶體36555825 bytes僅為獨立預覽快照，不能代替整村或長時間效能。角色舊來源、runtime GLB、正式main、候選入口及project.godot的七項保留雜湊已記錄。

## 檔案與重現

- 工具：`scripts/tools/prepare_lia_side_repair.py`、`apply_lia_side_repair.py`；檢查器：`tests/static_character_review.gd`。
- [輸入及修圖來源](../source_assets/character_rebuild_20261020/lia/side_surface_20261028/generation_provenance.json)：原圖／生成圖SHA、編輯限制與投影參數。
- [局部修整驗收](../source_assets/character_rebuild_20261020/lia/side_surface_acceptance_20261028/README.md)：Godot畫面、結構／保留證據及失敗診斷；v1/v2目錄保留Blender原生畫面及收據。
- [旅館老闆重新核對](../source_assets/npc_rebuild_20261020/innkeeper/reaudit_20261028/README.md)：225項報告及八張原生畫面。

本機大檔（新blend、GLB、baseline與4K成品貼圖）精確忽略，未混入Git；已提交修圖輸入和可重現工具。工作檔只在新資料夾建立，原件不覆寫。

```powershell
# 在D:/RPGGAME執行；腳本拒絕覆寫既有output。prepare的原始blend留本機。
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/prepare_lia_side_repair.py -- --input source_assets/character_rebuild_20261020/lia/authored_neck_v3_20261028/lia_authored_neck.blend --output artifacts/lia-side-replay/input
# 將凍結來源left_repair.png與right_repair.png複製到新input，再執行回投影。
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/apply_lia_side_repair.py -- --source artifacts/lia-side-replay/input --output artifacts/lia-side-replay/output
# 使用隔離profile，原生圖形檢查目前v2；不設定--headless。
$env:APPDATA='D:/RPGGAME/artifacts/lia-side-replay/profile'
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_side_v2 --solid-material=LiaAuthoredSkin --model=D:/RPGGAME/source_assets/character_rebuild_20261020/lia/side_surface_v2_20261028/lia_side_surface.glb --output=D:/RPGGAME/artifacts/lia-side-replay/godot
```

## 後續門檻

下一項是依實際邊界修復頸領／後髮／衣物表面，再做綁骨及動畫整合。這次只有兩次有證據的側面配色回投影，沒有重新啟用已停止的三版頸部試作。現有可玩莉雅和固定RC3不變；RC3新30分鐘長測、人工美術及實體輸入仍未完成，Android／iOS、第一章保持暫停。
