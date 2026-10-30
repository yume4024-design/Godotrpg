# 莉雅候選網格邊界量測 — 2026-10-30

針對仍未合格的莉雅新候選，建立不啟動 Blender／GPU 的唯讀 GLB 邊界分析，供後續實際拓樸修整使用。來源為 `source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.glb`，SHA256 `bd9d5c1c8f016fb12a6e096a4cad642b32b4f728f6e02b393147ab9040b0e5ac`；來源模型與正式遊戲引用沒有改動。

## 結果與解讀

- 候選 12,554 個三角形（身體 12,078、頸部 476），靜態 GLB 預檢通過 15,000 面預算與 UV 檢查；`--allow-static` 不代表有骨架或動作合格。
- 頸部網格的精確座標邊界數為 0；身體網格有 168 個單面邊、39 個邊界連通群。兩個網格**沒有精確重合的頂點**，因此不是共享頂點的連續網格；這本身不等於視覺上一定有縫。
- 篩選 `x=-0.14…0.14、y=1.50…1.69、z=-1…1` 的領口附近，找到 62 個身體邊界頂點。它們到頸部**最近頂點**距離最小 5.51 mm、中位 29.72 mm、P95 43.23 mm、最大 60.52 mm。這不是到表面的最短距離，也不是實際空隙或穿模深度；區域可能混合領口、下巴及其他開口。
- 最大邊界群有 58 條邊及分岔節點，位於約 `y=1.519…1.628`。不能把整群當成單一閉合洞直接填面；應在 Blender 實際檢視面向、材料與分支後逐段修補。
- 精確座標合併計數有 627 個被三面以上使用的邊，但疊合的不同材質或多層衣物可能共享座標；該值不是「627 個確定破洞」或 Blender 原生非流形判定。衣襬和袖口也可能有正常開口，不可一律焊接。

[完整量測](evidence/lia_boundary_20261030/inventory.json)、[靜態預檢](evidence/lia_boundary_20261030/static_glb_audit.json)；已有[正面](../source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/front.png)及[背面](../source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/back.png)原生渲染仍顯示領口、袖口及裙襬缺陷。這次沒有修改貼圖、網格、骨架或動作，視覺與動畫仍未通過。

## 重現與驗證

```powershell
python -m unittest discover -s tests -p test_glb_boundaries.py -v
python scripts/tools/inspect_glb_boundaries.py --input source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.glb --output artifacts/lia-boundary-new.json --reference-node LiaContinuousNeckClavicle --region -0.14 0.14 1.50 1.69 -1 1
python scripts/tools/audit_character_glb.py --input source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.glb --category player_character --allow-static --output artifacts/lia-static-new.json
```

工具五項單元檢查通過：開放四邊、封閉四面體及塌縮三角形、疊合交界、頂點距離、拒絕未處理的節點變換。工具也拒絕蒙皮及 morph，保留已有輸出不覆寫；它不計算表面交叉、容差合併或模型動畫，不取代 Blender 驗收。

RC5 30分鐘圖形長測在本輪進行；本工具為短時間 CPU 唯讀分析，未開啟 Blender 或另一個圖形渲染程序。待長測終態後再在 Blender 副本檢查局部邊界與修補，重新做正側背渲染、GLB、骨架和動作驗證；未完成前不替換可玩莉雅。
