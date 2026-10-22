# 新版礦坑支架整合證據

2026-10-22；起點bb1ac68，實作／限制見[報告](../../../docs/ENV02_MINE_SUPPORT_INTEGRATION_REPORT.md)。

- baseline.json：替換前原生凍結的34碰撞multiset、四互動、標記、九核心來源及475實際膠囊占用；拒絕覆寫。
- before_result.json／before.txt：18／0；result.json／after.txt：84／0，後者含16段真實Player InputMap走跑及短時全圖觀測。五張WebP是實際Godot viewport，已查看；美術局部與整體限制見visual_review.json。
- rejected_*：初始轉場等待、測試方向／資料驗證及自動輸入互擾三次失敗，未計通過。
- regression_passed.json與regression_logs.json.gz：最終16模式576／0的manifest及完整日誌。只有VisualG06Story明確移除該QA程序joypad-motion，Phase6及觸控保留原綁定。
- regression_*failed：首次Boss返回位置偏差及隔離設定過廣破壞刻意手把注入的失敗manifest／日誌，均保留。
- inventory_runtime.json.gz／inventory_summary.json：實際三圖實例盤點，107GLB／12貼圖來源；不是可見面數、藝術或效能驗收。
- preservation.json：核心來源UTF-8 LF SHA、正式v0.6.1與固定RC4包原SHA均不變。沒有提交本機存檔、.godot、EXE／PCK或個人設定。

圖形為Windows Compatibility／RTX3080。全圖各300幀60FPS上限，不能冒稱30分鐘、人手實測、未鎖幀容量或Android／iOS通過。支架Draw Calls增加已記錄，主角、其他環境、G08及完整第一章未完成。

SHA256.json的文字檔以UTF-8、LF、無BOM計算，避免Git Windows換行正規化造成假差異；WebP／gz等二進位按原始bytes。壓縮檔為gzip JSON，可用Python gzip.open(...,'rt',encoding='utf-8')檢視。
