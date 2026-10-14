# 灰石村 G05 基礎組裝

2026-10-14。使用 Godot 4.7.2.stable.official.ed1daf0bf；新版仍為獨立預覽，正式 0.6.1 的主場景、序章、存檔格式及位置驗證未修改。

## 配置與交付

沿用 G02 的 120×120m 地形、河谷、瀑布、農田/礦坑台地，以及 G03 七個原有建築 PackedScene；未重新建模或下載新素材。區域依最新參考圖與正文：中央井廣場、西北旅館/農田、西側道具店、北公會、東武器店/河流/橋、南住宅/入口/碼頭、東北礦坑、西世界出口。

新增八個可替換的 G04 佔位 PackedScene：well、bridge_deck、dock_deck、fence、lamp、crop、waterwheel、sign。模組位置固定於村莊場景，後續可替換視覺子資源；橋與碼頭沿用原有地面/欄杆碰撞，板條只是視覺覆層。水車/作物為無碰撞裝飾；井、燈柱、路標及圍欄使用簡化碰撞。這不是 G04 正式素材庫完成。

補上北側橫路、公會前庭、住宅接路與農田通路；七個 ActivitySpaces 標記預留 NPC 空間，不包含 NPC 或導航 AI。建物門依然閉合，互動與室內切換留 G06。

```text
GreystoneVillage
  Terrain       G02 地形與橋/碼頭支撐碰撞
  Roads         原有道路 + 前庭/支路
  Buildings     Inn / GuildHall / ItemShop / WeaponShop / HouseA / HouseB / FarmHouse
  Water         河流 / 瀑布
  Landmarks     礦口、既有松樹與標籤
  Bounds        河岸、橋欄、碼頭欄杆、外緣碰撞
  Markers       玩家出生、建築入口與地點
  Props         可替換佔位 PackedScene 實例
  ActivitySpaces 七處門前活動預留
```

## 重建與檔案

執行既有 `scripts/tools/greystone/build_layout.py`，會呼叫新增 `assemble_village.py`。不需重新輸出七個建築或地形 GLB。同步更新 `source_assets/greystone_g02/layout.json` 的方塊配置；生成的場景以產生器為準。

- 主場景：`scenes/world/greystone_village.tscn`
- 模組：`scenes/world/greystone/placeholders/*.tscn`（八檔）
- 組裝：`scripts/tools/greystone/assemble_village.py`、`build_layout.py`
- 預覽標題：`scripts/tools/greystone/preview.gd`
- 回歸：`tests/greystone_layout_test.gd`
- 文件：本報告、GREYSTONE_BUILD_TASKS、GREYSTONE_VILLAGE_SPEC、TASKS、CHANGELOG

## 驗收與限制

實際圖形程序以 Input Map 操作現有 CharacterBody3D，非傳送式全村通路測試；建築入口測試則逐棟重設起點以隔離檢查。不是使用者手動驗收。曾發現公會路燈與住宅圍欄擋住路線，已移開物件而非放寬通行斷言。

檢查涵蓋南入口→廣場→旅館/公會/兩店→礦口→橋→西出口→住宅→碼頭→農田、正常速度礦坑斜坡上下、井周圍環行、河岸/外緣/店面/橋欄/碼頭防墜，以及七處門前淨空。

畫面證據在本機 `artifacts/greystone-g05/`。已查看廣場與全圖，確認區域關係及可辨識佔位。構圖評估（0–2）：環境引導線 2、前中後景層次 1、留白密度 1、玩家輪廓可見性 2。道路仍偏直角且留白多；這些是後續美術提升項，不能宣稱完整還原參考圖。

Android/iOS、FPS/Draw Calls、觸控、NPC 劇情、切場景與新村莊存檔遷移均未驗收；正式序章只做啟動回歸，不宣稱本輪重新通關。下一階段建議 G04 正式道具與植被，再進 G06 互動及位置遷移。


## 最終測試結果

| 命令（tools/godot.ps1 -Mode） | 實際結果 | 本機日誌 |
| --- | --- | --- |
| Check | 載入成功，退出 0 | artifacts/logs/check-20261014-144748-826.log |
| VisualGreystone | 98 項、0 失敗，Windows 圖形模式 | artifacts/logs/visualgreystone-20261014-144752-304.log |
| VisualGreystoneBuildings | 43 項、0 失敗，七棟入口及九材質共用 | artifacts/logs/visualgreystonebuildings-20261014-144840-806.log |
| Smoke | 正式主場景啟動成功，退出 0 | artifacts/logs/smoke-20261014-144851-706.log |

已另查看 06-bridge.webp、07-dock.webp 的實際畫面。git diff --check 通過；無正式主場景、project.godot、存檔或故事腳本變更。
