# RC4 固定提交 Windows 包複驗

日期：2026-10-22（Asia/Taipei）。遊戲來源 **`0bb2188df3fb25e61e58b1944f47e4b855f464f4`**，隔離工作樹 `g08-rc4-validation`，版本 `0.6.1-g08-rc4`。正式入口／base version／原 v0.6.1 包保留，不合併 main。**固定包原生長測 1804.213 秒／1548 項、另一程序讀取長測存檔 97 項及普通啟動／退出通過；新包實體鍵鼠／Xbox 尚未驗收，G08 整體未完成。**

## 包與來源

目錄：`builds/g08/rc4-fixed-0bb2188-v2/`，各 role 保留獨立 EXE／PCK。

| Role | PCK SHA256 |
| --- | --- |
| candidate | `cda06c308442128628490ef2651548c7fd34b185fbf6976f9b36604d319d05b8` |
| qa | `0f65e1c4a7adca01f0a08c0dbfb6b42b31d6b06da77ec37fcf422c07fd6e05f8` |
| qa-soak | `9066003b49c0bbce9e4cfa7c1eb1cc7beb523e258bd5ec782e9be433b753bb39` |

三個 EXE 均為 Godot 4.7.2 Windows x86_64 release template，109268480 bytes，SHA `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`。未內嵌 PCK，不宣稱三個 PCK 相同。

新工作樹最初為乾淨 `0bb2188`。Godot 首次 Check 自動正規化 `default_bus_layout.tres` 的 UID／預設值；保留診斷後，僅還原剛自動產生的此檔，再直接匯出。實測 export 不再次改寫它；v2 三包皆來自原提交音訊來源。匯出後僅 Godot `.import` 自動更新列在收據，沒有遊戲原始碼 overlay。第一次含正規化音訊的包留在 `rc4-fixed-0bb2188/` 作診斷，不是本表交付對象。

## 已完成驗證

- 可玩 EXE 原生啟動 smoke exit 0；release QA 完整序章 **162／0**、另程序讀檔 **46／0**，各約 12.586／30.655／7.939 秒。不是 30 分鐘通過。
- 兩次獨立 PCK 稽核均為 candidate 790 entries／QA 960 entries；**786 個共用 runtime 檔案雜湊完全相同**，包含隱藏匯入及編譯資源。來源參考、tests／tools／docs／source_assets／artifacts／builds／blend 等禁入路徑為空，未帶入 NPC 來源描述檔。
- 六個既有 NPC slot、男性村民保留、女性未放置；既有四個重製 NPC 的模型及 Idle／Talk 隨重啟恢復。莉雅只入隊一次，Q001／E008 獎勵收據、金幣／EXP／星印、森林前置與 Boss 勝利 Gate 保留。
- 已查看本固定包 Boss、村莊交易後及礦坑的實際 viewport 截圖。此包仍使用已驗收的舊主角 locomotion GLB；新 Ren／Lia 候選狀態沒有被誤標為正式替換。

原生短測命令：

```powershell
./tools/test_windows_candidate.ps1 -CandidateExe builds/g08/rc4-fixed-0bb2188-v2/candidate/ProjectCrystal.exe -QaExe builds/g08/rc4-fixed-0bb2188-v2/qa/ProjectCrystal.exe
python tools/audit_windows_candidate.py artifacts/g08/20261022-121605/manifest.json
python tools/audit_windows_candidate.py artifacts/windows_rc4_fixed_20261022/soak_pack/manifest.json
```

可審閱證據及 SHA 清單：[source_assets/windows_rc4_fixed_0bb2188](../source_assets/windows_rc4_fixed_0bb2188/README.md)。完整原始資料仍在本機 ignored artifacts，不提交玩家存檔、快取、EXE 或 PCK。

## 原生 Release 長測

`./tools/test_windows_release_stability.ps1 -QaExe builds/g08/rc4-fixed-0bb2188-v2/qa-soak/ProjectCrystal.exe -Mode Soak`，證據 `artifacts/g083/20261022-121807/`。PID 12900 正常 exit 0；`complete=true`、Windows、release、PCK SHA 符合上表，**1548／0、27 輪、81 次切圖、54 次可選戰鬥、162 次存檔驗證／套用**。Soak 1804.212708 秒，含前置序章的腳本取樣 1832.423659 秒，OS 程序總時間 1835.636150 秒。

GPU：RTX 3080／Compatibility。60 FPS 上限，QA 關閉 VSync；不是未限幀容量測試。先自動完成一次序章及 Boss 敗北重試，再在三圖實際以 InputMap 移動、服務交易、X001／X003 可選遭遇與存讀檔；不是人工 30 分鐘通關，也不是隨機遭遇系統驗收。長測期間沒有啟動其他 Godot／Blender／ComfyUI 工作；有文字整理及輕量來源檔盤點，不宣稱 OS／driver 完全獨占或清除快取。

| 分區 | 平均 FPS | 平均／P95／P99 ms | 最大幀 ms | Draw Calls min–max |
| --- | ---: | --- | ---: | --- |
| 灰石村 | 60.003 | 16.666／16.716／16.786 | 22.308 | 99–169 |
| 低語森林 | 60.002 | 16.666／16.733／16.880 | 19.304 | 368–429 |
| 礦坑 | 60.002 | 16.666／16.712／16.791 | 18.903 | 176–191 |
| 戰鬥 | 58.504 | 17.093／16.764／18.735 | 186.996 | 103–370 |
| NPC／交易 | 58.920 | 16.972／17.249／28.951 | 133.276 | 99–336 |
| 序章／啟動 | 37.934 | 26.362／17.317／144.814 | 3060.864 | 0–583 |

分區是測試 phase，含該段存讀、診斷及截圖成本，不能全部當作純渲染時間或將分區 P99 平均成全程 P99。原始 aggregate、首 300 個 >33ms spike、操作／截圖跨度與全部程序記憶體 CSV 已保存；此既有長測器沒有持久化每一個原始幀向量，不宣稱提供了完整逐幀 GPU trace。

- Working Set 取樣峰 758.293 MiB、結束 734.371 MiB；OS 歷史 Peak Working Set 761.566 MiB。Private Bytes 峰 1917.434 MiB、結束 1861.629 MiB。起始值含資源尚未載入期，不拿起終差額判定洩漏。
- 每圖 27 個 checkpoint 的 nodes／objects 均一致：村 1069／4122、林 833／3919、礦 458／3595。Release 引擎靜態記憶體及孤兒監測不可用，摘要列 null，不聲稱 0 bytes 或已排除所有資源洩漏。
- 轉場含原有淡入淡出，81 次平均／P95／最大 328.865／331.756／332.137ms。存檔驗證＋套用平均 364.650ms、最大 367.250ms，同樣包含等待及場景切換，不等於純 JSON 解碼成本。
- 戰鬥 launch→首個玩家輸入平均 558.919ms、最大 1133.082ms，含敵方先手／動作等待，不等於單幀停頓。

### 尖峰診斷及處理結論

本固定包 loading trace 為 splash→ready **8271.526ms**；loading_resources→creating_world 2222.400ms、creating_world→waiting_map 831.623ms、waiting_map→preparing_picture 5005.154ms。這些是呈現階段跨度，包含 frame 等待／首次繪製，**不是 GPU timestamp 或單一函式 CPU 時間**。啟動仍有秒級工作，處理方式是先呈現獨立 loading UI、完成首次世界繪製後才解鎖；沒有宣稱把 3 秒最慢幀消除。

另程序 `-Mode Detail`，相同固定 PCK，**38.582 秒／208／0**，非長測。五個 production 方法的來源／去時間戳等價契約 11／0、三個反破壞單元測試通過，包含實際序章／重試與六次暖機戰鬥。暖機 arena setup 5.707–6.287ms、stage setup 5.639–6.116ms，讀檔位置 query/free 0.025–0.042ms，動態地形／physics 等待 24.176–26.349ms；不能把這些小段相加當作整幀成本。

短診斷另有 X003 最大幀 **582.440ms**，十二張截圖 encode/write 34.165–177.300ms，與長測最大 186.996ms 分開保存。尚未取得 GPU／driver 函式 trace，不能將差額全歸因於某個 shader 或宣稱完全修復。處理結論：啟動由 loading 邊界承接，暖機戰鬥／服務尖峰列為待改善的已知問題，保留對應診斷及原始數據；不因 FPS 限速或短測通過而抹除。未見主線阻斷、存檔損壞、崩潰或引擎錯誤，實體操作感受仍待新包人工確認。

## 長測後重啟、啟動器與剩餘 Gate

同一長測 profile、同一 PCK 的新程序 `--reload --probe-loads`，**13.701 秒／97／0**：讀取長測實際留下的 `g08_tests/prologue.json`，金幣／EXP／裝備／旗標／獎勵帳本保留，讀前讀後存檔 SHA 相同，長測 metrics SHA 亦相同。最初 preflight 找不到預想的 `g083/soak.json`，未啟動程序；查明父類 `_run()` 覆寫 slot 後使用實際檔案，沒有建立假存檔或放寬驗證。短 Probe 不加算成長測時間。

`tools/start_rc4.cmd` 已複製至可玩包。重用既有普通啟動測試、指定這份 RC4 launcher（工具歷史輸出標記仍叫 RC3）；實際等待 8.156 秒，視窗保持存活／responding，正常 CloseMainWindow 後遊戲及 launcher exit 0，獨立 profile／local／temp／日誌正常。這不是實體輸入驗收。

正式 v0.6.1 EXE／PCK SHA 再核對維持 `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`／`a8c95f156c55a0cf15cb6b71e617c435868eb6822d0c08a014fbdefbb42002b7`。

2026-10-18 的 826 秒失敗輪次及額外切圖來源未確定，仍見歷史 [G08.3 報告](GREYSTONE_G083_REPORT.md)。本輪受控輸入長測沒有重現，不表示已證明那次失敗根因或修復了未確認的生產 bug。

下一 Gate：依 [操作說明](RC4_PLAYTEST_GUIDE.md) 完成本包實體鍵鼠與 Xbox 序章、商店／旅館、保存關閉重開讀取；不沿用 RC3 人工結果。G08.4／G08.5／完整第一章未開始；剩餘主角與環境素材保持待辦，Android／iOS 暫停。
