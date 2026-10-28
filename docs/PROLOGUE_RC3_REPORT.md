# 序章 RC3 修正版交付 — 2026-10-28

## 本輪結果

最新序章來源已封裝為獨立 Windows RC3，包含新版灰石村、低語森林、礦坑、可玩雷恩／莉雅、修正後的防墜與導航，以及 RC2 之後新增的展開地圖。自動回歸通過，不代表人工美術、實體鍵鼠／Xbox 或最終發布認可。

- 分支：`feature/greystone-g06`；遊戲包固定來源：`52c7f1d187c4e4f4039657f0be46b08c09351300`。
- 版本：`0.6.1-prologue-rc3-20261028`。後續報告與驗收工具提交不改變此包來源。
- 引擎與 Windows x86_64 Release 模板：`4.7.2.stable.official.ed1daf0bf`；Compatibility／RTX 3080。
- 啟動：`D:/RPGGAME/builds/prologue-candidate/rc3-20261028/candidate/start_prologue_candidate.cmd`。
- ZIP：`D:/RPGGAME/builds/prologue-candidate/rc3-20261028/ProjectCrystal-0.6.1-prologue-rc3-Windows.zip`（385,127,681 bytes）。
- 存檔隔離於本包 `candidate/user_test`。沿用候選 slot 名稱以支援既有遷移，不搬動或覆蓋使用者的正式存檔。

## 本輪修正

1. 匯出工具從已提交的版本設定建立新目錄，拒絕覆寫既有候選包；Git archive 只取提交內容，排除工作目錄中未完成美術及無關修改。
2. 查核本機匯出模板與引擎完整版本，再將模板複製至隔離匯出環境。candidate／qa 都實際使用 `--export-release`，不複製舊包 EXE 冒稱重新匯出。
3. 包內驗收補入展開地圖、礦坑接口防墜、舊檔遷移與另一程序讀檔。每次重跑使用新的 evidence/profile，保留失敗紀錄。
4. 修正驗收前置順序：P5 真實序章存檔 → G06 實際遷移產生 layout 2 測試存檔 → 新序章遷移。沒有人工編造存檔、放寬位置檢查或改動 SaveCodec。
5. 新增空白宿主的 PCK 比對工具，檢查隱藏匯入產物與實際資源可載入性；避免只比對 remap 檔卻漏掉模型或編譯腳本差異。

正式 `scenes/main/main.tscn`、戰鬥數值、技能、劇情 ID／旗標、單次獎勵與存檔 Schema 未因本輪封裝改動。正式版本設定仍為 0.6.1，候選版透過 feature override 選入口／版本。RC2 原 PCK 雜湊再次核對一致。

## 可執行測試與實際結果

完整驗收紀錄：`builds/prologue-candidate/rc3-20261028/acceptance/run-20261028-173114-965/`。

| 檢查 | 實際結果 | 執行方式／範圍 |
| --- | --- | --- |
| 序章 E001–E009、兩場主線戰鬥、回村／獎勵 | 93／0 | 原生圖形 QA EXE |
| 關閉後新程序讀取 | 25／0 | 原生圖形 QA EXE |
| 三區導航／朝向／路線資料 | 31／0 | 圖形 Godot 掛載 QA PCK |
| 展開地圖與選單焦點 | 77／0 | 圖形 Godot 掛載 QA PCK，三區及三種視窗尺寸 |
| 礦坑橋階接口 | 23 個實走案例、0 新缺口、0 失敗 | 圖形 Godot 掛載 QA PCK；真實 Player／InputMap |
| 正式 P5 舊檔前置 | 69／0 | 無頭 Godot 掛載 QA PCK，實際遊戲產生 fixture |
| G06 舊檔前置 | 51／0 | 無頭 Godot 掛載 QA PCK，實際遊戲遷移 fixture |
| 候選存檔遷移／備份／非法位置拒絕 | 91／0 | 無頭 Godot 掛載 QA PCK |
| 遷移後另一程序讀檔 | 6／0 | 無頭 Godot 掛載 QA PCK |
| 商店／旅館／交易帳本 | 50／0 | 無頭 Godot 掛載 QA PCK |
| 交易後另一程序讀檔 | 5／0 | 無頭 Godot 掛載 QA PCK |
| 玩家 .cmd 啟動器 | exit 0，12.104 秒 | 真實 candidate EXE 圖形啟動，180 幀後自動退出 |

合計 **498 個斷言／0 失敗，另 23 個邊緣案例**。不把無頭 fixture 或圖形自動輸入當作人工遊玩。完整驗收批次約 187 秒；不是 30 分鐘長測。`--script` 檢查使用完整 Godot engine 直接掛載 QA PCK，工作目錄是隔離匯出包，沒有來源場景回退；不是把 release template 當可執行腳本的 editor。

已查看本輪原生圖片：灰石村 1280×720、礦坑 960×540、森林 1280×720。地圖與清單可見、選取框清楚；密集地標與礦坑區名在小尺寸仍偏緊，未宣稱所有文字配置已達最終美術品質。

第一次驗收在遷移步驟失敗（2 checks／1 failure）：獨立 profile 缺少 `g06_tests/restart.json`。其原始 `acceptance/qa-migration-output.txt` 保留。修正測試依賴後，在上述全新目錄重跑完整批次通過；未把第一次失敗刪除或記為通過。

包稽核：candidate 1,095 項、qa 1,324 項；**1,092 個 runtime 項目 SHA256 完全一致**。只排除兩包必要不同的 project.binary、global_script_class_cache.cfg、uid_cache.bin。玩家包無 tests／source_assets／tools／docs／artifacts／builds 目錄。證據：`acceptance/pack-audit-20261028-061317-355/comparison.json`。

ZIP 僅包含 EXE、PCK、啟動器、README、manifest；完整解壓後 **5／5 雜湊一致**，沒有存檔、日誌、API Key 或本機 profile。摘要與雜湊留在 `acceptance/verified-summary.json`、`acceptance/delivery.json`。

| 產物 | SHA256 |
| --- | --- |
| RC3 EXE | `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562` |
| RC3 PCK | `b4bce35e15b9cfdf7fd642552a381de04e23045a21691f2ea98a9dcd3b56d607` |
| RC3 ZIP | `46d98923061e709fa9b08a22e9c831af1504aaea80ccc73b32cbac25201e1d49` |
| 保留 RC2 PCK | `8979b541f18892d2a5476923d7afc2a4bce146d877d3951afd0c8df04fe6840f` |

## 重現

在 `D:/RPGGAME` 執行：

```powershell
.\tools\verify_prologue_package.ps1 -Root D:/RPGGAME/builds/prologue-candidate/rc3-20261028
.\tools\compare_prologue_packs.ps1 -Root D:/RPGGAME/builds/prologue-candidate/rc3-20261028
```

建立新的候選時，先提交新的候選版本，再執行 `tools/package_prologue.ps1`。現有 RC3 目錄會被拒絕覆寫；不要為重跑驗收刪除整個包。測試日誌、模型實驗、存檔及匯出結果不進 Git。

## 未完成與下一步

- RC3 未做新的 30 分鐘長測；RC2 的 1810 秒只能代表 RC2。已知首次載入及交易／戰鬥尖峰尚未另作本輪效能修正。
- 莉雅新造型頸領／側臉及髮衣貼圖仍未合格，保留可玩舊模型；旅館老闆圍裙仍有視覺問題。沒有把靜態試作冒充完成角色。
- 人工美術及鍵鼠／Xbox 驗收依使用者指示暫停；Android／iOS、第一章仍暫停。
- 可繼續處理角色外觀缺陷與 RC3 效能量測；本輪只交付已驗證修正版，不標記完整序章最終發布就緒。
