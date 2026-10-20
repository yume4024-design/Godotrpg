# RC3 Windows 啟動器修復

2026-10-21；使用者回報「開了就跳出」。先停止下一項資產開發，以同一路徑重現，沒有把先前Smoke當成雙擊入口驗收。

## 根因與修正

原start_rc3.cmd呼叫Windows PowerShell的play_rc3.ps1；本機執行原則為Restricted，回報running scripts is disabled／UnauthorizedAccess、退出碼1。遊戲尚未啟動，沒有新引擎日誌。先前用目前開發shell執行.ps1 Smoke通過，沒有涵蓋使用者雙擊CMD所啟用的Windows PowerShell，屬測試覆蓋缺口。

新增可重用tools/start_rc3.cmd，直接用CMD start /wait執行EXE，獨立APPDATA／LOCALAPPDATA／TEMP仍指向同包user_test；保留原測試進度。遇到缺EXE、缺PCK、不可建目錄或遊戲錯誤碼時，顯示錯誤及日誌並保留視窗。沒有改ExecutionPolicy、登錄檔或Windows安全設定。

## 實際測試

- 舊Windows PowerShell入口重新實測：exit1、Restricted，原錯誤文字保留。
- 新CMD正常Smoke：exit0（仍不當作一般啟動驗收）。
- 不帶Smoke的原生圖形啟動：實際唯一子PID8592的首版探測見failed_probe_exit_handle.json；視窗8.134秒正常，但因未保留native handle導致探測ExitCode不可用，測試沒有標PASS。修正探測器後另開新程序，8.087秒、視窗標題「失落星核 — Project Crystal」、nonzero HWND、Responding=true；測試主動要求正常關閉，遊戲及launcher均exit0；探測器按唯一子程序實際命令列取確切log，不以最新檔案推測。
- 修正ZIP解壓至含空格與中文資料夾：一般圖形啟動8.101秒，同樣正常關閉exit0。程序CIM讀取在一般沙箱被拒，改以授權的程序觀測執行；這不是遊戲崩潰，也沒有因此假報第一次探測成功。
- 缺EXE：exit2；缺PCK：exit3（使用零位元fixture只驗證檢查入口，不執行它）。負向測試不阻塞自動化，產品預設錯誤時仍停留。
- 固定RC3 EXE／PCK未改；PCK SHA `2758b063385a25e724b13a546cff9585f65557dafed2989ebad005baf276d13c`。原ZIP保留；新增 `builds/g08/rc3-20261020/ProjectCrystal-0.6.1-g08-rc3-launcher-fix-windows-x64.zip`，8檔／225251759bytes，未包含user_test。ZIP逐檔SHA及CRC通過，SHA `e9ce1ce6f298a6417f78aa9de325bf800d5356c6a6feba23f698ffd298c06a2c`。

本輪是啟動器與封裝驗收，沒有重跑30分鐘、沒有假稱鍵鼠／Xbox或完整序章人工通關。已請使用者重開同一路徑確認視窗能否保持；修正後重試及完整實體操作仍待。G08整體與第一章未完成，Android／iOS持續暫停。

[小型原始證據](../source_assets/rc3_launcher_20261021/)；命令：`tools/test_rc3_launcher.ps1`，及 `-Launcher <解壓後start_rc3.cmd>`。該測試會在八秒後主動正常關閉它自己啟動的視窗，不會關閉其他遊戲程序。本機存檔、EXE、PCK與ZIP只保留於ignored artifacts／builds。
