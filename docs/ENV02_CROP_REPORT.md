# ENV02 葉菜作物 — 獨立模型候選

後續：28 株已接入 G06 灰石村，原位置不變、4032 面；場景 153／0／G06 576／0，見 [整合報告](ENV02_VILLAGE_INTEGRATION_REPORT.md)。以下保留獨立模組階段的原始結果。

2026-10-20，**PASS（僅獨立模組）**，正式農田配置及效能未驗收。Blender 5.2.2 LTS／Godot 4.7.2.stable.official.ed1daf0bf／Windows。

- 原創 Blender 模型：144／300 triangles，80 面菜心＋八片有厚度折葉，單 Mesh／兩 surfaces；0.70m 寬、約 0.59m 高，地面中心原點，符合舊作物佔位約 0.70m 寬／0.60m 高的尺度。
- `assets/models/greystone/props/leafy_crop.glb` 與 `scenes/world/greystone/props/leafy_crop.tscn` 為新增可重用資產；沒有改名冒充原佔位錐體。建模工具 `scripts/tools/greystone/build_leafy_crop.py` 僅寫新目錄，Native／GLB／SHA 與證據在 `source_assets/environment_rebuild_20261020/leafy_crop/`。
- 共用既有 G04_leaf／leaf_light，無貼圖／透明材質；不要求 UV 展開，不宣稱 UV 製作通過。沒有碰撞、採收、掉落、金錢或存檔功能。
- GLB 嚴格靜態預檢及 Blender evaluated 均為 144 面，明確預算 300；Godot 圖形 **204 checks／0 failures**，實際 28 株共用同一 Mesh 與兩個外部材質，總共 4032 triangles（預算 8400）。
- 檢查有限座標、地面／高度範圍、材質與 28 次實例化；已查看單株正／斜／俯視及 28 株排列，無缺面或貼圖缺失。這不是村莊探索或 FPS／Draw Calls／LOD 測試。
- 畫面微評：COMP-SAFE-EDGE 2、COMP-NEG-SPACE 2、COMP-BALANCE 2、COMP-DEPTH-LAYERS 1（獨立背景）、LIGHT-KEY-FILL 2、LIGHT-SPEC-LOT 2，11／12；僅模型預覽，葉片近看仍有明顯切面，不宣稱整村還原完成。

重現：`tools/review_greystone_crop.ps1`，使用獨立 APPDATA；`tests/greystone_crop_test.gd` 在實際圖形模式運行並輸出 WebP。預覽證據與 SHA 綁定於 acceptance.json／godot_report.json。

正式 greystone_village.tscn 的 28 組作物與水車仍用舊佔位，待下一次場景替換、道路／NPC 淨空、碰撞與效能回歸。森林／礦坑／物品需求、角色、A04、Windows Gate 與第一章未因此完成。
