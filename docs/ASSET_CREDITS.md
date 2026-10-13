# 素材來源與修改紀錄

使用者於 2026-10-12 授權使用素材商店資產並修改。正式選用時記錄來源頁、作者、版本/取得日期、授權、署名要求、原始檔與修改。允許使用素材不等於任何商店項目都可任意重製；以各項目的實際授權為準。

## Phase 1 已使用

| 素材 | 來源 | 修改/用途 |
| --- | --- | --- |
| 雷恩佔位人物 | 專案內自製 Godot BoxMesh/CylinderMesh | 橘色外套、深色頭髮/靴子、黃色圍巾及背包；無外部模型 |
| 練習場、樹木、遺跡、石塊、晶體 | 專案內自製 Godot 基本幾何體 | 場景編排、材質、碰撞形狀；晶體僅裝飾，未連接 E006 |
| HUD | 專案內自製 Control/Container/StyleBox | 位置與操作提示，不顯示未實作的 HP/任務狀態 |
| UI 字型 | Godot SystemFont 使用本機系統字型/引擎 fallback | 沒有複製或再散布字型檔；正式跨機發佈時須選定可散布字型並再次驗證 |

本輪未下載素材商店內容、未安裝外掛、未購買素材。Story Bible 的外部圖片連結僅為企劃參考，未匯入遊戲。

## Phase 2 已使用

P2 新增村莊、公會建築、森林樹木／石塊、路牌、寶箱及公會長／莉雅佔位角色，全部為專案內自製 Godot BoxMesh／PrismMesh／CylinderMesh，沒有外部素材。對話與狀態介面同樣自製，字型沿用本機 SystemFont。寶箱開啟姿態、名稱標籤和森林鏡頭區域已於遊戲中查看。

## Phase 3 已使用

P3 新增的戰鬥平台、雷恩／莉雅／守衛人形、史萊姆、回合標記與森林演練標誌皆由 Godot BoxMesh／CylinderMesh／SphereMesh 自製；戰鬥 UI、位移／傷害數字動畫同樣為專案程式生成。沿用本機 SystemFont，無下載、購買或新增外掛；正式模型、音效及可散布字型留 P6。

## 2026-10-13 卡通美術 v1（目前遊戲使用）

作者／來源：本專案原創，由 Codex 使用 Blender Python 建模。商店頁／外部版本／第三方授權文件／必要署名：不適用；沒有下載、購買、使用外部生成服務或複製企劃參考圖。工具版本 Blender 5.2.2 LTS，Godot 4.7.2。這些模型替換上列歷史階段的遊戲佔位，不影響保留的 P1 練習場。

| 素材 | 來源腳本 | 修改與用途 |
| --- | --- | --- |
| ren、lia、guildmaster | tools/build_cartoon_assets.py | 原創五官／髮型／多層服裝、背包、法杖、書本，六個剛性關節的視覺擺動 |
| forest_slime、corrupted_guardian | 同上 | 葉芽膠凍角色、分層石甲與紫晶守衛，探索演練點和戰鬥共用 |
| round_tree、guild_house、cottage | tools/build_cartoon_environment.py | 圓冠樹、瓦頂／窗框／花箱／煙囪建築，村莊／森林／戰鬥林地 |
| moss_rock、flower_patch、path_strip | 同上 | 覆苔岩石、花草、平坦圓角路面與邊界裝飾 |
| chest_base、chest_lid、campfire、signpost | 同上 | 保留開箱樞軸的木箱、金屬包邊、營火、雕刻箭頭路牌 |

原始建模檔：`source_assets/cartoon_v1/*_authoring.blend`；遊戲整理檔：同目錄 `*.blend`；面數：`*_metrics.json`；匯出：`assets/models/cartoon/*.glb`。材質為原創純色色盤，沒有外部貼圖；目前無蒙皮骨架。完整匯入／碰撞／畫面驗證與限制見 [美術報告](CARTOON_ART_REPORT.md)。

## 後續資產登錄欄位

資產名稱 / 商店與來源 URL / 作者 / 版本或取得日期 / 授權文件位置 / 必要署名 / 原始檔位置 / 修改內容 / Godot 匯入與碰撞驗證 / 使用場景。


## P5 原創礦坑與章末演出（2026-10-13）

`scenes/world/mine.tscn` 與 `scenes/battle/battle_mine.tscn` 為本專案新建；原始生成工具 `tools/build_mine_scene.py`。使用 Godot 基本曲面／幾何構造石壁、坑木、礦軌、礦燈、星晶，沿用既有原創 moss_rock GLB；沒有第三方下載、商店資產或新增署名義務。E006 的模型／光照脈衝與 E009 文字預告淡入淡出為原創程式演出。角色 GLB 及既有來源記錄不變。
