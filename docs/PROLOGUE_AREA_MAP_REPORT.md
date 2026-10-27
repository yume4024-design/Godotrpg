# 序章區域地圖與手冊修整 — 2026-10-27

## 範圍與結果

在 `feature/greystone-g06` 的序章候選來源加入可展開區域地圖，解決小地圖字小、無完整地標清單及選單焦點不穩定。基線提交 `9eaae6f960b3ab89b1fe6d0b439231ec14a032a8`。這是 RC2 之後的來源更新；既有 `builds/prologue-candidate/rc2-20261027` 固定包保持原樣，不能用它驗收本輪新增地圖。

- 點擊右上小地圖，或按 M／手把 Menu 後選「地圖」。沿用旅途手冊、InputMap、探索鎖與目前場景的導航資料。
- 灰石村、低語森林與礦坑顯示道路、角色位置／朝向、可見互動點與出口。右側編號清單可用鍵鼠／手把選取，圖上同步高亮；不提供快速傳送。
- 放大地圖維持世界比例。礦坑八區名稱較小地圖清楚；密集地標仍可能靠近，應以右側名稱及選取環確認。
- 選中分頁保留焦點，分頁使用可換行容器。地圖本體依手冊剩餘空間縮放，只有地標清單捲動。清單等待容器完成排版後才顯示焦點項目。
- 場景替換時重建地標清單，回呼使用弱參照，避免讀檔後操作已釋放的舊 NPC。
- 沒有改動角色 ID、數值、技能、事件、獎勵、存檔 Schema、地形或碰撞；正式 `main.tscn` 保留。共用手冊的焦點／排版改動另跑正式入口回歸。

## 重現及驗證

在 `D:/RPGGAME`，Godot `4.7.2.stable.official.ed1daf0bf`，Windows／RTX 3080／OpenGL Compatibility。工具隔離測試存檔至 `artifacts/godot-user`；`CRYSTAL_QA_ISOLATE_JOYPAD_MOTION=1` 隔離外部手把移動干擾。按鍵與控制器事件注入既有 InputMap／GUI，**不是實體 Xbox 驗收**。

```powershell
$env:CRYSTAL_QA_ISOLATE_JOYPAD_MOTION = '1'
.\tools\godot.ps1 -Mode TestPrologueAreaMap
.\tools\godot.ps1 -Mode VisualMineReferenceStory
.\tools\godot.ps1 -Mode TestMineReferenceStoryReload
.\tools\godot.ps1 -Mode TestPhase5
.\tools\godot.ps1 -Mode TestPhase5Reload
.\tools\godot.ps1 -Mode TestPrologueCommerce
.\tools\godot.ps1 -Mode TestPrologueCommerceReload
.\tools\godot.ps1 -Mode TestPrologueNavigation
Remove-Item Env:\CRYSTAL_QA_ISOLATE_JOYPAD_MOTION -ErrorAction SilentlyContinue
.\tools\godot.ps1 -Mode TestPhase6
```

| 檢查 | 結果 | 實際範圍 |
| --- | --- | --- |
| Check | PASS | 資源匯入與腳本解析 |
| 區域地圖圖形測試 | 77／0 | 滑鼠開圖、E001 對話鎖、持續移動輸入被鎖、Esc 返回、開圖後存讀檔、Menu/RB/A/B 焦點操作、三區地標、960×540／1280×720／1920×1080 視窗、地圖與圖例無裁切 |
| 圖形完整序章 | 93／0 | E001–E009、教學戰、Boss 失敗／重試／勝利、回村、單次獎勵、角色／NPC、HUD、保存 |
| 候選新程序讀取 | 24／0 | 同一受測來源存檔、角色／獎勵／故事與 UI 恢復 |
| 正式入口／重啟 | 69／0＋7／0 | 正式 v0.6.1 序章、無效檔拒絕與原功能 |
| 商店／旅館／重啟 | 50／0＋5／0 | 實際候選交易、扣款／物品／恢復、嚴格存檔驗證 |
| 三區導航 | 31／0 | 真實場景版本、森林九段路面、礦坑八區與舊村莊底圖隔離 |
| 既有 P6 輸入回歸 | 85／0 | 無頭注入 Menu／A／B／RB、戰鬥取消、音量焦點、類比移動／死區及鍵盤切換；非實體手把驗收 |

區域地圖最終執行命令為工具所指向的相同腳本：`Godot --path D:/RPGGAME --script res://tests/prologue_area_map_test.gd`。原生日誌 `artifacts/logs/area-map-after-4.log`；10 張畫面在 `artifacts/godot-user/Godot/app_userdata/失落星核 — Project Crystal/prologue_area_map/`。已檢視三區與縮小視窗的實際渲染畫面。視窗測試維持 1280×720 邏輯畫布並縮放，不等於手機介面驗收。

回歸日誌：`check-20261027-230550-086.log`、`testphase5-20261027-230619-140.log`、`visualminereferencestory-20261027-230619-140.log`、`testphase5reload-20261027-230725-820.log`、`testminereferencestoryreload-20261027-230727-657.log`、`testprologuecommerce-20261027-230738-997.log`、`testprologuecommercereload-20261027-230750-411.log`、`testprologuenavigation-20261027-230758-133.log`，均在 `artifacts/logs/`。

## 失敗與修正紀錄

1. 原始版本缺少展開地圖入口：基線測試 2 項中 1 項失敗。
2. 第一版測試錯用 device 16 注入手把，而 InputMap 使用 device 0；修正測試，沒有據此宣稱手把硬體失效。同時補場景替換後的清單更新及弱參照。
3. 第一版地圖底部被手冊捲動區裁切；只測視窗範圍不足，新增父容器裁切檢查並改為依可用空間配置。
4. 地標焦點可能早於容器排序，森林／村莊最後一項未捲入視野；延後 `ensure_control_visible`，最終完整包含所選按鈕，77／0。
5. 正式入口本體 69／0，外層臨時 PowerShell 命令誤以 `$LASTEXITCODE` 判斷已由 Process API 成功返回的腳本而中斷後續步驟；改用工具既有的例外／退出碼檢查後，獨立執行重啟 7／0。遊戲檢查沒有因此被跳過或改判。
6. P6 首跑85項中1項類比移動失敗，原因為該程序仍設定了「移除 InputMap 類比事件」的 QA 隔離環境變數；移除該變數、保留原測試及正式 InputMap 後85／0。日誌 `testphase6-20261027-231136-913.log`，無實體控制器連線。未用此測試冒稱硬體驗收。

## 修改檔案與使用

`scripts/ui/area_map_panel.gd` 與 `.uid`、`exploration_minimap.gd`、`exploration_interface.gd`、`party_menu.gd`；`scripts/core/greystone_integration.gd`；`tests/prologue_area_map_test.gd` 與 `.uid`；`tools/godot.ps1`；README、TASKS、GREYSTONE_BUILD_TASKS、CHANGELOG 與本報告。

查看最新來源：`./tools/godot.ps1 -Mode RunPrologueCandidate`。本輪沒有重製 RC2、沒有另做30分鐘長測；RC2既有長測只能代表其固定來源。人工美術／實體輸入驗收、Android／iOS、第一章仍暫停。新版莉雅綁骨與既有美術缺陷仍是後續項目；本輪不以導航改善宣稱全部序章美術完工。
