# 莉雅頸部比例候選 — 2026-11-02

**已在披肩修整版上縮短頭頸過渡，保留五官形狀；仍是未綁骨候選，未換入正式遊戲。** 披肩修正已於59e679b提交並同步。原有角色、序章與RC5不變。

## 實際量測及改動

來源為artifacts/lia-cape-fitted-20261031/lia_cape_trial.blend，SHA256 b9820e6db0f18892fbd703febd6ae6176c485ccdee78406e9bfaf0d6dbff3586。

- 中央下巴最低量測約z=1.64321m，既有頸部範圍1.475–1.700m、立領最高1.625m。此為網格座標，不是以畫面像素猜測比例。
- 對舊衣身／頭髮網格及獨立頸部使用z=1.515–1.635m的平滑過渡，上方剛性下移0.035m。低於過渡區的座標不動；過渡區的髮尾也隨之調整，不能聲稱所有頭髮完全剛性平移。
- 上方957個來源頂點及72個頸部頂點剛性平移，該區每面邊長誤差實測為0；五官未被壓扁。過渡導數最小0.5625，沒有垂直反折。UV逐項不變，法線用反向轉置調整並校正Blender壓縮法線誤差。
- 第一次輸出總高度變為1.915m；原Godot預設1.95m檢查回報63項／1失敗，保留[失敗證據](evidence/lia_neck_proportion_20261102/rejected_height_report.json)。沒有改測試或放寬誤差。
- 使用--normalize-height把所有模型均勻放大約1.0182767倍並烘入頂點，恢復1.95m、腳底0m；衣物和手臂只接受此共同等比例變換。報告中的局部頂點保留檢查是在這次統一尺度前執行，並另外驗證整體尺度反算誤差小於2e-7m。

## 檢查結果

| 項目 | 實際結果 |
| --- | --- |
| Blender 5.2.2 LTS GLB重新匯入 | PASS，11,492／15,000 triangles，UV／材質通過、無退化面 |
| 既有警告 | NONMANIFOLD_OR_BOUNDARY仍保留；不是封閉全身驗收 |
| Godot 4.7.2圖形／Windows Compatibility／RTX3080 | 最終63項／0失敗，保留1.95m檢查契約 |
| 來源及正式角色 | 原blend與正式lia_rigged.glb SHA256保持不變 |
| 動畫、戰鬥、探索、讀檔 | 新候選未測，無骨架，未改正式功能 |

[修整收據](evidence/lia_neck_proportion_20261102/receipt.json)／[Blender結果](evidence/lia_neck_proportion_20261102/blender_gate.json)／[Godot結果](evidence/lia_neck_proportion_20261102/godot_report.json)／[Godot全身](evidence/lia_neck_proportion_20261102/godot_front.webp)。

| 視角 | 前 | 後 |
| --- | --- | --- |
| 正面 | [前](evidence/lia_neck_proportion_20261102/before_neck_front.png) | [後](evidence/lia_neck_proportion_20261102/after_neck_front.png) |
| 側面 | [前](evidence/lia_neck_proportion_20261102/before_neck_side.png) | [後](evidence/lia_neck_proportion_20261102/after_neck_side.png) |
| 斜側 | [前](evidence/lia_neck_proportion_20261102/before_neck_three_quarter.png) | [後](evidence/lia_neck_proportion_20261102/after_neck_three_quarter.png) |

同鏡頭、同燈光與900×900 Cycles CPU16samples。正面頸部顯示長度減少；臉側原有切面、髮尾錯色與高領接觸仍可見，**髮尾／領口仍需要局部修整，不能宣稱無穿模或整體visual PASS**。衣身與裙襬碎面／錯色、配件、骨架、權重、動作及正式序章整合也未完成。保留原候選供比較，沒有直接套用到正式角色。

## 輸出與重現

候選：D:/RPGGAME/artifacts/lia-neck-normalized-20261102/lia_neck_fit.blend 及同名.glb。
GLB SHA256：ea23b06c1967de071c2b102259bf0b007fef416ab3051f4941ffd5c2e71b37ae。
Blend SHA256：9d0a72d8642bef5799e691a1c5e64aa33ac87bf4e6853cd439b26c92cb4cfe98。
正式莉雅GLB仍為d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4。

以下為實際命令，cwd D:/RPGGAME；重跑需替換為不存在的新輸出目錄。

~~~powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/fit_lia_neck_proportions.py -- --input artifacts/lia-cape-fitted-20261031/lia_cape_trial.blend --output artifacts/lia-neck-normalized-20261102 --normalize-height
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-neck-normalized-20261102/lia_neck_fit.blend --output artifacts/lia-neck-normalized-render-20261102 --view neck_front --view neck_side --view neck_three_quarter --view cape_front
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input artifacts/lia-neck-normalized-20261102/lia_neck_fit.glb --output artifacts/lia-neck-normalized-20261102/blender_gate --project-root D:/RPGGAME --category player_character --require-uv
$env:APPDATA='D:/RPGGAME/artifacts/lia-neck-normalized-20261102/profile'
$env:LOCALAPPDATA=$env:APPDATA
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_neck_normalized --solid-material=LiaAuthoredSkin --solid-material=LiaForearmLeather --solid-material=LiaForearmTrim --solid-material=LiaForearmCuff --solid-material=LiaMatchedSleeve --solid-material=LiaCollarLining --model=D:/RPGGAME/artifacts/lia-neck-normalized-20261102/lia_neck_fit.glb --output=D:/RPGGAME/artifacts/lia-neck-normalized-20261102/godot
~~~

序章尚待角色整合、效能尖峰修正及更新候選包。人工終驗依使用者要求暫停；Android／iOS及第一章未開始。未更動角色ID、數值、劇情旗標、獎勵或存檔格式。
