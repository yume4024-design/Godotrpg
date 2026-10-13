# P6 整合試玩紀錄（進行中）

日期：2026-10-13，Asia/Taipei；程式基線 `7ac24a7`。0.6.0 Windows 候選試玩版已匯出；**P6 尚未全部完成**，仍待玩家完整手把通關、20～30 分鐘節奏／時長與長時間效能驗收。最新使用者場景參考已記錄於 [場景方向](SCENE_ART_DIRECTION.md)，尚未套用到遊戲。

## 本輪交付

- 沿用原創圓潤卡通模型和關節動畫；加入四段短循環合成配樂（村莊、森林、礦坑、戰鬥）、七種互動／戰鬥／星晶音效，以及攻擊／治療／防禦光環。
- AdventureAudio 是 Main 的常駐呈現組件。六個音效聲道、兩個音樂播放器，0.65 秒交叉淡化；Music／SFX 分流，Master 限幅。無頭模式不啟動音訊播放；圖形測試另驗真正混音器输出。
- 手冊新增音量／靜音，透過 Audio 的修改入口保存至獨立 ConfigFile，不改冒險存檔 v1。調整音量後焦點留在原本的音量組。
- 明確配置 Xbox 左搖桿／十字鍵移動、A 互動／確認、B 返回／取消目標、Menu 手冊、LB／RB 循環焦點。沿用 Input.get_vector 的圓形死區；鍵鼠提示可切換。
- Windows release 模板、匯出預設、模板安裝、打包、匯出驗收與 PCK 比對工具。正式 PCK 排除 tests、tools、docs、source_assets；QA 預設使用同一 release 模板與獨立測試入口。

## 實際測試

引擎／模板：`4.7.2.stable.official.ed1daf0bf`。Windows 11 專業版 `10.0.26300`，AMD Ryzen 5 5600、31.89 GiB RAM、NVIDIA RTX 3080／617.42，Compatibility/OpenGL 3.3。圖形測試使用真正渲染、GUI 按鈕與 Godot InputEventJoypadButton；路程有移動至起測點，戰鬥仍由真實指令完成。

| 指令／案例 | 實際結果 | 日誌（artifacts/logs） |
| --- | --- | --- |
| Test / TestPhase2 / TestPhase3 / TestPhase4 | 24／58／75／70 項回歸通過 | test-20261013-164430-733.log；testphase2-20261013-164445-554.log；testphase3-20261013-164452-241.log；testphase4-20261013-164500-151.log |
| TestPhase5 / TestPhase5Reload | 69 功能／7 跨程序通過 | testphase5-20261013-164507-962.log；testphase5reload-20261013-164524-757.log |
| TestPhase6（音量焦點追加檢查前） | 84 項通過，無頭不驗聲音輸出 | testphase6-20261013-164233-932.log |
| VisualPhase6 | 95 項通過，含音量焦點追加檢查、兩場主線勝敗／重試、手把選指令與目標、保存／損壞檔／讀取、音訊 PCM 非零且未達削波值 | visualphase6-20261013-164504-792.log |
| ControllerProbe | XInput Controller，7 項實體輸入全部收到，34.90 秒；沒有注入按鍵 | controllerprobe-20261013-164727-629.log |
| ExportWindows / ExportQA | 正式／QA release 匯出成功 | exportwindows-20261013-212221-699.log；exportqa-20261013-165607-049.log |
| test_windows_build.ps1 -Mode Smoke | 正式執行檔從 builds/windows 獨立啟動，180 次迴圈後正常退出 | exported-smoke-20261013-165508-234.log |
| test_windows_build.ps1 -Mode QA | QA release 自新遊戲到交付，95 項通過；37.675 秒加速測試，不是遊玩時長 | exported-qa-20261013-165627-002.log |
| test_windows_build.ps1 -Mode Reload | 新程序讀回完成狀態、金幣、EXP、裝備及星印，連同呈現測試共 22 項通過 | exported-reload-20261013-212257-276.log |
| PCK 清單／內容比對 | 正式 197 項，QA 217 項；共 194 項完全相同，僅 project.binary／class cache／UID cache 不同。正式不含測試／工具／文件資源 | artifacts/phase6/windows-pack.json、qa-pack.json |

實體硬體資料：`artifacts/phase6/controller_hardware.json`，名稱 `XInput Controller`，Godot 判定 known=true。實收 A／B／Menu／LB／RB／十字鍵／左搖桿；這項基本輸入測試**不等同使用者已用手把完整通關**。

聲音已檢查 WAV 生成峰值、循環匯入、播放器數量、靜音與設定持久化，並在圖形模式驗證真正的混音 PCM。尚未有人工作曲／混音聽感評審；目前是短循環原創合成音樂，沒有角色配音。

## 效能與畫面

以下為第一次完整 QA release 圖形測試，各場景預熱 0.5 秒後採樣 120 幀，1280×720。這是短時樣本，不是最低硬體或長時間保證。

| 區域 | 幀間隔中位數 ms | p95 ms | 最大 ms | draw calls |
| --- | ---: | ---: | ---: | ---: |
| 村莊 | 16.667 | 16.717 | 16.832 | 1214 |
| 森林 | 16.668 | 16.716 | 16.788 | 967 |
| 礦坑 | 16.666 | 16.722 | 16.791 | 299 |
| 戰鬥演練 | 16.668 | 16.689 | 16.840 | 439 |

此樣本約 60 FPS，未測得需要本輪優化的持續瓶頸。release 模板的 MEMORY_STATIC 回傳 0，視為不可用；不宣稱零記憶體。編輯器圖形執行靜態記憶體約 224～310 MiB。後續重啟測試採樣呈現不同幀率，不以它宣稱效能改善。

畫面證據在 `artifacts/phase6/` 與 `artifacts/phase6-export/`。已檢視音量選單、960×540 任務日誌及防禦光環；檢查範圍的 0～2 分：SPACE-PANEL-PAD 2、COMP-SAFE-EDGE 2、COMP-THIRD-HUD 2。光環規模保持小，不蓋住 HP 或目標；未聲稱完整美術評分認證。

## 匯出來源與可重現步驟

模板來自 [官方 4.7.2 頁面](https://godotengine.org/download/archive/4.7.2-stable/) 的 godotengine/godot-builds release 資產，檔案 `Godot_v4.7.2-stable_export_templates.tpz`。官方 SHA256：`f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`，已完整驗證；只安裝 Windows x64 與 ICU 至工具隔離 profile。未升級引擎或新增外掛。

```powershell
python tools/install_export_templates.py '官方模板.tpz'
.\tools\godot.ps1 -Mode Check
.\tools\godot.ps1 -Mode ExportWindows
.\tools\godot.ps1 -Mode ExportQA
.\tools\test_windows_build.ps1 -Mode Smoke
.\tools\test_windows_build.ps1 -Mode QA
.\tools\test_windows_build.ps1 -Mode Reload
.\tools\package_windows.ps1
```

`python` 可換為本機 Python 執行檔。試玩說明見 [PLAYTEST_GUIDE](PLAYTEST_GUIDE.md)。遊戲存檔與音量設定均寫 user://；測試使用獨立 profile。引擎及其第三方授權由已安裝引擎的 Engine 授權 API 產生，見 [GODOT_LICENSES](GODOT_LICENSES.txt)。

最終正式包再啟動通過：`exported-smoke-20261013-212741-761.log`。本機 ZIP：`builds/ProjectCrystal-0.6.0-windows-x64.zip`，40,777,714 bytes，SHA256 `6dbd27150af622e53043da242ee1edd364c412f8360a6a6df2c1295f57a393bc`。ZIP CRC 檢查通過，僅含 exe／pck／試玩說明／素材清單／引擎授權／SHA256 清單；沒有 QA 執行檔或測試腳本。ZIP、模板與畫面未納入 Git。

## 修復與未完成

- 修復 Godot 預設 UI 動作缺少手把鍵、B 無法關手冊、同名音量按鈕導致焦點跨組。
- 音效初版在快速無頭退出時出現播放資源滯留；無頭不啟動音訊、離樹停止播放器，圖形驗收仍驗真正音訊輸出。
- 匯出暫存受 sandbox 位置影響，工具改用專案 TEMP／TMP。release 禁止 --path 覆寫，改成獨立啟動與 QA feature 專用 MainLoop；測試目錄取消 .gdignore，改由正式匯出排除，保留新增 .uid。
- 第一次 QA 入口因測試腳本尚未匯出而未啟動；修正後才得到 95 項通過。曾因自動審核額度限制中斷重啟測試，重置後已補做 22 項通過。
- 尚待：按新參考圖改造灰石村、玩家實機完整通關、20～30 分鐘節奏／時長、長時間穩定性、其他硬體與無繁中文字型系統。不能將本輪標為 P6 全部完成，也未開始第一章。
