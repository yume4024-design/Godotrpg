# Windows startup evidence — 2026-10-22

- `summary.json`：21 次原生 Release 短程實驗；基線 9 次不限幀，另基線／載入畫面各 6 次 60 FPS。不是 30 分鐘長測、人工通關或 Android 測試。
- 各 `startup.json.gz` 可用 Python `gzip.decompress` 讀取所有幀與事件；沒有刪除讀回／截圖或異常幀。`process.csv` 是程序 working set／private bytes，未提交存檔或 shader cache。
- `frozen_rc3_pack_comparison.json`／export receipt：診斷用的固定原 RC3 遊戲資源等價證據，**不是 RC4 固定版本包證明**。
- `regression/`：實際 bootstrap 序章 76／0、另一程序重啟 16／0、錯誤 UI 各 5／0，以及已拒用 threaded／取消 World3D 遺留資源的失敗日誌。失敗數據不混入通過結論。
- `g06.json`：16 模式 576／0。
- `draft_rc4/`：162／0＋46／0 的草稿包測試，但另包稽核失敗：`npc/` 來源 `.import` 描述檔被帶入。草稿未交付；排除修正後需固定提交重新打包。
- `loading_screen.webp`／`viewport.webp`：實際原生 viewport 截圖，已查看；不是生成示意圖。
- `SHA256.json`：文字採 UTF-8 無 BOM／LF 後的 SHA；壓縮幀資料 `source_raw_sha256` 對應解壓後文字。README 本身未納入初次雜湊清單。

測量時鐘自 QA script 初始化開始，不等於 EXE 總啟動時間；pre/post draw span 是 CPU 牆鐘、不是 GPU timestamp。未清除 OS／driver cache，不能宣稱冷 GPU 或首次峰值全由應用快取造成。詳見 [驗收報告](../../docs/G083_STARTUP_REPORT.md)。
