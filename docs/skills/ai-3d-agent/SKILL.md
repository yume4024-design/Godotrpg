---
name: ai-3d-agent
description: Generate and rebuild low-poly RPG characters through ComfyUI Pixal3D multi-view workflows, then refine, rig, inspect and export with Blender. Use for AI 3D asset production and triangle-budget validation.
---

# AI 3D Agent

以繁體中文溝通。將參考圖、角色規格或現有 GLB 轉成可檢驗的遊戲資產。Project Crystal 使用共用分類預算：一般敵人最多 10,000；菁英、Boss、玩家角色與 NPC 最多 15,000 triangles。未分類資產須明確指定預算，不再默認 5,000。這是由 Codex 執行的 Agent 工作流程，不是常駐服務。

## 規劃與生成

先確認輸入路徑、角色外觀、面數上限、輸出用途。沿用已提供的規格，缺少模型時先完成提示詞與工作規格，再指出所需輸入。男性戰士範例：黑髮黑眼、黑紅廉價裝備、無披風武器頭盔、全身 A-pose、手臂下垂約 35 度。其他角色不套用此範例。

MODLY 以匯出的 GLB 作為交接格式；不要假設有可呼叫的 MODLY API。使用者要求外部生成時才選擇現有生成工具，先查明工具介面、費用及資料傳送行為。不要把貼上指南的版本或日期當作已驗證事實。

## 預設生成入口：ComfyUI Pixal3D 多視角

`3d_pixal3d_multi_views` 是目前預設的本機 ComfyUI 生成工作流；若使用者另指定來源或工具，遵循該次指示。不擅自改回 MODLY、Hunyuan 或付費 API。先讀 server_info 與工作流節點／slots、確認模型及輸入可用，再驗證工作流。檢查實際 GPU 記憶體，逐角色執行，保留 job prompt_id，不在未完成時重複送件。

在工作目錄複製原工作流後修改，保留使用者原件。四面圖須按實際像素尺寸裁切，排除文字標籤；分離的四張圖可接四個 LoadImage。沿鏈路確認 front／left／back／right 對應，不能只信節點位置或編號。保留原圖，不自行鏡射或改造角色設計。修正 widget 的實際型別；例如 INT 欄位不能使用字串解析度。若 Comfy CLI 把 BOUNDING_BOX 轉回預設 512×512，即使驗證通過也要檢查實際中間圖；改用保留 crop_region 的 API 格式，不能以錯誤上半身圖片繼續產出。

生成時保留 UV／貼圖。低面數目標可在副本設定，但模型完成後仍須實測三角形；最終角色含固定配件的 evaluated mesh 不得高於所屬分類上限；可換武器分開統計並列出角色加武器的同屏成本。等於上限可通過面數 Gate，預留 5%～10% 修正空間是建議，不是額外硬上限。已合格的舊低面數模型不因上限提高而重製。不可為達面數直接破壞手指、臉部與關節。生成網格不是已綁定的遊戲角色：另在 Blender 檢查比例、拓樸、權重、代表性動作與配色，再輸出 GLB／工作 blend。

重製雷恩／莉雅時使用專案提供的各自參考圖，所有候選另存，保留既有模型與遊戲引用到新模型驗收通過。重用遊戲角色 ID、動作介面與 RPG 管理系統，不修改戰鬥數值、劇情旗標或存檔契約。模型／依賴缺失或生成失敗如實記錄；不得把準備工作或排隊狀態稱為完成重製。
### 更新後的工作流（2026-10-18）

每次從目前 ComfyUI workspace 的 `user/default/workflows/3d_pixal3d_multi_views.json` 重新讀取並記錄 SHA256；不要以專案舊 API 範本覆蓋使用者更新。此次檢查來源為 `D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/user/default/workflows/3d_pixal3d_multi_views.json`，SHA256 `E67579BC7FF8E9B5D21FDF19A50B395F16EF3FFEF0CDCF4A40E8A3D66B5110B9`。路徑與節點編號只是本機快照，移機或再次更新時重新解析。

新版預設使用四張獨立圖片，不再把同一張四面圖套入四個裁切：front 來源 LoadImage 364、left 377、back 378、right 379；目前檔名依序為 `正 (1).png`、`左 (1).png`、`背 (2).png`、`右 (2).png`。沿實際連線核對方向。各路經 ImageCropV2 → ImageCropToMask → SaveImageAdvanced → Pixal3DMultiViewConditioning；本版條件輸入鏈未經 RemoveBackground，不可因旁邊存在去背節點就假定已去背。替換角色時更新全部四路輸入；按各張圖片尺寸重設 crop_region 並檢查全身輪廓、手腳、文字及背景，禁止沿用舊拼圖座標或把左右視圖自動鏡射。

本版來源預設：shape upsample 1536、貼圖共用解析度 4096、remesh 768、DecimateMesh 30,000。30,000 是歷史生成候選設定，不符合目前角色／Boss 最多 15,000、一般敵人最多 10,000 的最終預算；保留高面數來源，再依角色輪廓與變形需要製作遊戲版本。不得默默套回舊 API 的 1024／384／4800 設定；需要降低硬體負擔時只修改副本並記錄原因、實際值與視覺結果。

本版原件的節點 94 `target_resolution` 仍為字串 `"1536"`，live validate 回報 expected INT；執行前於副本改為整數 1536 並重新驗證。驗證通過只代表 schema／連線檢查，不代表裁切轉換正確、記憶體足夠或生成品質合格。檢查轉出的 API crop_region 與實際中間圖後才能繼續。只要求更新 Skill 時，不送出生成工作、不改使用者原工作流或遊戲模型。
## Blender 加工

優先使用可用的 Blender MCP 讀取場景，先建立新工作目錄並保存備份。CLI 處理時使用新 Blender 背景程序，避免影響使用者正在編輯的場景。原始輸入一律保留。

1. 檢查物件、尺寸、評估後三角面、材質、UV、骨架、非流形與退化面。
2. 為超標部分分配面數，依輪廓與關節需要選擇修整方式。每次減面在副本進行並重新檢查；最多三次，品質下降則停止並回報人工 retopology 部位。
3. 有骨架或關節變形需求時，不能僅凭 Decimate 判定安全。檢查權重和代表性姿勢。保留角色指定配色與姿勢。
4. 修正命名、原點、法線與材質時不得猜測缺失的部位。Flat Shading 依指定視覺風格使用。零件分離必須依真實幾何判斷。
5. 用 MCP 視覺工具或渲染檢查正側背面與四肢間隙。沒有視覺檢查、變形測試或人工判斷的項目，報告為未驗證。

## 檢查與交付

附帶 `scripts/check_export.py` 可在獨立 Blender 程序匯入 GLB，產生 JSON 報告。它不會自動減面，不會驗證美術輪廓或動畫品質。預設只檢查；加 `--export` 才會在基本檢查通過後輸出 GLB 與 .blend。輸出目錄必須是新目錄。

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python '<skill-folder>\scripts\check_export.py' -- --input '<model.glb>' --output '<new-output-folder>' --project-root 'D:\RPGGAME' --category common_enemy --require-uv --require-rig
```

要求 UV、骨架時分別加入 `--require-uv`、`--require-rig`。骨架存在只代表檢出 Armature，不代表權重與動畫合格。封閉網格使用 `--require-closed`；衣物開口可能合理，因此非流形預設只警告。計數依 Blender evaluated mesh，固定配件計入。集合／GPU 實例與非預期重複 mesh 必須拒絕，不能漏算。匯入器生成的 glTF_not_exported 骨骼 custom-shape 輔助球明確列入 ignored_importer_bone_helpers，不算作角色幾何；不能據此排除任意隱藏模型。GLB 預檢先拒絕空網格、失效索引、NaN／Inf、缺 UV／綁定與越界權重，避免 Blender 自動修整掩蓋原檔缺陷。

最終交付原始來源路徑、工作 .blend、GLB、三角面報告，以及仍須人工處理的項目。面數超標或硬性檢查失敗不得宣稱可交付。FBX 僅在使用者需要且確認匯出器可用時提供。

## Project Crystal A01：分類與驗收契約（2026-10-20）

在 Project Crystal 工作時先讀 `docs/ASSET_TRIANGLE_BUDGET.md`；唯一數值來源為 `data/validation/asset_triangle_budgets.json`。分類鍵為 common_enemy／elite_enemy／boss／player_character／npc。工具接受 `--category` 或明確正整數 `--budget`；分類加較小預算可收緊，不能提高該類上限。

- 使用專案 `scripts/tools/audit_character_glb.py --input <GLB> --category <key> --output <report.json>` 預檢；UV 與骨架預設必須具備。靜態道具只在明確 `--allow-static` 時不要求骨架；純色無 UV 資產須明確 `--allow-missing-uv` 並記入報告，不得稱其 UV Gate 已通過。
- Blender 檢查器需在專案 cwd 執行或傳 `--project-root`，共用專案 policy／預檢；不自動減面。失敗回非零退出碼並保留 report.json；禁止用忽略例外繼續交付。
- 四視圖使用 front.png、left.png、back.png、right.png，各自 PNG RGBA、真 Alpha、完整身體與一致比例。`scripts/tools/audit_asset_references.py` 可檢查尺寸、SHA256、重複／精確鏡射及 Alpha；正交方向、四肢／裝備一致與文字標註仍需 HUMAN_REVIEW，結構通過不等於 READY。保留原件，不為改名搬動使用者來源。
- `scripts/tools/prepare_asset_workflow.py` 只在新檔套分類候選目標與 INT 修正；每次讀最新原件 SHA。工作流 widget／連線變更時停止檢查，不能猜節點。先 validate 副本，不排隊生成；生成階段才檢查裁切、實際四路條件、VRAM 與 seed。未驗收不重複送件，最多三次明確記錄的生成／修整嘗試後回報。
- 報告分開記 triangle_gate、結構／權重 Gate、visual_gate、animation_gate、引擎／功能 Gate，並記來源 SHA、category、上限、實測、固定配件與武器成本、命令、引擎版本、證據及限制。狀態為 NOT_STARTED／IN_PROGRESS／PASS／FAIL／BLOCKED／HUMAN_REVIEW；面數 PASS 不代表正式可用。
- A01 只更新工具與規範；A02 整理來源；A03 逐敵驗收；A04 才整合正式視覺。序章、數值、存檔及 Windows RC2 不隨 Skill 更新修改。

使用者 2026-10-20 追加場景／造景／物品 3D 建模與雷恩／莉雅重製：依 `docs/ASSET_PRODUCTION_REQUESTS.md` 排入後續任務。環境物件逐件明確 --budget；角色重製沿用提供的原設計與獨立候選驗收，不把既有模型重新命名冒充新成果。
