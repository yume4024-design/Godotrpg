# 《失落星核》｜Project Crystal

原創 Windows Low Poly 3D JRPG。先完成 20～30 分鐘序章《灰石村的異變》，再逐章擴充到六篇章、約 12～16 小時與三種結局的完整企劃目標。

**Phase 5 已完成**：序章 E001～E008 可從新遊戲玩到回村交付，追加章末離村預告 E009。灰石村、低語森林與廢棄礦坑已連通；雷恩／莉雅雙人隊伍、回合戰鬥、成長、裝備、任務日誌與保存／讀取可用。

角色與場景保留圓潤可愛卡通風格。礦坑新增開頂回廊、礦軌、坑木、礦燈、星晶覺醒動畫，以及獨立的腐化守衛戰舞台。第一章目前只有解鎖旗標和預告，地圖尚未開放。

操作：WASD／方向鍵移動，E 互動；對話用 E／空白鍵／Enter 或繼續按鈕。M 開關旅途手冊，Esc 關閉；F5 保存、F9 讀取，亦可使用 M → 旅程頁按鈕。R 返回本區起點。戰鬥用滑鼠，或 Tab／方向鍵和 Enter 選指令與目標。

試玩路線：開場 → 公會長接 Q001 → 莉雅入隊 → M 裝備 → 森林補給與史萊姆戰 → 東侧入口進礦坑 → 進入內部取得藥品 → 調查星晶 → 覺醒與腐化守衛戰 → 經森林回村交付 → 離村／第一章預告。營地可恢復 HP／MP；主線與演練分開，演練不給故事獎勵。

兩場主線戰鬥與交付合計 212 金幣、每位隊員 300 EXP；每個來源只給一次，第一枚星印不重複。裝備影響數值，探索仍以隊長代表隊伍，雙人在戰鬥中登場。

**請在離開遊戲前手動保存。** 忙碌時的 F5 請求會等到安全點再寫入，F9 不會中斷戰鬥。已有存檔時開啟遊戲會先顯示續玩／新旅程選擇。單欄位保留上一份有效備份，格式錯誤不污染目前進度；詳見 [存檔格式與路徑](docs/SAVE_FORMAT.md)。工具入口與直接從編輯器啟動使用的 user:// 位置可能不同。

開啟 project.godot 按 F5，或使用下方 Run 指令即可遊玩。Windows 獨立匯出、手把、音效／特效、效能及 20～30 分鐘流程計時仍屬 P6，尚未驗收。

## 閱讀順序

1. [開發規範](AGENTS.md)
2. [遊戲範圍](docs/GAME_DESIGN.md)
3. [架構與資料歸屬](docs/ARCHITECTURE.md)
4. [每次開發的執行流程](docs/WORKFLOW.md)
5. [階段任務與進度](docs/TASKS.md)
6. [驗收清單](docs/ACCEPTANCE.md)
7. [環境及驗證紀錄](docs/ENVIRONMENT.md)、[變更紀錄](docs/CHANGELOG.md)

故事工作先讀 [故事整合與階段安排](docs/STORY_IMPLEMENTATION.md)，再按需查閱 [Story Bible v1.0 原文](docs/STORY_BIBLE.md)。原文完整保留；實作差異與待補內容均記在整合文件，企劃中的參考圖片不視為已授權遊戲素材。

內容資料：[E001～E008](data/story/prologue_events.json)、[Q001](data/quests/q001.json)、[B001/B002](data/battles/prologue_battles.json)。E004/B001 與 E007/B002 已接入正式主線；追加 E009 章末敘事不發獎勵。

## 本機工具

使用者提供的 `D:\Godot_v4.7.2-stable_win64.exe` 是資料夾。實際命令列執行檔是其下同名前綴的 `_console.exe`，已確認為 Godot 4.7.2。

在 PowerShell 執行：

```powershell
Set-Location D:\RPGGAME
.\tools\godot.ps1 -Mode Version
```

開發與遊玩指令：

```powershell
.\tools\godot.ps1 -Mode Check
.\tools\godot.ps1 -Mode Smoke
.\tools\godot.ps1 -Mode Test
.\tools\godot.ps1 -Mode TestPhase2
.\tools\godot.ps1 -Mode VisualPhase2
.\tools\godot.ps1 -Mode TestPhase3
.\tools\godot.ps1 -Mode VisualPhase3
.\tools\godot.ps1 -Mode TestPhase4
.\tools\godot.ps1 -Mode VisualPhase4
.\tools\godot.ps1 -Mode TestPhase5
.\tools\godot.ps1 -Mode TestPhase5Reload
.\tools\godot.ps1 -Mode VisualPhase5
.\tools\godot.ps1 -Mode PreviewBattle
.\tools\godot.ps1 -Mode PreviewArt
.\tools\godot.ps1 -Mode Editor
.\tools\godot.ps1 -Mode Run
```

`Check` 等待資源匯入；`Smoke` 執行 120 次主迴圈；`Test` 執行 24 項 P1 物理/輸入回歸；`TestPhase2` 執行 58 項 P2 整合檢查；`VisualPhase2` 用實際渲染器走相同流程並保存八張畫面，共 66 項檢查。首次下載專案先執行 Check，產生類別快取。日誌寫入 `artifacts/logs/`，工具將子程序設定/快取隔離在 `artifacts/godot-user` 與 `artifacts/godot-local`；Run/Editor 使用同版本圖形執行檔啟動獨立視窗。

`TestPhase3` 執行 75 項戰鬥整合檢查；`VisualPhase3` 用 Windows 渲染器操作同一流程並保存十張畫面，共 85 項。`PreviewBattle` 使用測試腳本走到第一場演練後停下供手動操作，含測試用快速抵達與補給；一般遊玩請用 `Run`。

`PreviewArt` 開啟五個卡通模型展示；`TestArt` 執行 17 項模型／材質／關節驗证，`VisualArt` 另保存正側背面與步行姿勢，共 21 項。[美術更新報告](docs/CARTOON_ART_REPORT.md) 包含來源、面數、重建方式與驗收限制。

歷史 [P4 驗收報告](docs/PHASE4_REPORT.md) 記錄 70 項功能／82 項圖形檢查、成長规则及限制。`TestPhase4`／`VisualPhase4` 執行主線入隊、選單實際按鈕、兩次敗北／重試及獲獎流程。

本輪 [P5 驗收報告](docs/PHASE5_REPORT.md) 記錄 69 項功能、77 項圖形模式及 7 項跨程序讀檔檢查。先執行 TestPhase5，再執行 TestPhase5Reload；測試只使用獨立的測試存檔。

歷史 [P3 驗收報告](docs/PHASE3_REPORT.md) 包含命令、畫面、修復與限制；[P2 報告](docs/PHASE2_REPORT.md)／[P1 報告](docs/PHASE1_REPORT.md) 保留歷史紀錄。可以使用並修改素材商店資產；目前使用自製 Blender 模型及 Godot 場景，見 [素材紀錄](docs/ASSET_CREDITS.md)。

引擎換位置時可傳入 `-GodotPath '完整執行檔路徑'`，或設定環境變數 `GODOT_PATH`。若系統執行政策禁止腳本，可用下列直接命令查版本，無需改動整台電腦的政策：

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --version
```

## 下一個開發任務

> 下一階段為 Phase 6：音效／特效、手把與效能驗收、Windows 匯出及完整序章節奏／時長驗證。按 TASKS.md 執行，保留 P1～P5 回歸。
