# Mine support frame source and acceptance

本專案原創參數化模型，重用G04木材／端木／鐵材；沒有商店下載或付費生成。`mine_support_frame.blend`為可編輯來源；遊戲GLB只保留在assets/models/environment，未重複提交同一GLB。

`build.json`為最終Blender輸出收據，804／1200面、三個268面部件，按原柱／樑尺寸檢查；最終native Blend SHA為`484767ba21facc87758f2a5180c1c091889fee2afcd70e40ca3aefa34abceb46`。`preservation.json`包含builder／GLB SHA、18個正式核心／資料檔保留及no-focus設定清除證據。

`structural.json`是headless53／0；`graphical.json`是Windows原生58／0、no-focus window=true。四張WebP為實際Godotviewport，並非生成概念圖；已查看各角度，適用視覺項目與限制見`visual_review.json`。膠囊物理測試不是完整Player／實體輸入、正式礦坑或效能驗收。

`rejected_thumbnail.txt`、`rejected_path.*`、`rejected_unisolated_log.txt`保存未採用輪次；只修自己的工具／metadata並重跑，未變更原模型、正式碰撞或SaveCodec。`preview_smoke.txt`只證明新預覽場景可載入。

文字證據統一UTF-8無BOM／LF，SHA256清單以提交後文字為準。正式八組坑木尚未替換，下一步須另做實際礦坑整合／遮擋與存讀回歸。見[報告](../../../docs/ENV02_MINE_SUPPORT_REPORT.md)。
