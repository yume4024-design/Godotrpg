# 本機環境與準備驗證

記錄日期：2026-10-12（Asia/Taipei）。

## 已確認

| 項目 | 實際結果 |
| --- | --- |
| 工作目錄 | D:\RPGGAME；開始時為空 |
| 使用者提供路徑 | D:\Godot_v4.7.2-stable_win64.exe，實際為資料夾 |
| GUI 執行檔 | D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe |
| Console 執行檔 | D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe |
| 引擎 --version | 4.7.2.stable.official.ed1daf0bf |
| Git --version | 2.55.0.windows.5 |
| 專案狀態 | Phase 1／2 已完成；E001/E002、探索／對話／任務接取可玩，詳見 PHASE2_REPORT.md |
| Git 倉庫 | 已初始化本地 main；無遠端/推送 |

## 流程準備時執行結果（歷史紀錄）

- 直接呼叫 Godot console 的 `--version`：成功。
- 查看本機 `--help`：確認 `--headless`、`--path`、`--import`、`--log-file`、`--quit-after` 參數存在；Check 使用 `--import` 等待匯入完成後退出。
- PowerShell Parser 解析 tools/godot.ps1：無語法錯誤。
- `tools/godot.ps1 -Mode Version`：成功回報相同引擎版本。
- `tools/godot.ps1 -Mode Check`：因缺少 project.godot 正確拒絕；這是前置條件測試，**不是遊戲載入通過**。
- 把 Godot 資料夾傳給 `-GodotPath`：正確拒絕非執行檔路徑。
- Markdown 相對檔案連結與必要文件/目錄：檢查無缺漏。

## 流程準備時尚未驗證（歷史紀錄）

遊戲專案匯入、Main 啟動、GDScript、玩家移動/碰撞、圖形畫面、手把、Blender/模型工具、Windows export templates 及匯出產物均未測試。工具 Check/Smoke 的實際 Godot 專案成功路徑，待 P1 建立專案後驗證。

本次不需要安裝引擎、外掛或下載素材。後續以本機實際引擎/API 為準，不依執行檔資料夾名稱推測版本。

## Phase 1 更新

目前已驗證載入、啟動、24 項物理/輸入檢查、圖形畫面與編輯器開啟，詳見 [PHASE1_REPORT](PHASE1_REPORT.md)。工具將 Godot 使用者設定/快取放在專案 artifacts 以避免 sandbox 對系統目錄的寫入限制；手把、模型工具、export templates、匯出及故事仍待後續驗證。

## 故事資料整合核對（2026-10-12）

- STORY_BIBLE.md 與使用者附件 SHA256 相同：`E2F015627440D8D4C8090C40774BAE6DCC4A543882D6FF6C5E99515295BD4692`。
- 以 PowerShell `ConvertFrom-Json` 解析三份資料；8 個事件、1 個任務/5 個目標、2 場戰鬥，ID 無重複。
- 條件/任務目標旗標均可在事件定義找到來源；Q001、B001、B002 內部引用及戰鬥勝利門檻核對通過。
- 事件/戰鬥 JSON 與來源內容一致；任務僅修正兩個已記錄的目標旗標。顯示獎勵與 E008 一致，兩戰加任務的預期金幣/EXP 增量為 212/300。
- 23 個本機 Markdown 連結有效；所有遊戲階段保持未開始，仍無 project.godot。
- 以上為靜態內容核對。尚不存在的角色/物品/敵人/演出/地圖引用未通過執行期驗證，未執行遊戲測試。
