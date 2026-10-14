# 灰石村 G03：基礎建築驗收

2026-10-14。G03 基礎建物模組完成；整村參考圖還原、裝飾與劇情整合仍屬後續工作。正式遊戲版本仍為 0.6.1，本輪修改在獨立灰石村預覽中。

## 本輪修改

沿用 Quaternius CC0 素材並保留原始輸入，來源見 [ASSET_CREDITS](ASSET_CREDITS.md)。上一輪 e67661e 的七棟改色初版是歷史基線，本輪已修改實際幾何：

- 旅館：收窄主棟、加入較低側翼、煙囪、木骨架與窗框，形成非對稱輪廓。
- 公會：增加山牆門廳、立柱及徽牌，與旅館區分。
- 道具店/武器店/民宅 A/農舍：保留來源下半部牆面和木石細節，移除高旅館屋頂、閣樓窗及舊門廊；重做單層山牆、斜屋頂、屋脊、煙囪與兩柱淺門廊。清除了裁切後的懸空木片。
- 道具店加櫃檯與展示罐；武器店加爐罩與鐵砧；農舍加木百葉；民宅 B 保留雙層輪廓。
- 七棟均新增厚門板、門框及門把；GLB 實際門板四角量測寬度 1.80～2.13m。這是閉合外牆的門面與未來互動預留，並非已實作可穿越室內的門洞。
- 屋身、旅館側翼、門廊柱、櫃檯、鐵砧等用獨立 BoxShape3D；主碰撞及 DoorApproach 座標跟隨最終模型量測，不再依舊白盒座標猜測。
- 九個外部 Godot 材質由 building_import.gd 在匯入時共用；實際測試檢查跨七棟的 Resource 同一性。沒有大型貼圖。

## 交付與重建

七個獨立模型在 assets/models/greystone/buildings，各由 scenes/world/greystone 下的同名 PackedScene 引用。Y-up、地面中心原點、正面 +Z，尺寸維持規格，無縮放碰撞節點。

Blender 工作檔：source_assets/greystone_g03/greystone_buildings.blend。工作前副本 before_refinement.blend 留在本機並由該目錄 .gitignore 排除。前段使用 Blender MCP 實際編輯/檢視；MCP 中斷後改用独立 factory-startup 背景程序，沒有重設使用者開著的 Blender。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python scripts/tools/greystone/build_buildings.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' scripts/tools/greystone/check_buildings.py --prepare-materials
& 'C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe' scripts/tools/greystone/build_layout.py
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode VisualGreystoneBuildings
./tools/godot.ps1 -Mode VisualGreystone
./tools/godot.ps1 -Mode PreviewGreystone
```

## 模型實测

| 模型 | 三角面 | X/Y/Z 公尺 | 門板寬約 m |
| --- | ---: | --- | ---: |
| Inn | 8,328 | 12/9/9 | 1.88 |
| Guild | 8,124 | 15/11/11 | 1.80 |
| Item Shop | 4,154 | 8/7/7 | 2.13 |
| Weapon Shop | 4,154 | 8/7/7 | 2.13 |
| House A | 4,070 | 7/6/6 | 2.10 |
| House B | 5,854 | 7/8/6 | 1.80 |
| Farm House | 4,094 | 7/6/6 | 2.10 |

合計 38,778 三角面，比初版 52,474 減少約 26.1%。每棟 7 個材質表面；這不是全場景 Draw Calls。數據、障礙物尺寸和 SHA256 見 [export_metrics.json](../source_assets/greystone_g03/export_metrics.json)。

## 驗證證據

Godot 4.7.2.stable.official.ed1daf0bf；Windows / OpenGL Compatibility / RTX 3080。

| 檢查 | 實際結果 | 證據 |
| --- | --- | --- |
| GLB payload 檢查 | 七檔各一場景/節點/Mesh、接地置中、無貼圖/動畫、<10k面；實際頂點含門板四角且寬≥1.5m | scripts/tools/greystone/check_buildings.py；artifacts/greystone-g03/glb-check.txt |
| 專案載入 | 七個模型及共用材質匯入成功，退出0 | artifacts/logs/check-20261014-142528-950.log |
| 建築近景與入口操作 | 43項，0失敗；逐棟接近門口、落地、閉門阻擋、退出，九材質實例共用 | artifacts/logs/visualgreystonebuildings-20261014-142607-817.log |
| 全村連續探索 | 70項，0失敗；W/Input Map、旅館/公會/商店/民宅周邊、橋/碼頭/礦口/農田、河岸與邊界 | artifacts/logs/visualgreystone-20261014-142618-946.log |
| 視覺檢查 | 已查看 Blender 模型及 Godot 七棟近景、村莊整圖；修復舊屋簷殘片 | artifacts/greystone-g03/detail-*.webp、02-layout.webp |

中途一次全村測試因舊商店牆面常數失敗，已改為「目前碰撞面 + 玩家膠囊半徑」的精確停止位置斷言並通過重跑。以上操作由圖形程序送入 Input Map，不冒充使用者手動驗收；未重跑無關故事/存檔系統。

## 邊界與下一步

G03 完成的是基本可重用建築及外牆碰撞，不代表整張參考圖已還原。屋簷細節、周邊裝飾密度、井/水車/木橋/碼頭/欄杆、岩階與植被留 G04/G05。按第一輪 01→02→03→05 的規劃，下一步是 G05 基礎組裝與構圖調整，再補 G04 正式道具。

NPC/劇情/門戶切換/觸控/存檔位置遷移留 G06。未驗證 Android/iOS、正式匯出與效能；不得由面數下降推定手機合格。

## Git

依使用者追加指示，origin 已連到 https://github.com/yume4024-design/Godotrpg.git，git ls-remote 成功。此為連線設定；本輪未執行 push。
