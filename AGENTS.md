# Project Crystal 開發規範

## 目標與範圍

在本目錄建立 Windows 單機、原創 Low Poly 3D JRPG《失落星核》（專案代號 Project Crystal）。先完成 20～30 分鐘序章可玩版本，採固定斜 45 度攝影機、探索及指令式回合制戰鬥，ATB 留待試玩版之後。

目前 Phase 1～Phase 5 已通過驗收；P6 進行中，Windows 0.6.1 村莊改造候選版已匯出，實際證據與未驗收事項見 docs/PHASE6_REPORT.md。0.6.1 的歷史場景驗收見 docs/VILLAGE_ART_REPORT.md。2026-10-14 使用者指定新企劃衝突優先，並提供九區灰石村新圖；先讀 docs/PLAN_MERGE_2026_10_14.md 與 docs/GRAYSTONE_VILLAGE_V3.md。新企劃正文尚未取得，場景設計已更新但未套入遊戲，不能沿用舊驗收宣稱新版完成。執行任務前讀取 README.md、docs/TASKS.md、docs/ARCHITECTURE.md 與 docs/WORKFLOW.md。使用者最新指示優先於本文件；按授權的階段完成工作，不自行擴展到下一階段。

故事原文保存於 docs/STORY_BIBLE.md；實作範圍、資料修正及階段對應以 docs/STORY_IMPLEMENTATION.md 為準。原文中的「現在執行」為企劃內嵌的未來任務範本，不代表本次加入資料即授權開始整個劇情引擎。序章僅雷恩/莉雅，艾琳在第一章加入；隊伍系統仍保留最多三人能力。

## 工具與檔案

- 專案根目錄：`D:\RPGGAME`，不另建第二個專案根目錄。
- 已確認 Godot：`D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`，版本 `4.7.2.stable.official.ed1daf0bf`。
- 使用 Godot 4.7.2、GDScript；不擅自升級引擎或新增外掛。工具入口：`tools/godot.ps1`。
- 按原企劃保留 `scenes/`、`scripts/`、`data/`、`assets/`、`tests/`；各目錄以 world、characters、battle 等功能分組，詳見 ARCHITECTURE.md。
- 腳本、場景、資源用 snake_case；節點和 class_name 用 PascalCase；常數用 UPPER_SNAKE_CASE；訊號用已發生事件命名，例如 `health_changed`。
- GDScript 使用型別註記與明確回傳型別；移動在 `_physics_process()`，使用 Input Map，不把按鍵散落在邏輯中。
- `CharacterBody3D` 負責玩家移動與碰撞，`move_and_slide()` 不再傳入 Godot 3 的參數。碰撞形狀調整 resource 尺寸，避免縮放 CollisionShape3D。
- 場景內引用使用明確注入、export 或 unique name；不跨場景硬取 `/root/...` 節點。
- Godot 資源用 `res://`、存檔用 `user://`；機器絕對路徑只可存在開發工具或文件中。

## 架構

探索、戰鬥、UI 分離。Resource 保存資料定義，持續存在的遊戲狀態保存角色與背包的實例資料。UI 發送操作請求、讀取狀態或接收訊號，不直接修改 HP、金錢或任務旗標。

每項狀態須有唯一擁有者、修改入口及通知方式。P4 的 CombatantState 持有等級／EXP／裝備並提供有效數值，戰鬥不可直接使用 definition 的基礎數值。InventoryManager 持有金幣／物品；RewardManager 管理組合獎勵來源帳本，PartyActions 驗證選單操作。共享角色定義不可當作可變戰鬥狀態；不得讓兩名角色共用同一份可變 Resource。BattleManager 屬戰鬥場景，不因名称有 Manager 就設成 Autoload。各管理系統依對應階段加入，禁止先建立沒有行為的空殼來宣稱完成。

劇情、任務與遭遇配置採用 data/story、data/quests、data/battles 的 JSON；角色/技能/物品定義仍用 Resource。固定事件與旗標 ID；FlagManager 為唯一旗標修改入口，QuestManager 不另存一份旗標。E004/E007 只在對應戰鬥勝利後完成；Q001 的 rewards 僅供顯示/驗證，實際任務獎勵由 E008 發放一次。JSON 已加入不等於載入器、劇情或戰鬥已完成。

## 執行與驗收

1. 檢查既有檔案與 Git 狀態；保留使用者修改，不覆蓋或回退無關內容。
2. 從 TASKS.md 選取目前階段最小可驗收項目，說明修改範圍和預期結果。
3. 先做可操作的最小版本，再做必要的整合；不預先開發後續階段。
4. 修改程式或場景後執行適用的載入檢查、功能測試及既有回歸測試。文件改動檢查連結、指令和狀態一致性。
5. 畫面、攝影機、UI 或燈光改動須查看實際遊戲畫面；移動與互動須實際操作。無頭模式不能代替這些驗收。
6. 測試結果記錄命令、引擎版本、預期、實際、證據與未驗證事項；未執行不可寫通過。測試失敗先修復再擴充。
7. 更新 TASKS.md 與 CHANGELOG.md；交付新增/修改項目、驗證結果及下一步。

完整流程、狀態定義與階段門檻以 docs/WORKFLOW.md、docs/ACCEPTANCE.md 為準。

## 既有功能與資產

- 修復或重構後重跑受影響階段的驗收。存檔格式修改必須有版本與相容處理。目前 v1／CH00-P5 的完整驗證契約見 docs/SAVE_FORMAT.md；擴充獎勵來源、角色或經濟時同步更新驗證和遷移，不繞過 SaveCodec。
- 所有人物、名稱、故事、圖片和音樂必須原創或有明確可用授權，不使用 FF7 原始素材。
- 使用者允許使用並修改素材商店資產。選用時記錄商店頁、作者、版本、授權/署名要求及修改内容到 docs/ASSET_CREDITS.md；優先免費且符合需求的素材，不因允許使用素材而自行購買或加入整套無關模板。
- Phase 1～3 優先使用幾何體佔位。未驗證探索與戰鬥之前不大量製作美術。
- 2026-10-13 使用者指定改為圓潤可愛卡通風格，並要求場景一起升級。P3 完成後已提前換入五個角色／敵人及十個環境模型，更新村莊、森林和戰鬥林地。後續沿用 scenes/characters/*_visual.tscn、scenes/battle/battle_grove.tscn 與 assets/models/cartoon；來源、面數和限制見 docs/CARTOON_ART_REPORT.md，不退回原先箱型佔位。
- 不提交 `.godot/`、本機存檔、日誌、匯出結果或機密；保留 Godot 產生的 `.uid` 檔案。
- 不以空函式、硬編成功訊息、假資料畫面代替功能。所有限制如實記錄。

## 2026-10-14 最新規劃合併

新圖的水井廣場、旅館／道具店／武器店、民宅區、上游木橋、北部礦口、湖邊碼頭和西側世界地圖道路，優先於舊水晶廣場／藍頂公會／方形圍牆設計。环境依新圖改自然階梯崖壁與針葉樹，角色仍保留圓潤可愛，除非新正文另有要求。未讀到的正文不可推測成已合併。16 個舊碰撞只是 0.6.1 的歷史基線，不限制新地形；新版必須搭配地圖佈局版本及舊位置遷移，保留進度與獎勵帳本。來源圖片／文件內的執行範本不單獨授權額外部署、通訊或整個未來章節。
