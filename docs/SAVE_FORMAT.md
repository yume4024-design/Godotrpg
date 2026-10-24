# 序章存檔格式 v1

## 2026-10-24 更新參考灰石村位置版4

新版獨立入口為 `scenes/main/greystone_reference_integration.tscn`，新槽 `user://crystal_reference_v4_slot_01.json`；Schema3／CH00-G06.4不變。村莊位置版2或3先在各自原始地圖完成地板／膠囊驗證，再將複本映射位置版4廣場(-3,3.1,3)，再次驗證新圖。來源槽保留，隊伍、裝備、經濟、旗標、任務、劇情及收據不改。新村莊粗界仍x/z±60、y -0.1～10.2m；不能以粗界直接接受水中或岩內位置。舊設定拒絕新版位置，歷史Schema2不能偽稱位置4，無效來源拒絕且保留檔案。本候選同時重用礦坑位置4與森林位置3。[測試證據](GREYSTONE_REFERENCE_20261024_REPORT.md)。

## 2026-10-24 礦坑位置版4（獨立候選）

新`mine_reference_integration.tscn`使用`user://crystal_mine_reference_slot_01.json`，Schema仍3／CH00-G06.4。只有此設定`mine_layout_version=4`接受礦坑位置4；既有入口預設3，森林位置版仍3、村莊仍依各入口2／3。新版礦坑粗界x/z±56、y -0.1～7.2m，之後仍強制實心膠囊與地板驗證，不能直接接受水中或岩內。

舊位置1／3先在原始礦坑／expanded礦坑獨立物理世界驗證，再映射(-44.5,0.1,28)及版本4，再驗新圖。原件只讀，保存新槽；角色、裝備、經濟、旗標、任務及收據保留，v1依既有契約加入零交易帳本。歷史schema2不能虛報位置4，舊設定拒絕未來版，不提供反向降版。[實測](MINE_REFERENCE_REPORT.md)。

## 2026-10-23 Blender 灰石村候選位置版

獨立入口 `scenes/main/greystone_blender_integration.tscn` 使用
`user://crystal_blender_candidate_slot_01.json`，保留 v0.6.1 與原 G06 主檔。
全域 schema 仍為 3、content_version 仍為 CH00-G06.4；只有灰石村的
`location.layout_version` 為 3。原 G06 預設仍為位置版 2，不接受新版座標。
歷史 schema 2 不能宣稱位置版 3；森林／礦坑既有位置版本不變。

讀取灰石村位置版 2 時，先在保留的原地圖獨立物理世界驗證原座標與
候選旗標對應的 NPC 碰撞，再複製狀態，僅映射 location 至新版安全廣場
`(-3, 3.1, 3)`／layout_version 3，最後在新地圖以正式 1.95m 膠囊及地板射線
重新驗證。角色、背包、金錢、交易帳本、旗標、任務及獎勵收據不變。
v1 依既有遷移先進入位置版 2，再通過相同驗證；任一步失敗不套用狀態。
匯入只讀原件，後續保存到獨立候選欄位。

新版粗範圍維持 x/z ±60m，y 為 -0.1～10.2m；舊位置版 2 仍為原上限 6.2m。
這不是物理位置合格證明：讀檔必須通過實際實心障礙膠囊查詢與地板射線。
Blender 方塊代理匯入的空心三角面已在共用 geometry adapter 轉為 BoxShape3D，
避免建物內部被誤認為空間。初次遷移測試 58 / 1 留證，修正後 58 / 0；
擴充歷史版本反例的最終數字見灰石村重建報告。

首次引入於 P5。P1～P4 沒有磁碟存檔，因此沒有需要轉換的舊版遊戲檔。`schema_version: 1`、`content_version: "CH00-P5"` 為本版相容條件；缺少版本、舊於 v1 或未來版本均明確拒絕，保留原檔。後續若改欄位、ID 或內容規則，須增加版本並先遷移成當前資料再驗證，不能直接套用或重置舊進度。

## 操作與路徑

- F5 或 M → 旅程 → 保存；F9 或同頁「讀取旅程」讀取主檔，「讀取上一份備份」明確選擇備份。
- 正式邏輯只使用 `user://crystal_slot_01.json`；備份為同路徑加 `.bak`，寫入暫存檔加 `.tmp`。不把機器路徑存入遊戲資料。
- 使用 `tools/godot.ps1` 時，APPDATA 被隔離到專案 `artifacts/godot-user`；直接從 Godot 編輯器／未來匯出版啟動時使用該啟動環境自己的 `user://`。不同啟動方式不假設共享存檔。
- 啟動發現主存檔時，先開啟旅程頁，選擇讀取或新旅程；不先播放 E001。新旅程不立即刪除舊存檔，直到使用者下次保存才更新欄位。
- 目前為單欄位手動存檔，沒有自動存檔。遊戲結束前請保存；尚未保存的變更不會自動保留。

## 資料欄位

| 欄位 | 內容與唯一狀態擁有者 |
| --- | --- |
| schema_version／content_version | SaveCodec 的格式及內容版本 |
| flags | FlagManager 的固定 ID → bool；事件完成由同一份旗標表示 |
| quests.accepted／completed | QuestManager 的接受／交付狀態；五個目標仍從旗標投影 |
| party | 有序角色 ID、level、exp、hp、mp、equipment；CombatantState 擁有數值，PartyManager 擁有成員 |
| inventory | InventoryManager 的 gold、counts、單物品寶箱 claimed 帳本 |
| rewards | RewardManager 的來源 → gold／exp／items 收據，包括 E005／E006／E008 |
| location | 穩定 map ID 與 x／y／z 數值；沒有序列化 Node、Vector3 字串或 Resource |
| story | EventRunner 的 objective、安全點 active_event 空字串；探索區域敗北後的暫時抑制狀態 |

## 保存與還原契約

1. 對話、演出、戰鬥、转場或還原期間收到保存請求，合併為一筆 pending；在可操作安全點再保存。戰鬥結果必須確認返回後才成為安全點，避免只保存獎勵卻漏掉勝利旗標。讀取在忙碌期間直接拒絕。
2. 保存先建立 JSON 基本型別快照並驗證；寫 `.tmp`、flush、close，保留上一份有效主檔為 `.bak`，最後 rename 更新主檔。失敗會顯示訊息；不把損壞主檔蓋到有效備份。
3. 讀取限制檔案大小 1 MiB。解析和完整驗證完成後，先建立候選角色，尚不修改目前進度。
4. 驗證型別／整數／範圍、已知 ID、角色順序與入隊旗標、EXP 與等級門檻、裝備相容／總持有量、任務與旗標一致、獎勵收據與實際來源一致、關鍵星印數量。當前序章沒有購物或額外 EXP 來源，因此金幣／EXP 必須吻合收據；未來加入新經濟來源須同步擴充版本契約。
5. 地圖存在、座標有限且在合理範圍後，於獨立 World3D 載入候選地圖，使用玩家膠囊檢查障礙物並射線確認地板。不在目前地圖上試放玩家，也不接受晶體內部或懸空位置。
6. 全部通過後鎖定探索，透過各狀態擁有者一次套用，再替換地圖、恢復位置／區域抑制與通知 UI。失敗保留原進度；成功不重播 E001、不重領寶箱、星印或事件獎勵。
7. 備份由使用者明確選擇讀取，不在主檔損壞時靜默倒退。格式驗證失敗不覆寫主檔或備份。

檔案格式為可讀 JSON，沒有加密或防修改承諾；驗證目的是保持可執行與一致的遊戲狀態。未執行斷電、磁碟硬體故障或雲端同步測試。

測試檔只使用 `user://p5_tests/restart.json`／`visual.json`，不讀寫正式欄位。跨程序測試先執行 TestPhase5，再執行 TestPhase5Reload；後者從另一個 Godot 程序讀取前者留下的檔案。指令與結果見 [PHASE5_REPORT](PHASE5_REPORT.md)。


## G06.1 opt-in schema 2（2026-10-14）

上述 v1 規則繼續適用正式 main.tscn。新 greystone_integration.tscn 使用獨立 crystal_g06_slot_01.json、schema_version=2、content_version=CH00-G06.1。location.layout_version 在舊三圖為 1、新 greystone_runtime 為 2，其他組合拒絕。

v1 必須先通過全部原驗證和原地圖膠囊/地板查詢；合法舊村位置映射 (0,0.1,48)，森林/礦坑原位保留，再驗新版完整狀態與位置。讀取不改寫原檔，明確保存才寫新欄位；舊正式模式拒絕 v2。詳見 [G06報告](GREYSTONE_G06_REPORT.md)。


## G06.4 opt-in schema 3（2026-10-15）

整合入口目前寫 schema_version=3 / content_version=CH00-G06.4，位置 layout_version 維持舊三圖 1、新村 2。新增 inventory.commerce，只有 potion_bought（0～9999 整數）及 inn_stays（0～10000 整數）。金幣必須精確吻合原獎勵金幣總額減去購入數×5及住宿數×10；藥品上限加入購入數，允許正常消耗。EXP、星印、裝備與事件收據驗證維持原契約。

v1/v2 不接受 commerce 欄位。SaveManager 先完成來源格式與物理位置驗證；v1 先走既有位置遷移至 v2，再加零交易帳本升至 v3；v2 保留原位置加入零帳本。升級後再次經 SaveCodec 驗證，讀取不覆寫原檔。InventoryManager 還原帳本時明確轉整數，避免 JSON 數值型別造成執行期字典不一致。正式 main 仍只接受 v1。

交易視窗期間保存排隊、讀取拒絕；扣款、物品/帳本與住宿恢復同步完成後才通知，結果對話結束再寫待存檔。詳細價格、容量及取消規則見 [交易規則](GREYSTONE_COMMERCE_RULES.md)。這是資料一致性驗證，不宣稱防作弊。


G06.6 修正：隔離物理驗證場景須依已通過 SaveCodec 的候選旗標設定莉雅是否存在及其碰撞，不能沿用預設場景或目前遊戲的旗標。已招募莉雅的原站位可以保存/讀取；未招募時同一位置仍被膠囊碰撞拒絕。地板、河流、牆與邊界查詢未放寬，schema 3 不變。

## 2026-10-15 森林／礦坑 layout 3

G06 整合入口的 schema 3、CH00-G06.4 保持不變。forest/mine 新存檔使用 location.layout_version=3；舊版 layout 1 仍須通過原範圍與原場景碰撞驗證，以相同座標遷移，下次儲存寫入 3。新版範圍 forest |x|、|z|<=24；mine |x|<=25、|z|<=19；y 為 -0.1～2，並須通過實際位置物理驗證。礦坑仍要求 e004_done。版本 2 不適用這兩張地圖；未知版本拒絕。新版外圍座標不得偽裝舊版本接受。原正式入口不讀新版 schema。角色、背包、旗標與獎勵契約不變；新增自由挑戰不發獎。
