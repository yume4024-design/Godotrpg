# 《失落星核》｜Project Crystal

原創 Windows Low Poly 3D JRPG。先完成 20～30 分鐘序章《灰石村的異變》，再逐章擴充到六篇章、約 12～16 小時與三種結局的完整企劃目標。

**Phase 1 已完成**：可啟動的 3D 練習場、雷恩幾何體佔位、WASD/方向鍵移動、固定 45 度跟隨鏡頭、碰撞與 HUD。劇情 JSON 已保存，NPC/故事載入器/戰鬥尚未實作。

操作：WASD 或方向鍵移動，R 返回起點，關閉視窗退出。鏡頭保持角度並隨角色平移。開啟 project.godot 後按 F5，或執行下面的 Run 指令即可遊玩。

## 閱讀順序

1. [開發規範](AGENTS.md)
2. [遊戲範圍](docs/GAME_DESIGN.md)
3. [架構與資料歸屬](docs/ARCHITECTURE.md)
4. [每次開發的執行流程](docs/WORKFLOW.md)
5. [階段任務與進度](docs/TASKS.md)
6. [驗收清單](docs/ACCEPTANCE.md)
7. [環境及驗證紀錄](docs/ENVIRONMENT.md)、[變更紀錄](docs/CHANGELOG.md)

故事工作先讀 [故事整合與階段安排](docs/STORY_IMPLEMENTATION.md)，再按需查閱 [Story Bible v1.0 原文](docs/STORY_BIBLE.md)。原文完整保留；實作差異與待補內容均記在整合文件，企劃中的參考圖片不視為已授權遊戲素材。

已加入的內容資料：[E001～E008](data/story/prologue_events.json)、[Q001](data/quests/q001.json)、[B001/B002](data/battles/prologue_battles.json)。它們需在 P2～P5 接上實際系統後才可遊玩。

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
.\tools\godot.ps1 -Mode Editor
.\tools\godot.ps1 -Mode Run
```

`Check` 等待資源匯入並檢查引擎輸出；`Smoke` 執行 120 次主迴圈後退出；`Test` 執行 24 項真實場景物理/輸入檢查。首次下載專案先執行 Check，產生 Godot 類別快取再執行 Test。日誌寫入 `artifacts/logs/`，工具將子程序的 Godot 設定/快取隔離在 `artifacts/godot-user` 與 `artifacts/godot-local`，不修改 Windows 全域設定。

本輪 [驗收報告](docs/PHASE1_REPORT.md) 包含渲染證據、測試方法與限制。可以使用並修改素材商店資產；本階段仍使用自製幾何體，見 [素材紀錄](docs/ASSET_CREDITS.md)。

引擎換位置時可傳入 `-GodotPath '完整執行檔路徑'`，或設定環境變數 `GODOT_PATH`。若系統執行政策禁止腳本，可用下列直接命令查版本，無需改動整台電腦的政策：

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --version
```

## 下一個開發任務

> 依照 AGENTS.md 與 docs/TASKS.md，執行 Phase 2：建立灰石村/低語森林往返、NPC 互動與對話 UI，再以 E001/E002 接上最小故事/旗標/接任務流程；保留 Phase 1 的移動與碰撞回歸，實作、驗收並更新紀錄。
