# 灰石村建造規格 — G03 基礎建物完成 / 2026-10-14

## 2026-10-24 更新參考候選（本候選優先）

以 [更新圖](references/greystone_reference_20261024.png) 為準：六棟主要建物、上游橋與中央拱橋、東岸上下台地及階梯、礦坑連續道路。農舍及農田不放入此圖主要畫面，原資產保留。公會重用東北藍頂建物的既有功能。新版村莊位置版4，鏡頭俯角45°、水平朝向12°；正式入口及舊位置版2／3地形保留。主檔、精確座標、功能／視覺證據與尚存美術差距見 [新版報告](GREYSTONE_REFERENCE_20261024_REPORT.md)。以下較早版本記錄保留，與本圖衝突時以本節為準。

## 2026-10-23 Blender 重建候選補充（本候選優先）

最新參考圖為 [greystone_20261023.png](references/greystone_20261023.png)。
完整 Blender 主檔組裝後分九組匯入，四種 Pixal 建築／五個可重用 GLB／七棟實例。
新入口 `scenes/main/greystone_blender_integration.tscn` 採村莊位置版 3、獨立存檔槽，
原 G06 位置版 2 與正式 v0.6.1 入口保留。角色實際膠囊高 1.95m、跨階 0.18m；
以下 2026-10-14 的 1.6m 與舊座標表為歷史版本，不套用新版候選。
本候選精確配置、啟動指令、測試與限制見 [重建報告](GREYSTONE_REFERENCE_REBUILD_REPORT.md)，
位置遷移驗證以 [SAVE_FORMAT](SAVE_FORMAT.md) 為準。Android / iOS 持續暫停。

最新使用者貼文與 [最新參考圖](references/graystone_village_2026_10_14.jpg) 優先；原企劃未被修改的故事、角色、指令式回合制與狀態所有權繼續適用。合併決策見 [PLAN_MERGE](PLAN_MERGE_2026_10_14.md)。

## 平台、尺度與方向

- 目標 Windows / Android，iOS 預留。Android 中階 30 FPS、Windows 60 FPS 是 G07 驗收目標，尚非測試結果。
- Godot 4.7.2、GDScript；1 unit = 1 公尺，Y 向上。地圖 X/Z 各 -60～60，共 120×120m。
- 北 = -Z，東 = +X；固定俯角 45°、方位 45°，正交鏡頭跟隨玩家，初始 size 28。整圖檢視 size 155 僅供 QA。
- Q 版、低面數切面、柔和暖色、簡單共用材質。角色保留現有可愛造型；新環境不沿用舊版高面數大塊合併模型。
- 建築原點地面中心、正面 +Z；尺寸表依 X 寬 / Y 高 / Z 深。GLB 用 Blender 匯出器處理座標轉換，禁止再手動重轉軸。
- 主路 6m、次路 3m、廣場 28×28m、上游河寬約8～10m；下游按最新還原度要求拓寬至約30m湖邊、人物碰撞高度 1.6m。G03建築門板實測寬1.80～2.13m；G01 沒有室內或可穿越門洞。

## 區域與座標

| 區域 | 中心 X,Z | 建造內容 / G01 表現 |
| --- | --- | --- |
| Village_Center | 0,0 | 水井廣場；目前石井方塊佔位，選井而非水晶柱以符合新圖 |
| Village_West | -20,-18 / -23,0 | 旅館 12×9×9、道具店 8×7×7；西出口 -53,10 |
| Village_North | 0,-30 | 公會 15×11×11，依新正文加入；農舍 -39,-35、農田標記 -42,-24 |
| Village_East | 20,-14 | 武器店 8×7×7；河 X=30～38；橋 Z=-28，瀑布已加入，水車留G04 |
| Village_South | ±19,22 | 民宅 A 7×6×6 / B 7×8×6、碼頭 32,32、出生點 0,48 |
| Village_Mine | 24,-52 | 礦坑入口標記；高地6m與坡道已加入；切場景留G06 |

圖片提供區域關係，正文補充北側公會、西北農田及南入口。G01 平地白盒為歷史基線。G02 已加入旅館2m、農田4m、礦坑6m台地，連續可走坡面、河谷崖壁及瀑布；階梯造型及正式建築仍待後續。詳見 [G02報告](GREYSTONE_G02_REPORT.md)。

## 檔案與場景樹

```text
scenes/world/greystone_village.tscn
  Terrain       地面、橋面、碼頭（可碰撞）
  Roads         路面覆層（不另設碰撞，避免接縫）
  Buildings     七個獨立 PackedScene 實例
  Water         河面，不可行走
  Landmarks     水井佔位及地點標籤
  Bounds        可見河岸、橋欄及地圖邊界碰撞
  Markers       出生點、門前、出入口座標
scenes/world/greystone/*_blockout.tscn
scenes/world/greystone_preview.tscn
  Village / Player / Camera3D / WorldEnvironment / Sun / HUD
scripts/tools/greystone/build_layout.py
scripts/tools/greystone/preview.gd
assets/models/greystone/          G03 / G04 GLB 接入位置
```

建物碰撞使用實際尺寸 BoxShape3D，無縮放碰撞節點。場景可直接在編輯器檢查；白盒產生器只覆寫其八個明確命名場景，手工修改前應先修改產生器，避免重建遺失調整。

## 工具與重建

G01時MCP離線；G02使用者開啟Blender後已連線，protocol11的基本操作可用，本機Blender5.2.2可執行。G01 按使用者要求以原生幾何體確認佔位比例，不把它當成正式建模完成。G03 起優先 MCP；不可用時用可重複 Blender Python 產生獨立 GLB；若 Blender 也不可用才保留原生佔位。

```powershell
# 在專案根目錄；或使用其他可用 Python 3
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' scripts/tools/greystone/build_layout.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python scripts/tools/greystone/export_terrain.py
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode TestGreystone
./tools/godot.ps1 -Mode VisualGreystone
./tools/godot.ps1 -Mode PreviewGreystone
```

## 系統整合邊界

G01 使用現有 Player / PlayerInput / PlayerMovement，鍵盤與 Xbox 共用 Input Map。觸控虛擬搖桿與互動按鈕留 G06，Android 真機留 G07/G08；不宣稱目前已支援手機完整遊玩。

預覽不連入 TravelManager / SaveManager，也沒有虛構 NPC、商店或任務成功。正式主場景、0.6.1 版本與 CH00-P5 存檔契約暫不變。G06 正式換圖時必須加入位置版本及舊存檔遷移，不把 120m 座標送入舊版 ±12.5m 驗證器。

E001 旅館、E002 公會委託、E003 莉雅、E008 回公會；E004～E007 仍由森林／礦坑管理。進礦坑前置與一次性獎勵不得被新入口繞過。新文未刪 E009，保留既有序章收尾。價格、住宿費及世界地圖範圍在 G06 確定，不憑圖片加入航行系統。

## G02 地形實作補充

120m是地圖包圍範圍，西側外緣改為不規則折線；水面-3.6m、上游5.4m。地形與碰撞使用相同頂點，靜態地形用ConcavePolygonShape3D；建物/樹幹仍用簡化形狀。道路裁切自地形三角形，僅視覺上浮0.045m。GLB地形組件與source_assets/greystone_g02原始資料由同一產生器維護，不能只手改GLB而不同步碰撞。23棵共用松樹為還原度與尺度背景，不代表G04素材庫完成。

G03七棟差異化素材庫建物已接入預覽，完整狀態見 [G03報告](GREYSTONE_G03_REPORT.md)。現行 scenes/world/greystone/*.tscn 為 GLB 建物實例；保留 *_blockout.tscn 為歷史佔位。門板寬度已量測，屋型、簡化碰撞與九個 Godot 共用材質已驗證；門仍閉合，互動留G06。重建須先依G03報告產生模型及export_metrics，再執行地圖產生器。


## G05 基礎組裝補充

[組裝報告](GREYSTONE_G05_REPORT.md)：新增 Props 與 ActivitySpaces 節點、八個可替換佔位 PackedScene，中央水井取代方塊。七棟建築位置沿用已驗證配置，補齊前庭與通路。井/橋/碼頭/水車目前是 G04 佔位，並非正式道具驗收。生成器現在亦寫入 placeholders 目錄；修改應同步 assemble_village.py。
