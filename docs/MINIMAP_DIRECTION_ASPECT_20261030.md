# 縮略地圖斜向箭頭比例修正 — 2026-10-30

序章候選的地圖道路、地標與角色位置按地圖顯示區域及世界範圍分別縮放 X／Z；人物箭頭先前直接使用世界方向，當畫面區域或地圖範圍不是等比例時，斜向箭頭與地圖上的前進方向不一致。此輪將箭頭方向套用相同座標比例後正規化；地圖資料、玩家控制、碰撞、故事和存檔沒有改動。

## 重現與測試

Godot `4.7.2.stable.official.ed1daf0bf`，Windows，圖形測試使用 Compatibility／RTX 3080。用獨立測試存檔，未碰觸正式存檔。

| 檢查 | 結果 | 範圍 |
| --- | --- | --- |
| `godot --headless --path D:/RPGGAME --script res://tests/minimap_direction_aspect_test.gd` | 修正前 49 項／17 失敗；修正後 49／0 | 八個方向、三種畫面區域、兩種世界長寬；修正前回退至舊箭頭計算 |
| `tools/godot.ps1 -Mode Check` | 通過 | 載入和腳本解析 |
| `-Mode TestPrologueAreaMap` | 80／0 | 實際鍵盤事件移動後比較地圖方向；三區畫面、地圖開關、模擬手把選擇與存讀檔 |
| `-Mode TestPrologueNavigation` | 31／0 | 村莊／森林／礦坑導航資料與舊村地圖隔離 |
| `-Mode TestMineNavigation` | 224／0 | 八區及橋梯導覽、橋上移動、模擬手把焦點與任務狀態 |
| `-Mode VisualMineReferenceStory` | 94／0 | 序章圖形流程、兩場主線戰鬥、任務獎勵與存檔 |
| `-Mode TestMineReferenceStoryReload` | 24／0 | 另程序續讀、劇情、隊伍與獎勵帳本 |

[鍵盤移動後的遊戲原生畫面](evidence/minimap_aspect_20261030/moving_direction.webp)已檢視。以上鍵鼠／手把輸入由測試程式送出，不等於使用者實體操作驗收；測試涵蓋本次方向計算及既有列出的路線，不代表所有地形已實走。

此前重新審核的 R1–R4 已由 [序章整合修正報告](PROLOGUE_REPAIR_20261027_REPORT.md) 處理；本次不是重新實作。莉雅新模型仍有領口、袖口、衣襬問題及缺少骨架／動作，保持候選，舊可玩模型不替換。RC5 固定包不包含本次來源修改；未重新匯出或重新執行長測。人工驗收、Android／iOS 和第一章維持暫停。
