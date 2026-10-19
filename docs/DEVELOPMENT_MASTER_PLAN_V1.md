# PROJECT CRYSTAL / 失落星核
# Codex Development Master Plan v1.0

## 0. 專案與工作模式

Repository:
https://github.com/yume4024-design/Godotrpg

目前工作分支：
feature/greystone-g06

目前已知基線：
- main: 63e605922a
- feature/greystone-g06: aa71fc71d7
- Windows RC2: 0.6.1-g08-rc2
- Godot: 4.7.2（依目前專案報告，執行時重新確認）
- 開發語言：GDScript
- 3D 工具：Blender、ComfyUI Pixal3D Multi-View
- 主要目標平台：Windows PC

注意：以上為規劃時的基線，不得假設執行時仍是最新版本。

你是本專案的 Godot 工程師、3D 資產整合工程師及 QA 執行者。

請依 AGENTS.md 與現有 ai-3d-agent SKILL 執行。

每次開始前：
1. 確認儲存庫、目前分支、HEAD 與工作目錄狀態。
2. 閱讀最新 TASKS、CHANGELOG 與各階段報告。
3. 先盤點已實作功能，避免重複建立。
4. 不覆蓋未提交的使用者修改。
5. 若目前分支已前進，使用最新有效基線。
6. 若發現正在進行的工作，先判斷能否安全接續。
7. 本計畫中的未完成項目不得預先勾選。

工作採用小型可驗收階段。

每一階段必須包含：
- 實作
- 自動測試
- 必要的圖形與視覺驗收
- 面數或效能報告
- 失敗修正
- Git 提交
- 下一階段建議

只在當前階段 PASS 後，才能開始下一階段。

若無法取得使用者圖片、模型、GPU 或其他必要環境，標記 BLOCKED，說明缺少的條件；不得生成替代結果冒充完成。

---

# 1. 全域技術與美術標準

## 1.1 遊戲美術風格

- Stylized Low Poly 3D JRPG
- Anime-inspired proportions
- Faceted geometry
- Clean character silhouettes
- Consistent character scale
- Forest/fantasy color palette
- 少量精細材質，不追求寫實 PBR 外觀
- 與雷恩、莉雅及灰石村現有資產保持一致

不得擅自改成寫實、高精雕或不同的卡通風格。

## 1.2 三角面預算

新的最終模型限制：

| Type | Maximum Triangles |
|---|---:|
| Common Enemy | 10000 |
| Elite Enemy | 15000 |
| Boss | 15000 |
| Player Character | 15000 |
| NPC | 15000 |

規則：
1. 使用 evaluated mesh 的三角面統計。
2. 預算為上限，不是必須達到的目標。
3. 主要角色必要的固定配件計入角色總量。
4. 可替換武器另外統計，並記錄角色加武器的同屏成本。
5. 高於預算一律 FAIL。
6. 保留約 5%～10% 預算作為後續修正餘裕。
7. 無論面數是否合格，都必須另外測試骨架、動畫、輪廓和材質。
8. 已通過舊規格的模型不需要因新上限提高而重建。

## 1.3 參考圖標準

每個需要四視圖重建的資產使用：

- front.png
- left.png
- back.png
- right.png

要求：
- 四張獨立圖片，不是四圖合成一張。
- PNG RGBA，背景 Alpha 透明。
- 檢查真正的 Alpha，不以棋盤圖案冒充透明。
- 前後左右正交視角，禁止任意 3/4 角度代替。
- 同一角色的高度、比例、裝備一致。
- 不得將左側直接鏡射作為右側。
- 所有圖片保留完整身體、四肢、髮型、翅膀或其他必要部件。
- 不包含文字、紅框、標籤或不相關物體。
- 一致性不足時先修正參考圖，不送入正式生成。

## 1.4 生成與匯出

沿用專案已存在的：
3d_pixal3d_multi_views

流程：

Reference PNG
→ ComfyUI Pixal3D
→ Raw GLB
→ Blender inspection
→ Retopology / Decimation
→ UV and Material
→ Rig / Animation
→ Optimized GLB
→ Godot PackedScene
→ Functional QA

Pixal3D 生成的原始模型不得直接認定為遊戲正式模型。

保留原始 GLB、工作 Blender 檔及重現生成的設定。

---

# 2. A01 — 更新 AI 3D SKILL

## 目標

統一新的 10000／15000 三角面標準，讓後續所有角色與敵人使用同一套可驗證流程。

## 實作

檢查：
- docs/skills/ai-3d-agent/SKILL.md
- scripts/tools/audit_character_glb.py
- Blender check_export.py
- ComfyUI Pixal3D workflow
- Godot asset preview

更新：
- 敵人分類
- Boss 分類
- NPC 分類
- 玩家角色分類
- 面數預算參數
- GLB 驗證條件
- 圖片命名與四視圖檢查
- 工作流程錯誤處理
- 報告格式

設計共用的 Asset Triangle Budget Schema。

驗證工具須接受明確預算，而非全部固定 5000。

## 驗收

測試以下邊界：
- 9999 / 10000 / 10001
- 14999 / 15000 / 15001
- 缺少 UV
- 缺少骨架
- 失效或空白 Mesh
- 非有限座標
- 意外重複的模型實例

面數上限採「最多」，等於上限時可通過面數檢查，但其他品質條件仍須獨立通過。

## 交付

docs/ASSET_TRIANGLE_BUDGET.md

更新 ai-3d-agent SKILL、相關驗證工具與 TASKS。

Gate A01：
PASS / FAIL / BLOCKED。

---

# 3. A02 — 參考圖資產準備

## 3.1 目標敵人

五種敵人：

E01 Spore Sprite
E02 Thorn Boar
E03 Crystal Bat
E04 Ore Beetle
E05 Corrupted Guardian

Forest Slime 已有獨立製作流程，本批不重新生成。

## 3.2 NPC

N01 Blacksmith
N02 Item Merchant
N03 Innkeeper
N04 Village Citizen Male
N05 Village Citizen Female

其中鐵匠已有四視圖設計歷史，必須沿用使用者已確認的外觀與修正：

- 背面腰部不可出現原先被要求移除的工具袋與工具。
- 保留正常皮帶及圍裙。
- 左右手與拇指的解剖方向必須一致。
- 使用已修正的後視圖作為依據。
- 不重新加入已被移除的配件。

## 3.3 艾琳 Eryn

艾琳為未來第一章隊友。

使用無箭袋版本的四視圖重建角色主體。

弓、箭袋、箭矢作為獨立裝備處理。

## 3.4 圖像資產目錄

建議：

assets/source/characters/eryn/references/

assets/source/npc/blacksmith/references/
assets/source/npc/item_merchant/references/
assets/source/npc/innkeeper/references/
assets/source/npc/villager_male/references/
assets/source/npc/villager_female/references/

assets/source/enemies/spore_sprite/references/
assets/source/enemies/thorn_boar/references/
assets/source/enemies/crystal_bat/references/
assets/source/enemies/ore_beetle/references/
assets/source/enemies/corrupted_guardian/references/

先盤點現有來源目錄，不擅自搬動已有使用者資產。

若圖片僅存在於 ChatGPT 對話、尚未進入 Codex 可讀工作區，必須回報缺少的圖片，不得偽造輸入。

## A02 驗收

每個待生成資產必須具備：
- 4 張獨立 PNG
- 正確視角
- 真正透明背景
- 完整人物／怪物
- 裝備位置一致
- 圖像尺寸紀錄
- 每張圖片 SHA256
- 四視圖視覺檢查報告

僅對實際具備完整資料的資產標記 READY。

---

# 4. A03 — 五種敵人 3D 模型製作

每個敵人作為獨立任務。

禁止一次提交五個 ComfyUI 工作卻不驗收。

製作順序：

A03.1 Spore Sprite
A03.2 Ore Beetle
A03.3 Thorn Boar
A03.4 Crystal Bat
A03.5 Corrupted Guardian

## 4.1 Spore Sprite

預算：最多 10000 triangles

重點：
- 紅色蘑菇帽與白色斑點
- 圓潤菇靈頭部
- 葉片披肩
- 小型手臂
- 懸浮身體
- 綠色魔法紋樣

至少規劃 Idle / Move / Attack / Hit / Death 動作狀態。

## 4.2 Ore Beetle

預算：最多 10000 triangles

重點：
- 深灰礦石甲殼
- 黃橙色星晶尖刺
- 六足昆蟲結構
- 前後足及鉗部不互相穿插
- 左右甲殼一致

驗證多足移動、轉向、攻擊、受擊及死亡姿勢。

## 4.3 Thorn Boar

預算：最多 10000 triangles

重點：
- 深棕色野豬身軀
- 白色獠牙
- 荊棘藤蔓
- 背部翠綠星晶
- 四足落地
- 可辨識的衝撞方向

驗證四足步態、奔跑、衝撞、受擊及死亡。

## 4.4 Crystal Bat

預算：最多 10000 triangles

重點：
- 深紫色身體
- 青藍色水晶
- 紫色翼膜
- 左右翼展一致
- 翅膀關節與膜面連接正確
- 飛行時不明顯自我穿模

驗證 Idle Fly、Move Fly、Attack、Hit、Death。

需要檢查展翼、收翼及動畫過渡的實際三角面和可視效果。

## 4.5 Corrupted Guardian

分類：Boss
預算：最多 15000 triangles

重點：
- 灰黑色岩石身體
- 青藍星晶裂縫
- 大型雙臂
- 石製護甲
- 胸口發光晶核
- 巨大且清晰的輪廓

動作至少規劃：
- Idle
- Walk
- Heavy Attack
- Special Attack
- Hit
- Stagger
- Death

確保 Boss 在 Godot 戰鬥鏡頭下仍完整可辨識。

## 4.6 每個模型交付

每個敵人保留：
- references/
- generated_raw.glb
- optimized.blend
- optimized.glb
- generation_manifest.json
- triangle_report.json
- validation_report.md
- preview_front.webp
- preview_side.webp
- preview_back.webp
- preview_in_godot.webp

建立 SHA256 與生成參數紀錄。

## 4.7 生成規則

1. 先測試單一模型在 GPU 上能否穩定生成。
2. 不假設 12GB VRAM 一定能執行全部節點。
3. 使用目前可用的模型權重及工作流設定。
4. 固定並記錄 Seed。
5. 每次生成完後檢查原始網格。
6. 形狀不正確時先修圖或重試形狀階段。
7. 不為提高成功率而無限制重跑。
8. 每角色最多進行有限次生成及修整，未達標則停止並回報。
9. 不得以靜態展示模型冒充可動畫模型。

---

# 5. A04 — 敵人整合 Godot

## 目標

替換五種敵人的視覺資產，不改動既有 RPG 規則。

現有視覺場景：

- spore_sprite_visual.tscn
- thorn_boar_visual.tscn
- crystal_bat_visual.tscn
- ore_beetle_visual.tscn
- guardian_visual.tscn

開始前重新核對實際路徑。

## 整合原則

- 保留 Enemy ID
- 保留戰鬥數值
- 保留技能
- 保留 AI
- 保留戰鬥回合順序
- 保留掉落、經驗及獎勵
- 保留主線事件旗標

新模型透過獨立 PackedScene 載入。

保留舊版 Visual Scene 作為回退資產。

## 驗收

逐隻驗證：
- Godot GLB 載入
- 材質與 UV
- 外觀比例
- 旋轉方向
- 動畫播放
- 戰鬥相機完整取景
- Hit / Death 狀態
- Scene Reload
- 戰鬥回探索
- 無資源遺失及重大渲染錯誤

完成後執行 G06 既有戰鬥和序章回歸。

另外執行代表性敵人數量下的 Draw Calls、幀時間及記憶體量測。

不可只用 GLB 面數合格判定整合成功。

---

# 6. A05 — NPC 模型製作與整合

## 製作順序

1. Blacksmith
2. Item Merchant
3. Innkeeper
4. Village Citizen Male
5. Village Citizen Female

預算：每個最多 15000 triangles。

可重用必要的 NPC 骨架與動畫介面，但需確認比例、手部、裙擺或圍裙的權重相容。

## 交付要求

每個 NPC：
- 四視圖
- 原始 GLB
- 優化 GLB
- Blender 工作檔
- Idle 動畫
- Talk 動畫
- 必要的互動動作
- Godot PackedScene
- 面數報告
- 角色驗收截圖

## 整合要求

只替換角色外觀，不修改：
- NPC ID
- 對話與互動範圍
- 商店價格
- 旅館恢復規則
- 任務流程
- 存檔內容

NPC 巡邏若仍未完成，另外建工作項目；不得把外觀整合當成巡邏驗收。

---

# 7. G08.3 — Windows RC2 完整驗收

此工作線可與 A01～A05 並行，但必須在獨立工作樹或隔離分支執行。

G08 驗收必須以固定 SHA、固定候選 PCK 為基線。

## 7.1 完整通關

從新遊戲開始，依實際操作驗證：

E001 → E002 → E003 → E004/B001 → E005 → E006 → E007/B002 → E008 → E009

測試：
- 移動與鏡頭
- 公會接任務
- 莉雅入隊
- 史萊姆教學戰
- 森林探索
- 礦坑探索
- 腐化守衛 Boss
- 戰敗重試
- 星印取得
- 回村交付
- 金錢／EXP 獎勵
- 商店及旅館
- 存檔、關閉、重啟讀檔

不修改原始角色數值或主線規則以讓測試通過。

## 7.2 實體輸入

驗證真實：
- 鍵盤
- 滑鼠
- 可用時的 Xbox 相容手把

若無法取得實體設備，標記 BLOCKED。

不得把 InputMap 模擬當作完整實體輸入驗收。

## 7.3 Release 長時間測試

使用 RC2 release 匯出包執行至少 30 分鐘。

記錄：
- Average FPS
- P95/P99 frame time
- 最慢幀
- Draw Calls
- Working Set
- Private Bytes
- Scene Transition
- Battle Transition
- Save/Load
- 崩潰與錯誤日誌

既有 664ms 初始化尖峰、約 142ms 戰鬥／讀檔尖峰須分別診斷。

不得直接把先前編輯器或測試程序的 30 分鐘結果當作 RC2 Release 成績。

## 7.4 關卡與視覺

檢查：
- 18cm 階梯上限行為
- 高牆、低天花板及斜坡
- 礦坑橫梁遮擋
- 角色與鏡頭碰撞
- 角色近景穿模
- 動畫切換
- 材質遺失
- NPC 不可互動
- 地圖出口與返回點

## 完成門檻

- 玩家可正常通關序章
- 沒有阻礙主線的重大缺陷
- 沒有可重現的存檔損壞
- 沒有未處理的重大崩潰
- 已知效能尖峰有紀錄和處理結論
- Windows RC 包可獨立啟動及退出

若不達標，修正並重新輸出 RC3，不直接升正式版本。

---

# 8. G08.4 — 發布前品質改善

僅在 G08.3 通過後開始。

工作：
1. 修正 G08.3 發現的阻斷缺陷。
2. 完善必要的操作提示。
3. 移除玩家版本不必要的開發工具列。
4. 驗證不同視窗解析度。
5. 保留遊戲存檔遷移能力。
6. 檢查素材授權與資源包內容。
7. 進行低階 Windows PC 測試（若有設備）。
8. 確認角色與地形沒有重大美術錯誤。

先修正功能正確性，再處理非阻斷性的美術品質。

---

# 9. G08.5 — Windows 序章發布候選

交付：
- Windows x86_64 EXE
- PCK
- README
- CHANGELOG
- ASSET_CREDITS
- SHA256 manifest
- QA Report

建立版本標籤候選，例如：
0.7.0-prologue-rc1

版本號需確認專案現行慣例後再決定，不能自動覆寫正式版本。

Git 合併 main 必須另行請求使用者確認。

當所有發布門檻通過後，才回報「可發布」。

---

# 10. C1 — 第一章：翠影森林的守護者

此階段在 Windows 序章候選驗收完成後開始。

## 故事內容

第一章核心：
- 雷恩、莉雅前往更深處的翠影森林
- 遇見精靈弓箭手艾琳
- 調查森林星晶異變
- 探索精靈聚落與古樹神殿
- 取得第二枚星印
- 推進黑曜調查團的主線伏筆

詳細事件與任務 ID 先根據既有故事資料核對，再建立新的穩定 ID，不預先佔用可能已存在的識別碼。

## C1.1 艾琳模型

預算：最多 15000 triangles。

根據先前無箭袋四視圖重建。

保留：
- 棕色半束長髮
- 精靈尖耳
- 綠色遊俠服
- 皮革護腕
- 腰包
- 深色長褲
- 棕色長靴

另外製作：
- Bow
- Quiver
- Arrows

武器、箭袋以獨立掛點管理，避免與角色本體面數和骨架混淆。

## C1.2 艾琳角色系統

建立弓箭手職業行為：
- Idle
- Walk
- Run
- Aim
- Shoot
- Hit
- Guard
- Death

接入現有隊伍管理、戰鬥、技能與存檔系統。

先確認原有隊伍最大人數與戰鬥角色槽位，不假設系統已完整支援第三名角色。

## C1.3 第一章地圖

分段製作：
1. 深層翠影森林
2. 精靈聚落
3. 古樹神殿
4. Boss 戰區域

先以簡單幾何體製作可玩白模。

待導航、碰撞、事件與場景切換通過後，再替換正式環境素材。

## C1.4 第一章驗收

- 艾琳入隊僅一次
- 三人隊伍戰鬥
- 弓箭技能與動畫同步
- 地圖進出
- Quest Flag 正確
- 第二枚星印只能取得一次
- 場景切換存檔
- 戰敗重試
- 不破壞序章

完成第一章最小可玩流程後，再安排新的敵人、支線與演出。

---

# 11. 測試與提交規則

每一階段：
- 先執行基線測試
- 只修改當前階段所需檔案
- 修正問題後重新測試
- 產出實際報告
- 提交 Git Commit
- 回報變更 SHA

測試不得：
- 以模擬輸入冒充人工操作
- 以靜態模型冒充動畫資產
- 以模型預算通過冒充視覺驗收
- 以短時間測試冒充 30 分鐘長測
- 以桌面測試冒充 Android 驗收
- 隱藏失敗測試
- 修改遊戲平衡來掩蓋缺陷
- 刪除舊版模型或正式存檔

需要人工判斷的項目必須標記為 HUMAN_REVIEW，等待實際確認。

---

# 12. 文件與報告

建立或更新：

docs/ASSET_TRIANGLE_BUDGET.md
docs/ENEMY_MODEL_PRODUCTION_PLAN.md
docs/NPC_MODEL_PRODUCTION_PLAN.md
docs/ASSET_GENERATION_REPORT.md
docs/GREYSTONE_G08_REPORT.md
docs/TASKS.md
docs/CHANGELOG.md

每項任務使用以下狀態：

NOT_STARTED
IN_PROGRESS
PASS
FAIL
BLOCKED
HUMAN_REVIEW

禁止用單一完成百分比取代具體測試與交付證據。

---

# 13. 執行順序與停點

第一輪：
A01 — 更新 SKILL 與模型面數規格。

第二輪：
A02 — 整理全部四視圖來源。

第三至第七輪：
A03.1～A03.5 — 五種敵人逐隻生成。

第八輪：
A04 — 敵人 Godot 整合。

第九輪：
A05 — NPC 模型製作，逐隻驗收。

獨立 Windows QA 工作線：
G08.3 → G08.4 → G08.5。

之後：
C1 第一章。

為避免一次執行造成大批不可驗證的修改，每輪只處理一個任務 ID。完成後提供驗收與下一輪建議，等待使用者確認才繼續；獨立工作線可以在使用者批准後並行。

## 現在立刻執行

只開始 A01。

先檢查最新 Git 狀態與專案現有 SKILL，完成 10000／15000 三角面預算更新、驗證工具及文件。

執行測試並提交到功能分支。

回報：
1. 完成內容
2. 檔案變更
3. 測試結果
4. Commit SHA
5. A02 所需的參考圖清單
6. 下一階段是否 READY

不要在本輪自行開始五種敵人批次生成。
不要修改正式 Windows RC2。
不要合併 main。