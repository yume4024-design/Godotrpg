# 序章整合修正與 Windows RC2 — 2026-10-27

## 範圍與狀態

修正重新審核 R1–R3：目前序章候選同時載入 reference_v5 灰石村、layout 4、對應鏡頭、新雷恩、既有可玩莉雅、擴充森林及新版礦坑。礦坑防墜反例已修補，小地圖資料來源與方向已修正。R4 包內驗收與提交後續紀錄在本報告末尾。

正式 main.tscn／v0.6.1、戰鬥數值、角色 ID、旗標、任務獎勵和存檔 Schema 未修改。人工驗證依使用者要求繼續暫停；未將本輪自動測試宣稱為實體鍵鼠／Xbox、30 分鐘長測或最終美術通過。Android／iOS、第一章未開始。

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
