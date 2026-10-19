# 資產三角面預算與 A01 驗證契約

適用：2026-10-20 Master Plan v1.0；新角色、敵人、NPC 與後續環境建模。A01 Gate：PASS。

## 唯一數值來源

`data/validation/asset_triangle_budgets.json`，格式定義為相鄰的 `asset_triangle_budget.schema.json`。Python／Blender 與 Godot 工具讀取同一個檔案，不各自寫死預算。

| category | 最多三角形 |
|---|---:|
| common_enemy | 10000 |
| elite_enemy | 15000 |
| boss | 15000 |
| player_character | 15000 |
| npc | 15000 |

- 上限採 `0 < triangles <= maximum`，等於上限可通過面數 Gate；10001／15001 必須失敗。
- 建議留下 5%～10% 修整空間，不把建議餘裕變成硬性 9000／13500 上限。
- 固定配件與必要身體零件計入角色總量；可換武器單獨列實測與明確單件預算，另報同屏合計。
- 環境建築、造景、道具及其他未分類物件用明確正整數 `--budget`，在單件任務定用途、尺寸、畫面占比及同屏成本；不沿用角色上限作為全部場景物件預設值。
- 傳 `--category` 可套分類上限；加 `--budget` 只能收緊該類限制。無 category／budget、未知 category、負數或零預算均拒絕。
- 已合格的低面數資產不因上限提高而自動重製；使用者本輪另外指定雷恩／莉雅重製，依最新授權加入後續工作。

## 分層 Gate

| Gate | 內容 | 不代表 |
|---|---|---|
| GLB 預檢 | 有效 JSON/BIN、活動場景實例、索引、有限位置、UV、綁定、權重、inclusive 面數 | evaluated mesh／材質輪廓合格 |
| Blender | 匯入前預檢＋evaluated mesh（含 modifier）、退化面、UV、綁定、實例 | 動作美術合格 |
| 視覺／動畫 | 四面、代表性姿勢、掛點、穿模、切換 | 遊戲流程合格 |
| Godot 功能 | PackedScene、戰鬥取景、場景往返、存讀檔／既有規則回歸 | Release／實體輸入驗收 |

報告欄位：schema_version、category、maximum_triangles、triangles、headroom_triangles、triangle_gate、status、sha256、requirements、failures、warnings、visual_gate、animation_gate。`visual_gate=HUMAN_REVIEW`、`animation_gate=NOT_STARTED` 不能被面數 PASS 蓋掉。

狀態使用 NOT_STARTED／IN_PROGRESS／PASS／FAIL／BLOCKED／HUMAN_REVIEW。空白／失效 Mesh、缺要求的 UV／骨架、NaN／Inf、非法索引、未計數實例等一律 FAIL。

GLB 預檢統計活動 scene 的 mesh node 出現次數；同一 mesh 被重複掛兩次會計兩份成本並 FAIL，不只數 meshes 定義一次。集合／GPU instancing 先拒絕而不低估。Blender 僅排除被骨骼 custom_shape 引用且位於匯入器 `glTF_not_exported` collection 的輔助顯示模型；排除清單寫入報告。一般隱藏零件、固定配件不因此免計。

## 指令

以下從專案根目錄執行。工具不修改來源 GLB、不自動減面；Blender 輸出資料夾必須是新目錄。

```powershell
# 嚴格單件：預設要求 UV 與綁定骨架。
python scripts/tools/audit_character_glb.py --input model.glb --category common_enemy --output artifacts/asset_gate.json

# 角色／裝備分開限制，同時列出同屏成本；1500 僅為本命令示例的單件武器預算。
python scripts/tools/audit_character_glb.py --input actor.glb --category player_character --equipment weapon.glb --equipment-budget 1500 --output artifacts/equipped_gate.json

# 靜態場景物件：由該件任務給預算，明確免骨架。
python scripts/tools/audit_character_glb.py --input prop.glb --budget 2000 --allow-static --output artifacts/prop_gate.json

# Blender 最終 evaluated mesh 檢查。
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input model.glb --output artifacts/new_asset_check --category common_enemy --require-uv --require-rig

# 原有角色 bundle 介面保留：主 JSON 仍為 list，另寫 .gate.json 詳細 Gate。
python scripts/tools/audit_character_glb.py --pixal

# 參考圖結構與真正透明度檢查，仍需人工方向／完整性確認。
python scripts/tools/audit_asset_references.py --input references --output artifacts/reference_gate.json

# 工作流只產生副本（保留 8% 餘裕），不排隊生成。
python scripts/tools/prepare_asset_workflow.py --source current_workflow.json --output artifacts/new_workflow.json --category common_enemy

python tests/asset_validation_test.py
python tests/asset_validation_test.py --blender 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe'
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python-exit-code 1 --python tests/blender_asset_budget_test.py
./tools/godot.ps1 -Mode TestAssetBudget
```

單件 `--allow-static`／`--allow-missing-uv` 是明確需求設定，報告會列出；不得把省略的項目寫成通過。歷史人物 bundle 的純色眼皮等零件可沒有 UV，因此 bundle 明確使用 require_uv=false；新分類單件預設仍嚴格要求 UV。

## 四視圖輸入

命名 front.png／left.png／back.png／right.png。PNG RGBA、背景真 Alpha、統一畫布、完整身體及四肢／翅膀，禁止標籤與紅框。工具記錄尺寸、Alpha 範圍、輪廓邊界及 SHA256，拒絕完全重複／精確鏡射側圖；不能自動證明正交、解剖、裝備一致或沒有文字，結構成功只到 HUMAN_REVIEW。

## 實際驗證

詳見 [ASSET_GENERATION_REPORT.md](ASSET_GENERATION_REPORT.md) 與 [ASSET_A01_TEST_RESULTS.json](ASSET_A01_TEST_RESULTS.json)。本輪只認證工具規則；沒有新生成資產的正式品質認證。Android／iOS 暫停，Windows RC2 未改。
