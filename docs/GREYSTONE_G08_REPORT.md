# G08 Windows 候選驗收 — 第一輪

日期：2026-10-18（Asia/Taipei）；分支 `feature/greystone-g06`，起點 `b9218700fc721df348d07b7072b5adf52231f93f`。**G08.1 候選匯出與自動化功能驗收通過；G08 整體未完成，不是發佈核准。**

## 候選包與測試環境

Windows／RTX 3080／Godot `4.7.2.stable.official.ed1daf0bf` release template、Compatibility。候選與 QA 使用獨立自訂 feature，實測候選版本 `0.6.1-g08-rc1`，base version 仍 `0.6.1`；正式主入口 `scenes/main/main.tscn` 不變。

- 可玩包：`builds/g08/candidate/20261018-093908/ProjectCrystal.exe`，PCK 同目錄。
- 最終 QA：`builds/g08/qa/20261018-095052/ProjectCrystal.exe`。
- 最終本機證據：`artifacts/g08/20261018-095058/manifest.json`，含三個程序退出碼、耗時、日誌與舊測試檔 SHA256。
- 可玩 PCK SHA256：`571C1DAE5E30FECBD108BCAC596A45C1D6173B8128160F6F71EC73B1B1B5C18F`。
- QA PCK SHA256：`1FF618F2966B9062C04920A4E126D04D8B23E4970F7D743DE0C3BEBCCB3B5677`。
- 兩包 exe 為未內嵌 PCK 的相同 release template：`D34D36F3BE1A6C49C56525AE86469B92E4F417DDF0B43CF00DD80C385C4B0562`。

正式 `builds/windows/ProjectCrystal.exe`／PCK 前後雜湊分別維持 `D34D36F3BE1A6C49C56525AE86469B92E4F417DDF0B43CF00DD80C385C4B0562`／`A8C95F156C55A0CF15CB6B71E617C435868EB6822D0C08A014FBDEFBB42002B7`，未覆蓋正式輸出。新匯出均放日期子目錄。

## 實際驗收

| 項目 | 實際結果與範圍 |
| --- | --- |
| Release 匯出／獨立啟動 | 可玩 exe 啟動並正常退出，QA 亦為 release，均 exit 0；不以編輯器執行冒充匯出測試 |
| 包內序章／戰鬥／交易／遷移 | **100／0**；E001～E009、森林教學前置、Boss 敗北重試及勝利、回村交付、莉雅只加入一次、單次星印／金幣／EXP、商店扣款、住宿全隊恢復 |
| 包內獨立重啟 | **14／0**；另一個 exe 程序重新讀取角色／裝備／212 金幣／星印／獎勵帳本，確認有效版本覆寫與 WASD 綁定 |
| 舊檔遷移 | 使用 `TestPhase5` 產生的 schema 1／CH00-P5 測試檔，複製到獨立 QA profile；沿用 SaveManager 遷移到 schema 3／新版村莊安全點，原檔位元組、party／flags／quests／rewards／金錢及物品數量不變，再還原新槽位 |
| 動線／碰撞 | `VisualGreystone` **98／0**；主路、高地、橋、碼頭、建物前庭、水井與牆體碰撞；為專案圖形場景測試，非包內所有道路逐點檢查 |
| 環境素材 | `VisualGreystoneProps` **43／0**；素材、共用資源、橋／碼頭畫面 |
| 六類 NPC | `TestG06NPC` **60／0**；距離、對話、碰撞及路線；非巡邏功能驗收 |
| 模型 | 包內戰鬥偵測雷恩／莉雅 19 joints，新版 GLB 及材料成功載入；模型本輪不修改，4,815／4,806 面沿用 G07.5 審核 |
| PCK 內容與一致性 | 可玩包 628／QA 737 檔案；**616 個共用遊戲資源雜湊全部一致**，含匯入／編譯資源；排除 project.binary、UID／全域 class cache 等不同包裝設定，不宣稱兩個 PCK 相同 |
| 素材／機密／開發資料 | 可玩包沒有 tests、tools、docs、scripts/tools、assets/source、source_assets、artifacts、builds、blend 或根目錄參考圖；14 個根目錄來源檔名由產生器排除。附引擎與素材授權；未加入憑證 |

本輪核心斷言為 **114＋98＋43＋60＝315 項、0 失敗**；PCK 檔案比對另計，不把比對檔案數加成遊戲功能斷言。日誌：`visualgreystone-20261018-094724-936.log`、`visualgreystoneprops-20261018-094707-535.log`、`testg06npc-20261018-095014-233.log`。包內程序日誌在上述最終 evidence 目錄。

已查看包內 Boss 戰及交易／住宿後的村莊畫面，角色、HP／MP、金錢與道具顯示正常；另保留最終 evidence 下的 WebP。沒有新增角色、劇情、經濟規則、存檔 Schema 或新章節。

## 失敗輪次及修正

1. 第一輪新工具的模式條件誤將匯出模式也帶入野外重啟測試分支，匯出時多載入測試樹並留下 RID。比較既有匯出模式後確認啟動參數差異，修正條件並重匯出；錯誤檢查維持嚴格，沒有白名單忽略 RID 錯誤。失敗輸出保留於 `artifacts/g08-*-export-diagnostic.txt`，不用作交付。
2. 初版 QA 有返回位置／教學戰等待及後續出口的非穩定失敗。診斷捕捉到預期放開輸入後仍有 `(3.18198,0,3.18198)` 速度。QA 改為明確持有／釋放移動 InputMap action、檢查 WASD 綁定、只在 QA 程序提供焦點通知；同時以 60 FPS 測試節奏及五秒牆鐘取代 200 個 render frames 的等待。這是測試驅動隔離修正，**不宣稱修復生產輸入或證明實體鍵盤／手把完全無問題**。
3. 修正驅動後三個乾淨 profile 連續 **90＋13／0**，證據 `094651`、`094734`、`094808`；之後只增加版本／舊檔檢查，最終 **100＋14／0**。先前失敗 `093902`、`094307`、`094515` 均保留，不混入成功統計。
4. PCK 盤點在空白專案中執行，排除稽核腳本／設定本身；Godot remap 的模型使用 ResourceLoader.exists 確認。稽核輸出位於工作目錄外，避免將先前 JSON／日誌算成 PCK 檔案。

## 可重現命令

```powershell
# 使用現有可執行 Python 3；產生兩個 G08 preset，重複產生已確認相同。
python tools/prepare_windows_candidate.py
./tools/test_windows_candidate.ps1
python tools/audit_windows_candidate.py <新產生的 manifest.json 路徑>
./tools/godot.ps1 -Mode VisualGreystone
./tools/godot.ps1 -Mode VisualGreystoneProps
./tools/godot.ps1 -Mode TestG06NPC
```

本機使用 Comfy 環境的 Python 執行兩個純標準庫工具，不要求安裝套件。QA 使用獨立 APPDATA／LOCALAPPDATA，存檔與截圖只寫 user://，沒有接觸玩家正式存檔。`-CandidateExe`／`-QaExe` 可指定已匯出的精確檔案重跑。包內 QA 是自動化圖形測試，不是人工通關；60 FPS 限速只在 QA，候選遊戲行為不改。

## G08 尚未通過的項目

- 礦坑橫梁／其他遮擋、既有 12cm 實體台階限制、角色近景瑕疵及專用劍招；本輪僅驗收，未更改這些生產功能。
- G07.5 的初始化 664ms、後續戰鬥／讀檔約 142ms 尖峰仍待深入定位。該 30 分鐘資料來自上一輪圖形專案測試，**本次 release 候選沒有另跑 30 分鐘長測**。
- 候選仍保留 G06 開發工具列、NPC 巡邏未驗收；野外是固定可選遭遇，沒有隨機抽選系統。武器店買賣不是既有已完成交易功能。
- 人工完整通關、實體鍵盤／手把、低階 PC、未簽章執行檔在其他 Windows 安裝環境的行為與發佈包長測仍待驗收。
- 觸控本輪不重跑手機驗收；Android／iOS 持續暫停，第一章不開發。

下一個最小階段為 **G08.2：遮擋／台階問題的重現與修正驗收**，再安排玩家候選包完整通關及發佈前門檻。不能將本輪寫成整體 G08 或正式發佈完成。遊玩說明見 [候選版指南](GREYSTONE_G08_GUIDE.md)。原始日誌／builds 留在被 Git 忽略的本機目錄，報告與工具提交功能分支；不合併 main，保留先前 Skill 及根目錄參考圖修改。

可玩 ZIP：builds/g08/ProjectCrystal-0.6.1-g08-rc1-Windows-20261018.zip；SHA256：641F1E06ECA81D2B912980178322DD7FCD7576FD683FD57B36EFBC7B40403F92。隨附 README、授權與已逐檔核對的 SHA256.json；不包含 QA 執行檔。
