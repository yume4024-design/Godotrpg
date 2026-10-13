# 《失落星核》｜Project Crystal

原創 Windows Low Poly 3D JRPG。先完成 20～30 分鐘序章《灰石村的異變》，再逐章擴充到六篇章、約 12～16 小時與三種結局的完整企劃目標。

**Phase 4 已完成**：E001→E004 主線可玩，與莉雅交談後正式組成雙人隊伍，進入森林觸發第一場主線戰鬥。新增金幣、EXP／升級、裝備與旅途手冊（狀態／背包／技能／裝備）。

**角色與場景已更新為圓潤可愛的卡通風格**：五個原創角色／敵人模型具備五官、服裝、裝備與待機／步行擺動；村莊、森林及戰鬥舞台加入圓冠樹、瓦屋、覆苔岩石、花草、圓角道路、寶箱和營火。美術沿用使用者指定的圓潤可愛卡通風格。

操作：WASD 或方向鍵移動，靠近後按 E 互動；對話中按 E／空白鍵／Enter 或點擊繼續按鈕，先顯示全文再進下一句；M 開關旅途手冊，Esc 關閉手冊；R 返回本區起點。鏡頭保持角度並隨角色平移，森林空地有局部縮放。開啟 project.godot 後按 F5，或執行下面的 Run 指令即可遊玩。

試玩路線：開場對話 → 公會長接受委託 → 與莉雅交談入隊 → M 開手冊，替雷恩／莉雅換裝 → 右側入口進森林 → 開演練補給箱取得恢復藥 ×3 → 沿路前進觸發主線戰鬥 → 勝利獲得 12 金幣、每人 20 EXP 並升到 Lv2 → 返回探索。營地可恢復 HP／MP；「挑戰·腐化守衛」較難，建議先休息並保留藥品。戰鬥使用滑鼠，或 Tab／方向鍵與 Enter 選擇；取消目標不消耗回合。

主線遭遇獎勵只發一次；演練仍不推進故事、不發金幣或經驗。勝利保留消耗，升級增加存活角色的 HP／MP 差額；敗北重試／撤退回復進戰前狀態。撤退後離開觸發區再走回即可重試。新遊戲提供青銅短劍、柳木法杖、旅人皮衣各一件；裝備從背包取出，卸下歸還。探索顯示隊長，雙人在戰鬥中登場。礦坑、完整任務交付與存檔留 P5；目前關閉遊戲會重置進度。

## 閱讀順序

1. [開發規範](AGENTS.md)
2. [遊戲範圍](docs/GAME_DESIGN.md)
3. [架構與資料歸屬](docs/ARCHITECTURE.md)
4. [每次開發的執行流程](docs/WORKFLOW.md)
5. [階段任務與進度](docs/TASKS.md)
6. [驗收清單](docs/ACCEPTANCE.md)
7. [環境及驗證紀錄](docs/ENVIRONMENT.md)、[變更紀錄](docs/CHANGELOG.md)

故事工作先讀 [故事整合與階段安排](docs/STORY_IMPLEMENTATION.md)，再按需查閱 [Story Bible v1.0 原文](docs/STORY_BIBLE.md)。原文完整保留；實作差異與待補內容均記在整合文件，企劃中的參考圖片不視為已授權遊戲素材。

內容資料：[E001～E008](data/story/prologue_events.json)、[Q001](data/quests/q001.json)、[B001/B002](data/battles/prologue_battles.json)。E004/B001 已接入正式主線；E007/B002 的勝利等待橋接保留獨立測試，礦坑主線於 P5 整合。

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
.\tools\godot.ps1 -Mode PreviewBattle
.\tools\godot.ps1 -Mode PreviewArt
.\tools\godot.ps1 -Mode Editor
.\tools\godot.ps1 -Mode Run
```

`Check` 等待資源匯入；`Smoke` 執行 120 次主迴圈；`Test` 執行 24 項 P1 物理/輸入回歸；`TestPhase2` 執行 58 項 P2 整合檢查；`VisualPhase2` 用實際渲染器走相同流程並保存八張畫面，共 66 項檢查。首次下載專案先執行 Check，產生類別快取。日誌寫入 `artifacts/logs/`，工具將子程序設定/快取隔離在 `artifacts/godot-user` 與 `artifacts/godot-local`；Run/Editor 使用同版本圖形執行檔啟動獨立視窗。

`TestPhase3` 執行 75 項戰鬥整合檢查；`VisualPhase3` 用 Windows 渲染器操作同一流程並保存十張畫面，共 85 項。`PreviewBattle` 使用測試腳本走到第一場演練後停下供手動操作，含測試用快速抵達與補給；一般遊玩請用 `Run`。

`PreviewArt` 開啟五個卡通模型展示；`TestArt` 執行 17 項模型／材質／關節驗证，`VisualArt` 另保存正側背面與步行姿勢，共 21 項。[美術更新報告](docs/CARTOON_ART_REPORT.md) 包含來源、面數、重建方式與驗收限制。

本輪 [P4 驗收報告](docs/PHASE4_REPORT.md) 記錄 70 項功能／82 項圖形檢查、成長规则及限制。`TestPhase4`／`VisualPhase4` 執行主線入隊、選單實際按鈕、兩次敗北／重試及獲獎流程。

歷史 [P3 驗收報告](docs/PHASE3_REPORT.md) 包含命令、畫面、修復與限制；[P2 報告](docs/PHASE2_REPORT.md)／[P1 報告](docs/PHASE1_REPORT.md) 保留歷史紀錄。可以使用並修改素材商店資產；目前使用自製 Blender 模型及 Godot 場景，見 [素材紀錄](docs/ASSET_CREDITS.md)。

引擎換位置時可傳入 `-GodotPath '完整執行檔路徑'`，或設定環境變數 `GODOT_PATH`。若系統執行政策禁止腳本，可用下列直接命令查版本，無需改動整台電腦的政策：

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --version
```

## 下一個開發任務

> 下一階段為 Phase 5：完整任務日誌、廢棄礦坑、E005～E008、晶體演出、任務交付及版本化存檔。依 TASKS.md 授權階段執行，保留 P1～P4 回歸。
