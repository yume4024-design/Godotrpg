# G06.1 新舊地圖接軌與存檔遷移

2026-10-14；分支 `feature/greystone-g06`。本輪僅 G06.1，G06.2～G06.6 尚未開始。正式 main.tscn、village.tscn、project.godot 啟動入口與 v0.6.1 存檔欄位均保留。

## 架構與進入方式

`scenes/main/greystone_integration.tscn` 繼承正式 Main，重用同一 Player、Camera、Interface、SceneManager、DialogueManager、StoryManager、QuestManager、Party/Inventory/RewardManager。沒有新增第二套劇情服務。

`scenes/world/greystone_runtime.tscn` 是 ExplorationMap 轉接場景，實例化現有 greystone_village.tscn；場景 ID 為 greystone_runtime，安全出生點 (0,0.1,48)，鏡頭 size 28。

```powershell
./tools/godot.ps1 -Mode RunG06
```

完成開場對話後，左側「G06.1 新舊村莊往返」可在新舊村莊安全點切換。對話/戰鬥/轉場/選單等忙碌時不可切換，森林與礦坑也不提供跨圖捷徑。「匯入 v0.6.1 存檔」讀取同一啟動環境的舊欄位，保留原檔。

新版目前只有地圖接軌，NPC/主線觸發仍在舊地圖；可返回舊村繼續原有序章。沒有宣稱新版 NPC、商店或旅館已完成。新版礦口沒有切換事件，不能繞過森林戰鬥。

## 存檔契約

- 正式啟動模式：schema 1 / CH00-P5，讀寫 `user://crystal_slot_01.json`，拒絕 schema 2。
- G06 啟動模式：保存 schema 2 / CH00-G06.1 至 `user://crystal_g06_slot_01.json`，可讀 v1/v2。
- v2 location.layout_version：village/forest/mine 固定 1，greystone_runtime 固定 2；缺失、未知或地圖不匹配的版本拒絕。
- v1 先通過原有完整資料契約及原圖物理驗證。只有合法 village 座標映射到新村入口；forest/mine 保留原座標與地圖。遷移只複製並變更 schema/content/location，保留其餘狀態。
- 遷移後再執行完整 v2 驗證及新圖獨立 World3D 的膠囊/地板查詢；任何一步失敗都不套用角色或進度、不改來源檔案。
- 新圖數值界限 X/Z ±60、Y -0.1～6.2 只做初步限制，河流、井、牆、懸空仍須物理驗證；舊圖界限完全保留，沒有直接放寬舊座標驗證。
- 舊存檔匯入只讀取，不自動寫回；玩家明確保存才寫新欄位。經濟契約未改，購物/住宿須後續另定義帳本及版本。

## 測試方式

先以正式 P5 測試完成真實序章、戰鬥、裝備及獎勵，產生 `user://p5_tests/restart.json`。G06 測試只複製到 `user://g06_tests/legacy.json`，新檔為 `user://g06_tests/restart.json`；不讀寫正式玩家欄位。

```powershell
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode TestPhase5
./tools/godot.ps1 -Mode TestPhase5Reload
./tools/godot.ps1 -Mode VisualG06
./tools/godot.ps1 -Mode TestG06Reload
```

涵蓋舊村→新村、舊森林/礦坑位置保留、旗標/收據/角色/EXP/裝備/背包/任務/故事完整比對、舊檔位元組不變、非法舊位置/舊障礙物/新河流/新井/未知版本/金幣不符拒絕、失敗後全狀態不變、新舊村往返、實際滑鼠點入口、現有玩家移動、選單、重複獎勵拒絕、新檔保存與跨程序重啟。

最初測試直接比較執行期 StringName 字典與 JSON String 字典導致錯誤斷言，已改為同一 capture_state 序列化契約比對，並把磁碟原文與狀態檢查拆開；未放寬遊戲驗證。

## 範圍與後續

G06.2 六類 NPC/對話；G06.3 E001/2/3/8/9 與森林/礦坑往返及單次事件；G06.4 商店與旅館價格/交易帳本；G06.5 MobileInputLayer；G06.6 整合回歸。每項另有可執行結果才標完成。Android 真機、G07/G08、第一章均未開始。


## 實際結果

Godot 4.7.2.stable.official.ed1daf0bf；圖形使用 Windows / OpenGL Compatibility / RTX 3080。

| 檢查 | 結果 | artifacts/logs 證據 |
| --- | --- | --- |
| Check | 載入成功 | check-20261014-203201-268.log |
| TestPhase5 | 69 項/0失敗 | testphase5-20261014-203058-306.log |
| TestPhase5Reload | 7 項/0失敗 | testphase5reload-20261014-203114-736.log |
| VisualG06 | 51 項/0失敗 | visualg06-20261014-203429-418.log |
| TestG06Reload | 6 項/0失敗 | testg06reload-20261014-203435-209.log |

實際畫面：artifacts/phase5/g06-integration.webp；已檢視 HUD、入口按鈕及玩家位置。按鈕位於既有 HUD 下方，圖形測試使用滑鼠事件點擊，不只呼叫方法。畫面可讀性/操作入口各 2/2；場景美術仍沿用 G04/G05 的已知限制。
