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
