# 鐵匠與艾琳 — 完整模型生成

2026-10-18 使用者指定 `npc/` 與 `艾琳角色圖/`，以角色完整為優先，不刻意減面。本次只製作獨立來源模型，不替換遊戲引用、不新增第一章或修改角色數值、劇情與存檔。

## 輸入與方法

- `npc/` 目前包含鐵匠四面圖；艾琳使用自己的正、左、背、右四張圖。原圖保留，未鏡射。
- 使用本機 ComfyUI `3d_pixal3d_multi_views` 現行工作流副本；原件 SHA256 `1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275`。
- Shape 1536、貼圖 4096、Remesh 768；移除 DecimateMesh，平滑迭代 0、小零件刪除門檻 0。Remesh 會重建拓樸，因此另外保留重建前原始形狀。
- 預檢四路實際圖片，確認全身、頭、手、靴子及方向均保留；兩份完整 API 驗證無錯誤。生成及貼圖在本機執行，沒有付費 API。
- 詳細設定、參考圖雜湊及工作 ID 見 `source_assets/quality_characters_20261018/generation_manifest.json`。

## 交付與狀態

模型保存在 `source_assets/quality_characters_20261018/`，繼承來源目錄 `.gdignore`，不會被 Godot 當作正式遊戲資源匯入。大型 GLB／Blend 留在本機，不直接提交至 GitHub。

| 角色 | 原始形狀三角形 | 貼圖 GLB 三角形 | Blender 匯入後 | 貼圖 GLB 大小 |
| --- | ---: | ---: | ---: | ---: |
| 鐵匠 | 9,927,242 | 4,490,390 | 4,489,845 | 196,224,548 bytes |
| 艾琳 | 9,605,674 | 4,030,176 | 4,029,104 | 185,945,428 bytes |

GLB accessor 與 Blender 匯入後面數分開記錄；匯入器會丟棄部分不可表示的退化／重複面，未添加 Decimate 或主動減面。原始 GLB 未改寫。

每個角色目錄包含 `{name}_shape_original.glb`、`{name}_textured_full.glb`、`glb_audit.json` 與 `blender_inspection.json`；`inspection/` 包含 `{name}_full.blend` 及 `front.png`、`side.png`、`back.png`。角色名稱為 `blacksmith`／`aerin`。

## 實際檢查

- Comfy 完整工作均完成：鐵匠 `1ae48984-0a04-4753-ba4e-b4b5d9acba85`；艾琳 `6f477860-f244-483d-9ff1-2e7e483564c8`。
- Blender **5.2.2 LTS** 新背景程序逐一匯入，兩名角色均有 UV、1 材質及 3 張內嵌貼圖，尺寸 4096²、4096²、2048²。檢視正／側／背面實際渲染，完整頭身與四肢均存在。
- 已存獨立 Blend；材質與貼圖保留。沒有移動使用者現有 Blender 場景。
- 鐵匠與艾琳分別有 28／39 條超過兩面共用邊；未焊接邊界分別為 649,614／737,553，包含 glTF 的 UV／法線拆點，不能直接解讀成同數量破洞。匯入後面積 ≤1e-16 的面均為 0。未認證封閉網格或可直接變形拓樸。
- 可見手指、扣件及艾琳五官有 AI 重建痕跡，部分指縫不清楚；沒有因此自動破壞／簡化整體模型。工作模型約 1m 高、原點與生成結果相同，尚未改為正式角色身高與腳底原點。
- Blender 出現本機縮圖快取無法寫入提示，程序仍 exit 0，六張渲染與兩個 Blend 實際存在；不將縮圖提示列作模型匯入失敗。

## 重現

`scripts/tools/prepare_quality_character_workflows.py` 產生本機 API 副本，不會送件；必須先用 Comfy 工具取得當前工作流 slots。`audit_quality_glb.py` 讀取 GLB metadata 並串流計算 SHA256；`inspect_quality_character.py` 在獨立 Blender 執行匯入、網格檢查、三面渲染及保存 Blend。無面數上限斷言。工具 Python 語法檢查通過。

例：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python scripts/tools/inspect_quality_character.py -- --input D:/RPGGAME/source_assets/quality_characters_20261018/aerin/aerin_textured_full.glb --output D:/RPGGAME/artifacts/quality_characters/aerin_review --name aerin
```

尚未綁定骨架、製作動畫或完成遊戲整合；不得將來源模型稱為已通過遊戲角色驗收。完整性檢查須以生成後的 3D 視圖為準，參考圖預檢不代表最終拓樸或手指品質通過。
