# G08.3 Windows Release 通關回歸與長測

日期：2026-10-18（Asia/Taipei）；分支 `feature/greystone-g06`；基線 `aa71fc71d78619390cd85bed80407e790f8c3692`。正式 v0.6.1、rc2 可玩包、角色／數值／劇情／獎勵／Schema 保留。Android／iOS及第一章暫停。

**狀態：受控 Release 自動長測及重啟通過；效能尖峰、人工／實體輸入與原失敗來源仍待驗收，G08.3／整體 G08 不宣稱全部完成。**

## 最終受控長測

證據：`artifacts/g083/20261018-111013/manifest.json`、`summary.json`、`process.csv`及 profile 下 `g083/metrics.json`。使用 `builds/g08/qa-soak/20261018-110852/ProjectCrystal.exe`，PCK SHA256 `CF7CA697A5063497C25FDE691A22902FAEED7A0B07842D451D81E713D21D7A20`。

- 連續圖形 soak **1809.621902秒（30分9.622秒）**；主迴圈含序章1836.030266秒，程序牆鐘1838.393秒，exit0。
- **27輪、81次切圖、54次可選戰鬥、162次計時讀檔、1344檢查／0失敗**。劇情只通關一次，循環不重複發放星印／金幣／EXP。
- 使用同一長測 profile，以原 rc2 短版 QA 的另一程序 `--reload` 讀取長測末檔：**14/0**；`restart.log`／`restart_result.json`，保留212金幣、莉雅EXP、星印、裝備、任務及獎勵帳本。
- 舊可玩rc2與本次Soak QA盤點614／729檔，**610共用遊戲資源雜湊一致**；`runtime_audit_manifest.json`與`pack_audit.json`。沒有把QA測試開銷冒稱純可玩包開銷。
- 查看此輪 `g08_tests/evidence/g083-mine-6.webp`，角色／UI／橫梁退讓正常；各圖檢查點nodes分別1123／832／470，未隨輪次增加。這不證明所有資源無洩漏，Release孤兒監測不可用。

| Phase（含該段測試操作） | 平均FPS | 平均ms | P95ms | P99ms | 最大ms | Draw Calls範圍 |
| --- | --- | --- | --- | --- | --- | --- |
| 序章／啟動 | 38.55 | 25.937 | 17.514 | 167.842 | **3053.011** | 0–625 |
| 灰石村／存讀檔 | 59.18 | 16.898 | 16.766 | 18.547 | 176.845 | 99–194 |
| 森林／存讀檔 | 58.92 | 16.971 | 16.795 | 24.937 | 178.558 | 364–450 |
| 礦坑／存讀檔 | 59.25 | 16.878 | 16.770 | 17.100 | 277.378 | 176–206 |
| NPC／交易／恢復 | 56.45 | 17.714 | 20.233 | 68.755 | 137.575 | 99–359 |
| 戰鬥／返回與讀檔 | 56.09 | 17.828 | 17.077 | 57.736 | 259.384 | 127–373 |
| 轉場phase | 59.29 | 16.865 | 16.787 | 18.899 | 72.868 | 99–463 |

81次轉場的整段耗時平均329.669ms、P95 331.984ms、最大401.255ms，含320ms設計淡入淡出；162次驗證＋套用讀檔平均366.645ms、P99 506.397ms、最大565.990ms。戰鬥啟動到玩家輸入平均574.303ms、最大1151.481ms，包含先手行動，與下文arena建立短測分開。

遊戲PID每秒取樣工作集峰值753.297MiB，OS PeakWorkingSet記錄773.223MiB；Private Bytes峰值922.109MiB。120–300秒／1500–1800秒窗口的工作集中位數657.926／646.305MiB，Private Bytes中位數829.703／827.605MiB；這兩個窗口沒有持續增加，但最後瞬間值及峰值仍保留，不宣稱完整無洩漏。Release引擎靜態記憶體不可用，沒有挪用Debug數據當成本輪結果。

原始幀分布納入全部取樣；超33.333ms逐事件明細最多保留前300筆，這輪達上限，不把300當成總長幀數。各phase最大／百分位仍計算全部樣本。新增ComfyUI模型生成在此長測結束後才開始，不混入本輪GPU負載。

## 方法與證據

- 新增獨立 `g083_qa` Release preset，主迴圈 `WindowsReleaseStabilityTestTree`；沿用 rc2 遊戲資源與既有 RPG Manager。所有新增遊戲內程式均在 tests，候選排除 tests，不修改生產邏輯。
- 使用 Godot 4.7.2 / Windows / RTX 3080 / Compatibility 原生圖形 exe，60 FPS 限速。先自動操作一次完整序章，再至少1800秒持續三圖移動、NPC／商店／住宿、X001／X003可選戰鬥、保存／讀取。戰鬥包含雷恩／莉雅模型、動作及返回探索。
- 使用 InputMap 注入、測試用路段重新定位與加速對話／戰鬥。這不是玩家人工30分鐘完整通關，也不驗收隨機遭遇、劇情節奏或實體手把。QA長測階段隔離非測試裝置輸入，正式遊戲不改。
- 幀時間為 process_frame 間牆鐘，含測試本身、截圖、診斷序列化、存讀檔與場景切換；各地圖 phase 也包含該圖存讀檔，不能全部當作純行走渲染。轉場耗時含兩段各0.16秒的既有淡入淡出。
- 同一遊戲 exe PID 每秒記錄 Working Set、Private Bytes、Peak Working Set；引擎 `MEMORY_STATIC` 與孤兒節點監測在 Release 不可用，raw 0 不當作0 bytes或無孤兒證明。依據：[Godot 4.7 Performance](https://docs.godotengine.org/en/4.7/classes/class_performance.html)。摘要工具將靜態記憶體改列null並保留原始JSON。
- 秒級啟動尖峰是乾淨 QA profile 下的實測，不等於清除作業系統／驅動快取的冷啟動測試。未取得 GPU／CPU 函式採樣，不猜測每個尖峰的根因。

## 已完成的短版分段診斷

`./tools/test_windows_release_stability.ps1 -QaExe builds/g08/qa-soak/20261018-110852/ProjectCrystal.exe -Mode Probe`

**143/0，38.298秒，非長測。** 證據：`artifacts/g083/20261018-110906/manifest.json` 及其 profile 下 `g083/load_probe.json`。完整序章後，各地圖5次暖機重建，分開量測 PackedScene instantiate、World3D建立、add_child／_ready及兩個物理幀等待；另各3次實際戰鬥，用 arena_started 訊號拆分建立與首個玩家輸入。

| 地圖 | instantiate ms 範圍 | add_child／_ready ms 範圍 | World3D ms 範圍 | 物理等待 ms 範圍 |
| --- | --- | --- | --- | --- |
| 灰石村 | 2.152–2.520 | 4.517–6.142 | 0.635–0.692 | 23.961–26.043 |
| 森林 | 1.249–1.333 | 1.725–1.955 | 0.642–0.779 | 29.391–29.693 |
| 礦坑 | 0.593–0.664 | 2.204–2.582 | 0.644–0.725 | 29.382–29.898 |

X001 launch→arena_started為39.496–40.728ms，arena_started→玩家輸入15.801–20.153ms；X003分別40.999–52.159ms與1067.423–1621.991ms。後者包含敵方先手／動作等待，不能把總等待都說成資源載入。前者仍超過單幀16.67ms，屬後續可定位的戰鬥建立成本；這些暖機小樣本不能解釋全部啟動／渲染尖峰，也不代表已優化。

## 失敗輪次與限制

1. `artifacts/g083/20261018-104759/`：嘗試用 CLI main-loop 覆寫既有 QA feature，實際仍進短版 QA，隨後缺少其 v1 fixture；沒有長測 metrics。改為獨立 preset，不改存檔驗證，不抵算長測。
2. `artifacts/g083/20261018-104942/`：實際圖形運行到 soak 826.347秒，第13輪回村後保存／讀取被拒絕、NPC路徑缺失，共621檢查／7失敗，exit1。最後節點數與預期村莊不一致；原始版缺少當下map／輸入追蹤，無法確認額外切圖來源，**不宣稱已證明是外部操作，也不宣稱修復了生產遊戲切圖bug**。該輪不算30分鐘通過。
3. `artifacts/g083/20261018-110715/`：短診斷兩項UI隔離斷言失敗；隔離狀態切換與事件檢查過早。將隔離在_finish明確啟用，等待process／physics後，下一短測143/0。正式遊戲輸入未修改。
4. 增加測試用輸入記錄、地圖／鎖／交易狀態與失敗截圖，以及每段移動後的地圖一致性斷言。控制後續長測的輸入，不以隔離測試取代實體鍵鼠／手把驗收。所有失敗資料保留。

## 可重現指令

```powershell
./tools/godot.ps1 -Mode Check
python tools/prepare_windows_candidate.py
./tools/godot.ps1 -Mode ExportG083QA
./tools/test_windows_release_stability.ps1 -QaExe <上述匯出的ProjectCrystal.exe>
python tools/summarize_windows_release_stability.py <成功長測manifest.json>
# 額外暖機拆分診斷；不能代替1800秒Soak
./tools/test_windows_release_stability.ps1 -QaExe <同一exe> -Mode Probe
```

預設Soak設1950秒程序上限，只有原生Release、圖形、完整1800秒且零失敗才通過；Probe有獨立模式與120秒上限。APPDATA、LOCALAPPDATA、TEMP均隔離在artifacts/g083；不接觸玩家存檔。大型JSON／CSV／截圖／匯出保留本機ignored目錄，報告與測試工具納入Git。

## 未完成門檻

- 玩家使用可玩候選包及實體輸入完整通關、節奏與其他Windows／低階PC驗收。
- 秒級啟動與暖機後戰鬥／讀檔尖峰的完整根因及針對性修正。
- 前述826秒輪次額外切圖來源尚未確認；受控長測不會抹除該失敗紀錄。
- 其他遮擋與角色近景限制仍見G08主報告。整體G08不勾選完成，不合併main。
