# G08.3 戰鬥字型重用與短版 Release 診斷

2026-10-20（Asia/Taipei）。實作已由隔離 `codex/g083-rc2-probe` 的 `1288aee915f5f661c26754784b7db24de1d68c4f` 套用到功能分支 `c2c4ebdddd06489a812e940ed46a0829450d7d83`。**這是局部效能修正，G08.3／G08 仍未完成。** 正式 v0.6.1、歷史 RC2 產物與 main 保留；Android／iOS 暫停。

## 修正與證據範圍

原本每個戰鬥角色建立一份 `SystemFont`，每次戰鬥介面也重新建立字型。改為兩份預載入唯讀共用 `.tres`，維持原本 Microsoft JhengHei／Noto Sans CJK TC 家族順序、38px 場上字／19px 介面字、大小、描邊與版面。不改角色資源、數值、技能、事件、獎勵或 SaveCodec。沒有加入新字型檔或下載第三方字型。

獨立工作樹：`C:/Users/yume4/.codex/worktrees/g083-release-probe/RPGGAME`；基線為 `c6248a52b89043773e6fa533650f4b55d2fb3681`。當時兩個修正腳本及 QA 工具尚未提交，因此原始 manifest 如實記 dirty files；PCK 使用下列精確 SHA 固定。本次量測不代表較新 ENV02 村莊的完整效能。

Godot `4.7.2.stable.official.ed1daf0bf`、Windows 原生圖形 Release、RTX 3080、Compatibility、60 FPS 上限。測試先實際跑自動序章／Boss／返回／存讀檔，再各三次 X001／X003；不是玩家人工操作，也不是新一輪 30 分鐘長測。

| 輪次 | 牆鐘秒 | 檢查／失敗 | PCK SHA256 |
| --- | ---: | ---: | --- |
| 原始 RC2 Probe | 33.177 | 143／0 | `CF7CA697A5063497C25FDE691A22902FAEED7A0B07842D451D81E713D21D7A20` |
| 改前 Detail | 27.965 | 146／0 | `215C19027B0E68E00913B70D70DF46EC0574686E74B66BD00C571A75900E1B29` |
| 共用字型 Detail | 27.964 | 146／0 | `C6E95A0B12CDF8B0192690D387ACDB851919B61558AF4286813D93955D2818B9` |
| 字型身分／截圖計時 | 28.219 | 172／0 | `9C4CF67C507C1A18FC2EF946D6772E67346D5CDDFC922A6199CDEBCF320C0C83` |
| 同 PCK 關截圖診斷 | 26.561 | 160／0 | 同上一輪 |

原始完整測試資料及日誌／隔離存檔已另複製至 `D:/RPGGAME/artifacts/g083_qa_worktree_20261020/`，不納入 Git。可提交的原始指標、manifest、程序記憶體取樣及四張 WebP 在 [證據目錄](../source_assets/g083_font_diagnostics_20261020/)。不把缺少的截圖 12 項算成 PASS；關截圖明確記 SKIPPED，runner 禁止在 Soak 使用此選項。

## 實測 CPU 建立成本

四個 QA 子類別僅對原方法插入時間戳，透過 Resource 快取於主場景載入前換入；實際節點的腳本身分、九場含主線／重試的計時記錄均檢查。逐方法還原後與目前正式方法文字完全一致，來源正規化 SHA 另存；11 項契約檢查及三個 host 測試通過，包含刪除碰撞查詢／結算訊號的負例。原正式輸入、碰撞、安全位置驗證與獎勵邏輯不替換。

| 暖機遇敵，每種三次 | 改前 ms 範圍 | 改後 ms 範圍 |
| --- | ---: | ---: |
| X001 arena instantiate＋ready＋setup＋signals | 26.428–26.912 | 5.842–6.158 |
| X003 同上 | 27.087–27.734 | 6.062–6.204 |
| X001 單名牌建立平均 | 4.943 | 0.0139 |
| X003 單名牌建立平均 | 5.098 | 0.0142 |

UI ready 由約 6.3ms 變為 0.7ms；角色外觀 ready 仍約每人 2–3ms。此輪沒有改共用可變骨架／動畫狀態。上述 CPU 建立總和不含 deferred 排程／先手動作、GPU 首次繪製或函式採樣。X003 等待玩家輸入約一秒可能含敵人先手，不能當作載入 CPU。

讀檔驗證仍建立獨立 World3D，保留兩個物理幀等待：村莊 instantiate 約 1.6–2ms、ready 約 3–3.4ms、等待約 25–28ms、碰撞 query 約 0.025–0.05ms；不能為降數字刪除驗證。轉場仍有設計的 320ms 淡入淡出。

## 包含所有幀的結果與截圖成本

| Phase／輪次 | FPS | 平均 ms | P95 ms | P99 ms | 最大 ms | Draw Calls |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 序章，改前 | 55.79 | 17.924 | 17.277 | 68.067 | 246.639 | 0–625 |
| 序章，改後 | 55.96 | 17.869 | 17.213 | 68.768 | 246.818 | 0–625 |
| X001，改前 | 59.09 | 16.923 | 25.587 | 43.605 | 43.605 | 121–363 |
| X001，改後 | 60.01 | 16.665 | 19.606 | 26.201 | 26.201 | 121–363 |
| X003，改前 | 59.46 | 16.818 | 16.881 | 39.793 | 62.139 | 121–338 |
| X003，改後 | 60.00 | 16.667 | 16.738 | 25.919 | 33.508 | 121–338 |
| 序章，同 PCK 明確關截圖 | 58.79 | 17.009 | 17.097 | 24.982 | 254.381 | 0–625 |

另一次加入兩張名牌畫面及截圖 span 的輪次，X001 P99／最大 160.874ms、X003 最大 161.863ms，這些樣本沒有排除。Viewport readback 約 4–7ms、同步 WebP 編碼／寫檔約 100–170ms，時間與多個長幀重疊；因此短版 QA 的部分尖峰來自保存驗收畫面。關截圖只用來隔離這個成本，不能取代原本含截圖結果或長測。

關截圖仍有初期四幀 254.381／92.383／58.633／36.271ms，另有 44.732／39.246ms；**啟動尖峰未完全定位**。Detail 的取樣在 QA 腳本安裝後開始，未覆蓋整個 OS 程序啟動或快取清除後冷啟動，不能宣稱已解決原 664ms／歷史秒級尖峰。

程序每秒取樣：改前 Working Set 峰值 696.391MiB／Private Bytes 878.637MiB；改後 652.742／851.520；加截圖 span 659.699／878.871；關截圖 645.457／853.027。輪次短、未做記憶體因果對照，不能宣稱已節省固定記憶體或沒有洩漏。Release 引擎靜態記憶體監測為不可用，JSON 使用 null，不冒稱 0 bytes。

## PCK 對照及失敗保留

新工作樹重新匯入後，與歷史 RC2 的編譯場景／GLB 資源 byte equality 檢查**失敗**；不是可拿來沿用舊「610 共用資源一致」證明的新候選。失敗盤點保留在本機原始證據 `20261020-165949/pack_audit/`。

相同 146 項檢查的最小前後包 `215C...`／`C6E9...` 另核對：**735 共用項目一致、5 變動、4 新增、0 移除**。變動只在兩個正式腳本、相同改法的 QA stage、來源收據及 UID 快取，新增兩份字型與 remap；見 [最小字型差異](../source_assets/g083_font_diagnostics_20261020/minimal_font_pack_comparison.json)。沒有遊戲場景／角色／戰鬥資料變動。

改用同一工作樹與匯入快取，比較改前 `215C...` 和加截圖 span 後 `9C4C...`：**733 個共用項目 hash 一致、7 個變動、4 個新增、0 移除**。變動為兩個正式戰鬥腳本、QA stage／主測試／來源收據與 Godot 類別／UID 快取；新增兩個字型 `.res` 及其 `.remap`，完整路徑見 [實際差異](../source_assets/g083_font_diagnostics_20261020/same_cache_pack_comparison.json)。場景／模型在這個對照內一致，不推論舊 RC2 byte equality。

## 畫面檢查與未通過事項

已查看 X001／X003 的 512 短邊總覽及 X001 原生 1280×720 字形；[逐項評分](../source_assets/g083_font_diagnostics_20261020/visual_review.json)。中文字無缺字，原字型家族／大小身分在實際 Release 節點檢查通過。這是字型重用範圍視覺檢查，不是全部 UI／角色品質認證。

未解決：X001 菇帽會深度遮住部分場上 HP（CTRST-OVERLAP-LEG=0），雷恩名牌與灰色 G06 開發列局部重疊；本次保留原配置，沒有以此宣稱全部資訊可讀。仍須處理啟動尖峰、歷史 826 秒不明切圖重現、固定新 SHA 的 30 分鐘 Release／跨程序重啟、更新後候選的實體輸入。歷史 RC2 的使用者實體驗收不自動轉用到新包。

## 重現

```powershell
python tools/audit_g083_detail.py --output artifacts/g083_detail_contract.json
python tests/test_g083_detail_contract.py
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode ExportG083QA
$qaExe = 'builds/g08/qa-soak/20261020-195302/ProjectCrystal.exe' # 或填入上行新匯出路徑
./tools/test_windows_release_stability.ps1 -QaExe $qaExe -Mode Detail
./tools/test_windows_release_stability.ps1 -QaExe $qaExe -Mode Detail -SkipCaptures
```

Resource 快取換入只在明確的 QA Detail 入口：參考 [Godot 4.7 Resource.take_over_path](https://docs.godotengine.org/en/4.7/classes/class_resource.html#class-resource-method-take-over-path)。一般遊玩及 Soak 不安裝計時子類別；新正式字型資源仍生效。更新檔案為兩個戰鬥腳本、兩份字型資源、四個計時子類別及 UID／來源收據、Release runner／測試、host 契約檢查與本輪文件／證據。

功能分支 c2c4ebd 的 G06 全回歸已執行：`./tools/test_g06.ps1`，16 模式／576 斷言／0 失敗，含三個實際圖形模式（68＋22＋53），日誌與結果見 feature_g06_regression.json；觸控為桌面注入，不是 Android。不帶 Detail 的新 Release Probe 也已通過 143／0，見下。完整 A01～A05／新雷恩莉雅／環境物品／G08.3～G08.5／C1 仍未完成。

## 功能分支正常 Release 整合結果

`c2c4ebdddd06489a812e940ed46a0829450d7d83` 匯出 `builds/g08/qa-soak/20261020-195302/ProjectCrystal.exe`，執行 `-Mode Probe`（沒有 `--probe-detail`，不安裝四個診斷子類別）。原生圖形 Release **143／0、35.300 秒**；PCK SHA256 `5EDA02629CAD5BB2AB1FC1FB361551FB0DCF9B3A04E9C1BBC467242BEBA6F641`。X001 launch→arena 6.737／7.167／6.656 ms，X003 6.880／7.695／7.064 ms，包含 deferred dispatch。涵蓋實際完整序章、六場暖機戰鬥、返回與讀檔；原始資料在 feature_release_probe。這是短版整合驗證，仍不是新 30 分鐘或實體玩家通關。
