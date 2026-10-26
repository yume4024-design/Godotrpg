# Project Crystal 專案重新審核 — 2026-10-27

## 結論

**未通過整合完成／發布就緒審核。** 既有序章、單次獎勵、交易與存讀檔回歸可通過，但有兩項 P1：完整序章入口仍使用舊灰石村，以及礦坑橋階接口能走出平台下墜。這是本輪實際重現結果，優先於先前「全場景已整合／防墜完成」的描述。

本輪只審核與記錄，沒有修改遊戲程式、模型、劇情、戰鬥數值、存檔 Schema、正式 main.tscn 或匯出包。沒有開始第一章或行動平台，也沒有要求恢復人工驗收。

- 主專案：`D:/RPGGAME`；分支 `feature/greystone-g06`。
- 基線 HEAD：`4ba2b2c88ec1b7a1296cb520f47953cffcbb3d99`；不是本輪新提交。
- 開始時有 30 個 tracked 修改及 395 個 untracked 檔案。來源包含未提交的場景、模型及 HUD，不能只用 HEAD 代表本輪受測內容。
- 本機快取的 origin 功能分支與 HEAD 差距 0／0；本輪未 fetch，不宣稱查核了 GitHub 即時狀態。
- Godot `4.7.2.stable.official.ed1daf0bf`；Windows／RTX 3080／OpenGL Compatibility。

## 確認的問題

### R1 — P1：完整序章沒有載入最新灰石村

`scenes/main/prologue_candidate.tscn:3` 繼承 `mine_reference_integration.tscn`，後者繼承 `greystone_blender_integration.tscn`。最終仍選到 `scenes/world/blender_candidate/greystone_runtime.tscn`、村莊 layout 3、`greystone_blender_master.tscn` 及舊 `blender_master` 模型。

圖形程序實際讀取的結果如下，不只是靜態檔名比較：

| 入口 | 村莊主檔 | layout | CameraRig 角度 | 雷恩 |
|---|---|---:|---|---|
| prologue_candidate | greystone_blender_master.tscn | 3 | (-45,45,0) | ren_rebuilt_visual |
| greystone_reference_integration | greystone_reference_master.tscn | 4 | (-45,12,0) | ren_pixal_visual |

最新村莊主檔使用 `assets/models/greystone/reference_v5`、修整後的建築／地表及 daylight 資源。現在兩個入口各自只集合一部分最新成果：序章入口有新雷恩，參考村莊入口有新村莊。

影響：用「完整序章」啟動或使用對應 RC1 仍看不到新村莊；原有 89 項故事測試並未斷言正確村莊主檔，NPC 檢查也直接載入舊 `blender_candidate`。

修正方向：統一候選入口到新版村莊與鏡頭，保留新雷恩、現有莉雅、礦坑與獨立存檔；套用已存在的 layout 3→4 安全遷移，再增加實際載入的村莊主檔／layout／角色路徑斷言。不可只改文件或放寬位置驗證。

證據：`artifacts/review_20261027/integration_probe.json`、`integration_probe.log`；兩張同一起點的遊戲截圖：

![完整序章目前載入的舊村莊](../artifacts/review_20261027/prologue_candidate.webp)

![參考入口載入的新版村莊](../artifacts/review_20261027/greystone_reference_integration.webp)

### R2 — P1：礦坑防墜開口過寬，仍能掉出可走區域

`scripts/world/mine_reference_geometry.gd:152` 對所有橋階開口固定移除中心左右各 3.65m 的護欄，即 7.3m；`data/world/mine_reference_layout.json` 的橋階寬度是 5m。橋頭兩旁因此留下無支撐、也無阻擋的空隙。四面外牆僅限制全圖 X/Z 邊界，不能阻止內部落差下墜。

本輪先掃描平台周界，再用真實 `ExplorationPlayer`／CharacterBody3D／InputMap 實走，每個案例在平台內落地後向外跑 60 個 physics frame。保持正式 1.95m capsule、0.32m 半徑、4.5m/s 跑速及 0.18m 台階設定；沒有瞬移到平台外冒充穿越。

| 平台／方向 | 起點 x,y,z | 約 1 秒後 y | 結果 |
|---|---|---:|---|
| 入口營地／東 | -24.7,0.1,28.7 | -5.710 | 下墜 |
| 礦車軌道／北 | -35.3,3.1,-15.3 | -2.710 | 下墜 |
| 礦車軌道／東 | -24.7,3.1,3.1 | -2.710 | 下墜 |
| 木橋岔路／北 | 21.9,3.1,-3.3 | -2.709 | 下墜 |
| 木橋岔路／南 | 21.9,3.1,5.3 | -2.712 | 下墜 |
| 木橋岔路／西 | 20.7,3.1,-3.3 | -2.710 | 下墜 |
| 水晶採掘／南 | -35.3,7.1,-26.7 | 1.288 | 下墜 |
| 水晶採掘／東 | 3.3,7.1,-31.3 | 1.290 | 下墜 |

掃描找到 23 個候選取樣點；實走的是上述 8 個不同邊緣案例，**8／8 均失敗**，不宣稱所有其餘點已實走。現有礦坑路線測試仍為 68／0，因其走橋階中央，且防墜新增斷言主要是數量與一個邊緣射線，沒有涵蓋開口兩側。

修正方向：依各 link 的實際寬度、方向、平台交線建立連續橋頭碰撞，保持主路通行；把外推 capsule 與實走測試加入所有接口。墜落回復只能作額外保護，不能代替修好路面與護欄。

證據：`artifacts/review_20261027/edge_probe.gd`、`edge_probe.json`、`edge_probe.log`、`fall_*.webp`。探針成功執行的 exit 0 只代表證據採集完成；JSON 的 `fallen=true` 才是本次失敗結果。

### R3 — P2：小地圖方向及村莊底圖與角色／場景不一致

- `scripts/ui/exploration_minimap.gd:155` 讀 `-player.global_basis.z`，但 `scripts/characters/player.gd:22` 只轉動 `Visual`。實際向 +X 移動後，可見角色方向為 `(1,0,0)`，地圖仍取 `(0,0,-1)`；方向線不會跟隨轉向。
- 小地圖只用 map_id 選固定 `greystone_reference_layout_v4.json`。本輪探針確認序章實際村莊 layout 3，而小地圖資料 layout 4。舊地圖與新版地圖共用同一 ID，僅核對標題不能驗證底圖正確。
- 森林小地圖目前主要畫外環四段線，沒有畫既有中央通道與連接支路；屬導覽完整性待改善，未當成阻斷序章的錯誤。

修正方向：注入當前地圖及 layout 對應的導航資料，方向使用視覺面向或明確的玩家朝向 API；新增東西南北轉身與道路／出口位置對照測試。

證據：`edge_probe.json` 的 `heading`、`integration_probe.json` 的 `minimap_layout`。

### R4 — P2：本機最新來源尚未形成可重現的交付版本

隔離空白測試宿主掛載現有 `builds/prologue-candidate/rc1-20261027/candidate/ProjectCrystal.pck`，讀到 1165 項檔案，沒有 `exploration_minimap` 腳本或 remap。RC1 是 HUD／防墜更新之前的固定包，不能拿它驗收本機新增功能。新版村莊資源雖被 all_resources 打包收錄，也不代表啟動時實際使用。

另外 `scenes/main/prologue_candidate.tscn`、`scripts/ui/exploration_minimap.gd`、`tests/prologue_candidate_test_tree.gd` 尚未進 Git；其他多個 tracked 檔已修改。從 HEAD 重建不會得到目前受測內容。本輪未上傳、未覆蓋 RC1，未把 395 個來源檔一併提交。

修正方向：完成 R1～R3 後，挑選必要檔案形成可追溯提交，再產生新版本號的獨立候選包；核對包內腳本／主場景／模型及雜湊，重跑包內序章與新程序讀檔。不能只更新包的說明檔。

證據：`artifacts/review_20261027/rc1_pack.json`、`static_audit.json`。

## 本輪實際回歸結果

以下通過項目僅代表各測試的範圍，不抵銷 R1～R3 的重現問題。工具 `tools/godot.ps1` 同時檢查引擎退出碼與 ERROR／SCRIPT ERROR；沒有依賴上一輪報告當成新測試。

| 命令／探針 | 結果 | 範圍 |
|---|---:|---|
| `tools/godot.ps1 -Mode Check` | PASS | 載入／腳本解析 |
| `-Mode VisualMineReferenceStory` | 89／0 | 圖形 E001–E009、戰鬥／敗北重試、回村、單次獎勵、存讀檔與 HUD 存在 |
| `-Mode TestMineReferenceStoryReload` | 20／0 | 另一程序重讀候選存檔 |
| `-Mode TestMineReferenceMigration` | 59／0 | 舊 v1／G06 礦坑檔驗證、遷移、原檔保留、無效位置拒絕 |
| `-Mode TestMineReference` | 68／0 | 圖形主路、跨橋、北線往返及水道淨空；不是任意邊緣安全驗證 |
| `-Mode TestReferenceCommerce`／`TestReferenceCommerceReload` | 50／0、5／0 | 新版參考村莊的商店、旅館、交易帳本及重啟 |
| `artifacts/review_20261027/candidate_commerce.gd`，另程序加 `-- --reload` | 50／0、5／0 | 同樣交易套件直接載入目前 prologue_candidate，使用獨立測試欄位 |
| `-Mode TestPhase5`／`TestPhase5Reload` | 69／0、7／0 | 保留的正式入口序章／損壞檔拒絕／重啟 |
| `-Mode VisualRenRuntime` | 93／0 | 新雷恩 14 段、19 骨、持劍掛點與恢復 |
| `-Mode TestPixalCharacters` | 88／0 | 舊 Pixal 雷恩及目前仍使用的莉雅；不能當作新雷恩測試 |
| `edge_probe.gd` | **8 個實走下墜** | 新增的反例測試；並確認方向線不更新 |
| `integration_probe.gd` | **入口差異確認** | 原生兩入口載入與畫面、3 次三區往返、清理 |

本輪主要日誌在 `artifacts/logs`：`check-20261027-025954-817.log`、`visualminereferencestory-20261027-030019-635.log`、`testminereferencestoryreload-20261027-030134-881.log`、`testminereferencemigration-20261027-030142-990.log`、`testreferencecommerce-20261027-030156-797.log`、`testreferencecommercereload-20261027-030207-674.log`、`testphase5-20261027-030215-157.log`、`testphase5reload-20261027-030231-627.log`、`testminereference-20261027-030430-231.log`、`visualrenruntime-20261027-030859-254.log`、`testpixalcharacters-20261027-030910-877.log`。額外探針與候選交易日誌在 `artifacts/review_20261027/`。

批次 PowerShell 外層一度因 `$LASTEXITCODE` 為空而印出 `AUDIT_MODE_FAILED=... EXIT=`；這不是 Godot 失敗。上述結果以工具實際拋錯狀態、原生日誌及各測試 RESULT 為準。

## 角色與短測量測

直接讀 GLB accessor：目前候選雷恩本體 **10,655 triangles／19 骨／14 動畫**，獨立劍的 Godot 測試為 330 triangles；莉雅 **4,806／19／7**。舊「兩主角都低於 5000」只適用歷史 Pixal 版本，不能套到現在新雷恩；後續已有約 10k／完整性優先的資產政策，這裡不因此另判失敗。新莉雅靜態來源並未變成正式可玩角色。

五隻 rebuilt 敵人 GLB：守衛 9,762、收翼蝙蝠 6,249、礦甲蟲 9,911、菇靈 9,811、野豬 9,998 triangles。資料盤點不等於本輪逐隻全動畫驗收；原史萊姆仍為 1,912 triangles 的既有模型。

礦坑既有圖形路線測試採 60 FPS 上限，共 8,778 幀、約 147.6 秒：平均 59.48 FPS、P95 16.721ms、P99 16.788ms、最大 245.465ms；路點 Draw Calls 91～180，引擎 static memory 45,092,782～45,301,226 bytes。最大幀包含測試截圖／取樣影響，未做 CPU/GPU 瓶頸歸因。

完整候選另外三次村莊→森林→礦坑→村莊循環：每輪回村 3,473 nodes、0 orphans；warm-up 後引擎記憶體約 362.39MB，三輪間約增 2.4KB。清理後剩 root 一個 node、0 orphans。已調用 Godot skill 的 memory/purge 輔助工具；這是短循環觀察，不能證明長時間無洩漏，也不是 Windows 程序 working set。

已查看兩個村莊入口畫面、礦坑下墜證據、新雷恩持劍與莉雅施法截圖。未宣稱所有姿勢無穿模、美術符合原圖、鍵鼠／Xbox 人工通關、30 分鐘長測或 Android／iOS 驗收。

## 後續順序與 Git

1. 先修礦坑橋階接口，補全邊緣實走反例。
2. 統一序章入口到最新村莊＋最新可玩角色，驗證舊 layout 存檔安全遷移。
3. 修正小地圖朝向及底圖資料來源，檢查三區導覽完整性。
4. 挑選必要變更提交、新版候選包與包內回歸；人工驗收維持暫停，等待使用者之後恢復。

審核新增本文與本機 artifacts 探針，更新 TASKS／GREYSTONE_BUILD_TASKS／CHANGELOG 及兩份前次報告的更正提示。未修改 runtime，未建立 commit、未推送、未合併 main。現有功能與美術成果保留。
