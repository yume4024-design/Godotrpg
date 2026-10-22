# Fixed RC4 package evidence

遊戲提交 `0bb2188df3fb25e61e58b1944f47e4b855f464f4`，Windows Godot 4.7.2 release，三包角色為 candidate／qa／qa-soak。`export_receipt.json` 保存各包 SHA／大小與匯入後來源差異。

`manifest.json`、三份原生日誌文字、prologue／reload result 為實際可玩 smoke 及 162／0＋46／0 短測；不是長測或人工通關。兩份 pack audit 分別對照功能 QA 與 soak QA，786 個共用實體 runtime 雜湊全部相同。

根目錄三張 WebP 來自此固定包的短測 viewport，soak 另有末輪三圖截圖，保留原始內容。已查看 Boss／交易、礦坑及長測森林畫面；未以生成圖片代替驗收。SHA256 清單涵蓋目前凍結的證據，含追加的長測／重啟／診斷與 launcher 收據。

`soak/`：固定 PCK 原生 Release 1804.213 秒、1548／0，另程序讀取實際長測存檔 97／0；compressed metrics、全部程序 CSV、日誌、三圖末輪截圖、重啟收據／SHA 保存。aggregate 來自所有取樣幀，但既有長測器沒有持久化完整逐幀向量；首 300 個 spike 並非完整 GPU trace。

`detail/`：38.582 秒、208／0 的獨立短診斷；保留 582.440ms 的 X003 幀及截圖成本，不能混入長測或聲稱尖峰已消除。`launcher.json` 為此 RC4 啟動器普通啟動／正常退出證據，歷史測試工具輸出 RC3 標記不表示測了舊包。新包人工鍵鼠／Xbox 仍待；不冒稱實體輸入或 Android 通過。

見 [固定包紀錄](../../docs/RC4_FIXED_PACKAGE_REPORT.md) 與 [啟動診斷](../../docs/G083_STARTUP_REPORT.md)。
