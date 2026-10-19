# 敵人模型製作計畫

2026-10-20。A02 五敵來源已結構及四面檢查；A03 依次重用並驗證既有成果，避免重複生成。PASS 只代表模型／動畫候選，正式戰鬥整合屬 A04。

| 任務 | 類別／上限 | 既有候選來源 | 本輪狀態 |
|---|---|---|---|
| A03.1 Spore Sprite | common_enemy／10000 | source_assets/asset_production_a03/spore_sprite | PASS：9811 面／7 骨／6 動作；196 影格／Godot 256 項 |
| A03.2 Ore Beetle | common_enemy／10000 | source_assets/asset_production_a03/ore_beetle | PASS：9911 面／15 骨／5 動作；159 影格／Godot 416 項 |
| A03.3 Thorn Boar | common_enemy／10000 | source_assets/asset_production_a03/thorn_boar | PASS：9998 面／12 骨／7 動作；211 影格／Godot 471 項 |
| A03.4 Crystal Bat | common_enemy／10000 | 同根目錄 crystal_bat | NOT_STARTED |
| A03.5 Corrupted Guardian | boss／15000 | 同根目錄 corrupted_guardian | NOT_STARTED |

每個來源下 `references/<id>_{front,left,back,right}.png` 已存在；A02 仍須依新標準核對 Alpha、畫布、方向、完整性與 SHA，才可 READY。孢子菇靈與守衛另有 reference_sheet_corrected.png，保留方向修正歷史，不回用錯方向原圖。

既有模型、骨架、32 動作與局部貼圖修補報告存在，不能因新增預算就盲目重新提交五個生成工作。先核對既有候選是否符合單件要求與缺失清單；菇靈／甲蟲／野豬／蝙蝠各有五種基本動作，守衛尚須核對重擊／特殊攻擊／stagger 等狀態。A04 正式整合尚未開始。

Forest Slime 沿用獨立流程，本批不重製。每隻保留原件、工作 Blend、最終 GLB、生成與面數／變形／視覺報告。不可只憑面數宣稱通過。
