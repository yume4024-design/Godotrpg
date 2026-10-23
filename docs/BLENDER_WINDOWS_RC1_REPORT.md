# 灰石村 Blender Windows RC1 固定包驗證

2026-10-24（Asia/Taipei），功能分支 `feature/greystone-g06`。
固定遊戲來源 **`63d05f5c13c09531ba7a773b253e449828218e3a`**，版本 **`0.6.1-greystone-blender-rc1`**。
Godot **4.7.2.stable.official.ed1daf0bf**，Windows x86_64 release template。
**包內原生序章 116／0、另一程序重啟 22／0、普通啟動及正常關閉通過；不是新長測或實體輸入驗收。**

## 可玩產物

`builds/greystone-blender/rc1-63d05f5/candidate/start_blender_village.cmd`

同目錄 EXE／PCK／啟動器／授權與操作說明一起使用，見[試玩指南](BLENDER_WINDOWS_RC1_GUIDE.md)。
本輪另提供不含 `user_test/` 的 Windows ZIP，SHA 及大小見下方凍結證據。
新包沿用載入畫面、現有 Player／UI／RPG Manager 及候選 layout 3；加入獨立的延後關閉生命週期以釋放音訊／世界資源。
正式 `run/main_scene` 及 base version 0.6.1、舊 RC4、角色／數值／故事／任務／存檔 schema 均保留。
不合併 main，Android／iOS、第一章及新模型沒有開發。

| 角色 | 大小 | SHA256 |
| --- | ---: | --- |
| 兩包 EXE | 109268480 bytes | `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562` |
| Candidate PCK | 319111348 bytes | `1a7448b726327c0553510db30fba4a84c5a72143709a198235ed998ff59d19f8` |
| QA PCK | 319634928 bytes | `b7b15bb2a472e8c63e865323db36b7376bc66761c3503e6933f05bbd42cf0c7f` |

## 固定來源與包稽核

- 從本聊天新建、初始 tracked clean 的 managed worktree 匯出。舊驗收工作樹有修改，沒有重設或覆寫它們；主目錄未提交的角色／怪物素材也未帶入。
- 首次 import 自動正規化 audio bus，僅在本輪新工作樹還原剛擷取的原始 bytes，再匯出；沒有 runtime overlay。最終收據未發現剩餘 tracked 差異。
- **Candidate 939 entries、QA 1129 entries；935 份共用 runtime bytes SHA 全部一致**。包含隱藏匯入／編譯資源，非只核對可見 remap。
- 新入口、Blender 村莊、水 GLB 及三個 surface shaders 均在包內。Candidate 不含 tests／tools／source_assets／artifacts／builds／來源參考圖或 `.blend`，未發現差異或禁入檔案。
- 擴充的包稽核工具保留原預設；對既有 RC4 重跑得 790／960 entries、786 共用 SHA 一致，原結果不被新候選的 required paths 取代。
- 正式 v0.6.1 EXE／PCK 及固定舊 RC4 EXE／PCK 的前後 SHA 完全相同。

## 原生 Release 驗證

自動驗收使用同一候選 loading bootstrap 建立的遊戲實例，透過既有 InputMap、對話、戰鬥與交易入口操作。
QA 使用獨立 profile，隔離搖桿軸避免桌面焦點／手把漂移干擾；可玩包不採用 QA 輸入隔離。
沒有透過改旗標或直接標記勝利替代兩場主線戰鬥。

| 範圍 | 實際結果 |
| --- | --- |
| 載入邊界、E001～E003、森林教學、礦坑／Boss、回村交付、E009 | 納入新程序 116／0 |
| 六原 NPC、莉雅單次加入、商店鼠標確認、金幣扣除、旅館全隊恢復 | 納入 116／0 |
| 真正生成的 schema 1 與 G06 layout 2 舊測試檔匯入，保留來源 bytes／角色／裝備／經濟／旗標／任務／收據 | 納入 116／0 |
| 水中非法座標拒絕，當前狀態與來源保留；橋邊水 shader／無水底碰撞與實際圖形截圖 | 納入 116／0 |
| 保存後另一程序續玩、精確 212 金幣／300 EXP／星印與收據、模型／水 shader 保留 | 22／0 |
| 普通啟動器，不加 smoke／QA 旗標；視窗正常回應，CloseMainWindow 正常結束 | 12.125 秒觀察，遊戲及 launcher exit 0 |

本輪合計 **138／0**，另有包稽核與普通啟動檢查，沒有把它們混加成更多劇情 assertions。
已實際查看此 PCK 的木橋水景、Boss 戰與商店交易後 viewport；圖形正常，沒有缺少新 surface shader。
最初 runner 在兩份 QA 都通過後，於普通啟動器的 CIM 查詢權限處結束，因此沒有保存 QA 程序秒數；保留實際結果與日誌，不補造時長。

## 啟動驗收工具修正

三次未通過的啟動工具紀錄保留，不抵算成遊戲通過：

1. Sandbox 不能查詢 CIM；改用授權範圍內的程序查詢，僅控制本測試啟動的子程序。
2. 即時讀取遊戲正在寫入的 log 遇到 Windows 共享限制。
3. 改成共享讀取後仍等不到即時 marker；關閉後 log 具有 ready 記錄，證實該 Release 日誌有緩衝。

最終以普通視窗保持 12 秒、檢查 responsive，再正常關閉並從已沖寫的 log 確認 `BLENDER_WINDOWS_READY`。
這證明關閉前曾完成載入，不宣稱量到精確首個 ready 時間；沒有為通過測試而改動或重匯出遊戲 PCK。
runner 現在在啟動器檢查前先保存 QA 結果，失敗也保留 manifest；不重新執行已通過的序章來掩蓋工具失敗。
舊 RC3／RC4 啟動工具的預設行為保留，新參數只用於此包。

## 指令及證據

```powershell
# SourceRoot 必須是固定來源的乾淨 managed worktree，BuildRoot 必須尚不存在。
./tools/build_blender_windows.ps1 -SourceRoot '<驗收工作樹>' -BuildRoot '<新輸出資料夾>'
./tools/test_blender_windows.ps1 -BuildRoot builds/greystone-blender/rc1-63d05f5
python tools/audit_windows_candidate.py artifacts/blender_windows/20261024-003525/manifest.json
```

普通啟動測試的 CIM 可能需要本機執行權限；該工具僅查詢自己建立的候選子程序，不要求玩家啟動器提權。
工具歷史標記仍叫 `RC3_NORMAL_LAUNCH`；實際 launcher、EXE／PCK SHA 和新版來源列在收據，並非用 RC3 代替新包。

本機完整測試輸出在 `artifacts/blender_windows/20261024-003525/`，固定包在 `builds/greystone-blender/rc1-63d05f5/`。
本輪匯出專用工作樹已交給 managed archive 清理，固定來源提交與本機包保留；沒有清理較早的使用中驗收工作樹。
不提交 EXE／PCK／ZIP、測試存檔或 profile。凍結結果、包 SHA、稽核清單、截圖與失敗工具紀錄見
[`source_assets/greystone_blender_20261023/windows_rc1_acceptance/summary.json`](../source_assets/greystone_blender_20261023/windows_rc1_acceptance/summary.json)。

## 尚待驗收

- **本包**實體鍵鼠／Xbox 完整序章、服務及保存關閉重開；舊 RC3 通過不替代本包。
- 本包 30 分鐘原生長測、動態幀時間／程序記憶體／轉場尖峰。沒有沿用舊 RC4 的長測結果。
- 美術仍有既有 AI 建物／地形細節差異；不宣稱這次包已達概念圖完全還原。
- G08 總 Gate 尚未完成，沒有開始後續章節或行動平台。
