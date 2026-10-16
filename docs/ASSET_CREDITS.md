# 素材來源與修改紀錄

## 2026-10-16 四視角女角

- 來源：使用者本次提供的四張女角圖；副本保存在 `assets/source/female/references/`。使用者授權本次建模，外部作者及散布授權未獨立確認。
- 本機 HY3D 多視角生成幾何，Blender 重建／減面、頂點配色、眼睛／衣緣／腰扣及基本七骨綁定。
- 遊戲資產：`assets/models/female/lia_user.glb`；未購買或下載素材商店角色。製作與限制見 [女角報告](FEMALE_CHARACTER_REPORT.md)。

## 2026-10-16 使用者主角

- 來源：使用者提供 `D:\3dtest\Character_MV_00002_.glb` 與專案根目錄的主角四面 PNG；由使用者授權本次修改，原作者及外部散布授權尚未獨立確認。
- 修改：重建／減面、頂點配色、眼部幾何、七骨基本綁定；輸出 `assets/models/hero/ren_user.glb` 及 `assets/source/hero/ren_user.blend`。
- 未下載或購買第三方素材。原始 GLB 與參考 PNG 保留；詳細限制見 [主角模型報告](USER_HERO_REPORT.md)。

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


## P6 聲音、光環與場景參考（2026-10-13）

- `assets/audio/original/*.wav`：本專案原創程式合成，來源工具 `tools/build_audio.py`，22,050 Hz／單聲道。四段短旋律循環（village/forest/mine/battle）、七種音效（confirm/hit/heal/guard/victory/defeat/crystal）。無外部取樣、素材商店頁或第三方署名要求；音訊可由固定種子重建。
- 攻擊／治療／防禦光環：BattleStage 使用 Godot TorusMesh／Tween 原創製作，無外部特效素材。
- `docs/references/village_reference.jpg`：使用者提供，僅作場景設計參考，未直接用作遊戲素材；排除於匯出。方向見 SCENE_ART_DIRECTION.md，0.6.1 已以原創幾何實作灰石村第一輪。
- Godot 4.7.2 及第三方引擎授權：`docs/GODOT_LICENSES.txt`，由 Engine API 取得並隨 Windows 包附上。Windows SystemFont 只在使用者系統讀取，不打包微軟字型檔。

## 灰石村 0.6.1 原創場景

`village_guild`、`village_shop`、`village_plaza`、`village_borders`、`village_valley` 五個 GLB 由 `tools/build_village_art.py` 在 Blender 5.2.2 LTS 建立；作者為本專案製作，沒有外部模型／貼圖／商店素材／付費服務。使用者參考圖僅提供色彩與場景方向，沒有擷取圖像作材質。藍色水晶徽章為本專案重新設計。原始 `.blend`、面數紀錄在 `source_assets/village_v2`，不匯出至遊戲。修改內容包含倒角建築、瓦片、花箱、條紋棚布、廣場／晶柱、河岸橋樑和遠景。沿用角色與樹木來源不變；詳見 [場景報告](VILLAGE_ART_REPORT.md)。

## 2026-10-14 灰石村新參考（設計階段）

`docs/references/graystone_village_2026_10_14.jpg` 為使用者提供的 1000003469.jpg，只作最新場景參考，未當作遊戲貼圖或模型。`graystone_village_v3_layout.svg` 與 PNG 是本專案依九區需求繪製的配置示意，非遊戲渲染、非第三方素材、未匯入 runtime。字型使用系統字型渲染，沒有打包字型檔。

## Greystone G01（2026-10-14）

scripts/tools/greystone/build_layout.py 生成原創 Godot 原生白盒，七個建物模組，無第三方素材、貼圖或付費生成。角色引用既有 Ren 視覺，授權來源不變。正式GLB尚未製作；建造參考沿用使用者提供的1000003469圖。

## Greystone G02（2026-10-14）

本專案原創程序地形，依使用者提供的灰石村圖製作。Blender5.2.2及原生Python產生59個GLB，12,409三角面（唯一資源）；23棵松樹共享一個模型。無第三方下載、付費生成或額外署名要求。原始OBJ/manifest/metrics與Blender檢視副本在source_assets/greystone_g02；產生器在scripts/tools/greystone。背景松樹屬G02尺度佈景，完整G04素材庫未完成。

## Greystone G03 素材庫改製（2026-10-14）

以下模型均由 Quaternius 製作，Poly Pizza 頁面標示 Public Domain (CC0)，素材庫搜尋顯示 CC0 1.0。可修改/再散布，無強制署名；本專案仍保留作者及來源。頁面無語意版本號，採 2026-10-14 下載版本。未購買付費素材。

| 來源 | 頁面發布日期 | 原始檔 | 使用 |
| --- | --- | --- | --- |
| [Fantasy Inn](https://poly.pizza/m/x3ZcGn3jr4) | 2021-10-03 | source_assets/greystone_g03/vendor/quaternius_fantasy_inn.glb | 旅館、公會、商店、民宅 A、農舍初版 |
| [Fantasy House](https://poly.pizza/m/BH2XHWUNmF) | 2021-10-03 | source_assets/greystone_g03/vendor/quaternius_house.glb | 民宅 B |
| [House](https://poly.pizza/m/oJJIRwv6Bo) | 2022-09-04 | source_assets/greystone_g03/vendor/quaternius_small_house.glb | 僅 Blender 候選檢視，未用於遊戲 |

修改：重新製作米白灰泥/深木色/暖窗/紅褐及灰藍屋頂材質，依地圖規格調整比例與原點，平面著色、Godot Y-up 匯出、新增床/藥瓶/劍招牌，另建簡化 Godot 碰撞。七個輸出在 assets/models/greystone/buildings；Blender 修改腳本 build_buildings.py。模型未被當作本專案原創；招牌浮雕為本專案新增。

公開 GLB 下載位址分別為 static.poly.pizza/270a08b6-87e1-47eb-ad1c-5fd7be321bcd.glb、341c9305-c6dd-4427-ad00-620ad57eb14e.glb、65d155f6-705c-4e6c-9e3a-b9974bb82324.glb，均從對應來源頁取得。外掛一鍵匯入不支援時使用公開下載，不涉及使用者 API key。

2026-10-14 G03 細化：來源沿用上述 CC0 模型。新製旅館側翼、公會門廳、單層山牆屋頂、門廊、煙囪、門板/把手、櫃檯及鍛造設施；移除旅館母型的部分屋頂/門廊幾何。材質提取至 assets/materials/greystone 共用。未加入新的第三方來源或付費資產。


## G04 程序環境素材（2026-10-14）

17 項素材由本專案 Blender Python 建立或重用原創 G02/G05 幾何；沒有新第三方下載、付費素材或貼圖。來源/變更/面數見 [G04報告](GREYSTONE_G04_REPORT.md) 與 source_assets/greystone_g04/metrics.json。既有 Quaternius 建築授權與署名記錄不變。

## 2026-10-15 原創擴充怪物

assets/models/expansion 四個 GLB（孢子菇靈、荊棘野豬、星晶蝙蝠、礦甲蟲）由本專案 Blender Python 幾何體原創建模，無第三方下載、貼圖或付費素材。來源腳本 scripts/tools/expansion/build_monsters.py；可編輯源檔 assets/source/expansion，.gdignore 排除 Godot 自動匯入。面數及限制見 WILDERNESS_EXPANSION_REPORT.md。場景重用原已記錄的 cartoon 與 greystone 素材，未變更其來源授權。
