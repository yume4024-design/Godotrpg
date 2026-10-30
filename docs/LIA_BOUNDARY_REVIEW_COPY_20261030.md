# 莉雅領口 Blender 定位副本 — 2026-10-30

將前次量測的62個 GLB 邊界位置映射到獨立 Blender 副本，供後續拓樸修整，不修改現有可玩莉雅。原 `.blend` SHA256 `1e8d238dc505c3c347d125b43501093c47f4be5c59df437dd4330e1dc235e37e`；原 GLB SHA256 `bd9d5c1c8f016fb12a6e096a4cad642b32b4f728f6e02b393147ab9040b0e5ac`。

副本 `D:/RPGGAME/artifacts/lia-boundary-review-20261030/lia_boundary_review.blend` 的身體網格有三個 `Review_` 頂點群，依到頸部三角面的無方向距離分為 ≤2 mm、2–20 mm、>20 mm。62個 GLB 精確座標全部對上原 Blender 網格，最大誤差0；源網格存在 UV／法線分離頂點，對應群組分別為4、39、129個 Blender 頂點，並非 172 個不同的測量點。大於20 mm的群組已選中，供定位，不代表應直接縫合。

Blender 5.2.2 獨立背景程序另存副本；重新開啟兩份檔案比較，幾何、UV、角落法線、材質槽、物件變換及內嵌圖片雜湊一致，五項檢查通過，來源檔雜湊不變。[建立收據](evidence/lia_review_mapping_20261030/receipt.json)／[重新讀檔比較](evidence/lia_review_mapping_20261030/verification.json)。`tests/test_lia_review_mapping.py` 的座標轉換與分組邊界2項測試通過。

此副本**僅用於定位，沒有修復網格、貼圖或綁骨，沒有進入遊戲**。距離不能判斷兩個表面是否相交；需對照正側背外觀與材質識別，分段修整後再做真正的骨架、動作和視覺驗收。副本留在 ignored artifacts，可從來源與腳本重新產生：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python scripts/tools/prepare_lia_boundary_review.py -- --blend source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.blend --glb source_assets/character_rebuild_20261020/lia/material_cleanup_v2_20261029/lia_material_cleanup.glb --report docs/evidence/lia_surface_distance_20261030/inventory.json --output artifacts/lia-review-new
```

輸出目錄必須不存在。以 `scripts/tools/verify_lia_boundary_review.py` 比對來源與新副本；不以原本可玩莉雅的動畫結果冒稱此候選已通過。
