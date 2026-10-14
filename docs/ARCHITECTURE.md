# 架構設計與實作邊界

> **2026-10-14 正文合併更新（優先於本檔較早條款）**：新企劃已由使用者貼文取得，不再待正文。灰石村採 120×120m、Q 版低面數切面、北側公會/西北農田/東北礦坑/東河/南入口/西出口；平台 Windows + Android，iOS 預留。執行以 [GREYSTONE_VILLAGE_SPEC.md](GREYSTONE_VILLAGE_SPEC.md) 與 [GREYSTONE_BUILD_TASKS.md](GREYSTONE_BUILD_TASKS.md) 為準。G01 獨立佔位預覽，不替換正式0.6.1存檔；G06再遷移位置及串接劇情/觸控。本檔舊「待正文」、PC限定、圖片未列公會、固定舊碰撞等描述保留為歷史，不是目前限制。


Phase 1～5 已實作三區探索、故事 E001～E009、戰鬥、隊伍／成長／裝備、完整 Q001 日誌與存讀檔。下方 P2～P4 段落為歷史基線；最新行為以 P5 段落為準。

## P2 組裝與狀態歸屬（歷史基線）

Main 的 ExplorationGame 負責初始化、JSON 錯誤處理、輸入鎖與服務注入；保留 Main、Player、CameraRig 和所有服務節點，只替換 MapContainer 下的村莊／森林。沒有 Autoload，也沒有空的 GameManager 或 SessionState；本輪 session 由持續存在的 Main 子組件擁有，P3～P5 在這個生命週期上擴充。

| 狀態 | 唯一擁有者／修改入口 | 通知 |
| --- | --- | --- |
| 劇情旗標 | FlagManager.set_flag | changed |
| 已接受任務 | QuestManager.accept；目標完成數讀 FlagManager | changed |
| 物品數量、已領來源 | InventoryManager.claim 同步提交兩者；consume 消耗；restore_counts 僅敗北還原數量 | changed |
| 目前事件、目標與執行鎖 | EventRunner.try_start／對話與戰鬥結果回呼 | busy_changed、objective_changed、event_completed、event_failed |
| 對話行與等待狀態 | DialogueManager.start／advance／mark_revealed | active_changed、line_changed、finished |
| 地圖與切換鎖 | ExplorationSceneManager.travel | transition_changed、map_changed |

StoryCatalog 解析及驗證 JSON；StoryManager 依 trigger kind/key 路由 E001/E002；EventRunner 在任何狀態變更前檢查可執行動作，對話結束才提交動作及完成旗標。後續事件明確停用，沒有模擬入隊或戰鬥勝利。UI 僅發送 advance_requested，管理打字 Tween 並回報 reveal_finished，不修改旗標／背包／任務。

WorldInteractable 使用距離加物理射線檢查；Main 每個物理幀在地圖快取清單找最近可達對象，執行時再驗證距離與視線。地圖使用 Marker3D 定義出生點與森林鏡頭區域；角度固定，只平滑改變正交視野。切圖立即上鎖，再延後替換地圖與淡入淡出，入口出生點離出口互動半徑至少 3 公尺。

道具定義是唯讀 ItemDefinition Resource；數量／來源帳本為 InventoryManager 私有 Dictionary。P2 寶箱来源 village_supply_chest 僅給 trail_ration ×1。P3 演練來源 forest_training_supplies 給 potion ×3，與 E005 分離；potion 在戰鬥恢復 60 HP，不復活。沒有磁碟保存或金幣。

## P3 戰鬥組裝與狀態歸屬（歷史基線，含美術追加）

Main 的 PartyManager 常駐並持有 CombatantState；CombatantDefinition／SkillDefinition／ItemDefinition 為唯讀 Resource。每位角色與敵人都有獨立 CombatantState，HP／MP 僅由 damage／heal／spend_mp／restore 修改並發出 changed。PartyManager 轉發 changed 給探索 HUD，战鬥使用同一角色實例，不複製一份數值。正式遊戲初始化雷恩；莉雅定義供獨立治療測試，入隊留 P4。

Main 的 BattleFlow 載入 BattleCatalog、管理進戰票號和戰前角色／道具快照；每次進戰才建立 BattleArena。Arena 擁有局部 BattleManager、BattleStage、BattleInterface 和獨立鏡頭。戰鬥期間探索地圖／玩家停止處理且隱藏；Main 保存返回位置，結束後恢复。BattleManager 不設為 Autoload。

BattleManager 依速度降序產生每輪佇列，同速按 instance_id，死亡者跳過。狀態為 IDLE → WAITING／RESOLVING → FINISHED；UI 的 action_requested 帶行動、目標及回合 token，驗證後立即鎖定再消耗。傷害為 max(1, 攻擊或魔法 + 技能威力 − 防禦或魔防)；防禦向上取整減半，直到自己下一次行動。敵人選最低 HP 比例存活目標，守衛偶數輪且 MP 足夠時使用魔法。

BattleStage 僅讀取狀態，依 action_resolved 做位移／數字動畫。每次動畫從固定站位起算並終止舊位移，防止快速行動累積漂移。BattleInterface 僅發請求；未學技能、錯誤目標、無資源及舊 token 均由 manager 拒絕。

追加卡通美術後，CombatantDefinition.appearance 注入 PackedScene；BattleStage 不再現造箱型人形。CartoonActor 包裝 GLB 和命名關節，僅處理待機、步行、死亡停止，不改數值或碰撞。探索玩家和 NPC 也實例化同一組 *_visual.tscn；Player 將實際水平速度傳入 set_motion，模型尺寸只縮放視覺子節點，原本碰撞 Shape 不變。

環境美術為 village／forest 中直接實例化的 GLB，編輯器可見，不靠執行時改寫碰撞或搜尋路徑替換模型。battle_grove.tscn 為 BattleArena 的靜態視覺子場景，BattleStage 只管理戰鬥員、回合圈與動畫。宝箱沿用原 Lid 節點及旋轉行為，裝飾不持有任務或獎勵狀態。

勝利保留當前 HP／MP／道具，結果僅含 reward_preview；EXP／金幣實際發放留 P4。敗北重試或撤退還原進戰前快照，物品來源帳本不回退。重試保留票號並重建敵人；按返回後 BattleFlow 只發一次 concluded。EventRunner 必須吻合等待票號和 battle_id 且勝利，才經 FlagManager 寫 victory_flag、執行 complete_actions、寫完成旗標。敗北清除等待，允許重新觸發事件；重試期間持續等待。

E004/E007 目前只在整合測試中明確啟用、設置前置旗標，再以真實指令完成勝敗；預設事件仍僅 E001/E002。森林演練直接使用 B001/B002，沒有主線等待或獎勵。營地恢復 HP／MP，不補道具。完整事件鏈留 P4／P5。

## P4 隊伍、成長與交易（歷史基線）

Main 增加 Rewards、PartyActions、PartyMenu，仍無 Autoload。PartyManager.recruit 只接受已註冊角色，拒絕重複 ID 和第四人；正式註冊只有莉雅。E003 在對話結束後招募成功才設旗標，招募後隱藏原 NPC 並取消其碰撞；探索仍以隊長代表隊伍。

CombatantState 擁有 level／experience／equipment；CombatantDefinition 提供唯讀成長係數，ItemDefinition 提供槽位、角色條件及加值。有效 attack／magic／defense／ward／max_hp／max_mp 由實例計算；BattleManager、BattleStage、UI 和休息均讀有效值，卸下不影響基底或其他角色。PartyActions 以能力檢查確認選單正在開啟且沒有戰鬥／對話／轉場，再協調狀態與背包交易。

InventoryManager 擁有 gold、物品數量及既有單物品寶箱來源帳本。RewardManager 唯一擁有組合獎勵帳本（starting_kit、battle:B001/B002、未來 event:E008）；先驗證完整包，再同步寫金幣／物品／全隊 EXP 和帳本，通知前已全部完成，重入被鎖住。兩類來源各由自己的入口發放，E008／Q001 不可改走 Inventory.claim 繞過組合帳本。QuestManager 的 JSON rewards 仍只顯示，不發放。

BattleFlow 接受 settled 事件後，僅主線勝利經 RewardManager 發獎一次；演練不發獎。同一遭遇重複結算被 battle:<id> 阻擋。旗標仍等玩家確認結果返回後才完成；敗北與重試不領獎，回復進戰前 HP／MP／物品快照，無需回退未曾發放的 EXP／金幣。E008 任務完成與旗標的完整交易尚待 P5，P4 僅驗證其獎勵包與去重。

森林使用明確注入的 Marker3D、半徑和 trigger key，ExplorationGame 在可操作的物理幀重新檢查區域及條件。主線敗北撤退後暫抑制同區觸發，離開後解除；前置條件改變時仍會在區內重判。PartyMenu 只讀資料並發 equip_requested／item_requested，Main 轉交 PartyActions；M／Esc、遮罩及探索鎖防止輸入穿透。

## P5 故事提交與保存

Main 新增 StorySequence、SaveManager，仍由同一個持續存在的場景注入服務，不使用 Autoload。礦坑的 sequence_target／sequence_light 和區域 Marker3D 經 export 明確注入；地圖材質與環境獨立，主線 B002 注入礦坑戰鬥背景，演練維持原場景。

EventRunner 先驗證已啟用事件與動作資源引用，E006 等待實際 Tween 完成後才提交物品和旗標。RewardManager 的同步 commit 回呼在獎勵／收據已寫入、尚未通知時提交任務與旗標；EventRunner 暫停自己的目標訊號與 Flag／Quest 訊號，全部完成後才通知。因此 E008 的 complete_quest 不依賴事件尾端才產生的 prologue_complete，也不會讓獎勵觀察者讀到部分狀態。原 E001～E008 不改寫；E009 補章末敘事／預告，沒有獎勵。

QuestManager 擁有 accepted／completed，日誌以 FlagManager 投影五項目標；UI 只讀 journal。SaveManager 擁有待保存請求與檔案 I/O；SaveCodec 驗證 JSON 及建立候選角色，各遊戲服務仍擁有其狀態，沒有第二份持續遊戲狀態。讀取前在獨立 World3D 驗證地圖碰撞及地板；完全通過才凍結通知、經各 owner 還原、替換地圖與位置、恢復通知。

安全點存 active_event 空字串、完成旗標及探索區域抑制；不序列化等待中的戰鬥／演出。對話／演出／戰鬥中的保存請求只排隊，讀取忙碌時拒絕。格式 v1、暫存後替換及上一份有效備份見 [SAVE_FORMAT](SAVE_FORMAT.md)。未來增加商店或額外 EXP 來源，必須擴充 SaveCodec 的收據一致性契約與版本遷移。

## 資料流

輸入/UI 請求 → 當前流程或戰鬥控制器 → 狀態擁有者的方法 → 狀態變更訊號 → UI/動畫更新。

探索與戰鬥共用角色實例狀態。場景切換不得重建玩家 HP、MP、經驗、金幣或背包；場景只保存位置、視覺與當次流程需要的暫時資料。

## 系統職責

| 系統 | 擁有/負責的內容 | 預計引入 | 生命週期 |
| --- | --- | --- | --- |
| Main / Player | 主場景組裝、角色位置/速度、鏡頭與 HUD | P1 | 場景內 |
| ExplorationGame / BattleFlow | 組裝常駐服務、探索／戰鬥輸入鎖、戰鬥票號和戰前快照 | P2～P3 已實作 | Main 常駐組件 |
| SceneManager | 地圖切換、出生點、探索返回位置及轉場保護 | P2 | 跨場景 |
| PartyManager | 角色實例 HP/MP、等級、經驗、技能及隊伍成員 ID | P3 最小版，P4 擴充 | 跨場景 |
| BattleManager | 回合排程、行動驗證、敵方暫態、結算產生 | P3 | 戰鬥場景內 |
| InventoryManager | 物品數量、金幣、裝備持有及消耗操作 | P2 最小版，P4 擴充 | 跨場景 |
| FlagManager | SessionState 中唯一的劇情旗標修改/通知入口 | P2 最小版，P5 保存 | 跨場景 |
| StoryManager / EventRunner | 事件條件、執行狀態、順序動作與等待結果；不持有第二份背包/旗標 | P2 最小版，P3～P5 整合 | 跨場景流程 |
| DialogueManager | 對話資料、顯示請求、等待關閉；UI 只呈現 | P2 | 流程服務＋場景內 UI |
| QuestManager | 任務接受/交付狀態，依 FlagManager 投影目標完成度 | P2 最小版，P5 日誌/保存 | 跨場景 |
| SaveManager | 狀態快照、格式驗證、遷移及讀寫 | P5 | 跨場景服務 |

本輪 session 由 Main 常駐組件分別擁有各狀態分區，沒有另建 GameManager／SessionState 空殼，也不重複建立第二份角色或背包資料。Manager 是職責名稱，不要求全部變成 Autoload；由 Main 明確注入依賴，避免互相在 `_ready()` 取用。

## 定義與實例

- `data/` 下的 Resource 定義角色基礎值、敵人、技能、道具，使用穩定 ID；遊戲中當作唯讀模板。
- 劇情事件、任務與戰鬥遭遇配置使用 JSON（已加入三份序章資料），經型別、ID、引用及動作驗證後執行；不把對話硬編在場景脚本。詳細契約見 [故事整合規格](STORY_IMPLEMENTATION.md)。
- Main 常駐組件擁有角色/背包/任務的可變實例。建立新遊戲時由模板產生，不直接修改共享 `.tres`。
- 隊伍角色以角色實例 ID 引用；戰鬥透過 PartyManager 持有的 CombatantState 方法改變 HP/MP，避免退出戰鬥後遺失。
- 行動資料與回合排程分開；未來 ATB 僅替換排程入口。
- 勝利獎勵在單一結算入口套用一次；死亡、取消選單或連按不可重複消耗/獲得物品。
- JSON 只保存明確基本型別；位置明確轉成 x/y/z 數值，不直接序列化 Node、Resource 或 Vector3。檔案有 `schema_version`，讀取驗證後再整體套用，損壞檔不覆寫目前進度。

## 目錄

沿用使用者企劃的目錄配置；每個分類下再依功能分組。保留的空目錄用 `.gitkeep` 標記，不代表功能已實作。

```text
RPGGAME/
  AGENTS.md / README.md
  project.godot                 # Main 啟動入口
  docs/                        # 設計、任務、驗收與紀錄
  tools/                       # PowerShell 開發工具
  scenes/{main,world,characters,battle,story,ui}/
  scripts/{core,world,characters,battle,inventory,quests,save,story}/
  data/{characters,enemies,skills,items,story,quests,battles}/
  assets/{models,textures,animations,audio,effects}/
  source_assets/               # Blender 等原始檔；.gdignore
  tests/                       # 各階段行為測試
  artifacts/                   # 忽略匯入及版本控制的日誌/證據
  builds/                      # P6 匯出產物
```

Phase 1 場景樹：Main(Node3D) → WorldEnvironment、Sun(DirectionalLight3D)、World(地板/障礙物/邊界)、Player(CharacterBody3D：碰撞/幾何體/Input/Movement)、CameraRig(Camera3D)、HUD(CanvasLayer)。玩家、世界與 HUD 各自獨立場景；攝影機與目標經 export NodePath 明確注入。PlayerInput 讀取 Input Map；PlayerMovement 處理地面投影、速度/重力與碰撞；Player 組裝兩者並轉向佔位視覺。固定鏡頭保持俯角/方位角 45 度，只隨玩家平移；輸入長度限制為 1，防止斜向加速。

首輪採 Compatibility renderer、60 Hz 物理更新；不引入付費資產、戰鬥外掛、複雜 DI 或多執行緒框架。實際效能目標待 P6 記錄測試硬體後驗證。

故事腳本預定置於 scripts/story；QuestManager 保持在 scripts/quests，對話 UI 放 scenes/ui。原企劃建議目錄不另生成第二份 QuestManager。SessionState 統一保存事件完成狀態、旗標、任務、隊伍及獎勵帳本；事件中途執行時鎖定觸發，僅在安全檢查點存檔，避免等待戰鬥/演出時保存半套狀態。


## P6 呈現與匯出

Main 的 AdventureAudio 唯一持有音樂切換、六聲道音效池與音量設定；聆聽 BattleFlow.arena_started、戰鬥結算、StorySequence.started 和保存訊號，不改角色／旗標。PartyMenu 只呼叫 set_levels；設定寫獨立 ConfigFile，不改 SaveCodec v1。headless 不啟動音訊，圖形測試驗混音輸出。

InputMap 明確定義 Xbox 與 UI 動作，PlayerInput 仍用 Input.get_vector／物理移動；Main 僅切換提示。戰鬥 B 只取消目標選擇，回合及資源驗證仍由 BattleManager 負責。

正式 Windows 匯出排除 tests/tools/docs，QA feature 使用 DeliveryTestTree 與空 QAEntry；兩者使用同一 release 模板，遊戲資源逐一比較。測試不靠 release 的命令列入口覆寫。source_assets、日誌、匯出、模板下載都不作遊戲資源。

0.6.1 村莊：五個 GLB 分別持有公會、住宅、鋪面／晶柱、邊界及村外遠景；每組在 Blender 合併網格並保留材質分面，避免逐瓦／逐花建立執行期節點。這些是呈現層，碰撞仍由 village.tscn 的 16 個既有代理持有；測試固定基線 `tests/fixtures/village_collision_v1.json`。ExplorationMap.default_camera_size 預設 17，村莊設 21；轉場立刻套用該地圖鏡頭尺寸，區域縮放維持既有行為。開啟 4x MSAA，無新增插件、Autoload 或存檔欄位。

2026-10-14 的九區礦村要求尚處設計階段，未改 runtime。未來換圖须將地圖佈局版本與位置遷移納入 SaveCodec：只有明確識別的舊版合法村莊存檔可轉安全點，仍先驗候選位置再一次套用狀態；非法／損壞資料不可自動改成新遊戲。新商店／住宿若引入金幣支出，須同步擴充經濟帳本契約，不能繞過既有數值一致性驗證。具體版本及資料形狀待新正文合併。


## G06.1 安全接軌

新增繼承 Main 的 greystone_integration.tscn，沿用既有管理器；以 greystone_enabled 明確選擇 schema 2，正式模式保持 schema 1。greystone_runtime.tscn 用 ExplorationMap 包裝既有模型場景。SaveManager 在原完整驗證與物理位置通過後呼叫 GreystoneMigration，再驗證新位置，最後透過原狀態所有者還原。沒有第二份劇情狀態或交易系統。


## G06.4 商店與旅館

InventoryManager 擁有購入/住宿累計及扣款方法，沿用唯一金幣與物品狀態；沒有第二個經濟 Manager。CommercePanel 僅顯示價格/數量與發出 confirmed/cancelled。GreystoneIntegration 驗證目前互動對象、距離及忙碌狀態，在確認後立即關閉交易意圖以拒絕重複回呼，再轉交 InventoryManager。住宿透過 PartyManager.rest 恢復；全部成員恢復完成後發出 party.changed，使觀察者讀到完整狀態。存檔由既有 SaveManager/SaveCodec 執行版本遷移與交易一致性驗證。
