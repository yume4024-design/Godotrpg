# 雷恩衣褲分層診斷（2026-10-20）

**整體 FAIL，正式雷恩未替換。** 新分層副本首次通過七動作／127 影格的數值 Gate，但實際跑步近景仍有衣緣碎片與穿插，另有 68 個外層面片的角法線保存檢查失敗。不能據此宣稱角色正式可用，完整第一章目標維持進行中。

## 輸入與真實拓樸

從已提交的 `source_assets/character_rebuild_20261020/ren/crotch_repair/ren_rigged.blend` 建立新目錄；SHA256 `93e7f80ada44f2ce8e00205f88e59f61c125c78772881bd4cd92b9740a65c850`。保留原件及所有失敗副本。

只按 UV 分裂後的索引會得到 1323 個面片組，不能當作真正破口。只讀檢查以完全重合座標辨識幾何連接（沒有焊接模型）：13329 個頂點／5029 個位置，32 個組件；主表面含 9969 面。正／背／側 .74m 正交近景均已查看，短衣擺與主體不是可直接抽離的完整獨立網格。

沿解剖標記走最短邊路徑的第一份規劃失敗：腰線／衣緣切邊相接，面片 flood 回到整個主表面。第二份整面選取預覽也錯切白色衣緣及腰包；兩份均留存 FAIL，不拿來輸出正式模型。規劃階段另有非簡單路徑與面數範圍 sanity check 的拒絕；修正規劃檢查不代表放寬動作品質 Gate。

## 實際做了什麼

在副本依查看過的衣緣輪廓切三角面，插值保留原 UV，拆為外套／剩餘身體，再加入 128 面深色褲子內層。沒有縮小 walk .45／run .75 幅度，沒有改七段骨姿、角色 ID、戰鬥、旗標、存檔、正式主入口或 RC2 包。

| 副本 | 面數 | 七動作／127 影格 | 真實畫面 |
| --- | ---: | --- | --- |
| garment_layers_v1 | 14040 | FAIL，run 2.711273 倍；五影響截成四個時在中線切換腿骨 | FAIL，衣緣穿插，首版未複製角法線 |
| garment_layers_v2 | 14040 | PASS，run 2.325045，walk 1.784690 | FAIL，部分白衣緣仍跟隨褲腿而分離 |
| garment_layers_v3 | 14074 | PASS，run 2.325045，walk 1.784690 | FAIL，近景仍見碎片／層間穿插 |

v2／v3 的外套以 Torso／LegLeft／LegRight 三個連續影響綁定，原兩個 Coat 骨及其動畫保留但不再作用於新衣層。這是綁定設計變更，不能稱完全保留舊變形。19 骨／七段名稱及 127 影格骨矩陣最大差為 **0**；跑步 2.5 倍門檻維持不變。

## 可執行檢查

Blender **5.2.2 LTS**。最新候選 GLB SHA256 `a2c258c9382ddef8d819613324e75ad51d56790ddaeb19090064973f3c10ce8c`；Native SHA256 `7e87c2764b721997851f3885c0e4570a943352d2e41f180a62f081c7abd0fe8f`。

- 嚴格 GLB 預檢及獨立 Blender 重匯入 **PASS**，14074／15000，UV／綁定／索引／有限值；3 Mesh／2 材質、4K 貼圖。閉合性沒有宣稱通過。
- 七片段逐整數影格 **127／0 數值失敗**。所有循環端點誤差為 0；這不是完整動畫或遊戲驗收。
- 13946 個原外層三角面保存檢查：UV 最大差 **1.333e-7**、面積總差 **1.672e-8 m²**，packed 4096² albedo SHA 完全相同；骨架／骨姿／名稱／權重契約通過。
- **角法線 FAIL：68 面，最大向量差 1.996755**，包含近反向差異；不是可忽略的小量化誤差。保存檢查整體退出碼 1，原門檻 .002 沒有調高。
- 第一份保存檢查使用 float32 的 barycentric 投影，在細長三角面誤判位置／UV；改 float64 最小平方投影後 UV 通過，角法線仍如實失敗。首次原始無窮值診斷以 `.invalid_json.txt` 保存，不能當標準 JSON 成功報告。
- 兩次跑步／兩次施法的實際 Blender 渲染已查看；v3 640² 原 PNG 留本機，512² WebP 入庫。動作切回／持劍／掛點／Godot 新候選／探索戰鬥／存讀檔 **未測**，沒有借用舊角色或 ENV02 結果宣稱通過。
- Blender 僅使用者縮圖快取寫入失敗；Native／GLB 實際儲存成功，與上述品質失敗分開記錄。

## 再現

在專案根目錄，用既有 Blender 背景程序執行；每次 `--output` 必須新目錄。工具不會改開啟中的使用者 Blender。

```powershell
$blenderExe = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
$sourceRig = 'source_assets/character_rebuild_20261020/ren/crotch_repair/ren_rigged.blend'
& $blenderExe --background --factory-startup --python-exit-code 1 --python scripts/tools/build_ren_garment_layers.py -- --input $sourceRig --output artifacts/ren_layer_rebuild --profile layers_v3
& $blenderExe --background --factory-startup --python-exit-code 1 --python scripts/tools/audit_asset_motion.py -- --input artifacts/ren_layer_rebuild/ren_rigged.blend --category player_character --output artifacts/ren_layer_rebuild/motion.json
& $blenderExe --background --factory-startup --python-exit-code 1 --python scripts/tools/audit_ren_layer_preservation.py -- --source $sourceRig --candidate artifacts/ren_layer_rebuild/ren_rigged.blend --output artifacts/ren_layer_rebuild/preservation.json
```

最後一條預期因角法線 Gate 退出非零；不能捕捉例外後當成通過。`--profile layers_v1`／`layers_v2` 留供重現已拒用配方。渲染工具目前只接受專案自有 Ren source_assets 工作副本。

## 接下來的實際限制

三個分層版本均已回報並拒用，不再藉修改角度輪廓或縮小 stride 重試這套切片法。下一次需要完整重拓樸的衣擺面圈、內層與一致角法線，並排除模型原有重疊薄片；數值通過不解決這個物理結構問題。新角色保持選用工作副本，舊正式角色保留。

下一個獨立工作是依既有固定版本流程隔離 Windows G08.3 效能重現，保留既有 RC2；不能在重建／Blender 工作負載並行時量效能。蝙蝠完整收翼、旅館拓樸、莉雅重製、A04／A05 正式整合、其餘環境物品及完整 C1 仍未完成。Android／iOS 持續暫停。
