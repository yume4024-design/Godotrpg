---
name: crystal-scene-builder
description: Build and refine reference-driven modular Blender environments and playable Godot scenes for Project Crystal, including visual fidelity, materials, traversal and regression evidence. Use for village, forest, mine or dungeon construction from scene references; validate Windows candidate exports when delivery is in scope.
---

# Crystal Scene Builder

將使用者參考圖製作成可探索的完整場景。以目前專案 AGENTS、TASKS 和最新使用者指示確定範圍；不是只輸出概念圖、空殼場景或隨意排列幾何體。

## 工作入口與完成條件

- 先讀現有場景報告與 Git 狀態，辨識最新來源、已交付包、未提交使用者修改及目前授權範圍。已合格部分重用；「繼續」依最新任務接續，不重跑整個製作流程。
- 拆圖／建模／材質修整時讀 [場景修整與實景驗證](references/scene-refinement.md)。完整 Windows 候選交付在範圍內時，再讀 [Windows 固定包交付](references/windows-delivery.md)；單純改素材或更新 Skill 不因此啟動打包。
- 以「參考對照 → Blender 模組／完整主檔 → Godot 實景 → 真實動線／RPG 回歸 → 本輪交付」循環。每輪先處理已重現的主要差距，修正失敗後才擴充。
- 分別記錄場景搭建、視覺對照、自動功能測試、固定包測試、人工認可；各項須有對應證據。佈局相近、檢查數量或面數達標，都不代表畫面已還原。保留與參考圖的具體差距，不把候選交付寫成使用者認可。

## 構圖與資產

- 先拆解參考圖：命名區域、相鄰關係、高低差、地標、道路、橋、水道、入口和劇情點。寫入可讀的場景規格與機器可讀 layout，區分必要空間關係與可調比例。
- 同時對照建築／人物尺度、廣場與草地比例、河寬、植栽密度、主色及鏡頭投影。既有布局若不符最新要求，明確列出需要重建與遷移的部分，不能為保留舊碰撞而宣稱已還原。
- 盤點現有 GLB、PackedScene、材質、碰撞與授權。合格資產優先重用；新增缺少的組件，不能把重新命名的舊資產算成新模型。
- 按圖片底部素材表建立模組清單。規則結構可用 Blender Python 建模；複雜外形需要 AI 生成時採用已安裝 ai-3d-agent 的當前本機 Pixal3D 流程，保留來源與 job ID。沒有明確授權不購買素材或使用付費 API。
- 四視圖必須為正交 front/left/back/right、完整輪廓和一致比例；不能以鏡射冒充另一面。若可以直接以 Blender 正確建模，不為湊流程而生成無用圖片。
- 在獨立 Blender 場景組裝整個環境，保留可編輯 blend、分區 Collections、可重用物件與共享材質。使用者正在編輯其他 blend 時用背景程序，先讀取 live scene；不要清空其場景。
- Blender CLI 加入 `--python-exit-code 1`，核對完成 marker 與腳本／layout SHA；一般退出碼0可能仍有Python例外，不能用殘留GLB或舊manifest冒稱新生成成功。
- 原則為 1 Godot unit = 1m，Godot Y up；Godot 座標 (x, y, z) 轉到 Blender 為 (x, -z, y)，匯出 glTF 2.0/GLB。以目前玩家實際身高、門洞及走道檢查比例，避免只對縮圖構圖。
- 材質沿用場景色彩語彙。岩層、土粒、木紋、動態水面、瀑布、晶體發光需有可見效果；不把來源概念圖當貼圖。記錄實測面數、材質、Mesh 與重複實例成本；環境預算按用途訂定，不套用角色上限。
- Blender程序節點不保證能經glTF轉入Godot。需要時在Godot建立等效共享Shader或另烘焙貼圖；以實際引擎畫面確認，防止木材匯入成白色。合併分區前將活動網格設為單一使用者，避免join改寫其他實例的共享資料。
- MCP 不支援某項操作時，保留其安全設定，改用支援的 GLB 匯入或獨立 Blender Python 流程；記錄主檔與 live scene 的版本，避免拿舊預覽驗收新輸出。

## 可玩性與整合

- 地面／橋面／斜坡使用簡化且對齊的碰撞；裝飾不使用密集網格碰撞。可見樓梯可搭配連續坡面碰撞，但要實際走跑驗證上、下行及轉折。
- 深坑、水面與地圖外圍須有明確邊界。不得以隱形平地填滿水道來偽裝可探索，亦不得靠瞬移測試宣稱整條路可走。
- Godot 保留分區、視覺、碰撞、互動與出生點管理，重用 PackedScene／Mesh，不將全部世界合成無法替換的一塊模型。
- 接回既有 Player、Camera、Dialogue、Story、Quest、Battle、Inventory 與 Save 系統。場景重建不建立平行管理器，不改角色 ID、數值、旗標或獎勵規則。
- 改變可走佈局時建立獨立 location layout version；舊位置先在原地圖驗證，再映射安全點，保留完整進度與來源存檔。新位置仍須真實碰撞驗證，不放寬 SaveCodec 以接受水中或岩內座標。
- 僅做美術修整時，對照修改前後道路、地形、碰撞及互動／出生點；可用世界座標幾何雜湊輔助保護。雜湊不代替新植栽、屋簷、岩石的實際通行與遮擋檢查。
- 新候選使用獨立入口與存檔槽，正式入口及已交付包保留，除非使用者明確要求替換。

## 驗證與交付

- 先跑資源匯入／載入，再用真正 CharacterBody3D 和 InputMap 行走主要完整路線、樓梯、橋、阻擋與出口。抽樣碰撞掃掠輔助覆蓋，不代替實際移動。
- 查看 Blender 全景與 Godot 實際畫面，至少含整體構圖、每個必要區域及人物尺度。讀檔或定位後等兩個物理幀及 frame_post_draw 再截圖，避免捕捉尚未跟隨人物的鏡頭。
- 驗證場景往返、劇情／戰鬥返回位置、單次獎勵、商店／旅館、舊檔遷移和新程序讀取。序章只接現有事件，章末解鎖不等於建立第一章。
- 記錄 FPS／幀時間、Draw Calls、記憶體口徑、硬體及已知尖峰。無頭載入不能代替圖形與移動驗收；Release 不支援的監測值記 null。
- 來源專案與匯出包使用不同證據；版本更新時核對候選設定、QA 預期值及匯出 preset，再從固定提交建置。保留失敗記錄及修正後重跑結果，不把退出碼0或出現視窗當作完整通過。
- 人工驗證暫停時，繼續獲授權的建模、整合與自動圖形測試；人工 Gate 記為暫停，不能標示通過，也不因等待人工而停止可獨立完成的工作。
- 更新規格、任務、CHANGELOG、來源／授權與實際測試報告。交付 blend、模組 GLB、Godot 入口、圖像證據、缺陷及 Commit SHA。保留未提交使用者修改，不提交本機存檔、暫存、原始引擎日誌、匯出包或機密。

此流程整理自灰石村完整場景與 RC3 的實際修整。專案內 `docs/GREYSTONE_SCENE_COMPLETION_REPORT.md` 可追溯當次證據；當次座標、面數、版本與測試數量不是其他場景的固定門檻。
