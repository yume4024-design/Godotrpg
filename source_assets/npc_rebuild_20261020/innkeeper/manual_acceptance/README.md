# 旅館老闆局部重拓樸與獨立骨架候選

2026-10-21，`PASS_INDEPENDENT_NPC_CANDIDATE`。沿用使用者核准酒紅背心／米白圍裙四視圖及原本Pixal3D來源；本輪沒有新增Comfy生成、第三方模型或付費服務。正式旅館NPC尚未替換。

## 實際修改

- 原圍裙黑色三角裂口為交叉／內翻幾何，原三份法線／攤平失敗保留。新配方以固定來源SHA與實際射線／UV量測界定腰線 **z=.85～.885m**，完整替換前布片2754個面，重建24×16連續曲面、.004m厚度，從原albedo轉移至512²新atlas。
- 原來源13642 triangles；重建後 **12785／15000**、20骨、Idle／Talk各2秒。沒有整體減面或改臉／手／酒紅背心／背後繫帶。10888個保留面的位置與UV比對無缺失；原body貼圖SHA相同。自訂法線經Blender重新編碼，最大分量差 **.000105054**，不是位元完全相同。
- 首版只刪淺色面遺留交叉片；第二版刪除區越過實際背心腰線；額外hem篩選誤傷褲面。已改用實測腰線、保留原hem，並對跨下緣三角面做幾何裁切，保留褲子片段，沒有用加長圍裙掩蓋洞。
- 發現合併後新atlas位於未使用的第二UV層，修正為共用UV層並驗證實際TEXCOORD_0範圍兩軸皆1.0。沒有以「存在UV」取代貼圖映射驗證。
- `failed_attempts/` 保存所有可辨版本SHA／實際失敗圖與測試器錯誤。失敗Blend／GLB只留本機，不把它們當合格模型。一次局部拓樸工作中的實作修正已逐項記錄，沒有新AI生成或盲目攤平循環。

## 已執行

Godot **4.7.2.stable.official.ed1daf0bf / Windows Compatibility**；Blender **5.2.2 LTS**。

- 嚴格GLB與Blender重匯入：12785面、UV／Skin／權重／預算PASS。
- 原生Blender變形：**98影格PASS**，Idle最大邊伸長1.041144、Talk1.761692，未放寬2.5門檻；循環端點差0、足底約.002m。
- Godot四面／Idle／Talk正側／重載 **225／0**；雙實例三輪切換／不重播／獨立動畫庫／重載 **19／0**。實際畫面已查看，原黑縫與新增穿出布片未見；仍有細小腰線接面等原生成限制。
- 獨立Debug檢查場景單次快照Draw Calls=2、引擎記憶體37389503 bytes；不是完整村莊／長測或原生Release效能驗收。
- 最終未綁骨架階段的靜態預覽 **21／0**；該臨時runtime副本已移除，來源靜態GLB／Blend留本機，正式交付是下列rigged資產。數值及路徑收據保留，不假裝臨時路徑仍存在。
- 共用builder的道具商預設重建 **7組語義比對完全相同**，Idle／Talk取樣姿勢差0；道具商控制器回歸 **19／0**。第一次innkeeper控制器因測試白名單未加入而拒絕，修正測試入口後重跑，原失敗不抹除。
- 女村民profile也重新建置並與已核准來源做7組語義比對，全同、Idle／Talk姿勢差0；未將新profile分支改動悄悄套入既有角色。
- 初次法線精確比較失敗，是重新編碼後不能逐分量位元相等；後續分別驗證位置／UV完整保留及法線誤差<.001（約.057度級分量容差）。保留首份失敗，沒有宣稱首輪或所有檢查從未失敗。

## 重現與交付

```powershell
# 在新的輸出資料夾重建，不覆蓋現有來源。
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/rebuild_innkeeper_apron.py -- --input source_assets/npc_rebuild_20261020/innkeeper/manual_acceptance/source_baseline.blend --output <新靜態資料夾>
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/build_merchant_npc.py -- --profile innkeeper --input <新靜態資料夾>/innkeeper_retopology.blend --output <新動作資料夾>
./tools/review_npc_rig.ps1 -Asset innkeeper
./tools/review_npc_rig.ps1 -Asset innkeeper -Controller
```

GLB：`assets/models/rebuilt_npc/innkeeper.glb`，SHA **3baeda38ab638039aa01e9b2a4333f118a4df277c89e683ee8b26e70ea9c111d**。可重用視覺：`scenes/characters/npc/innkeeper_visual.tscn`；工作檔：同角色`idle_talk_manual_v1/innkeeper_npc.blend`，固定來源保存本目錄`source_baseline.blend`，避免只剩無法重現的本機輸入。

此候選源高1.72m，正式整合時仍須按最新村內1.95m尺度、既有NPC位置與碰撞驗收。沒有逐指骨架、倒茶／道具交接、走路／巡邏、布料物理或全閉合拓樸宣稱；原拆分網格8955邊界／8958非流形邊照實保留。沒有修改NPC ID、價格／住宿恢復、事件、旗標、獎勵、SaveCodec、正式v0.6.1或封存RC3。Android／iOS暫停。A05整體與第一章仍未完成。
