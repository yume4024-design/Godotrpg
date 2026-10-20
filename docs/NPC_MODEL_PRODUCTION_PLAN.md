# NPC 模型製作與整合計畫

2026-10-20。A02 已完成 NPC 五套來源結構及四面檢視；四組新設計由使用者回覆「四組都採用」。獨立 NPC 素材製作已先推進；正式整合仍保留 A03／A04 Gate，未宣稱可用角色已完成。

| 順序／ID | NPC | 四視圖候選來源 | 狀態 |
|---|---|---|---|
| N01 | Blacksmith | reference_library_20261020/npc/blacksmith/references | 候選 Idle／Talk PASS：9937 面、19 骨、98 影格、Godot 213＋19／0；正式整合未開始 |
| N02 | Item Merchant | 同庫 npc/item_merchant/references | 來源 PASS；A05 IN_PROGRESS：12573 面靜態候選／14 項圖形檢查，骨架待製作 |
| N03 | Innkeeper | 同庫 npc/innkeeper/references | 來源 PASS；A05 NOT_STARTED |
| N04 | Village Citizen Male | 同庫 npc/villager_male/references | 來源 PASS；A05 NOT_STARTED |
| N05 | Village Citizen Female | 同庫 npc/villager_female/references | 來源 PASS；A05 NOT_STARTED |

上次四類缺圖已補製並核准，不能再列為阻擋。來源庫前綴為 source_assets/；詳見 [A02 報告](ASSET_A02_REPORT.md)。

每套整理為獨立 front.png／left.png／back.png／right.png 的 PNG RGBA。保留原路徑，不直接搬移或覆蓋。鐵匠既有 source_assets/quality_characters_20261018/blacksmith 高面數與約萬面動作候選必須先盤點；特別確認背部腰間已去除舊工具袋／工具、保留皮帶／圍裙，並核對拇指解剖方向。候選來源存在不等於修正版已驗收。

每個 NPC 最多 15000 triangles，固定配件計入，Idle／Talk／必要互動動作與掛點各自驗收。僅換外觀；NPC ID、對話、交易、旅館、觸發範圍、任務與存檔不變。巡邏不是模型整合的隱含完成項。
