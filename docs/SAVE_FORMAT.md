# 序章存檔格式 v1

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
