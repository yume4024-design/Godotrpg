# 礦坑碰撞與探索 HUD 修整 — 2026-10-27

> **同日重新審核更正：** 下列 68／0 等結果仍是原測試的真實結果，但不能表示全圖防墜通過。新增橋階邊緣實走 8／8 下墜；小地圖朝向與村莊底圖亦有問題。圖形序章測試沒有交易確認／扣款斷言，交易改以本輪另跑的候選 commerce 套件 50／0＋5／0作證。詳見 [PROJECT_REAUDIT_20261027.md](PROJECT_REAUDIT_20261027.md)。問題尚未修正。

## 本輪範圍

只更新整合候選版使用的礦坑與探索介面；正式 `main.tscn`、v0.6.1、劇情旗標、戰鬥數值及存檔格式均未切換或修改。

### 礦坑碰撞與防墜

- 沿用 Blender 清單內的 501 個既有地形／結構碰撞，額外為 15 個大型平台岩塊及 24 個坑道入口／營地岩塊建立簡化盒碰撞。
- 依八個可行走區域加上低矮防墜碰撞；依橋樑與階梯實際穿越平台邊界的位置留通道。
- 地圖最外圍加四面高牆阻止玩家離開洞穴。沒有鋪設跨越地下水的隱形接地面。
- 小型碎石維持可跨越的地面裝飾，不以密集小碰撞造成卡腳；大型岩塊與結構岩壁有碰撞。

### 導航及 HUD

- 候選 RPG HUD 顯示目前區域、主線目標、委託進度、雷恩與莉雅 HP／MP 條、金幣、恢復藥及旅途手冊入口。
- 右上小地圖依灰石村、低語森林、礦坑切換；顯示區域輪廓／標籤、道路或礦道、礦坑水域、互動目標、出口、玩家位置與朝向，並附顏色圖例及北向。
- 整合候選版的村莊切換、舊檔匯入、觸控和畫質設定移至預設隱藏的 F10 開發面板，避免常駐遮擋；正式入口未接入。
- 對話時隱藏底部移動提示，減少 HUD 重疊。

## 驗證

引擎：Godot 4.7.2.stable.official.ed1daf0bf；Windows 圖形模式，OpenGL Compatibility，NVIDIA GeForce RTX 3080。

- `tools/godot.ps1 -Mode Check`：通過。
- `tools/godot.ps1 -Mode TestMineReference`：68 項、0 失敗。實際 `CharacterBody3D`／InputMap 走測完成礦坑主路線（29 點）、跨橋路線（4 點）、北側階梯路線（6 點）及反向路線（6 點）；外圈、平台邊緣、岩石碰撞通過，地下水無隱形地板。測試 FPS 平均約 59.49，P95 16.713 ms，P99 16.812 ms；這不是 30 分鐘長測。
- `tools/godot.ps1 -Mode TestMineReferenceStory`：78 項、0 失敗（無頭功能回歸）。
- `tools/godot.ps1 -Mode VisualMineReferenceStory`：89 項、0 失敗（Windows 圖形序章回歸）；包含三區切圖時小地圖更新、隊伍狀態卡、F10 開關及完整 E001–E009 序章、Boss、回村、交易和存檔流程。
- `tools/godot.ps1 -Mode TestMineReferenceStoryReload`：20 項、0 失敗；另一個 Godot 程序讀取完整序章存檔，確認主線旗標、委託、角色、獎勵帳本與裝備保留。
- 圖形截圖：`artifacts/godot-user/Godot/app_userdata/失落星核 — Project Crystal/mine_reference_tests/g063-01-mine-entrance.webp`、`candidate_ui.webp`。

## 限制

- 人工鍵鼠／Xbox 操作依使用者指示暫停；未宣稱人工驗收、Windows 發布包、30 分鐘長測或 G08 通過。
- Android／iOS 未測試。正式 v0.6.1 的 HUD 與入口保留原樣；本輪 HUD 改善只接在整合候選版。
