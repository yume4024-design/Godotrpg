# 灰石村 G03：素材庫建築第一版

2026-10-14；正式遊戲仍為 0.6.1。本次替換獨立灰石村預覽的七棟建物，G03 仍在進行中。

## 已交付

- 素材庫搜尋後選用 Quaternius 的 CC0 Fantasy Inn / Fantasy House；原始 GLB 保存於 `source_assets/greystone_g03/vendor/`，來源與修改見 [ASSET_CREDITS](ASSET_CREDITS.md)。
- Blender MCP 實際匯入、修改並檢視。外掛 protocol 11 不支援 Poly Pizza 一鍵匯入，改從素材公開頁的官方 GLB 連結下載，再用 Blender glTF 匯入；未修改外掛、未讀取 API key、未購買素材。
- 七個獨立 GLB/PackedScene：旅館、公會、道具店、武器店、民宅 A/B、農舍。統一米白灰泥、深木色、紅褐/灰藍/陶橙屋頂、暖色窗面，加入床/藥瓶/劍招牌浮雕。沒有大型貼圖。
- 規格尺寸、地面中心原點、Godot +Z 正面；屋身 BoxShape3D 縮小，不沿屋簷包住。門仍為封閉外觀，沒有室內或切場景。
- `build_buildings.py` 可重跑，僅重建自有 `Crystal_G03_Buildings` 場景。`build_layout.py` 使用已存在的 GLB，缺檔才使用白盒。
- 可編輯副本：`source_assets/greystone_g03/greystone_buildings.blend`。匯出限制 active scene + selection，避免其他場景物件混入 GLB。

## 模型實測

`scripts/tools/greystone/check_buildings.py` 直接檢查匯出 GLB：每檔一場景、一節點、一 Mesh、零貼圖/動畫、接地、水平置中、每棟小於本輪初版 10,000 面上限。

| 模型 | 三角面 | 材質表面 | X/Y/Z 公尺 |
| --- | ---: | ---: | --- |
| Inn | 7,816 | 7 | 12/9/9 |
| Guild | 7,804 | 7 | 15/11/11 |
| Item Shop | 7,792 | 7 | 8/7/7 |
| Weapon Shop | 7,792 | 7 | 8/7/7 |
| House A | 7,756 | 7 | 7/6/6 |
| House B | 5,758 | 9 | 7/8/6 |
| Farm House | 7,756 | 7 | 7/6/6 |

數據及 SHA256：[export_metrics.json](../source_assets/greystone_g03/export_metrics.json)。此為模型統計，不是全場景 Draw Calls 或 Android 效能結果。共用 Blender 色盤不等於跨 GLB 共用 Godot 材質 Resource。

## 驗證

引擎 4.7.2.stable.official.ed1daf0bf；Windows / OpenGL Compatibility / RTX 3080。

- `./tools/godot.ps1 -Mode Check`：退出 0，七個 GLB 匯入成功；`artifacts/logs/check-20261014-081604-608.log`。
- Python 執行 `scripts/tools/greystone/check_buildings.py`：七檔通過上述結構/尺寸檢查。
- `./tools/godot.ps1 -Mode VisualGreystone`：70 項、0 失敗；`artifacts/logs/visualgreystone-20261014-081823-919.log`。實際圖形程序送入 W/Input Map 移動，驗證廣場、主要建築周邊、農田/礦口、河岸/邊界、商店牆面阻擋。商店阻擋斷言配合縮小後屋身立面。
- 已查看 Blender 原模型正面/斜面、改色建築群，以及 Godot 旅館近景、整圖和農田視角。證據在 `artifacts/greystone-g03/`；自動送入操作不等於使用者手動驗收。

## 待完成

目前只有兩種來源屋型，六棟使用旅館母型變體；商店/民宅輪廓仍太相近，尚未達到參考圖的多樣性，G03 不標完成。下一步優先改單層民宅/商店屋型、旅館側翼及屋頂比例；測量並修正有效門寬至少 1.5m、細化門廊碰撞、提取 Godot 共用材質，再做近景驗收。

水井、橋梁、碼頭、水車、階梯崖壁、欄杆/植被密度仍待 G04/G05，整張圖尚未达到參考圖完成度。NPC/劇情/觸控/存檔遷移留 G06；Android/iOS、正式匯出及效能未驗證。正式遊戲地圖與故事/存檔系統未變。
