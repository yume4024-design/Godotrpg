# 序章整合修正與 Windows RC2 — 2026-10-27

## 範圍與狀態

修正重新審核 R1–R3：目前序章候選同時載入 reference_v5 灰石村、layout 4、對應鏡頭、新雷恩、既有可玩莉雅、擴充森林及新版礦坑。礦坑防墜反例已修補，小地圖資料來源與方向已修正。R4 包內驗收與提交後續紀錄在本報告末尾。

正式 main.tscn／v0.6.1、戰鬥數值、角色 ID、旗標、任務獎勵和存檔 Schema 未修改。人工驗證依使用者要求繼續暫停；圖形自動測試與實體鍵鼠／Xbox、人工美術認可分開記錄。Android／iOS、第一章未開始。

## 實作

- prologue_candidate 繼承 greystone_reference_integration，保留獨立候選存檔與 ren_rebuilt_visual。圖形測試檢查實際 Village 主檔、CameraRig 及角色，不再直接載入另一張村莊代替入口驗收。
- 礦坑護欄按每條 link 的實際寬度和邊界交點裁切，與橋側護欄重疊 0.1m；平行道路不誤開洞，短邊段不再被捨棄。地下水保持空腔；保留 501 原碰撞與先前新增 39 大岩塊／礦口碰撞。
- ExplorationMap 明確提供導航資料路徑、種類和範圍。相同 map_id 的舊版村莊不借用新版底圖。森林小地圖取 9 組實際道路網格的世界座標範圍，顯示中央道路及兩側連接線；出口標記取真實互動點。
- 玩家朝向來自 Visual 的 +Z，對齊實際轉身；測試涵蓋四方向移動與停止後朝向。
- 沿用嚴格 SaveCodec 與既有 layout 遷移。新增同 slot 的 RC1 layout 3→4 測試，檢查載入不改原始位元組、明確保存保留 .bak，沒有放寬位置驗證。
- 打包改從 Git HEAD 的 tracked 快照匯入／匯出，避免混入工作目錄內大量 untracked 美術實驗。保留 RC1；RC2 另建 candidate／qa，沿用已驗證 Godot 4.7.2 EXE，沒有冒稱本機匯出模板重產 EXE。

## 來源實測

引擎：Godot 4.7.2.stable.official.ed1daf0bf，Windows、RTX 3080、OpenGL Compatibility。指令均在 D:/RPGGAME 執行，測試使用 artifacts 下隔離 user://。

| tools/godot.ps1 模式 | 實際結果／涵蓋範圍 |
| --- | --- |
| TestPhase5 / TestPhase5Reload | 69／0 + 7／0，保留正式入口序章、損壞檔拒絕與重啟 |
| Check | 載入／匯入通過，無解析錯誤 |
| TestMineEdges | 以 Godot --script res://tests/mine_edge_safety_test.gd 執行：23 個歷史危險樣本實際跑步不墜落，四方向／停止朝向通過；全平台邊緣 0.4m 間距掃描沒有新缺口 |
| TestMineReference | 68／0，主路、交叉橋、北線跑步及反向走路通過，地下水無隱形地板 |
| VisualMineReferenceStory | 91／0，圖形 E001–E009、教學戰、Boss 失敗重試與勝利、回村、212 金幣／每人300 EXP／單次星印、NPC、UI與保存 |
| TestMineReferenceStoryReload | 22／0，獨立程序續讀、裝備／隊伍／故事及單次獎勵保留 |
| TestPrologueMigration / TestPrologueMigrationReload | 91／0 + 6／0，layout 2／3 遷移、同 slot RC1 升級、非法位置拒絕、原始檔保留與重啟 |
| TestPrologueCommerce / TestPrologueCommerceReload | 50／0 + 5／0，實際候選商店／旅館、扣款、物品上限、防重入、交易存檔與全隊恢復 |
| TestPrologueNavigation | 31／0，三區切換、實際主檔／鏡頭、森林所有 9 路面與底圖覆蓋、舊版資料隔離；三張圖已查看 |

主要證據：artifacts/logs/prologue-edge-repair.log、visualminereferencestory-20261027-055814-156.log、testminereference-20261027-055921-557.log、testprologuemigration-20261027-060003-051.log、testprologuenavigation-20261027-060211-633.log。測試畫面在 artifacts/godot-user/Godot/app_userdata/失落星核 — Project Crystal/prologue_repairs/，故事畫面在同層 mine_reference_tests/。

## 完成邊界

本輪修復可驗證的序章整合／防墜／導航問題。與參考圖的美術保真度、旅館老闆既有造型缺陷、新莉雅靜態候選轉可玩、人工美術認可與實體控制器體驗仍不可由自動通關替代。女性村民依先前指示維持候選。不能以本輪結果宣布全部美術／G08 最終驗收完成。

## RC2 包內驗收

- 修正提交：8d05a6f3937750efbff471b2ce455f0ee1ec5871。
- 最終包來源：d8baaee91ef9ec18a2cf0976cc7d55b2761922f2；中間提交修正系統 TEMP 寫入權限與快照漏帶 default_bus_layout.tres。
- 隔離建置經全新匯入後，candidate 與 qa 匯出成功；RC1 未覆蓋。
- Candidate PCK：8979b541f18892d2a5476923d7afc2a4bce146d877d3951afd0c8df04fe6840f。
- EXE：d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562，既有同版本 runtime。
- 使用包內 EXE 圖形執行完整序章 93／0、新程序讀取 25／0；普通候選 EXE 圖形啟動 180 幀無錯誤。
- Godot 4.7.2 console engine 僅掛載 QA PCK，從包內執行導航 31／0、舊版序章測試生成遷移 fixture 69／0、交易 50／0、交易重啟 5／0。這四項是包內容測試，並非包內 EXE 執行額外 --script；已確認 release EXE 不接受 --path，額外腳本以完整 engine 執行。
- 最初交易測試在全新 profile 缺少 P5 前置 fixture 而失敗；補跑真正的 P5 序章產生測試檔後，原交易檢查通過。沒有放寬任何存檔驗證。
- Native pack audit 在空專案掛載：candidate 1092 項、qa 1315 項。625 個主要遊戲資源與其匯入／匯出產物完全相同；兩包共有項僅 project.binary、global_script_class_cache.cfg 與 uid_cache.bin 不同，對應測試入口／測試類別。
- 所有包內日誌與檔案雜湊在 builds/prologue-candidate/rc2-20261027/acceptance/。可用 tools/verify_prologue_package.ps1 重現，有 Music／SFX 實際匯流排斷言。
- 30 分鐘圖形模式循環已完成，使用相同 QA PCK 加外部診斷腳本，不是人工遊玩。資料如下。

## RC2 圖形長測與重啟

- Godot 4.7.2 console engine 掛載上述 QA PCK，工作目錄為包的 qa 資料夾，沒有來源專案資源回退。1280×720、Compatibility、RTX 3080、限幀 60、關閉 VSync。
- 先完整自動序章一次，再執行 **1810.265 秒（30 分 10 秒）**循環；含前置序章的總程序採樣 1856.356 秒。27 輪 × 3 地圖、81 次切換，最終 `G075_RESULT checks=1264 failures=0`、exit 0；無 ERROR／SCRIPT ERROR／FAIL／WARNING。
- 實際 InputMap 移動與碰撞、NPC 對話／購物／住宿、森林及礦坑可選戰鬥、戰鬥返回、每區存讀檔及狀態逐項一致性、唯一星印／獎勵帳本均檢查。每區採固定可走區段重新定位，**不是連續人工走完全圖**；計時包含診斷、截圖及存讀檔成本。
- 同一長測存檔在新圖形程序重啟：25／0，隊伍、裝備、金幣212、莉雅EXP300、劇情與單次星印保留。沒有複製或改寫正式使用者存檔。
- `tests/prologue_rc2_stability_test.gd` 保留實際執行診斷腳本的相同程式內容（執行來源SHA256 `2c85b684c841cf518b67a80fada42bfdc6af8759e55c0ea6c777b97df685db86`；Git會正規化換行）；重啟腳本為 `tests/prologue_rc2_restart_test.gd`。JSON 在最後時長斷言之前輸出，故 checks=1263；終端含該斷言為1264，未手動更改原始證據。

| 區段 | 平均FPS | 平均幀ms | P95 ms | P99 ms | 最大幀ms | Draw Calls 範圍 |
|---|---:|---:|---:|---:|---:|---:|
| 灰石村探索 | 59.80 | 16.722 | 16.764 | 16.947 | 88.556 | 776–1043 |
| 森林探索 | 59.89 | 16.696 | 16.752 | 16.939 | 66.571 | 288–334 |
| 礦坑探索 | 60.00 | 16.668 | 16.740 | 16.939 | 83.487 | 184–207 |
| 戰鬥及返回 | 57.24 | 17.470 | 16.860 | 52.926 | 221.659 | 101–333 |
| NPC／交易 | 54.79 | 18.252 | 19.437 | 70.513 | 218.444 | 953–1213 |
| 場景切換 | 56.45 | 17.713 | 27.481 | 69.034 | 83.493 | 175–1194 |
| 初次載入及完整序章 | 21.79 | 45.899 | 18.598 | 243.646 | 8245.355 | 0–1300 |

每次切換連同既有等待完成邏輯：村莊平均338.808ms／最大352.094ms，森林340.666／350.519ms，礦坑342.810／345.993ms。這是整段切換耗時，與單幀時間不同。

程序記憶體每5秒取樣326次，涵蓋長測約第3分鐘至結束：工作集採樣峰值894.45MiB、程序生命週期峰值959.12MiB、最後883.46MiB；Private Bytes峰值2179.90MiB。採樣未涵蓋前約3分鐘，不宣稱完整程序曲線。引擎 MEMORY_STATIC 峰值409.63MiB；相同地圖檢查點從首輪到末輪約增加1.1MiB，包含本次診斷累積的幀時間陣列。三區節點數一直為4715／861／919，沒有隨循環增加。

存讀檔立即取樣時 orphan nodes固定28；獨立重啟探針等待3幀，觀察21→0，與HUD移除後 queue_free 的延後回收相符。沒有將立即取樣的28記為零，也不以本輪資料保證不存在任何記憶體洩漏。

**仍需改善的效能項目**：首次載入／初次圖形初始化區段有8.245秒尖峰；交易、戰鬥與切換有52–244ms的P99或最大尖峰。村莊 Draw Calls 明顯高於森林／礦坑。這些是後續量測與優化方向；本輪沒有用平均60FPS宣稱所有畫面均穩定60FPS，也沒有在尚無Profiler分解證據時斷言GPU或CPU根因。

證據根目錄：`builds/prologue-candidate/rc2-20261027/acceptance/`（soak.log、soak-process.csv、soak-restart-output.txt）；原始 report.json 與畫面位於同包的 `soak-profile/Godot/app_userdata/失落星核 — Project Crystal/`。畫面已檢視村莊、森林、礦坑，長測日誌及原始數據留本機、不提交存檔或日誌。

## 固定包與重現方式

- 啟動：`D:/RPGGAME/builds/prologue-candidate/rc2-20261027/candidate/start_prologue_candidate.cmd`。實際執行啟動器並運行180幀通過；使用隔離 user_test/profile，不觸及正式存檔。
- ZIP：`builds/prologue-candidate/rc2-20261027/ProjectCrystal-0.6.1-prologue-rc2-Windows.zip`，SHA256 `4effc9bdcc7fd6ca785ddf9518f266012cc81efaba293551d561a5144c1a9350`。
- 解壓比對5／5檔案一致（EXE、PCK、啟動器、README、manifest），沒有封入 user_test、存檔或日誌。
- `tools/verify_prologue_package.ps1` 已整份執行成功，先驗兩包EXE／PCK雜湊，再跑序章、重啟、導航、前置fixture、交易／重啟及普通候選啟動。已確認且保留之前缺fixture／匯出TEMP／遺漏音效bus的失敗紀錄，不將它們當成通過包。
- 新增／主要修正：`scenes/main/prologue_candidate.tscn`；`scripts/world/mine_reference_geometry.gd`、`exploration_map.gd`、`expanded_wilderness.gd`；`scripts/characters/player.gd`；`scripts/ui/exploration_minimap.gd`；候選HUD及場景資料；`tests/mine_edge_safety_test.gd`、`prologue_navigation_test.gd`、`prologue_migration_test.gd`、`prologue_commerce_test.gd`、`prologue_rc2_stability_test.gd`、`prologue_rc2_restart_test.gd`；`tools/package_prologue.ps1`、`verify_prologue_package.ps1`、`start_prologue_candidate.cmd`與`godot.ps1`。完整已追蹤變更可查修正提交8d05a6f及後續提交，既有無關美術實驗與兩份文件修改未混入。

在獨立PowerShell工作階段重跑長測（會產生新的測試存檔；不覆蓋本次證據）：

```powershell
$rc = 'D:/RPGGAME/builds/prologue-candidate/rc2-20261027'
$engine = 'D:/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe'
$env:APPDATA = "$rc/soak-recheck-profile"
$env:LOCALAPPDATA = $env:APPDATA
$env:TEMP = "$rc/recheck-temp"
$env:TMP = $env:TEMP
$env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = '1'
New-Item -ItemType Directory -Path $env:APPDATA,$env:TEMP -Force | Out-Null
Set-Location "$rc/qa"
& $engine --main-pack "$rc/qa/ProjectCrystal.pck" --log-file "$rc/acceptance/soak-recheck.log" --script D:/RPGGAME/tests/prologue_rc2_stability_test.gd
if ($LASTEXITCODE -ne 0) { throw 'Soak failed; inspect log before retrying.' }
& $engine --main-pack "$rc/qa/ProjectCrystal.pck" --log-file "$rc/acceptance/soak-recheck-restart.log" --script D:/RPGGAME/tests/prologue_rc2_restart_test.gd -- --reload
if ($LASTEXITCODE -ne 0) { throw 'Restart failed.' }
```

本輪結論：R1–R4可重現的程式／碰撞／導航／交付問題已修正。人工美術與實體控制器認可未恢復，已知造型問題和效能尖峰仍列明；**不是正式v0.6.1替換或G08最終發布通過**。
