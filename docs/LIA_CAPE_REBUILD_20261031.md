# 莉雅披肩及內袖重建 — 2026-10-31

**已實際重建連續短披肩、白色滾邊與內袖；新角色整體仍未完成，不換入正式遊戲。** 上輪內領切割已提交d4dc9cb，屬實際進展。此前核准服務用量失敗本輪已恢復，沒有繞過核准。

## 改動與視覺判斷

- 依原已核准莉雅設計保留紫色短披肩、白色滾邊、胸前扣件及內袖。原模型肩部與背面存在重疊碎面；初選541個外層面仍混有內袖，未直接採用。重新界定完整披肩與上袖1264面，再以實際正、背、側畫面射線定位15個殘面，最終移除1279面。兩個胸前來源面3255／6766經頂點量測後保留。
- 新披肩是有4mm厚度的單一連續網格，256 triangles，使用既有紫布、白邊、內襯材質與UV；上緣依現有立領底部控制點建立，下緣白邊連續。沒有全身合點或再做整體減面。
- 內袖從已修好前臂的13／11點實測外圈延伸，維持原253／251個前臂與手部頂點位置；新內袖與前臂、手部為連續封閉表面。第一版內袖上端高於披肩，實際畫面發現後收低並縮小端圈，不能把初版面數通過當作造型合格。
- 9,484個未選衣身原面的座標和UV逐項保留，角落法線最大誤差0.00022586。頭髮、頸部、立領、下身、正式角色與遊戲狀態沒有被重建工具替換。
- 最終正、背、側及斜側檢視，先前披肩碎片、白邊破損和內袖肩頂凸起已消除。披肩與立領仍是獨立網格，未做蒙皮；不能將原生封閉檢查解讀為全身已焊接或動畫合格。

| 視角 | 修整前 | 修整後 |
| --- | --- | --- |
| 正面 | [前](evidence/lia_cape_rebuild_20261031/before_cape_front.png) | [後](evidence/lia_cape_rebuild_20261031/after_cape_front.png) |
| 背面 | [前](evidence/lia_cape_rebuild_20261031/before_cape_back.png) | [後](evidence/lia_cape_rebuild_20261031/after_cape_back.png) |
| 側面 | [前](evidence/lia_cape_rebuild_20261031/before_cape_side.png) | [後](evidence/lia_cape_rebuild_20261031/after_cape_side.png) |
| 斜側 | [前](evidence/lia_cape_rebuild_20261031/before_cape_three_quarter.png) | [後](evidence/lia_cape_rebuild_20261031/after_cape_three_quarter.png) |

同鏡頭、900×900、Cycles CPU16samples、同燈光及AgX；不是概念圖。[Godot全身](evidence/lia_cape_rebuild_20261031/godot_front.webp)。

## 實際檢查

| 檢查 | 結果與限制 |
| --- | --- |
| 原生Blender 5.2.2 LTS | 新披肩及兩側袖手網格邊皆manifold、無退化面；不是完整角色拓樸驗收 |
| GLB重新匯入 | PASS，11,492／15,000 triangles，UV及材質通過、無退化面；保留NONMANIFOLD_OR_BOUNDARY警告 |
| Godot 4.7.2 Windows Compatibility／RTX3080 | 圖形靜態63項、0失敗；無骨架、未測動作或遊戲整合 |
| 來源／正式模型 | 來源blend及正式莉雅GLB SHA256不變 |
| 文件／工具 | Python語法、連結、收據與模型SHA一致性檢查通過；使用已存選區重新執行建模，GLB SHA完全相同（[結果](evidence/lia_cape_rebuild_20261031/replay.json)） |

[完整收據](evidence/lia_cape_rebuild_20261031/receipt.json)／[Blender](evidence/lia_cape_rebuild_20261031/blender_gate.json)／[Godot](evidence/lia_cape_rebuild_20261031/godot_report.json)／[最終來源面清單與定位矩形](evidence/lia_cape_rebuild_20261031/selection.json)。

候選：D:/RPGGAME/artifacts/lia-cape-fitted-20261031/lia_cape_trial.blend 及同名.glb。
GLB SHA256：221fcb561103b80276e304fe013a3a7fc9b10e211c24ed8fa6724c1a557baa9d。
Blend SHA256：b9820e6db0f18892fbd703febd6ae6176c485ccdee78406e9bfaf0d6dbff3586。
來源blend SHA256：e77b8e89d132740209a12e5e64d2441592ff95d4cea58f4c5be2446e5350ce71。
正式莉雅GLB仍為d2ebab02be6b38b6d539f8a77d50d82baaebcf4e64153ac0c36b94e9fdfc96a4。

## 重現

cwd D:/RPGGAME。工具鎖定來源及選區SHA，輸出必須是新目錄；既有候選不覆蓋。

~~~powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/author_lia_cape.py -- --input artifacts/lia-collar-clipped-final-20261030/lia_collar_clipped.blend --selection docs/evidence/lia_cape_rebuild_20261031/selection.json --output artifacts/lia-cape-replay --fit-shoulders
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/render_lia_repair_inspection.py -- --input artifacts/lia-cape-replay/lia_cape_trial.blend --output artifacts/lia-cape-replay-render --view cape_front --view cape_back --view cape_side --view cape_three_quarter
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input artifacts/lia-cape-replay/lia_cape_trial.glb --output artifacts/lia-cape-replay/blender_gate --project-root D:/RPGGAME --category player_character --require-uv
$env:APPDATA='D:/RPGGAME/artifacts/lia-cape-replay/profile'
$env:LOCALAPPDATA=$env:APPDATA
& 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe' --path D:/RPGGAME --script res://tests/static_character_review.gd -- --raw-glb --portrait --id=lia_cape_fitted --solid-material=LiaAuthoredSkin --solid-material=LiaForearmLeather --solid-material=LiaForearmTrim --solid-material=LiaForearmCuff --solid-material=LiaMatchedSleeve --solid-material=LiaCollarLining --model=D:/RPGGAME/artifacts/lia-cape-replay/lia_cape_trial.glb --output=D:/RPGGAME/artifacts/lia-cape-replay/godot
~~~

本次實際命令的輸出目錄為artifacts/lia-cape-fitted-20261031及artifacts/lia-cape-fitted-render-20261031；重現範例換用新目錄。預覽渲染工具新增四個cape視角。

## 未完成與序章門檻

新莉雅仍有頸肩比例／下巴接合、衣身與裙襬錯色或碎面、臉側／髮尾與配件問題；骨架、權重、動作、法杖及正式移動／戰鬥／存讀檔回歸尚未完成，visual_gate整體FAIL、animation_gate NOT_STARTED。不將本次靜態63項宣稱角色可正式使用。

正式v0.6.1、RC5固定包、角色ID、戰鬥數值、技能、劇情旗標及存檔契約不變。序章仍需完成角色整合、追查已記錄的效能尖峰及更新固定包；人工終驗依使用者要求暫停，Android／iOS與第一章仍暫停。序章目標未標記完成。
