# 莉雅頸部試作 — 三版拒用

2026-10-22。**修整 IN_PROGRESS／三版配方 FAIL，沒有採用版本。** 原靜態模型與正式遊戲保持原狀。

- `before/`、`rejected_v2/`、`rejected_v3/`：各四個Blender原生近景，僅縮至512² WebP供檢查，沒有繪圖遮蓋。
- `source_neck_inventory.json`：原工作檔局部face IDs／座標／UV取樣色與十個高度切面；`cut_diagnostic.json`：切邊實際端點與連通診斷。
- `source_zero_normals.json`：原腰部三個零角法線；只在候選使用各自原面法線，不作全身重算法線或放寬保留容差。
- `acceptance.json`：三版結構／視覺分層結果、輸出SHA與未完成事項。
- `preserved_files.json`：正式角色、主入口、SaveCodec、序章與靜態來源對當時HEAD一致。
- `formal_character_regression.txt`：Godot4.7.2圖形88／0，測舊正式模型，不表示新模型已能用。

重現來源為已提交的 `../face_v2/lia_surface.blend`。從專案根目錄使用獨立Blender背景程序，不操作使用者正在編輯的場景：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python scripts/tools/inspect_lia_neck.py -- --input source_assets/character_rebuild_20261020/lia/face_v2/lia_surface.blend --output D:/RPGGAME/artifacts/lia_neck_recheck
```

`rebuild_lia_neck.py --input <來源> --output <全新路徑>`為v2；加`--seal-cut`為v3，兩者都明確拒用。v1在未定義零法線處失敗的收據保存於 `../neck_v1_20261022/`；v2／v3有各自repair_report與嚴格glb_audit。失敗大檔留本機ignored，不重複上傳4K色圖。

下一步需要沿真正領口重建連續頸部／鎖骨拓樸、接好局部UV並檢查下巴／頭髮交界，之後才驗證頭部轉向、彎曲與新骨架。矩形切盒加封閉管／過渡片的這組配方不再試第四次。候選沒有通過獨立整體表面保留、骨架、動畫、G06或新Windows包驗收。
