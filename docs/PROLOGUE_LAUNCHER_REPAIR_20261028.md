# 序章來源啟動器修正 — 2026-10-28

基線 `14c4e5994f86b4e06f89757b7956ea85712d48ba`，`feature/greystone-g06`，Godot `4.7.2.stable.official.ed1daf0bf`、Windows／RTX3080／OpenGL Compatibility。

## 已修正

`tools/godot.ps1 -Mode RunPrologueCandidate` 原本未列入互動啟動模式，落入60秒測試逾時分支，會強制關閉正在遊玩的序章。真實圖形重現於60.848秒返回失敗，訊息為 `Godot exceeded the 60000 ms timeout`。

把候選入口加入互動啟動模式；沿用隔離 APPDATA／LOCALAPPDATA／TEMP／TMP。另發現直接建立 GUI 程序仍可能繼承工具的輸出管線，使外層命令無法結束。最終使用 ShellExecute 啟動圖形程式，Godot 自行寫入既有 `--log-file`；啟動後以 finally 還原呼叫端環境變數。沒有停用測試模式的逾時保護。

## 實測

```powershell
./tools/test_prologue_launcher.ps1
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode RunPrologueCandidate -Describe
```

| 項目 | 結果 |
| --- | --- |
| 修正前圖形重現 | FAIL，60.848秒後被工具終止；`artifacts/launcher/20261028-055338-381/result.json` |
| 加入互動模式但仍直接 CreateProcess | FAIL，外層輸出管線被遊戲持有；只關閉該測試 log 識別的 PID 後才返回 |
| Start-Process 重導輸出試作 | FAIL，同樣保留外層管線；未作為最終實作 |
| 最終公開啟動命令 | **PASS，0.959秒返回，實際圖形視窗觀測71.558秒仍存活且回應正常** |
| 最終日誌 | `artifacts/logs/runprologuecandidate-20261028-060030-046.log`，無 SCRIPT ERROR／ERROR／載入失敗 |
| 專案載入 | PASS，`artifacts/logs/check-20261028-060110-633.log` |
| 工具解析與命令描述 | PASS，仍指向 `res://scenes/main/prologue_candidate.tscn` |

最終程序證據：`artifacts/launcher/20261028-060029-356/result.json`。驗證工具在另一個 PowerShell 程序呼叫公開命令，確認命令已返回、遊戲獨立存活超過原60秒限制、存在可回應視窗、圖形渲染器及無錯誤日誌；最後只關閉本次回報的遊戲 PID。這是啟動生命週期測試，**不是30分鐘序章通關、效能長測或實體 Xbox 驗收**。

## 範圍與未完成

修改 `tools/godot.ps1`、新增 `tools/test_prologue_launcher.ps1`，更新任務與變更紀錄。遊戲程式、角色、場景、數值、劇情、存檔 Schema 均未改；本輪沒有重新宣稱整套序章回歸。既有固定 RC2 保留，其 `.cmd` 啟動器不受本次來源工具缺陷影響；RC2也不含後續展開地圖，尚未重製新包。

同期完成莉雅局部頸部試作的證據整理，見 [莉雅報告](LIA_REBUILD_20261022_REPORT.md) 與 [三版原生畫面](../source_assets/character_rebuild_20261020/lia/authored_neck_acceptance_20261028/README.md)。僅保留靜態候選，不能算角色完整修復。人工美術／實體輸入、Android／iOS及第一章仍暫停。
