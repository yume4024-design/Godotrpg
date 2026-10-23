---
name: crystal-scene-builder
description: Build reference-driven modular Blender environments and playable Godot scenes for Project Crystal, with terrain, materials, traversal, story hooks and safe location migration. Use when creating or rebuilding villages, forests, mines or dungeons from a supplied scene reference.
---

# Crystal Scene Builder

將使用者參考圖製作成可探索的完整場景。以目前專案 AGENTS、TASKS 和最新使用者指示確定範圍；不是只輸出概念圖、空殼場景或隨意排列幾何體。

## 構圖與資產

- 先拆解參考圖：命名區域、相鄰關係、高低差、地標、道路、橋、水道、入口和劇情點。寫入可讀的場景規格與機器可讀 layout，區分必要空間關係與可調比例。
- 盤點現有 GLB、PackedScene、材質、碰撞與授權。合格資產優先重用；新增缺少的組件，不能把重新命名的舊資產算成新模型。
- 按圖片底部素材表建立模組清單。規則結構可用 Blender Python 建模；複雜外形需要 AI 生成時採用已安裝 ai-3d-agent 的當前本機 Pixal3D 流程，保留來源與 job ID。沒有明確授權不購買素材或使用付費 API。
- 四視圖必須為正交 front/left/back/right、完整輪廓和一致比例；不能以鏡射冒充另一面。若可以直接以 Blender 正確建模，不為湊流程而生成無用圖片。
- 在獨立 Blender 場景組裝整個環境，保留可編輯 blend、分區 Collections、可重用物件與共享材質。使用者正在編輯其他 blend 時用背景程序，先讀取 live scene；不要清空其場景。
- Blender CLI 加入 `--python-exit-code 1`，核對完成 marker 與腳本／layout SHA；一般退出碼0可能仍有Python例外，不能用殘留GLB或舊manifest冒稱新生成成功。
- 原則為 1 Godot unit = 1m，Godot Y up；Blender 輸入轉換為 (x, -z, y)，匯出 glTF 2.0/GLB。用人物約 1.95m、門洞及走道的實際比例檢查，避免只對縮圖構圖。
- 材質沿用場景色彩語彙。岩層、土粒、木紋、動態水面、瀑布、晶體發光需有可見效果；不把來源概念圖當貼圖。記錄實測面數、材質、Mesh 與重複實例成本；環境預算按用途訂定，不套用角色上限。
- Blender程序節點不保證能經glTF轉入Godot。需要時在Godot建立等效共享Shader或另烘焙貼圖；以實際引擎畫面確認，防止木材匯入成白色。合併分區前將活動網格設為單一使用者，避免join改寫其他實例的共享資料。

## 可玩性與整合

- 地面／橋面／斜坡使用簡化且對齊的碰撞；裝飾不使用密集網格碰撞。可見樓梯可搭配連續坡面碰撞，但要實際走跑驗證上、下行及轉折。
- 深坑、水面與地圖外圍須有明確邊界。不得以隱形平地填滿水道來偽裝可探索，亦不得靠瞬移測試宣稱整條路可走。
- Godot 保留分區、視覺、碰撞、互動與出生點管理，重用 PackedScene／Mesh，不將全部世界合成無法替換的一塊模型。
- 接回既有 Player、Camera、Dialogue、Story、Quest、Battle、Inventory 與 Save 系統。場景重建不建立平行管理器，不改角色 ID、數值、旗標或獎勵規則。
- 改變可走佈局時建立獨立 location layout version；舊位置先在原地圖驗證，再映射安全點，保留完整進度與來源存檔。新位置仍須真實碰撞驗證，不放寬 SaveCodec 以接受水中或岩內座標。
- 新候選使用獨立入口與存檔槽，正式入口及已交付包保留，除非使用者明確要求替換。

## 驗證與交付

- 先跑資源匯入／載入，再用真正 CharacterBody3D 和 InputMap 行走主要完整路線、樓梯、橋、阻擋與出口。抽樣碰撞掃掠輔助覆蓋，不代替實際移動。
- 查看 Blender 全景與 Godot 實際畫面，至少含整體構圖、每個必要區域及人物尺度。讀檔或定位後等兩個物理幀及 frame_post_draw 再截圖，避免捕捉尚未跟隨人物的鏡頭。
- 驗證場景往返、劇情／戰鬥返回位置、單次獎勵、商店／旅館、舊檔遷移和新程序讀取。序章只接現有事件，章末解鎖不等於建立第一章。
- 記錄 FPS／幀時間、Draw Calls、記憶體口徑、硬體及已知尖峰。無頭載入不能代替圖形與移動驗收；Release 不支援的監測值記 null。
- 人工驗證暫停時，繼續獲授權的建模、整合與自動圖形測試；人工 Gate 記為暫停，不能標示通過，也不因等待人工而停止可獨立完成的工作。
- 更新規格、任務、CHANGELOG、來源／授權與實際測試報告。交付 blend、模組 GLB、Godot 入口、圖像證據、缺陷及 Commit SHA。保留未提交使用者修改，不提交本機存檔、暫存、原始引擎日誌、匯出包或機密。
