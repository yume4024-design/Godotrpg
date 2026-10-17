---
name: ai-3d-agent
description: Generate and rebuild low-poly RPG characters through ComfyUI Pixal3D multi-view workflows, then refine, rig, inspect and export with Blender. Use for AI 3D asset production and triangle-budget validation.
---

# AI 3D Agent

以繁體中文溝通。將參考圖、角色規格或現有 GLB 轉成可檢驗的遊戲資產。預設目標為 5,000 triangles，可由使用者覆寫。這是由 Codex 執行的 Agent 工作流程，不是常駐服務。

## 規劃與生成

先確認輸入路徑、角色外觀、面數上限、輸出用途。沿用已提供的規格，缺少模型時先完成提示詞與工作規格，再指出所需輸入。男性戰士範例：黑髮黑眼、黑紅廉價裝備、無披風武器頭盔、全身 A-pose、手臂下垂約 35 度。其他角色不套用此範例。

MODLY 以匯出的 GLB 作為交接格式；不要假設有可呼叫的 MODLY API。使用者要求外部生成時才選擇現有生成工具，先查明工具介面、費用及資料傳送行為。不要把貼上指南的版本或日期當作已驗證事實。

## 預設生成入口：ComfyUI Pixal3D 多視角

`3d_pixal3d_multi_views` 是目前預設的本機 ComfyUI 生成工作流；若使用者另指定來源或工具，遵循該次指示。不擅自改回 MODLY、Hunyuan 或付費 API。先讀 server_info 與工作流節點／slots、確認模型及輸入可用，再驗證工作流。檢查實際 GPU 記憶體，逐角色執行，保留 job prompt_id，不在未完成時重複送件。

在工作目錄複製原工作流後修改，保留使用者原件。四面圖須按實際像素尺寸裁切，排除文字標籤；分離的四張圖可接四個 LoadImage。沿鏈路確認 front／left／back／right 對應，不能只信節點位置或編號。保留原圖，不自行鏡射或改造角色設計。修正 widget 的實際型別；例如 INT 欄位不能使用字串解析度。若 Comfy CLI 把 BOUNDING_BOX 轉回預設 512×512，即使驗證通過也要檢查實際中間圖；改用保留 crop_region 的 API 格式，不能以錯誤上半身圖片繼續產出。

生成時保留 UV／貼圖。低面數目標可在副本設定，但模型完成後仍須實測三角形；角色含必要武器預設低於 5,000 面。不可為達面數直接破壞手指、臉部與關節。生成網格不是已綁定的遊戲角色：另在 Blender 檢查比例、拓樸、權重、代表性動作與配色，再輸出 GLB／工作 blend。

重製雷恩／莉雅時使用專案提供的各自參考圖，所有候選另存，保留既有模型與遊戲引用到新模型驗收通過。重用遊戲角色 ID、動作介面與 RPG 管理系統，不修改戰鬥數值、劇情旗標或存檔契約。模型／依賴缺失或生成失敗如實記錄；不得把準備工作或排隊狀態稱為完成重製。
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
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --factory-startup --python '<skill-folder>\scripts\check_export.py' -- --input '<model.glb>' --output '<new-output-folder>' --budget 5000
```

要求 UV、骨架時分別加入 `--require-uv`、`--require-rig`。骨架存在只代表檢出 Armature，不代表權重與動畫合格。封閉網格使用 `--require-closed`；衣物開口可能合理，因此非流形預設只警告。腳本不統計集合實例，檢出實例就阻止交付。

最終交付原始來源路徑、工作 .blend、GLB、三角面報告，以及仍須人工處理的項目。面數超標或硬性檢查失敗不得宣稱可交付。FBX 僅在使用者需要且確認匯出器可用時提供。
