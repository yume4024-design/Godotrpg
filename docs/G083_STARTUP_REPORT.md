# G08.3 Windows 啟動診斷與 RC4 載入邊界

日期：2026-10-22（Asia/Taipei）。分支 `feature/greystone-g06`；本輪起點 `e435e67a6c36e6ccd52c3af950fa2148aa9fda1d`。**啟動修正與短程回歸通過；RC4 固定提交的 30 分鐘 Release／實體鍵鼠及 Xbox 驗收仍待，不宣稱 G08 完成。** Android／iOS 暫停，第一章未開始。

## 結果與測量範圍

凍結 RC3 可玩 PCK `2758b063385a25e724b13a546cff9585f65557dafed2989ebad005baf276d13c`，在獨立工作樹加入純觀測 QA 主迴圈。實體 PCK 稽核包含隱藏的匯入及編譯資源：702 個原條目中 699 個完全一致，僅 project.binary、UID／global class cache 三個包裝中繼資料不同；沒有替換遊戲方法。新增的 bootstrap 為此次待測呈現邊界。完整差異清單及匯出收據見[證據](../source_assets/windows_startup_20261022/README.md)。

以下均為 **60 FPS、Windows 原生 Release、同一程序內腳本初始化後的牆鐘時間**。各條件 2 次，保留所有原始幀與截圖成本，另有 9 次不限幀基線，合計 21 次。每例至少 180 幀、原生顯示、exit 0、errors 為空。這是短程診斷，不是 30 分鐘或人工通關。

| 條件 | 原入口首幀 pre/post draw 牆鐘 ms | 載入畫面出現 ms | 遊戲可操作 ms |
| --- | --- | --- | --- |
| 新 APPDATA 目錄 | 2497.074、91.345 | 37.054、35.486 | 1161.898、1142.249 |
| 重用相同 APPDATA | 27.271、27.836 | 28.259、28.635 | 1098.688、1098.270 |
| 只複製自身 shader cache | 63.431、64.439 | 33.379、34.074 | 1127.452、1127.489 |

原入口首個 script frame 前尚有約 618～634ms 同步準備工作。改後先顯示載入畫面，再載入／建立現有遊戲，等場景與兩個穩定渲染幀後淡出；載入中阻止輸入誤觸。候選遊戲加入 60 FPS 上限，避免原候選不限幀造成額外負載。

**表格不是 EXE 啟動總時間、GPU timestamp 或冷驅動快取證明。** OS／驅動快取未清除，基線先於載入畫面組執行，共享狀態可能影響首次 2.5 秒峰值；不能據此宣稱該峰值完全由應用 shader cache 引起或已消除。可確認的是載入 UI 已在實際遊戲資源載入及世界首次繪製前呈現。程序總時間、RSS／private bytes 每 100ms 原始值留在 CSV，不把 Release 的 unavailable 引擎記憶體 monitor 當作 0。

## 實作與失敗處理

- 新增獨立 `windows_candidate_bootstrap.tscn`，僅 G08 candidate feature 使用。正式 `main.tscn`、base version `0.6.1` 及 v0.6.1 輸出保留；RC4 覆寫版本為 `0.6.1-g08-rc4`。
- bootstrap 不持有角色／金錢／旗標／存檔政策；使用原遊戲實例與既有 RPG Managers。`game_created` 訊號只供 QA 在實例進樹前注入獨立存檔路徑。
- 曾嘗試 threaded 全場景載入：劇情斷言通過但 native verbose 退出有 3 個 RefCounted 遺留；同步原入口控制無此問題，故拒用該版本，採先呈現 UI 後同步載入。
- 缺場景與逾時均顯示中文原因及可按 Enter 的結束按鈕。逾時立即刪除新 World3D 曾留下 2 個 GLES3 texture；改為完成首個 render submission 後釋放。最終錯誤分支各 5／0，日誌無該錯誤；失敗版保留。
- 原 detailed profiler 的 stage 副本落後正式三敵錯位及 Boss 高度，導致 11 項契約中 3 項失敗。同步原本工作內容與兩個來源 SHA，現在 11／0，3 個契約單元測試通過；沒有放寬等價性比對。
- Windows 包稽核改為枚舉隱藏實體資源。初次 RC4 草稿的序章 162／0、重啟 46／0，但稽核抓到 `npc/` 四個來源圖 `.import` 描述檔，因此 **該草稿拒作交付**。三個 G08 presets 補排除 `npc/*`，固定提交重新匯出／稽核待下輪紀錄。預設產生器偵測到後方非自管 presets 而拒絕覆寫，未刪除其他 QA presets。

## 已執行回歸

| 驗證 | 實際結果 |
| --- | --- |
| Godot 4.7.2 專案載入 | Check exit 0 |
| 原 G06 16 模式 | 576／0；含事件、交易、碰撞、舊檔與單次獎勵 |
| 原生 loading 實例完整序章 | 76／0，載入中 E／W 不會推進對話或移動；戰鬥返回正常 |
| 另一程序重啟讀檔 | 16／0，載入畫面移除、同一遊戲實例與存檔保留 |
| 原生缺場景／逾時 UI | 各 5／0，實際按鈕事件正常結束程序 |
| RC4 草稿 Release | 序章 162／0、重啟 46／0；包內容失敗，不能列為交付包 |

六個既有 NPC ID／互動位置不變，原男性村民保留，女性只留候選。沒有改角色 ID、戰鬥數值、技能、劇情旗標、獎勵收據或 SaveCodec／Schema。新莉雅仍是頸領不合格的靜態候選，未啟用為正式角色。

## 可重現命令與下一步

```powershell
./tools/test_windows_bootstrap.ps1
./tools/test_windows_bootstrap.ps1 -Reload
python tests/test_g083_detail_contract.py
# 固定提交的隔離工作樹匯出後，指定兩個確切包，避免隱含重匯出：
./tools/test_windows_candidate.ps1 -CandidateExe <candidate.exe> -QaExe <qa.exe>
python tools/audit_windows_candidate.py <manifest.json>
./tools/test_windows_release_stability.ps1 -QaExe <qa-soak.exe> -Mode Soak
```

歷史凍結 RC3 診斷可用 `export_g083_startup_probe.py`、`audit_g083_startup_pack.py`、`probe_g083_startup.ps1`；工具故意鎖定原 RC3 提交／PCK SHA，不得用來證明其他版本等價。原始檔保留於 artifacts／builds，精簡可審閱證據存 source_assets。

接下來固定 RC4 source SHA，於隔離工作樹重新匯出可玩／QA／soak 包並完成實體資源稽核；再跑至少 1800 秒原生 Release 長測、另程序重啟及新包人工鍵鼠／Xbox。舊 RC3 的人工通過不轉移到 RC4。G08.4／G08.5、未完成角色與素材及完整 C1 仍保持待辦，不合併 main。
