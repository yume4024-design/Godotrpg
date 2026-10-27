# 莉雅連續頸部試作 — 原生證據

狀態：**靜態結構 PASS；整體視覺 FAIL／未採用；骨架、動畫及遊戲整合未開始。**

三次獨立背景 Blender 試作，未重跑已拒用的方塊／邊界帶狀補片配方。每次原件均為 `../face_v2/lia_surface.blend`，SHA256 `935c47d37706c711cafbb8f1156b6efb6fba1cdbc1edd341fcb3b7da4ec01281`。

| 試作 | 面數 | 移除原面 | 結論 |
| --- | ---: | ---: | --- |
| v1 | 12494 | 328 | 高領殘留皮膚碎片、接縫與裁切不合格 |
| v2 | 12480 | 294 | 頸部改善，但領內尖片與下巴接觸缺口仍在 |
| v3 | 12554 | 364 | 主要碎片消除；領口黑縫、側臉色塊及原貼圖線條仍未合格 |

各子目錄保存實際計畫、原始收據及四張 512×512 Blender 原生 PNG；未修圖。v2/clay 為三張 640×640 灰模診斷，確認尖片來自幾何。v3/static_glb_audit.json 僅證明 GLB 索引、UV、有限值及面數合格，不是動畫或視覺驗收。

v3 新頸部476面；12,078個保留原面逐頂點／UV核對，角法線最大差0.00010658，容差維持0.002。三個原有零法線例外以面／loop ID明確記錄。沒有全域減面、焊接或重新投影色圖。面數上限採當前 player_character 15,000 契約。

完整 BLEND／GLB 保存在本機 `../authored_neck_20261027/`、`../authored_neck_v2_20261027/`、`../authored_neck_v3_20261028/`，精確 Git ignore 不會刪除檔案。輸出 SHA 記在各 receipt.json；不將三份約16MB的試作重複推入遊戲資產。

重現（先指定全新輸出目錄，工具拒絕覆寫）：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python scripts/tools/author_lia_neck_regions.py -- --input source_assets/character_rebuild_20261020/lia/face_v2/lia_surface.blend --plan source_assets/character_rebuild_20261020/lia/authored_neck_acceptance_20261028/v3/plan.json --output artifacts/lia_neck_reproduction
```

v1 對應 `scripts/tools/author_lia_neck.py`，v2/v3 對應 `author_lia_neck_regions.py`；中性材質診斷用 `inspect_lia_authored_surface.py`。regions 工具後續加入重複／非法 face ID 拒絕，並修正非正方形圖片的取樣寬高索引；本次4096²來源取樣結果不變。不能藉重現指令繼續第四次同配方試錯。

後續需要實際領口內襯／邊界拓樸及側臉、髮／衣 UV 修整，再驗證變形；本輪沒有替換 Godot 中的莉雅。
