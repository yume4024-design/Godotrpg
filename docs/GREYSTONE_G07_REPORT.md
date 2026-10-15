# G07 場景效能報告

## G07.1 — Windows 圖形基線（2026-10-15）

基線commit fac928405744d19d894ad3e79c4486fd1b459e1c。完成量測工具與六視角基線；尚未進行畫質預設、LOD、資產合批或Android驗收。正式v0.6.1、新村佈局、NPC位置、碰撞、存檔及2倍探索鏡頭均不修改。

使用 `./tools/godot.ps1 -Mode ProfileGreystone`，必須有圖形顯示，無頭模式主動拒絕。載入真實greystone_integration，使用隔離存檔/音效設定，完成E001後定位到六個站位；每站暖機0.6秒，取樣2秒。VSync關閉、max_fps=0只作用於診斷程序。實際視角1280×720、正交size14，Windows/RTX3080/Compatibility、Godot4.7.2 debug引擎。

FPS為主迴圈牆鐘取樣率，非螢幕呈現率，也非GPU計時。Draw calls與primitives使用Performance整幀計數，含UI/陰影等pass，不能把圖元直接當作唯一可見模型三角面。靜態記憶體為引擎配置量而非程序RSS；視訊記憶體是引擎回報值。同步查詢本身具有診斷成本。

| 視角 | FPS | P95幀時間ms | Draw calls | 渲染圖元 |
| --- | --- | --- | --- | --- |
| south | 1165.3 | 1.038 | 148 | 9526 |
| plaza | 1118.6 | 1.050 | 234 | 26419 |
| inn | 1070.5 | 1.079 | 265 | 53973 |
| guild | 929.5 | 1.225 | 417 | 79119 |
| farm | 1135.7 | 1.039 | 206 | 37735 |
| mine | 1118.4 | 1.072 | 243 | 23518 |

場景載入至首張已就緒畫面 746.66ms，包含資源載入、實例化與初始化，不是磁碟冷快取測試。靜態配置約280MiB，視訊配置約74.5MiB。

整張地圖（包括不可見物件）MeshInstance 268、唯一Mesh167、唯一使用中Material180、實例三角面88,420、碰撞形狀142。純靜態盤點不包含Label文字生成網格；多材質與建築子網格是待剖析候選，不能只憑計數宣稱GPU瓶頸。

## 驗證與證據

- ProfileGreystone：15項/0失敗；日誌 `artifacts/logs/profilegreystone-20261015-090850-984.log`。
- Check：exit0；`artifacts/logs/check-20261015-090911-396.log`。
- JSON：`artifacts/performance/greystone_baseline.json`；六視角WebP在相同目錄，不提交生成產物。
- 已檢視公會實際畫面，角色及互動標籤可見、開場對話遮罩已關閉。站位通過落地檢查；定位使用reset_to，不能冒充本輪行走/碰撞全路線驗收。
- 初次診斷提早取用未就緒地圖、以及PrimitiveMesh不支援ArrayMesh專用查詢，已修正並完整重跑；只有最終成功紀錄作為基線。

## 下一步與限制

G07.2優先盤點公會及旅館的重複材質/子網格，採不改路面碰撞及NPC位置的共用材質或合批方案，再用相同取樣條件比較前後並檢視畫面。公會417次draw calls高於手機暫定200的診斷預算，但此Windows數值不等於Android實測。

本輪六個靜止視角在此桌面明顯高於60FPS，不能據此宣稱全程Windows效能合格；持續行走、場景切換尖峰、發布匯出、較低階PC、Android/iOS真機仍待驗證。低/中/高畫質、手機比例與觸控效能、G08未開始。

新增tests/greystone_performance_probe.gd（及uid）；修改tools/godot.ps1、TASKS、GREYSTONE_BUILD_TASKS、CHANGELOG。本輪無生產遊戲程式修改。


## G07.2 — 共用材質資源（2026-10-15）

公會、旅館GLB盤點結果：各為單一Mesh、七個材質面，已完成基本合批，因此不再破壞建築結構做重複合併。實際可消除的是地形GLB的獨立材質副本，以及村莊場景內相同的StandardMaterial3D定義。

- 新增六個terrain_00～05共用材質；59個地形匯入設定指向terrain_import.gd，保留GLB原檔與匯入LOD設定。
- 提取工具逐一比較同名材質的所有可保存屬性，存在差異即拒絕，不以近似顏色合併。
- 場景51個材質區塊縮為11個，僅完全相同序列化內容才共用；重跑工具合併0個，具冪等性。
- 整村使用中材質 **180→87（減少93，51.7%）**。MeshInstance268、唯一Mesh167、實例三角面88,420及碰撞形狀142保持一致。
- 六視角draw calls仍148/234/265/417/206/243，渲染圖元不變；不宣稱合批或FPS提升。相同時段控制組公會約695FPS、優化後多輪約808～841FPS，但更早基線929FPS，波動不足以歸因。靜態配置下降約0.6MiB；不是大量節省VRAM的成果。

### 驗證與再現

- `PrepareGreystoneMaterials`：六種材質、同名屬性一致，exit0。
- `VisualGreystone`：98項/0失敗，實際輸入走訪主要建築、礦坑、碼頭與障礙阻擋；日誌visualgreystone-20261015-093248-688.log。
- 新舊村莊TSCN將材質參照展開為屬性後比對一致：節點、位置、碰撞、NPC空間與有效材質均未改動。
- ProfileGreystone：六視角15項通過。控制組JSON保存於artifacts/performance/g072_control.json，原G07.1證據保存於g072_before，最新成果在greystone_baseline.json。產物不提交。
- 已檢視公會實際畫面，造型/色彩/道路/互動提示保留。曾遇Windows大小寫匯入快取警告，已統一terrain_*.tres命名並重新匯入，不把帶警告輪次當作最終驗收。

維護方式：地形新增色材質時先在未套用匯入替換的來源上執行 `./tools/godot.ps1 -Mode PrepareGreystoneMaterials`，確認屬性一致再匯入；正常專案直接Check即可使用已提交palette。重建greystone_village.tscn後執行 `python scripts/tools/greystone/deduplicate_scene_materials.py`，避免生成器重複材質回流。

本輪僅完成G07.2資源共用；下一步G07.3建立低/中/高畫質與陰影成本比較，仍需評估公會417次繪製呼叫。沒有更動正式入口、存檔或戰鬥。Android/iOS真機與G08未驗收。

檔案：assets/materials/greystone/terrain六個tres、59個terrain GLB.import、greystone_village.tscn、terrain_import.gd/share_terrain_materials.gd（含uid）、deduplicate_scene_materials.py、tools/godot.ps1及任務/變更/本報告。

最終無大小寫警告輪次：check-20261015-093627-458.log（exit0）、profilegreystone-20261015-093633-393.log（15/0）；Godot 4.7.2 / Windows / RTX3080。
