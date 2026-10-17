# 雷恩／莉雅 — ComfyUI Pixal3D 重製（2026-10-17～18）

依使用者指定，以現有 `3d_pixal3d_multi_views` 工作流重新生成兩人的身體／服裝／UV 貼圖，沒有把舊模型換名充當重製。Blender 重新建立骨架、權重、七段動作與少量可讀的眼睛／嘴線；G06 新版灰石村的探索、NPC、戰鬥與角色檢視已切換新 PackedScene。正式 v0.6.1 入口與輸出、舊角色 GLB／blend 保留。

## 實際交付

| 角色 | 執行用 GLB | 三角形 | 骨架 | 貼圖 |
| --- | --- | ---: | --- | --- |
| 雷恩 | assets/models/pixal3d/ren_rigged.glb | 4,815 | 19 節點 | 三張 1024×1024 PBR 圖 |
| 莉雅 | assets/models/pixal3d/lia_rigged.glb | 4,806 | 19 節點 | 三張 1024×1024 PBR 圖 |
| 莉雅持杖 | 上列莉雅＋既有 willow_staff | 4,946 | HandRight 掛點 | 沿用既有法杖 |

19 節點包含 Root 與不變形的 Coat 保留節點，16 個實際變形骨；手部為 Hand／Fingers 群組，**不是五指獨立關節**。七段可匯出動畫為 attack、cast、guard、hit、potion、walk、run；walk 一秒，其餘各 2/3 秒。兩人各有八個 Blink 表面及簡單嘴線，沒有口型動畫。雷恩現在有可播放的基本戰鬥動作，仍未新增劍模型或專用持劍招式。

- 工作檔：`assets/source/pixal3d/ren_rigged.blend`、`lia_rigged.blend`。
- 原始 ComfyUI 低面數輸出：`assets/source/pixal3d/raw/*_generated.glb`；原始 2K normal 保留，執行用模型在 Blender 匯出前降為 1K。
- 來源圖：`assets/source/pixal3d/references/`，雷恩為本次提供四面合圖、莉雅為先前四張指定圖；不修改根目錄原件。
- 雜湊、模型／工作流版本、實際 prompt_id 與參考圖：`assets/source/pixal3d/generation_manifest.json`。
- 新場景：`scenes/characters/ren_pixal_visual.tscn`、`lia_pixal_visual.tscn`。

## 工作流與技能變更

原工作流在本機 ComfyUI user/default/workflows，保留未改。專案 API 模板在 `scripts/tools/workflows/pixal3d/3d_pixal3d_multi_views.api.json`；`prepare_pixal3d_workflows.py` 產生雷恩合圖裁切、莉雅四張 LoadImage 的副本，不會自行送出生成。

實際 ComfyUI 0.41.3、Comfy CLI 1.22.0，RTX 3080 12GiB；使用已安裝的 `pixal3d_multiview_int8_convrot.safetensors`、DINOv3、Trellis.2 shape／texture VAE、BiRefNet。工作流驗證沒有付費 API 節點；未購買素材、下載額外模型或升級引擎。shape 1024、texture 1024、remesh 384、目標 4,800 面。原始成功輸出雷恩 4,757／莉雅 4,748 面；後加 58 面眼睛與嘴線，沒有把完整舊模型拼入候選。

最初 UI 副本把 target_resolution 字串改為 INT 後雖通過驗證，實際 PNG metadata 顯示 Comfy CLI 把四個 BOUNDING_BOX 全轉成預設 512×512，只得到同一張上半身。已取消該工作 `eda8fda3-d667-4641-a65a-80513c6bb39f`，未採用其模型；API 副本保存正確裁圖座標後，查看四張完整人物中間圖才繼續。成功工作：

- 雷恩 `4397b111-bf37-4ff4-8312-02494c7ba4f5`。
- 莉雅 `5bed02b9-a91d-463d-9b5a-b13db2b591fa`。

全域 `ai-3d-agent/SKILL.md` 已改以此流程為預設生成入口，專案鏡像見 [技能檔](skills/ai-3d-agent/SKILL.md)，保留原技能備份在 artifacts。技能驗證需使用具 PyYAML 的 Comfy Python 並開啟 UTF-8；已輸出 `Skill is valid!`。Blender MCP 確認目前使用者場景正在 PAINT_TEXTURE 且未儲存，因此所有加工均在獨立 Blender 5.2.2 背景程序執行。

## Blender 與 Godot 驗證

`inspect_pixal3d_candidate.py` 檢查原始 GLB、正規化為 1.95m、保存中間 blend 與四視圖。`refine_pixal3d_faces.py` 加可讀的眼睛／嘴線、UV 及眨眼形變。`rig_pixal3d_candidate.py` 按新角色手腕位置建立骨架與區域平滑權重，並烘焙循環平地鞋底；沒有套用不合比例的舊骨架。

修正過的實際問題：新增眼部最初沒有 UV，Godot tangent 生成報錯，已補 UV 後重匯入；最初固定手臂分區誤選少量髖部，已改成沿手臂中線的邊界並加入「髖部不可綁到手臂」檢查。最後 GLB 權重和最大誤差雷恩約 5.96e-8、莉雅約 8.94e-8，所有綁定關節索引有效。

Blender `check_export.py --budget 5000 --require-rig --require-uv` 兩者通過，最終報告在 `artifacts/pixal3d/check_ren_v2/`／`check_lia_v2/`。檢查器另計 80 面 Blender 骨骼顯示輔助物，為 4,895／4,886 面；Godot 與 GLB 實際網格數以上表為準。最終 `audit_character_glb.py --pixal` 及 `write_pixal3d_manifest.py` 再確認面數、19 joints、七片段與全部執行用貼圖 ≤1K。

Windows／Godot 4.7.2.stable.official.ed1daf0bf／RTX 3080 Compatibility，實際結果：

| 模式 | 結果 | artifacts/logs 日誌 |
| --- | --- | --- |
| Check | 載入及匯入成功 | check-20261018-000146-743.log |
| TestPixalCharacters | 88/0；兩人材質、動作／行走／跑步／恢復、持杖、眨眼與骨架有限值 | testpixalcharacters-20261018-000150-776.log |
| TestCharacterPreview | 12/0；滑鼠切換兩人、動作、法杖、視角及保存圖片 | testcharacterpreview-20261017-235300-897.log |
| VisualG06Story | 68/0；新版角色的村莊／森林／礦坑、Boss、任務、單次獎勵及存讀檔 | visualg06story-20261018-000204-012.log |
| TestG06StoryReload | 7/0；新程序讀取角色／裝備／212 金幣／星印／獎勵帳本 | testg06storyreload-20261018-000227-866.log |
| TestG06 | 51/0；舊檔位元組保留、遷移與無效資料拒絕 | testg06-20261017-235330-339.log |
| VisualFemaleAnimation | 舊版角色相容回歸 38/0，新增掛點 export 預設值保留原行為 | visualfemaleanimation-20261017-235105-704.log |
| ProfileCharacters | 31/0；新模型與原始卡通基線對照 | profilecharacters-20261017-235335-380.log |

新模型實際戰鬥 12 次成功行動：平均 1.023ms、P95 1.223ms、P99 1.386ms、最慢 7.013ms，327～343 Draw Calls；引擎靜態配置峰值約 125.1MiB、顯示配置約 77.4MiB。這是暖機後桌面診斷，含測試程式；不是程序 RSS、GPU 計時、無洩漏證明或低階 PC／手機認證。

已查看兩人新 GLB 四視圖、Godot 正／側／背、跑步、施法／攻擊與實際序章畫面；證據 `artifacts/pixal3d/{ren,lia}/godot_*.webp` 及 `artifacts/phase5/g063-*.webp`。動作驗證為指定小幅片段及有限取樣，不宣稱全動作完全無穿插。

2026-10-18 最後近景確認另發現手腕內緣跨分區被綁到下半身，造成跑步時少量碎片拉開；已調整手臂分界寬度及手指最低高度，加入「髖部不可綁手臂／外側手部不可綁腿」兩項建模檢查。上述 10-18 的載入、88 動作、68 序章及 7 重啟是此修正後的結果，已重看兩人跑步及持杖畫面，碎片拉開不再出現在抽樣姿勢。

## 保留事項

- 正式 `scenes/main/main.tscn`／v0.6.1 主入口未更換，正式 exe／pck SHA256 與先前一致。G06 經角色資料副本替換外觀，角色 ID、數值、技能、旗標、獎勵及存檔 schema 不改。
- 舊 `ren_user`、`lia_user`／`lia_rigged` 的 GLB、blend 與歷史測試保留。獨立莉雅貼地工具仍用先前已量測的舊角色原型；**新版模型沒有啟用未驗證的 IK**。
- AI 生成的衣料／髮束仍有局部貼圖扭曲及參考圖線條痕跡；近景品質不是四面原畫逐像素重建。手部是 Fingers 群組，不宣稱五指精密握劍；肩髖極端姿勢、衣物穿插、嘴型與專用劍招仍需進一步美術工作。
- 既有 12cm 實體階梯無法上階的控制器限制未變；Android／iOS 暫停，沒有進入 G07.5 或新增章節。

開啟新角色檢視：`./tools/godot.ps1 -Mode PreviewCharacters`；新版遊戲：`./tools/godot.ps1 -Mode RunG06`。舊 Windows 預覽 ZIP 是先前快照，沒有冒稱已重新匯出此輪模型。
