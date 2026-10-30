# 序章 RC5 Windows 候選版 — 2026-10-30

固定來源 `8aa4a662289cdf6846538b0e60c6ef222282211c`，分支 `feature/greystone-g06`，版本 `0.6.1-prologue-rc5-20261030`。包含 RC4 後的森林標籤避讓、樹冠遮擋淡化、探索 HUD 與礦坑地圖可讀性修正；原有雷恩與可動莉雅、三區探索、序章戰鬥與存讀檔保留。沒有把尚未合格的莉雅新候選模型換入。正式 v0.6.1 與固定 RC4 保留。

## 啟動與檔案

- 玩家啟動器：`D:/RPGGAME/builds/prologue-candidate/rc5-20261030/candidate/start_prologue_candidate.cmd`
- 壓縮包：`D:/RPGGAME/builds/prologue-candidate/rc5-20261030/ProjectCrystal-0.6.1-prologue-rc5-Windows.zip`（385,142,910 bytes）。
- 此包的存檔放在自己的 `candidate/user_test`，不會自動取得 RC4 的存檔。若需使用舊候選存檔，先備份，再將其複製到 RC5 的相同相對位置；先前遷移驗證不等於使用者自己的存檔已測試。
- ZIP 白名單五檔逐一解壓串流比對雜湊，5／5 一致；不包含存檔與日誌。[雜湊](evidence/prologue_rc5_20261030/delivery.json)。

## 包內檢查

使用 Godot 4.7.2.stable.official.ed1daf0bf Windows x64；合計 **21,844 項檢查／0失敗**，另有 **23 個礦坑邊緣行走案例／0新缺口**。包內 GUI 使用自動輸入，不等於人工鍵鼠或實體手把驗收。

| 檢查 | 結果 | 方式 |
| --- | ---: | --- |
| 序章與主線戰鬥／回村 | 94／0 | 原生 Release QA EXE，圖形 |
| 另開程序讀回序章 | 25／0 | 原生 Release QA EXE，圖形 |
| HUD／存檔與礦坑導覽 | 298／0、224／0 | Godot 圖形掛載 QA PCK |
| 森林遮擋、標籤與同地圖刷新 | 26／0、258／0、54／0 | Godot 圖形掛載 QA PCK |
| 三區導航與展開地圖 | 31／0、77／0 | Godot 圖形掛載 QA PCK |
| 礦坑邊緣行走 | 23案例／0缺口 | Godot 圖形掛載 QA PCK、實際 CharacterBody 輸入 |
| 舊序章／G06基線 | 69／0、51／0 | QA PCK 無頭 |
| 遷移與重啟 | 91／0、6／0 | QA PCK 無頭 |
| 商店／旅館與重啟 | 50／0、5／0 | QA PCK 無頭 |
| 碰撞快照對照 | 20,485／0 | QA PCK 無頭物理對照 |
| 玩家 EXE、公開 .cmd 啟動器 | 均 exit 0 | 圖形短啟動，.cmd 12.696 秒 |

候選與 QA PCK 在空白宿主核對 **1,096 個共用 runtime 項目一致**；只允許三個包設定／快取差異，玩家包不含測試、開發工具或存檔。[結果](evidence/prologue_rc5_20261030/pack_comparison.json)與[測試摘要](evidence/prologue_rc5_20261030/summary.json)。

已查看實際圖形輸出的[村莊](evidence/prologue_rc5_20261030/village.webp)、[森林](evidence/prologue_rc5_20261030/forest.webp)、[礦坑木橋](evidence/prologue_rc5_20261030/mine_bridge.webp)及[礦坑展開地圖](evidence/prologue_rc5_20261030/mine_map.webp)。截圖只代表所示站位，不是全場景人工美術驗收。

## 長測及限制

2026-10-30 已啟動此固定 QA PCK 自身的30分鐘圖形自動長測，執行目錄 `acceptance/soak-20261030-115445-671`；交付此報告時仍在執行，**尚未通過**。需待進程完成、檢查零失敗、重啟讀檔與包雜湊後另行登錄；不可使用 RC4 的長測替代。方法為完整 Godot 引擎掛載 QA PCK，不是獨立 Release 效能或人工30分鐘遊玩。

交易後讀檔仍有尖峰，新莉雅候選拓樸／貼圖尚需修整，人工美術與實體輸入最終驗收依使用者要求暫停；Android／iOS與第一章暫停。此包是可測候選，不宣稱序章最終發布完成。manifest 中的 Pending 是匯出時快照，完成測試後不改動已封存包。
