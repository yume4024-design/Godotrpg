# 灰石村 G02 地形驗收 — 2026-10-14

## 實際完成

獨立預覽已加入中央聚落 0m、旅館台地 2m、西北農田 4m、東北礦坑 6m。主路以連續坡面接合高地，沿用既有 CharacterBody3D；没有瞬移上坡，也沒有改動正式0.6.1或存檔規格。

依使用者追加「還原度要更高」調整：中央路面改為圓廣場；西側地形外緣有不規則轉折；北側山岩圍出礦村背景；東側河道轉折、下游拓寬為湖邊，水面降至 -3.6m，凸顯河谷落差。上游水面5.4m至下游落差9m，以簡化不透明瀑布面表現。碼頭加入支柱，礦坑加入山壁及木框輪廓；23棵共用低面數松樹用於尺度與區域辨識。

建築仍是G01佔位，井仍是方塊。沒有宣稱已完整還原參考圖：精細木構、窗框、正式井、水車、階梯外觀、柵欄、燈具及植被密度仍待G03～G05。G02以坡道完成通行，不虛構已完成階梯模型。

## 原創資產與 Blender

- `scripts/tools/greystone/build_layout.py` 同時產生場景、地形三角網格及碰撞資料；道路裁切自相同地形三角形，再上移0.045m，避免坡道接縫露草。道路不另設碰撞、不投射陰影。
- `export_terrain.py` 透過Blender5.2.2輸出59個GLB組件，合計 **12,409三角面（唯一GLB資源總和）**，非整個場景顯示面數。松樹實例、原生方塊、角色另計；這不是G07效能認證。
- 原始OBJ、manifest、layout、metrics及可編輯檢視副本在 `source_assets/greystone_g02/`，由`.gdignore`隔離遊戲匯入。GLB在 `assets/models/greystone/terrain/`。
- 使用者開啟Blender後，MCP已連線；addon1.7/protocol11落後server13，但基本腳本、匯入和look可用。未升級或安裝外掛、未使用付費生成。
- MCP安全模式拒絕直接讀檔執行Python腳本後，改用允許的明確匯入與建模指令。建立 `Crystal_G02_Review`，保留原 `Scene` 的3個物件；保存 `greystone_g02_review.blend` **副本**，沒有覆蓋使用者原檔。`blender_review.py`供本機重建，安全模式下用等效inline資料/操作。

## 驗證

引擎 `4.7.2.stable.official.ed1daf0bf`，Windows、Compatibility、RTX3080 / NVIDIA617.42。

| 命令 | 預期與實際 | 日誌（artifacts/logs） |
| --- | --- | --- |
| build_layout.py + Blender --background --python export_terrain.py | 可重建GLB與場景；59資源成功 | greystone-g02-blender.log |
| ./tools/godot.ps1 -Mode Check | 無解析/匯入錯誤；通過 | check-20261014-073503-777.log |
| ./tools/godot.ps1 -Mode VisualGreystone | **69項、0失敗**，真實視窗/物理及截圖 | visualgreystone-20261014-073527-209.log |
| ./tools/godot.ps1 -Mode TestPhase2 | **58項、0失敗**，既有探索/故事回歸 | testphase2-20261014-073620-280.log |

圖形測試實際送W鍵與Input Map方向，走過村口、廣場、旅館、公會、兩店前、住宅、礦坑、上游桥、西出口、農田與碼頭。主要長路線加速，礦坑坡道另外以 time_scale=1、60Hz正常速度上下行；農田實際Y≈4、礦坑Y≈6。測岩壁/店牆/河岸/碼頭缺口/西出口阻擋；內部地表網格射線抽樣沒有缺口，河道與不規則外緣不在抽樣中，因此不宣稱窮舉全圖。測試每幀恢復測試玩家輸入焦點，讓使用者可同時查看Blender；沒有移除正常遊戲的失焦保護。

曾發現並修復：農田道路貼旅館牆、切換Blender使自動路線暫停、Blender線性色彩與Godot色值不一致、坡面道路採樣不一致導致局部被地形遮住。早期失敗及timeout不列通過；以上表最終重跑為準。

已查看 Godot `artifacts/greystone-g02/01-plaza.webp`、`02-layout.webp`、`03-mine-highland.webp`、`04-farm-highland.webp`，以及Blender look的完整村落斜視圖；修正過亮與坡道路面後重拍。原始截圖與日誌不納入Git。

## 限制與下一步

G02基本地形/路線驗收完成；G03正式模組化建物尚未開始。NPC、旅館/商店行為、世界/礦坑切換、觸控、存檔位置遷移仍留G06。Android/iOS真機、效能和匯出未測；本輪未發布新版本，正式遊戲仍0.6.1。

下一步依最新圖製作旅館、道具店、武器店、民宅及公會的正式低面數模型，提高建築輪廓與材質還原度，逐一替換佔位。
