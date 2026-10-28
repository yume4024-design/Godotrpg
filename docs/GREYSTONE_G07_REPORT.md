# G07 場景效能報告

2026-10-29：最新序章 RC3 圖形自動長測1812.761秒、1264／0＋重啟25／0，三區探索約59.82～60.00 FPS；交易／戰鬥最大216～223ms。這次是Godot完整引擎掛載固定QA PCK，debug_build=true，與下方歷史Release長測分開。[完整數據、採樣修正及限制](PROLOGUE_RC3_SOAK_REPORT.md)。

2026-10-22更新：固定RC4／0bb2188於Windows RTX3080原生Release長測1804.213秒、1548／0；另程序讀長測存檔97／0、短Detail208／0及普通啟動／關閉通過。分區FPS、P95／P99、Draw Calls、記憶體及保留的啟動／戰鬥尖峰見[固定包報告](RC4_FIXED_PACKAGE_REPORT.md)。此為自動化圖形驗收，新包實體鍵鼠／Xbox與G08總Gate仍待；不是Android／iOS或新主角替換驗收。

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


## G07.3 — 三段畫質與陰影比較（2026-10-15）

RunG06上方新增「畫質：高」按鈕，按下依序高→低→中→高。桌面與既有觸控適配使用同一個Control。探索鎖定/戰鬥時禁用按鈕，預設高保留原視覺。畫質目前僅本次遊戲有效，重新啟動回高；未建立設定檔持久化，不改SaveCodec或遊戲存檔。

| 預設 | 探索主光陰影 | 陰影距離 | Viewport MSAA |
| --- | --- | --- | --- |
| 低 | 關閉 | 不使用 | 關閉 |
| 中 | 開啟 | 30m | 2× |
| 高 | 開啟 | 60m | 4×（原設定） |

ExplorationQuality持有純渲染設定，透過明確注入Viewport及Sun，不碰遊戲Manager。主光設定適用探索場景；MSAA屬共用Viewport，因此進入戰鬥也沿用所選抗鋸齒，未修改戰鬥燈光/數值。地圖鏡頭維持2倍，未移動地形、NPC或碰撞。

### 實際量測

Windows / RTX3080 / Godot4.7.2 / Compatibility，1280×720、公會靜止視角，VSync關閉；每段暖機0.6秒、取樣2秒。數據來自同一程序切換，包含新增按鈕的UI繪製。不是手機真機，也不是長時間GPU基準。

| 預設 | 取樣FPS | P95幀時間ms | Draw calls | 渲染圖元 |
| --- | --- | --- | --- | --- |
| 低 | 1115.1 | 1.128 | 160 | 37418 |
| 中 | 875.3 | 1.314 | 419 | 79197 |
| 高 | 855.2 | 1.384 | 419 | 79197 |

低畫質draw calls 419→160，下降61.8%，圖元79,197→37,418。中/高在此近景繪製呼叫相同；不宣稱縮短陰影距離在此視角能減少繪製呼叫。FPS在兩輪間有波動，不外推為全程或Android提升。低畫質畫面缺少地面投影、邊緣較鋸齒，屬明確品質取捨。

### 驗證

- Check：exit0，check-20261015-170447-501.log。
- VisualGreystoneQuality：26/0，visualgreystonequality-20261015-170613-489.log。實際滑鼠點選三段、陰影開關/距離及MSAA、非法值拒絕、角色/背包/劇情/任務/獎勵不變、落地位置不變、960×540按鈕、InputEventScreenTouch切換。
- VisualG06Touch：22/0，visualg06touch-20261015-170520-795.log，既有移動/對話/選單/戰鬥觸控回歸。
- TestG06Story：58/0，testg06story-20261015-170528-104.log，新村完整序章、場景往返、敗北/重試、單次獎勵及存讀檔。
- 合計106項斷言通過；查看低/高與小視窗實際WebP，按鈕及角色辨識正常。證據artifacts/performance/quality/{0,1,2,small}.webp與results.json，不提交產物。

新增scripts/ui/exploration_quality.gd及tests/greystone_quality_test.gd（含uid）；修改greystone_integration.gd、tools/godot.ps1及任務/變更/本報告。重現：`./tools/godot.ps1 -Mode VisualGreystoneQuality`。

下一步G07.4：動態探索路線與遠距可見性成本檢查，再決定LOD/可見性調整。設定持久化、Android/iOS真機、長時間/發布版效能、G08仍未驗收。正式main入口未更換。

## G07.4 — 動態探索與遠距可見性（2026-10-16）

完成本機短時動態取樣及可見性成本驗收，沒有套用破壞畫面的裁切。工具：`./tools/godot.ps1 -Mode ProfileGreystoneDynamic`。Windows／Godot4.7.2／RTX3080／Compatibility／1280×720／高畫質／VSync關閉。六區各由固定站位起步，InputMap向右移動2秒；逐區比較正常與暫時隱藏原點距離>45m的Mesh。每次重置起點，暖機0.6秒。不是單次連續全村巡迴，也不是冷啟動或發布版壓力測試。

| 區域 | 實走m | 正常平均ms | 正常P95 ms | 正常最大ms | 正常Draw Calls | 隱藏遠景Draw Calls | 隱藏P95 ms |
|---|---:|---:|---:|---:|---|---|---:|
| 南入口 | 9.00 | 1.02 | 1.29 | 2.22 | 150–215 | 134–180 | 1.16 |
| 廣場 | 9.00 | 1.01 | 1.21 | 1.71 | 246–374 | 240–370 | 1.20 |
| 旅館 | 7.63 | 1.02 | 1.19 | 1.84 | 274–329 | 274–329 | 1.23 |
| 公會 | 7.93 | 1.19 | 1.53 | 2.48 | 429–447 | 410–421 | 1.48 |
| 農田 | 8.75 | 1.10 | 1.64 | 2.71 | 218–240 | 187–208 | 1.33 |
| 礦口 | 3.52 | 1.05 | 1.40 | 2.27 | 232–255 | 139–149 | 1.17 |

引擎靜態配置峰值約280.18～280.55MiB，顯示記憶體約78.52～78.77MiB；不是程序RSS，也不是洩漏證明。各輪保留所有資源，hide並不釋放模型，因此無顯著記憶體節省。報告另保留TIME_PROCESS／PHYSICS監視器抽樣，但TIME_PROCESS出現高於實際幀間隔的快取值，不能據此宣稱CPU執行耗時或GPU瓶頸；表格幀時間使用單調時鐘逐幀差值。

瓶頸判讀：公會仍是繪製提交成本最高區域；45m遠景隱藏對其收益小，表示主要成本在近景建物／陰影，而非單純遠物件數量。礦口繪製減少較多，但固定半徑依原點裁切會改變可見陰影（公會比較圖已有證據），可能切掉大型延伸網格。不採用到正式場景。GPU/CPU根因未以硬體計時器確證；不可把draw calls數量直接稱為GPU瓶頸。後續優先比較近景陰影與可分區模型，而非全圖硬裁切。

驗證：63/0，profilegreystonedynamic-20261016-000154-493.log；輸出artifacts/performance/greystone_dynamic.json與dynamic_*比較圖。已查看公會正常／裁切圖，互動角色保留但陰影不同。每區檢查party/inventory/flags/quests/rewards/story不變。第一輪63/0，第二輪因視窗失焦無移動被測試正確拒絕；最終測試顯式注入輸入元件焦點通知，使用相同InputMap／碰撞移動，未修改正式焦點行為。所有失敗輪次不作為表格依據。

本輪無生產場景／碰撞／NPC改動，正式v0.6.1保留。G07.4有限範圍驗收完成；長時間尖峰、場景切換、低階PC與整體G07未宣稱完成。Android依使用者最新指示暫停，詳見ANDROID_ACCEPTANCE.md。

最終回歸：TestG06Story 58/0（testg06story-20261016-000233-134.log）、TestG06 51/0（testg06-20261016-000251-378.log）、Check exit0（check-20261016-000336-630.log）。連同動態63項共172項通過。未變更生產遊戲邏輯、主場景、存檔schema或匯出預設。

## G07.4 延伸：120秒動態取樣（2026-10-16）

命令 `./tools/godot.ps1 -Mode ProfileGreystoneEndurance`。沿用RTX3080／Windows／Godot4.7.2 Compatibility、1280×720、高畫質、VSync關閉。六區各20秒，每秒交替左右InputMap行走；區間重置站位，未裁切遠景。總取樣120秒、每區約89～90公尺累積往返移動，不是穿越整村90公尺。測試工具每秒注入焦點通知；不修改正式遊戲焦點邏輯。

| 區域 | 平均ms | P95 ms | P99 ms | 最慢ms | Draw Calls |
|---|---:|---:|---:|---:|---|
| 南入口 | 0.95 | 1.32 | 1.55 | 2.38 | 150–200 |
| 廣場 | 1.03 | 1.44 | 1.69 | 4.17 | 238–273 |
| 旅館 | 1.11 | 1.51 | 1.78 | 2.59 | 267–369 |
| 公會 | 1.21 | 1.60 | 2.01 | 3.30 | 419–447 |
| 農田 | 0.97 | 1.17 | 1.34 | 2.94 | 206–241 |
| 礦口 | 0.98 | 1.20 | 1.32 | 2.10 | 223–269 |

六區皆無超過16.667ms取樣幀。公會仍有最多繪製呼叫，未確認CPU/GPU根因，未改生產場景。記憶體每秒記錄引擎靜態配置（含測試陣列）；區內增量不能當作遊戲洩漏，跨區起始配置的小幅增加也可能是資源暖機。這輪沒有數十MB持續上升，仍不宣稱無洩漏。

63/0，日誌 profilegreystoneendurance-20261016-001903-041.log；Check exit0，check-20261016-002115-192.log。原始指標 artifacts/performance/greystone_endurance.json。已查看公會實際畫面，角色、互動提示與陰影保留。各區比對角色／背包／旗標／任務／獎勵／劇情狀態不變。本輪只新增診斷腳本及工具模式；此模式程序上限180秒，其他命令維持60秒。

下一步：場景切換的載入與尖峰量測。更長壓力測試、低階PC、發布版仍待驗收，Android維持暫停；本次不代表整體G07完成。

記憶體數值補充：各區起始靜態配置280.064～280.406MiB；峰值280.499～281.039MiB，單區增加約0.42～0.63MiB（包含每幀樣本陣列）。顯示配置74.460～74.710MiB。

## 2026-10-17 角色更新後回歸

六區動態探索重新取樣 63/0；正常場景 P95 1.072～1.462ms，公會 Draw Calls 348～366 最高。遠距裁切仍僅診斷，不修改正式可見性。角色 battle 比較新增 31/0，新角色實際行動 P95 1.026ms、337～353 Draw Calls。完整方法、記憶體限制與本機日誌見 [CP09 紀錄](CHARACTER_POLISH_REPORT.md#cp09windows-角色效能回歸)。僅 RTX 3080 桌面暖機樣本；Android 暫停，未作整體 G07 或低階設備合格宣稱。


## G07.5 — Windows 長時間穩定性（2026-10-18）

圖形 soak 1815.966 秒、含序章 1838.368 秒，81 次切圖、1086 斷言零失敗；G06 回歸 576 項通過。60 FPS 限速下探索平均約 16.67ms；初始化最大 664.406ms、後續 battle 區段最大 141.549ms，不能宣稱所有幀均達標。程序工作集取樣峰值 712.484MiB、引擎配置峰值 406.044MiB。方法、完整表格、已知問題及 G08 門檻見 [G07.5 報告](GREYSTONE_G075_REPORT.md)。沒有改動遊戲邏輯／模型／存檔；Android／iOS、G08 本輪未開始。
