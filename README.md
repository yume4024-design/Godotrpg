# 《失落星核》｜Project Crystal

原創 Windows Low Poly 3D JRPG。先完成 20～30 分鐘序章《灰石村的異變》，再逐章擴充到六篇章、約 12～16 小時與三種結局的完整企劃目標。

**Phase 2 已完成**：灰石村／低語森林可往返探索，支援 NPC 對話、打字跳過、E001/E002、接取 Q001，以及切圖後不重複領取的補給箱。Phase 1 練習場保留作為回歸場景。戰鬥從下一階段開始。

操作：WASD 或方向鍵移動，靠近後按 E 互動；對話中按 E／空白鍵／Enter 或點擊繼續按鈕，先顯示全文再進下一句；R 返回本區起點。鏡頭保持角度並隨角色平移，森林空地有局部縮放。開啟 project.godot 後按 F5，或執行下面的 Run 指令即可遊玩。

試玩路線：開場對話 → 公會長接受委託 → 莉雅的環境對話 → 補給箱 → 右側入口進森林 → 左側入口回村。莉雅入隊、礦坑與戰鬥尚未開放；當前進度僅在本次執行中保留，關閉後重置。

## 閱讀順序

1. [開發規範](AGENTS.md)
2. [遊戲範圍](docs/GAME_DESIGN.md)
3. [架構與資料歸屬](docs/ARCHITECTURE.md)
4. [每次開發的執行流程](docs/WORKFLOW.md)
5. [階段任務與進度](docs/TASKS.md)
6. [驗收清單](docs/ACCEPTANCE.md)
7. [環境及驗證紀錄](docs/ENVIRONMENT.md)、[變更紀錄](docs/CHANGELOG.md)

故事工作先讀 [故事整合與階段安排](docs/STORY_IMPLEMENTATION.md)，再按需查閱 [Story Bible v1.0 原文](docs/STORY_BIBLE.md)。原文完整保留；實作差異與待補內容均記在整合文件，企劃中的參考圖片不視為已授權遊戲素材。

內容資料：[E001～E008](data/story/prologue_events.json)、[Q001](data/quests/q001.json)、[B001/B002](data/battles/prologue_battles.json)。E001/E002 與 Q001 接取已接上遊戲；E003～E008 和戰鬥仍按 P3～P5 分階段實作。

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
.\tools\godot.ps1 -Mode Editor
.\tools\godot.ps1 -Mode Run
```

`Check` 等待資源匯入；`Smoke` 執行 120 次主迴圈；`Test` 執行 24 項 P1 物理/輸入回歸；`TestPhase2` 執行 58 項 P2 整合檢查；`VisualPhase2` 用實際渲染器走相同流程並保存八張畫面，共 66 項檢查。首次下載專案先執行 Check，產生類別快取。日誌寫入 `artifacts/logs/`，工具將子程序設定/快取隔離在 `artifacts/godot-user` 與 `artifacts/godot-local`；Run/Editor 使用同版本圖形執行檔啟動獨立視窗。

本輪 [P2 驗收報告](docs/PHASE2_REPORT.md) 包含渲染證據、測試方法與限制；[P1 報告](docs/PHASE1_REPORT.md) 保留歷史紀錄。可以使用並修改素材商店資產；目前使用自製幾何體，見 [素材紀錄](docs/ASSET_CREDITS.md)。

引擎換位置時可傳入 `-GodotPath '完整執行檔路徑'`，或設定環境變數 `GODOT_PATH`。若系統執行政策禁止腳本，可用下列直接命令查版本，無需改動整台電腦的政策：

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --version
```

## 下一個開發任務

> 下一階段為 Phase 3：角色／技能／敵人定義、指令式回合制戰鬥、勝敗與返回探索。依 TASKS.md 授權階段執行，並保留 P1／P2 回歸。
