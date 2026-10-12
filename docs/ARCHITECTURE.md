# 架構設計與實作邊界

Phase 1 的 Main、Player、固定鏡頭、練習場及 HUD 已實作；其餘管理系統仍為設計約定，於需要的階段逐一加入。

## 資料流

輸入/UI 請求 → 當前流程或戰鬥控制器 → 狀態擁有者的方法 → 狀態變更訊號 → UI/動畫更新。

探索與戰鬥共用角色實例狀態。場景切換不得重建玩家 HP、MP、經驗、金幣或背包；場景只保存位置、視覺與當次流程需要的暫時資料。

## 系統職責

| 系統 | 擁有/負責的內容 | 預計引入 | 生命週期 |
| --- | --- | --- | --- |
| Main / Player | 主場景組裝、角色位置/速度、鏡頭與 HUD | P1 | 場景內 |
| GameManager | 探索/戰鬥/結算等模式協調，持有本輪 SessionState | P2～P3 | 跨場景 |
| SceneManager | 地圖切換、出生點、探索返回位置及轉場保護 | P2 | 跨場景 |
| PartyManager | 角色實例 HP/MP、等級、經驗、技能及隊伍成員 ID | P3 最小版，P4 擴充 | 跨場景 |
| BattleManager | 回合排程、行動驗證、敵方暫態、結算產生 | P3 | 戰鬥場景內 |
| InventoryManager | 物品數量、金幣、裝備持有及消耗操作 | P2 最小版，P4 擴充 | 跨場景 |
| FlagManager | SessionState 中唯一的劇情旗標修改/通知入口 | P2 最小版，P5 保存 | 跨場景 |
| StoryManager / EventRunner | 事件條件、執行狀態、順序動作與等待結果；不持有第二份背包/旗標 | P2 最小版，P3～P5 整合 | 跨場景流程 |
| DialogueManager | 對話資料、顯示請求、等待關閉；UI 只呈現 | P2 | 流程服務＋場景內 UI |
| QuestManager | 任務接受/交付狀態，依 FlagManager 投影目標完成度 | P2 最小版，P5 日誌/保存 | 跨場景 |
| SaveManager | 狀態快照、格式驗證、遷移及讀寫 | P5 | 跨場景服務 |

GameManager 持有各狀態分區，不重複建立第二份角色或背包資料。Manager 是職責名稱，不要求全部變成 Autoload；Phase 1 不需要全域管理器。後續跨場景服務採最少必要的 Autoload/組件，由明確入口組裝，避免互相在 `_ready()` 取用。實作時才確定初始化順序並驗證。

## 定義與實例

- `data/` 下的 Resource 定義角色基礎值、敵人、技能、道具，使用穩定 ID；遊戲中當作唯讀模板。
- 劇情事件、任務與戰鬥遭遇配置使用 JSON（已加入三份序章資料），經型別、ID、引用及動作驗證後執行；不把對話硬編在場景脚本。詳細契約見 [故事整合規格](STORY_IMPLEMENTATION.md)。
- SessionState 擁有角色/背包/任務的可變實例。建立新遊戲時複製或由模板產生，不直接修改共享 `.tres`。
- 隊伍角色以角色實例 ID 引用；戰鬥透過 PartyManager 的方法改變 HP/MP，避免退出戰鬥後遺失。
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
