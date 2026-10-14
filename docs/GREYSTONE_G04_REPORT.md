# G04 灰石村環境素材庫

2026-10-14。Blender 5.2.2 背景 Python 建模/匯出，Godot 4.7.2；未重設使用者開著的 Blender。正式 0.6.1 主線與存檔不變，沒有開始 G06。

## 產物與來源

17 個獨立 GLB、17 個 PackedScene、9 個外部共用材質、一個 Asset Preview 場景。無貼圖、無外掛、無新下載。G03 七建築及既有地形保留。

| 模型 | 三角面（每個） | 處理 |
| --- | ---: | --- |
| pine_tree_a / pine_tree_b | 26 / 26 | 重用 G02 松樹幾何，不同比例/色彩，附樹幹 |
| bush_a / flower_a / grass_a | 60 / 444 / 30 | 新增簡單低面數灌木、花、草 |
| rock_small / rock_medium / rock_cliff | 21 / 21 / 21 | 重用 G02 岩石，置中、縮放成可重用尺寸 |
| stone_well | 280 | 重用 G05 井結構，轉 GLB |
| wooden_bridge / wooden_dock | 288 / 228 | 重用 G05 板面，納入 G02 欄杆/支柱結構 |
| wooden_fence / lamp_post / wooden_sign | 48 / 36 / 24 | 重用 G05 幾何，轉 GLB |
| barrel / crate / crystal_blue | 108 / 60 / 72 | 新增低面數木桶、木箱、星晶 |

合計 1,793 三角面，為素材各一份的總和，不是整村實例總面數或 Draw Calls。模型明細見 `source_assets/greystone_g04/metrics.json`。所有模型沿用或新增本專案原創程序幾何；原有 Quaternius 建築授權維持不變。

## 使用與重建

模型：`assets/models/greystone/props/`；材質：`assets/materials/greystone/props/`；可重用模組：`scenes/world/greystone/props/`。

預覽：`scenes/world/greystone_asset_preview.tscn`。F6 可查看全部素材；測試另擷取花、灌木、星晶、橋與碼頭近景。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python scripts/tools/greystone/build_props.py
./tools/godot.ps1 -Mode Check
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' scripts/tools/greystone/prepare_props.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' scripts/tools/greystone/build_layout.py
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode VisualGreystoneProps
./tools/godot.ps1 -Mode VisualGreystone
./tools/godot.ps1 -Mode VisualGreystoneBuildings
./tools/godot.ps1 -Mode Smoke
```

首次 Check 產生匯入設定；prepare_props 設定 prop_import.gd，第二次 Check 套用共用材質。模型用 Godot Y-up、公尺尺度；橋/碼頭原點在行走面，支柱在其下方，其他物件原點在地面。

## 整合與碰撞

assemble_village.py 在素材存在時將六種原佔位引用換成正式 GLB/模組；其餘植被、岩石、木桶、木箱與星晶放在道路之外。既有 23 棵背景樹保留，沒有重造整張地圖。水車與作物繼續使用 G05 佔位，未混稱為本次正式素材。

井、圍欄、柱體、樹幹、岩石與箱桶採 BoxShape3D；花、灌木、草、星晶無碰撞。獨立橋/碼頭模組含支撐與欄杆碰撞；村內直接引用其 GLB，沿用已驗證 G02 碰撞並隱藏重複欄杆/板面視覺，避免雙重碰撞或閃爍。

中途探索測試發現武器店旁木桶阻擋北側環路，導致後續路線失敗及 60 秒逾時；已將箱桶移至店後空地，未放寬測試路線或通過條件。

## 已知限制

這是簡單幾何、清晰切面素材庫，不代表整村參考圖完全還原。兩松樹主要以輪廓比例/色彩區別；路燈目前僅材質色，未加入動態光；植被無風動畫；水車仍是佔位。素材畫面評估（0–2）：輪廓辨識 2、統一配色 2、小物全圖可見性 1、構圖層次 1。

Windows 圖形測試可驗證資源與動線；Android/iOS 真機、效能、LOD、觸控、NPC、故事及存檔遷移均未驗收。下一階段為 G06，須另按授權整合互動及位置遷移；也可先進行美術細節迭代。


## 最終驗收

| 命令 tools/godot.ps1 -Mode | 結果 | 日誌 artifacts/logs/ |
| --- | --- | --- |
| Check | 最終 GLB 匯入成功 | check-20261014-150005-287.log |
| VisualGreystoneProps | 43 項、0 失敗 | visualgreystoneprops-20261014-150009-508.log |
| VisualGreystone | 98 項、0 失敗 | visualgreystone-20261014-193524-462.log |
| VisualGreystoneBuildings | 43 項、0 失敗 | visualgreystonebuildings-20261014-193614-211.log |
| Smoke | 正式主場景啟動成功 | smoke-20261014-193625-198.log |

獨立解讀 17 個 GLB payload：各一 Mesh、沒有 image，總面數 1,793，最大檔案 44,928 bytes；SHA256 與大小見 verified_glb.json。已檢視素材總覽、花/星晶/碼頭近景及整合後村莊全圖。圖形測試透過 Input Map 自動操作，不冒充人工通關。

G04 基礎素材庫及本輪整合已完成；G05 複驗亦通過。
