# 莉雅領口邊界至頸部表面量測 — 2026-10-30

沿用 [前一輪邊界量測](LIA_BOUNDARY_DIAGNOSTIC_20261030.md) 的靜態候選與範圍，擴充唯讀工具，計算每個身體邊界頂點到獨立頸部網格三角形的最近距離。來源 GLB SHA256 `bd9d5c1c8f016fb12a6e096a4cad642b32b4f728f6e02b393147ab9040b0e5ac`；模型、貼圖、骨架與遊戲引用均未修改。

| 同一批 62 個頂點 | 最小 | 中位 | P95 | 最大 | 2 mm 內 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 到最近頸部頂點 | 5.51 mm | 29.72 mm | 43.23 mm | 60.52 mm | 0 |
| 到最近頸部三角面 | 1.34 mm | 23.70 mm | 42.30 mm | 59.68 mm | 3 |

這說明只量頂點會高估到面距離。篩選範圍含領口、下巴與其他邊界，不能認為每個點都應貼到頸部。數值是**無方向的頂點到三角面距離**，不是表面交叉檢測、穿模深度、整圈縫隙量或美術判定；更不能直接把 62 點全部焊接。兩網格是否相交及邊界材質仍須在 Blender 副本逐段確認。

[完整清單與 62 個座標](evidence/lia_surface_distance_20261030/inventory.json) 可作為 Blender 定位依據。角色仍為 12,554 triangles，候選無骨架／未通過視覺與動畫驗收；現有可玩莉雅保留。

## 驗證

```powershell
python -m unittest discover -s tests -p test_glb_boundaries.py -v
python scripts/tools/inspect_glb_boundaries.py --input source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.glb --output artifacts/lia-boundary-surface-new.json --reference-node LiaContinuousNeckClavicle --region -0.14 0.14 1.50 1.69 -1 1
```

六項測試通過，涵蓋開放／封閉邊界、塌縮及重疊情況、錯誤變換拒絕，和三角面內部、邊、頂點及退化三角形距離。RC5長測仍在執行；本輪只做短時間 CPU 唯讀分析，未另啟圖形程序。待長測終態再以 Blender 副本檢查並修整，仍須原生渲染、骨架及動作驗收。
