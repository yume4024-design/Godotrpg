# 使用者新企劃條目整理 — 2026-10-14

來源為本次對話中使用者直接貼入的《失落星核》灰石村 — Codex 3D 場景建造提示詞。這是供版本控制的完整需求條目整理，**不是逐字原文**；原始貼文保留在對話。先前 Drive 檔案只是分享頁 URL，正文缺失問題現由使用者貼文解決。

## 共通要求

Q 版可愛 Low Poly 簡單幾何體、清楚切面、不用高密度曲面；柔和統一色彩、簡單材質、避免大型貼圖與密集小零件。Godot 4、Blender + MCP、Codex，Windows / Android、iOS 預留，GLB / glTF 2.0，模組化重用，固定斜 45 度鏡頭。不得覆蓋已完成遊戲系統，不引入未許可付費素材。先查 MCP，不可用用可重複 Blender Python，再不可用才用 Godot 原生幾何體。1 unit = 1m、Y 軸向上，路面有碰撞，PC 鍵盤及手機觸控。

## 01 初始化

建立 docs/GREYSTONE_VILLAGE_SPEC.md、docs/GREYSTONE_BUILD_TASKS.md、scenes/world/greystone_village.tscn、scripts/tools/greystone/、assets/models/greystone/。120×120m 暫定可依走道與建築比例調整。先基本地形、道路、建築佔位方塊和攝影機，不一次製作所有精細模型。載入检查、列新增檔、測試與未完成。

## 02 地形

中央廣場、西北農田高地、東側河瀑布、東北高地廢礦坑、南入口、西世界地圖道路，以坡/階梯/低面數岩石表現高差。廣場28×28m，主路4～6m、次路2.5～3m、河6～10m、角色1.6m。平面低面網格、模組崖、藍色透明或不透明水、簡化瀑布、道路材質或石板。入口可走至廣場/旅館/公會/商店/礦坑，不能穿岩壁或掉入非設計區，無明顯破洞，不用正式貼圖也可辨區。

## 03 建築

木骨架淺牆、紅藍棕屋頂、Q版比例、厚門簡窗、低面斜屋頂、簡煙囪/招牌/屋簷、色材質。House_A單層、House_B雙層、Inn、Guild_Hall、Item_Shop、Weapon_Shop、Farm_House。民宅7×6×6m、旅館12×9×9、公會15×11×11、店8×7×7、門有效寬≥1.5m。獨立模型、地面中心原點、統一正面、共材質、正確尺度、不要多餘內部幾何、預留門互動、分別GLB。匯入旋轉縮放正常、用途可辨、簡碰撞、可重複放置。

## 04 環境素材

Pine_Tree_A/B、Bush_A、Flower_A、Grass_A；Rock_Small/Medium/Cliff；Stone_Well、Wooden_Bridge/Dock/Fence、Lamp_Post、Wooden_Sign、Barrel、Crate、Crystal_Blue。松樹2～3層圓錐，岩石6～12主要可見面起步，不用高解析貼圖或細碎裝飾，共材質，手機可辨性/效能優先。獨立可擺、必要簡碰撞、裝飾免碰撞，匯出 assets/models/greystone/props/，Asset Preview 排列查比例材質。

## 05 組裝

Center圓廣場石井或星晶紀念碑與通路；West旅館道具店住宅世界出口；North公會農田松林高地；East武器店河水車木橋；South住宅碼頭入口；Mine廢礦口岩壁星晶及礦坑切換。依 greystone_reference 圖區域關係、沿路建築、不堵路、建物前NPC活動空間、完整探索主路、PackedScene重用，不合成巨大單一模型，建物/道路/植被/碰撞分節點。實走村口至各主要建築/橋/礦坑，45°可玩，地形模型碰撞導航一致，提供樹結構與測試。

## 06 RPG 功能

Guildmaster瑪爾克、Lia莉雅、Innkeeper、ItemMerchant、Blacksmith、Villager。NPC對話、公會委託、莉雅加入、商店、旅館回HP/MP、礦坑切場、西世界地圖出口、巡邏待機、碰撞及距離、任務標記。E001旅館醒來、E002公會委託、E003莉雅、E008Boss後回公會。E004～007森林/礦坑負責，村只負責必要出口和回村觸發。PC WASD/E/滑鼠選單；手機虛擬搖桿/互動/選單，同一遊戲與劇情邏輯。全部互動實際操作驗證。

## 07 效能

Windows60FPS，中階Android30FPS，iOS留同跨平台設計。省面、共Mesh/材質、遠景簡模/可見性、簡碰撞、關無必要動態陰影、限透明粒子、低中高畫質、載入時間、手機比例觸控。記Draw Calls/三角面/記憶體/FPS，無Android設備只能標PC結果，不能宣稱手機合格；優化不移動主路/NPC互動位置。

## 08 驗收

地圖載入、模型材質、地形孔洞、主要建築可達、NPC、公會任務、莉雅入隊、礦坑、戰鬥回村狀態、任務存讀、PC、觸控介面、鏡頭遮擋穿模、相應平台匯出。列實際完成及失敗、修可確認問題、更新TASKS/CHANGELOG、記版本；未測不可完成。

## 工作順序建議

參考圖應放專案可讀位置；提示詞示例 D:/GameProjects/ProjectCrystal 僅示例，現有專案仍 D:/RPGGAME。先按01～08循序；建議首輪01/02/03/05做地形道路基本建物可玩村，再加裝飾/NPC/故事，後用Blender MCP/MODLY替換模型、不重造地圖。MODLY 未授權購買或消耗點數。
