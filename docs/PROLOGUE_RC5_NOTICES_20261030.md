# RC5 發行附檔補齊 — 2026-10-30

檢查發現先前 RC5 的五檔 ZIP 與候選目錄未附專案已有的 Godot 引擎／第三方授權文字及素材來源清單。已從 RC5 固定來源 `8aa4a662289cdf6846538b0e60c6ef222282211c` 讀取 Git 提交中的 `docs/GODOT_LICENSES.txt` 和 `docs/ASSET_CREDITS.md`，加入候選目錄，另建立**附授權版本**：

`D:/RPGGAME/builds/prologue-candidate/rc5-20261030/ProjectCrystal-0.6.1-prologue-rc5-20261030-Windows-with-notices.zip`

原五檔 ZIP、EXE、PCK、啟動器、manifest 及測試存檔皆未改動；原五檔 ZIP 保留作歷史驗證，但缺少這兩個附檔，不作為建議分發版本。新 ZIP 包含原五檔加兩個附檔，共七檔，不包含存檔與日誌。未提交或未納入該固定版本的個人工作區改動沒有混入；原來源清單保留在使用者工作目錄。

## 驗證

- 原始 ZIP SHA256 先與原交付收據核對；五個既有壓縮項的長度、CRC 與壓縮資料 SHA256 保持一致。原始 ZIP 曾通過逐項解壓 SHA256 比對。
- 兩份新增文件逐字等於固定來源 Git 物件及候選目錄檔案；新包 SHA256 `b78105e5211da0561b6db84d6d61ffb12b739c7bc1ec39189ea48952a3ae5a96`，385,186,162 bytes。[收據](evidence/prologue_rc5_notices_20261030/delivery-with-notices.json)。
- `python -m unittest discover -s tests -p test_prologue_notices.py -v`：1／0，使用隔離模擬包檢查原 ZIP 不變、七檔內容及禁止覆寫。
- `tools/package_prologue.ps1` 也已改為從固定 Git 快照加入兩份文件並在候選 manifest 記錄其 SHA；PowerShell 語法檢查通過。該未來打包流程尚未重跑完整新包；本次 RC5 補件以 `tools/supplement_prologue_notices.py` 完成。

本次只補充已有文件，未重新審定所有素材權利；既有素材來源以固定提交的清單及專案記錄為準。RC5 包內測試見 [RC5 報告](PROLOGUE_RC5_REPORT.md)；其30分鐘圖形長測已完成，見[長測報告](PROLOGUE_RC5_SOAK_REPORT.md)；人工驗收暫停。
