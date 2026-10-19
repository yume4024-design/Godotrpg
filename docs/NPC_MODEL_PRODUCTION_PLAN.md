# NPC 模型製作與整合計畫

2026-10-20。A01 建立需求清單，A02／A05 尚未開始。

| 順序／ID | NPC | 四視圖候選來源 | 狀態 |
|---|---|---|---|
| N01 | Blacksmith | npc/鐵匠-{正面,左側,背面,右側}.Png | NOT_STARTED |
| N02 | Item Merchant | 本輪來源入口未找到完整四圖 | BLOCKED（缺來源圖） |
| N03 | Innkeeper | 本輪來源入口未找到完整四圖 | BLOCKED（缺來源圖） |
| N04 | Village Citizen Male | 本輪來源入口未找到完整四圖 | BLOCKED（缺來源圖） |
| N05 | Village Citizen Female | 本輪來源入口未找到完整四圖 | BLOCKED（缺來源圖） |

四類缺圖為當前檔案入口盤點結果，不表示已搜索使用者所有磁碟；A02 先再核對專案來源與後續提供的圖片。

每套整理為獨立 front.png／left.png／back.png／right.png 的 PNG RGBA。保留原路徑，不直接搬移或覆蓋。鐵匠既有 source_assets/quality_characters_20261018/blacksmith 高面數與約萬面動作候選必須先盤點；特別確認背部腰間已去除舊工具袋／工具、保留皮帶／圍裙，並核對拇指解剖方向。候選來源存在不等於修正版已驗收。

每個 NPC 最多 15000 triangles，固定配件計入，Idle／Talk／必要互動動作與掛點各自驗收。僅換外觀；NPC ID、對話、交易、旅館、觸發範圍、任務與存檔不變。巡邏不是模型整合的隱含完成項。
