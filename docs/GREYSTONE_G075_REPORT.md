# G07.5 — Windows PC 穩定性驗收

日期：2026-10-18（Asia/Taipei）。分支：`feature/greystone-g06`；測試起點 `42a04329407c0fe5871547d32956f4eef4c1edea`。Windows 圖形長測已完成；後續回歸結果見下表。

## 範圍與方法

Godot `4.7.2.stable.official.ed1daf0bf`，Windows／RTX 3080 12GiB／Compatibility、1280×720、高畫質、VSync 關閉、測試程序限 60 FPS。透過 `tools/godot.ps1 -Mode TestWindowsStability` 啟動真正圖形程序，先跑既有 G06 完整序章，再開始至少 1,800 秒連續 soak。不是人工全程遊玩、發布包、低階 PC 或手機測試。

測試沿用 SceneManager、InputMap、碰撞、Dialogue／BattleFlow／Inventory／SaveCodec：每輪切換灰石村→低語森林→廢棄礦坑，各以 20 秒左右往返移動、停止、存檔與讀檔；區段間 reset_to 定位，不能當成無瞬移走遍全地圖。村莊公會對話／商人購藥／旅館扣款及全隊恢復後，讀回交易前的有效測試存檔。森林與礦坑透過既有 BattleFlow 啟動 X001／X003 可選遭遇，以真實戰鬥命令結束並返回；這是可選遭遇配置測試，沒有假稱遊戲具備隨機抽選遭遇。主線 B001／B002、Boss 敗北／重試與 E001～E009 在開頭序章執行一次。

使用 `user://g075/soak.json` 獨立測試欄位，不接觸玩家正式存檔。未改角色 ID、數值、技能、旗標規則、任務獎勵或 Schema；各輪確認唯一星印及 E008 收據。GLB、正式 `scenes/main/main.tscn` 與 v0.6.1 輸出保持原檔。

逐幀時間使用單調時鐘的 process_frame 間隔，包含 60 FPS 限速等待、同步 I/O、測試截圖與報表成本，不是 GPU 時間或無限制渲染能力。Draw Calls 是整幀含 UI／陰影的引擎計數。PowerShell 每秒記錄實際圖形 Godot PID 的 WorkingSet64／PrivateMemorySize64／PeakWorkingSet64；引擎 MEMORY_STATIC 為另一個不同口徑。記憶體包含測試樣本、暖機及配置器保留，不能單憑峰值或短期變化證明洩漏。

場景切換時間自 travel 接受至淡出／實例化／淡入完成，包含約 0.32 秒的設計過場；幀時間尖峰另列。phase 標籤以回呼抽樣當下區分；存讀檔成本位於目前探索／戰鬥段，不能僅憑標籤判定尖峰根因。

## 測試結果

圖形程序 PID 32120；正式日誌為 `testwindowsstability-20261018-084836-558.log`（08:48:36 啟動，約 08:48:59 開始 soak）。Soak **1815.966 秒（30 分 15.966 秒）**，含序章 **1838.368 秒（30 分 38.368 秒）**。27 輪、81 次切圖、54 場可選戰鬥、27 次商店購買及 27 次旅館恢復；開頭另有主線戰鬥、Boss 敗北／重試。程序 exit 0，**1086 項斷言、0 失敗**，日誌沒有 SCRIPT ERROR／ERROR／Parse Error／資源載入失敗。JSON 的 1085 是最後「滿 1800 秒」斷言前的計數，最終以日誌 1086 為準。

| 區段 | 取樣幀 | FPS | 平均 ms | P95 ms | P99 ms | 最大 ms | Draw Calls | 引擎配置峰值 MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| battle | 3873 | 58.55 | 17.078 | 16.847 | 42.953 | 141.549 | 127–364 | 405.05 |
| forest | 33735 | 60.00 | 16.667 | 16.775 | 16.978 | 30.098 | 364–447 | 320.16 |
| greystone_runtime | 33808 | 59.99 | 16.668 | 16.760 | 17.008 | 80.651 | 94–178 | 322.05 |
| mine | 33874 | 60.00 | 16.667 | 16.756 | 16.924 | 52.555 | 176–206 | 319.42 |
| npc_commerce | 1933 | 59.52 | 16.802 | 17.301 | 28.636 | 80.947 | 94–342 | 322.05 |
| prologue | 1268 | 56.61 | 17.665 | 17.046 | 57.501 | 664.406 | 0–625 | 406.04 |
| transition | 1620 | 60.00 | 16.667 | 16.770 | 16.990 | 24.091 | 94–458 | 319.05 |

81 次 travel 完成時間：平均 **329.343 ms**、P95 **332.358 ms**、P99／最大 **332.545 ms**、最小 **326.452 ms**。這含淡入淡出且使用常駐 PackedScene／系統快取；不是磁碟冷啟動載入。transition 段最慢幀 **24.091 ms**。

程序工作集取樣最大 **712.484 MiB**；Windows 累積 PeakWorkingSet 最大 **712.812 MiB**。Private Bytes 最大 **888.621 MiB**。排除最初 60 秒及最後 5 秒後，前／後各 60 筆平均：工作集 **630.679／472.564 MiB**、Private Bytes **806.166／793.566 MiB**。工作集下降可能受 Windows 裁剪影響，不解讀成遊戲主動釋放了同等資源。

各地圖 27 個穩態檢查點：村莊 1120 nodes／4273 objects，森林 829／4003，礦坑 467／3705，均固定，orphans 全為 0。引擎配置首→末：村莊 **317.909→319.071 MiB**、森林 **317.003→318.114 MiB**、礦坑 **316.542→317.633 MiB**，約 +1.1 MiB，包含持續增長的測試幀樣本與檢查點；本輪無失控累積證據，但不是所有路線／數小時洩漏保證。

效能判讀：60 FPS 限速下探索平均達標，但存在尖峰，**不宣稱每幀均在 16.667 ms 內**。最慢 664.406 ms 發生在初始化／序章；後續 battle 區段最慢 141.549 ms，包含進戰及同步讀檔。讀檔會建立獨立物理世界驗證位置再套入狀態，屬需深入量測的候選；此輪沒有分離 CPU／GPU 計時、磁碟 I/O 或著色器編譯，不能確證根因。未以降低存檔驗證強度、修改遊戲數值或任意裁切場景掩蓋尖峰。

## 角色與畫面

唯讀 GLB 審核：雷恩 4,815／莉雅 4,806 三角形；莉雅持杖共 4,946。兩者各 19 joints 與 attack／cast／guard／hit／potion／run／walk 七片段，UV／材質及權重索引通過。原模型 SHA256：雷恩 `6BB14AE0C547D4B187CF6F87548F601856580E6412770623B7A42E40543921F6`；莉雅 `D2EBAB02BE6B38B6D539F8A77D50D82BAAEBCF4E64153AC0C36B94E9FDFC96A4`。

已查看本輪 `g063-04-guardian-battle.webp`、`g075-greystone_runtime-1.webp`、`g075-mine-1.webp`：角色與介面有渲染；礦坑橫梁會遮擋角色頭／上身，保留為已知視覺問題。畫面證據是選定時刻，不代表每幀均由人工檢查。

## 限制及後續門檻

Android／iOS、第一章、新角色生成、G08 本輪不執行。既有 12cm 實體台階限制、近景貼圖／極端姿勢及專用劍招缺口仍保留，沒有啟用新模型未驗證 IK。正式 v0.6.1 未覆蓋。

首輪診斷發現 console 包裝程序記憶體約 7 MiB，並非遊戲。已停止該輪，只將重新啟動的圖形程序數據納入正式結果；副本在 `artifacts/performance/g075-diagnostic/`，不能與正式 30 分鐘資料混算。

原始資料與截圖保存在被 Git 忽略的本機 artifacts，不宣稱已隨 Git 上傳：`artifacts/performance/g075.json`、`g075-process.csv`、`artifacts/phase5/g075-*.webp`，命令日誌於 `artifacts/logs/`。正式結論／摘要在本報告保存。
## 回歸與重跑方式

```powershell
./tools/godot.ps1 -Mode TestWindowsStability
./tools/test_g06.ps1
./tools/godot.ps1 -Mode TestPixalCharacters
./tools/godot.ps1 -Mode TestCharacterPreview
./tools/godot.ps1 -Mode TestPixalAttachments
./tools/godot.ps1 -Mode VisualFemaleAnimation
```

G06 整套 exit 0，16 模式、576 項斷言、0 失敗；完整本機清單 `artifacts/regression/g06-20261018-091926.json`。

| 模式 | 結果 | artifacts/logs 日誌 |
| --- | --- | --- |
| Check | exit 0 | `check-20261018-091927-061.log` |
| TestEnemyAI | ENEMY_AI_RESULT checks=10 failures=0 targets=[&"lia", &"ren", &"lia", &"ren"] | `testenemyai-20261018-091931-812.log` |
| TestPhase3 | PHASE3_RESULT checks=75 failures=0 renderer=headless | `testphase3-20261018-091932-441.log` |
| Smoke | exit 0 | `smoke-20261018-091939-989.log` |
| TestPhase5 | PHASE5_RESULT checks=69 failures=0 renderer=headless | `testphase5-20261018-091941-528.log` |
| TestPhase5Reload | PHASE5_RESULT checks=7 failures=0 renderer=headless | `testphase5reload-20261018-091957-953.log` |
| TestPhase6 | PHASE6_RESULT checks=85 failures=0 renderer=headless | `testphase6-20261018-091959-591.log` |
| TestG06 | G06_1_RESULT checks=51 failures=0 | `testg06-20261018-092018-747.log` |
| TestG06Reload | G06_1_RESULT checks=6 failures=0 | `testg06reload-20261018-092023-885.log` |
| TestG06NPC | G06_NPC_RESULT checks=60 failures=0 | `testg06npc-20261018-092026-163.log` |
| TestG06Story | G06_STORY_RESULT checks=58 failures=0 | `testg06story-20261018-092110-002.log` |
| TestG06StoryReload | G06_STORY_RESULT checks=7 failures=0 | `testg06storyreload-20261018-092128-369.log` |
| VisualG06Story | G06_STORY_RESULT checks=68 failures=0 | `visualg06story-20261018-092130-656.log` |
| VisualG06Touch | G06_TOUCH_RESULT checks=22 failures=0 | `visualg06touch-20261018-092154-533.log` |
| VisualG06TouchCommerce | G06_TOUCH_COMMERCE_RESULT checks=53 failures=0 | `visualg06touchcommerce-20261018-092201-857.log` |
| TestG06CommerceReload | G06_COMMERCE_RESULT checks=5 failures=0 | `testg06commercereload-20261018-092209-911.log` |

角色額外圖形回歸：

- TestPixalCharacters：PIXAL_CHARACTER_RESULT checks=88 failures=0；日誌 `testpixalcharacters-20261018-092226-496.log`。
- TestCharacterPreview：CHARACTER_PREVIEW_RESULT checks=12 failures=0；日誌 `testcharacterpreview-20261018-092239-678.log`。
- VisualFemaleAnimation：FEMALE_ANIMATION_RESULT checks=38 failures=0；日誌 `visualfemaleanimation-20261018-092507-670.log`。

另以 `TestPixalAttachments` 重用同一動作測試，改用新版莉雅：38 項／0 失敗（`testpixalattachments-20261018-092440-737.log`），實測 HandRight 掛點、移動杖端／掌心特效跟隨、藥品單次消耗與來源釋放。四項共 176 斷言／0 失敗；其中 VisualFemaleAnimation 的 38 項為舊模型相容回歸，不冒充新版角色測試。新版兩人七片段存在、walk/run/動作切換與恢復、骨架有限值、法杖裝卸、死亡／復活由 TestPixalCharacters 88 項驗證。已查看本輪雷恩跑步／使用道具、莉雅跑步／持杖施法圖：抽樣未見大幅拉成分離碎片或骨架崩解；袖口接縫及局部近景瑕疵仍保留，法杖仍接於手側；不是所有姿勢逐幀無穿插保證。

核心驗收合計（重跑不重複累加）：長測 1086＋G06 576＋角色 176＝1838 項斷言，0 失敗；Check 載入與唯讀 GLB 審核另通過。兩角色 GLB 與正式 main.tscn 結束雜湊和測試前一致。

## 交付與 G08 判斷

新增 `tests/windows_stability_test.gd`／`.uid`、本報告；修改 `tests/female_battle_animation_test.gd`（新增 --pixal 測試選項）、`tools/godot.ps1`、`docs/TASKS.md`、`docs/GREYSTONE_BUILD_TASKS.md`、`docs/GREYSTONE_G07_REPORT.md`、`docs/CHANGELOG.md`。原有 Skill 文件變更與根目錄參考圖片保留，Skill 鏡像不納入本次 G07.5 提交。

本輪修正的是量測對象及測試時限，沒有生產功能修正。30 分鐘穩定性／狀態回歸通過；**可開始 G08 Windows 候選功能驗收**，本輪尚未開始。未解決：同步操作尖峰根因、礦坑橫梁遮擋、既有台階／近景美術及專用劍招限制；隨機抽選遭遇系統不存在，沒有對不存在的功能宣稱通過。低階 PC、正式候選匯出包與人工完整遊玩仍待驗收，**不得據此直接宣稱發佈合格或整體 G07／G08 已完成**。Android／iOS 繼續暫停，不合併 main。

最後載入檢查：Check exit 0，`artifacts/logs/check-20261018-092503-551.log`；共享測試加入 --pixal 後，舊模型預設模式重跑仍 38/0。
