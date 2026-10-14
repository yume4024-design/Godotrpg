# G06.1 新舊地圖接軌與存檔遷移

2026-10-14；分支 `feature/greystone-g06`。本輪僅 G06.1，G06.2～G06.6 尚未開始。正式 main.tscn、village.tscn、project.godot 啟動入口與 v0.6.1 存檔欄位均保留。

## 架構與進入方式

`scenes/main/greystone_integration.tscn` 繼承正式 Main，重用同一 Player、Camera、Interface、SceneManager、DialogueManager、StoryManager、QuestManager、Party/Inventory/RewardManager。沒有新增第二套劇情服務。

`scenes/world/greystone_runtime.tscn` 是 ExplorationMap 轉接場景，實例化現有 greystone_village.tscn；場景 ID 為 greystone_runtime，安全出生點 (0,0.1,48)，鏡頭 size 28。

```powershell
./tools/godot.ps1 -Mode RunG06
```

完成開場對話後，左側「G06.1 新舊村莊往返」可在新舊村莊安全點切換。對話/戰鬥/轉場/選單等忙碌時不可切換，森林與礦坑也不提供跨圖捷徑。「匯入 v0.6.1 存檔」讀取同一啟動環境的舊欄位，保留原檔。

新版目前只有地圖接軌，NPC/主線觸發仍在舊地圖；可返回舊村繼續原有序章。沒有宣稱新版 NPC、商店或旅館已完成。新版礦口沒有切換事件，不能繞過森林戰鬥。

## 存檔契約

- 正式啟動模式：schema 1 / CH00-P5，讀寫 `user://crystal_slot_01.json`，拒絕 schema 2。
- G06 啟動模式：保存 schema 2 / CH00-G06.1 至 `user://crystal_g06_slot_01.json`，可讀 v1/v2。
- v2 location.layout_version：village/forest/mine 固定 1，greystone_runtime 固定 2；缺失、未知或地圖不匹配的版本拒絕。
- v1 先通過原有完整資料契約及原圖物理驗證。只有合法 village 座標映射到新村入口；forest/mine 保留原座標與地圖。遷移只複製並變更 schema/content/location，保留其餘狀態。
- 遷移後再執行完整 v2 驗證及新圖獨立 World3D 的膠囊/地板查詢；任何一步失敗都不套用角色或進度、不改來源檔案。
- 新圖數值界限 X/Z ±60、Y -0.1～6.2 只做初步限制，河流、井、牆、懸空仍須物理驗證；舊圖界限完全保留，沒有直接放寬舊座標驗證。
- 舊存檔匯入只讀取，不自動寫回；玩家明確保存才寫新欄位。經濟契約未改，購物/住宿須後續另定義帳本及版本。

## 測試方式

先以正式 P5 測試完成真實序章、戰鬥、裝備及獎勵，產生 `user://p5_tests/restart.json`。G06 測試只複製到 `user://g06_tests/legacy.json`，新檔為 `user://g06_tests/restart.json`；不讀寫正式玩家欄位。

```powershell
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode TestPhase5
./tools/godot.ps1 -Mode TestPhase5Reload
./tools/godot.ps1 -Mode VisualG06
./tools/godot.ps1 -Mode TestG06Reload
```

涵蓋舊村→新村、舊森林/礦坑位置保留、旗標/收據/角色/EXP/裝備/背包/任務/故事完整比對、舊檔位元組不變、非法舊位置/舊障礙物/新河流/新井/未知版本/金幣不符拒絕、失敗後全狀態不變、新舊村往返、實際滑鼠點入口、現有玩家移動、選單、重複獎勵拒絕、新檔保存與跨程序重啟。

最初測試直接比較執行期 StringName 字典與 JSON String 字典導致錯誤斷言，已改為同一 capture_state 序列化契約比對，並把磁碟原文與狀態檢查拆開；未放寬遊戲驗證。

## 範圍與後續

G06.2 六類 NPC/對話；G06.3 E001/2/3/8/9 與森林/礦坑往返及單次事件；G06.4 商店與旅館價格/交易帳本；G06.5 MobileInputLayer；G06.6 整合回歸。每項另有可執行結果才標完成。Android 真機、G07/G08、第一章均未開始。


## 實際結果

Godot 4.7.2.stable.official.ed1daf0bf；圖形使用 Windows / OpenGL Compatibility / RTX 3080。

| 檢查 | 結果 | artifacts/logs 證據 |
| --- | --- | --- |
| Check | 載入成功 | check-20261014-203201-268.log |
| TestPhase5 | 69 項/0失敗 | testphase5-20261014-203058-306.log |
| TestPhase5Reload | 7 項/0失敗 | testphase5reload-20261014-203114-736.log |
| VisualG06 | 51 項/0失敗 | visualg06-20261014-203429-418.log |
| TestG06Reload | 6 項/0失敗 | testg06reload-20261014-203435-209.log |

實際畫面：artifacts/phase5/g06-integration.webp；已檢視 HUD、入口按鈕及玩家位置。按鈕位於既有 HUD 下方，圖形測試使用滑鼠事件點擊，不只呼叫方法。畫面可讀性/操作入口各 2/2；場景美術仍沿用 G04/G05 的已知限制。


## G06.2 六類 NPC 與環境對話（2026-10-14）

本輪沿用已驗收 G06.1，不重作接軌/存檔。新增 greystone_npcs.tscn 並在 greystone_runtime.tscn 實例化；六個 WorldInteractable 由既有 ExplorationMap 掃描，沒有新增 NPC Manager 或劇情管理器。

| NPC | 位置 X/Y/Z | 重用造型 |
| --- | --- | --- |
| 公會長瑪爾克 | -2 / 0 / -22 | guildmaster_visual |
| 莉雅 | 3 / 0 / -22 | lia_visual |
| 旅館老闆 | -23 / 2 / -12.5 | guildmaster_visual |
| 道具商人 | -25 / 0 / 5 | guildmaster_visual |
| 鐵匠 | 18 / 0 / -8 | ren_visual |
| 村民 | -17 / 0 / 28 | ren_visual |

使用既有 CartoonActor 待機動畫，CapsuleShape3D 半徑 0.3m、高 1.6m，標籤區分角色。重用造型不是六套新角色美術；目前沒有巡邏 AI。

WorldInteractable 新增 ambient_only（預設 false），本輪六位設 true，NPC 仍走正式 interact 分派與同一 DialogueManager。此模式只跳過 StoryManager 主線事件嘗試，保留現有鎖定、距離、射線及 Dialogue UI。舊地圖設定不變，原本事件仍正常觸發。G06.3 才切換公會長/莉雅至主線事件，不將本輪環境對話誤稱任務接交完成。

莉雅保持 npc_lia 穩定 ID，沿用既有 PartyManager 成員檢查及 set_present；已入隊時隱藏站立角色、停用碰撞，讀檔及換圖均重算，不新增存檔旗標。

新增旅館老闆、商人、鐵匠、村民的對話資料；無扣款、商品、恢復或發獎，這些屬 G06.4。schema 2、v1 遷移、正式 v0.6.1 入口及森林/礦坑事件未修改。

驗收命令：Check、TestG06NPC、VisualG06NPC、TestG06、TestG06Reload、TestPhase5、TestPhase5Reload。NPC 測試使用真實 Input Map 移動及 E 鍵對話，逐個驗距離/碰撞/鎖定/釋放/射線遮擋；門前接近測試分別重設起點，另有村口→廣場→公會連續行走。以真實序章產生的 v1 測試存檔驗莉雅隱藏、往返持續與兩人隊伍/212 金幣保全。測試只使用 user://g06_npc_tests、g06_tests、p5_tests，正式欄位不變。

新增/修改檔案：scenes/world/greystone_npcs.tscn、greystone_runtime.tscn；scripts/world/interactable.gd、scripts/core/exploration_game.gd；data/story/exploration_dialogue.json；tests/greystone_npc_test.gd（含 uid）；tools/godot.ps1；本報告與工作清單、TASKS、CHANGELOG。

下一個未驗收階段：G06.3 新村主線 E001～E003/E008～E009 與森林/礦坑往返整合。尚未切換正式預設主場景；完成故事入口與回歸前保留 opt-in 啟動。Android 真機未測試，G07/G08 和第一章未開始。

### G06.2 實際測試結果

引擎：Godot 4.7.2.stable.official.ed1daf0bf，Windows。下列命令均以 `./tools/godot.ps1 -Mode <模式>` 執行，程序正常結束。

| 模式 | 實際結果 | artifacts/logs 證據 |
| --- | --- | --- |
| Check | 載入成功，exit 0 | check-20261014-223027-918.log |
| TestG06NPC | 60 項，0 失敗 | testg06npc-20261014-223032-242.log |
| VisualG06NPC | 66 項，0 失敗 | visualg06npc-20261014-223125-090.log |
| TestG06 | 51 項，0 失敗 | testg06-20261014-223211-820.log |
| TestG06Reload | 6 項，0 失敗 | testg06reload-20261014-223216-474.log |
| TestPhase5 | 69 項，0 失敗 | testphase5-20261014-223218-341.log |
| TestPhase5Reload | 7 項，0 失敗 | testphase5reload-20261014-223234-466.log |

圖形測試實際輸入移動及 E 鍵，產生六張 `artifacts/phase5/g06-npc-npc_*.webp`。已檢視公會長與旅館老闆畫面：角色站位、標籤及對話可見，玩家能靠近對話；對話截圖在逐字顯示期間拍攝。日誌與截圖為本機驗收產物，依既有規範不提交 Git。

本輪 G06.2 通過；角色專屬新造型、巡邏、主線綁定、交易及 Android 真機均不在本輪通過範圍。


## G06.3 新版村莊序章整合（2026-10-15）

本輪基於 b715dbc 的 G06.2，僅完成下一子階段 G06.3。正式發佈版本仍為 v0.6.1；G06 候選入口為 `./tools/godot.ps1 -Mode RunG06`，沒有替換 project.godot 的正式入口。

### 實作及邊界

- ExplorationGame 新增 initial_map / initial_spawn 注入，預設仍為舊村。整合場景指定 greystone_runtime / opening，由同一 Main 服務執行 E001。開場位置 (-20,1.6,-11) 在旅館前斜坡，不宣稱已建旅館室內。
- 公會長及莉雅關閉 ambient_only，走同一 StoryManager、EventRunner、DialogueManager。原 E001～E009 JSON、Flag ID、Q001、獎勵來源完全保留。
- 西出口 (-53,0,10) 須 E003；東北礦口 (24,6,-52) 須 E004。森林回村僅在整合入口重定向至 greystone_runtime / return，安全落點 (-48,0.1,10)，距出口 5m。正式森林場景資源不變。
- 礦坑出口維持返回森林，再由西側回新村；本輪未增加需要存檔的新「來程地圖」狀態。Boss 返回保持戰前位置。
- 公會前庭以既有 village_departure 區域事件觸發 E009，僅在 E008 完成後執行；第一章仍只有解鎖與預告。
- 沿用原村音樂；不新增交易、住宿扣款、MobileInputLayer、巡邏或第一章內容。schema/content/layout 版本不變，既有 v1 遷移及新欄位仍保留。

### 驗證方式與限制

新增 greystone_story_test.gd，重用 P5 操作/戰鬥測試 helper，在獨立 user://g06_story_tests 執行完整序章。使用實際 E/M/F5 輸入、選單按鈕與 BattleManager 指令（包含真實敗北和重試），沒有直接設完成旗標或模擬勝利。跨地圖入口以 E 操作。長距離定位使用測試 reset_to，森林與礦坑區域觸發使用移動輸入；不宣稱本測試為整村人工步行通關。整村路線沿用 G05 與 G06.2 驗收。

G06.2 測試只針對環境對話暫時將 NPC 設 ambient_only；實際場景主線綁定由本輪 G06.3 完整流程驗證。NPC 測試亦保留六角色碰撞/遮擋/移動及入隊隱藏檢查。

首次 TestG06Story 58 項中出生高度檢查失敗：旅館前活動區實際地面為 1.5m，不是平台的 2m。已將 opening Marker 從 2.1 改 1.6，重跑通過；沒有放寬存檔驗證。Python 測試產生器曾遇本機 cp950 解碼失敗，改明確 UTF-8 後正常生成。

Godot 4.7.2.stable.official.ed1daf0bf，Windows；圖形使用 OpenGL Compatibility / RTX 3080。命令均為 `./tools/godot.ps1 -Mode <模式>`。

| 模式 | 結果 | artifacts/logs 證據 |
| --- | --- | --- |
| Check | 成功，exit 0 | check-20261015-012331-197.log |
| TestG06Story | 58 項 / 0 失敗 | testg06story-20261015-012253-437.log |
| VisualG06Story | 68 項 / 0 失敗 | visualg06story-20261015-012313-436.log |
| TestG06StoryReload | 7 項 / 0 失敗 | testg06storyreload-20261015-012311-551.log |
| TestPhase5 | 69 項 / 0 失敗 | testphase5-20261015-012335-222.log |
| TestPhase5Reload | 7 項 / 0 失敗 | testphase5reload-20261015-012351-559.log |
| TestG06 | 51 項 / 0 失敗 | testg06-20261015-012353-160.log |
| TestG06Reload | 6 項 / 0 失敗 | testg06reload-20261015-012357-908.log |
| TestG06NPC | 60 項 / 0 失敗 | testg06npc-20261015-012359-974.log |

已檢視實際 g063-guild.webp、g063-mine-gate.webp、g063-05-chapter-preview.webp：入隊後莉雅站立 NPC 消失，礦口 E 提示可讀，章末預告正常疊加。視覺觀察：HUD/提示可讀性 2/2；環境標籤密度 1/2（礦口既有兩個標籤距離偏近），留後續視覺整理，不影響操作。證據位於本機 artifacts/phase5，依規範不提交產物。

精確結果：212 金幣、雷恩與莉雅各 300 EXP、1 枚星印；E003/E008 和獎勵收據拒絕重播；Boss 敗北不推進，重試勝利後才完成 E007。新舊存檔重啟與完整遷移檢查通過。

修改檔案：scenes/main/greystone_integration.tscn；scenes/world/greystone_runtime.tscn、greystone_npcs.tscn；scripts/core/exploration_game.gd、greystone_integration.gd；scripts/world/exploration_map.gd；tests/greystone_story_test.gd（及 uid）、greystone_npc_test.gd；tools/godot.ps1；GREYSTONE_BUILD_TASKS、TASKS、CHANGELOG、本報告。

下一個子階段為 G06.4：先定義價格與交易規則，再加入商店/住宿及相應存檔帳本驗證。G06.5/6、G07/8 及第一章未開始，Android 真機未驗證。
