# 現有環境資產盤點（2026-10-20）

**後續進度：** 新增水車獨立模組 1212／2500 triangles、Blender／Godot 26／0；見 [ENV02 水車報告](ENV02_WATERWHEEL_REPORT.md)。正式村莊仍保留水車及作物佔位，未宣稱整村替換或效能通過。以下 83 檔是建模前快照，不含這件新候選。

這是追加 ENV01／ENV02／ITEM01 的來源盤點，**不是新一輪造景或效能驗收**。依檔案重新量測，未修改任何模型、場景或碰撞；已合格模型先保留，不因追加需求全部重造。

| 現有目錄 | GLB 檔數 | 各一份的三角形總和 | 檔案大小總和 |
|---|---:|---:|---:|
| greystone/buildings | 7 | 38778 | 2877748 bytes |
| greystone/props | 17 | 1793 | 166344 bytes |
| greystone/terrain | 59 | 12409 | 1026952 bytes |

每檔原始 GLB SHA256、大小、active-scene 面數、材質定義與貼圖數見 `source_assets/environment_inventory_20261020/inventory.json`。這些總和不是整村實例面數或 Draw Calls；材質定義數也不是 Godot 共用材質／渲染批次數。沒有為環境套上角色的 15000 預算。

```powershell
& 'D:/Comfy-Desktop/ComfyUI-Installs/ComfyUI/ComfyUI/.venv/Scripts/python.exe' -X utf8 scripts/tools/inventory_environment_assets.py --output source_assets/environment_inventory_20261020/inventory.json
```

既有快照會拒絕覆寫；重測時指定新路徑。實際 83 個 GLB 均可解析，七建築／17 道具總面數與 G03／G04 報告一致；另外逐檔核對 17 道具的舊 verified_glb.json，SHA 及面數全部相同。這只能證明檔案沿用，不取代新版村莊藝術、碰撞及效能驗收。

## 確認仍需製作／確認的部分

- `greystone_village.tscn` 實際引用 `placeholders/crop.tscn` **28 個**、`placeholders/waterwheel.tscn` **1 個**；水車及作物沒有獨立正式 GLB，不能算在 G04 已完成 17 道具之內。ENV02 優先補這兩類。
- 七建築為既有可重用 GLB／PackedScene，原 Quaternius CC0 及本專案修改來源維持 ASSET_CREDITS 記錄；參考圖還原程度須再看當前遊戲畫面，不能只用模型存在宣稱完全還原。
- 擴充森林／礦坑由 `expanded_wilderness.gd` 使用舊 round_tree／moss_rock GLB、花／星晶 PackedScene；地板、邊界、道路與礦坑柱／橫梁仍有原生 BoxMesh。道路／碰撞幾何可以保留；需要裝飾造型的坑木另列可替換 GLB。
- 森林／礦坑所有素材、可見掉落／物品／武器掛點的完整盤點未完成；ITEM01 不能由本次灰石村清單宣稱完成。

## 下一個獨立建模項

先量測原水車及作物的尺寸、原點、材質和放置位置，再用 Blender 建立獨立模組。水車暫訂上限 2500 triangles、每組作物上限 300（28 組同屏最多 8400）；這是後續單件預算提案，尚無新模型或效能 PASS。

替換時保留道路與 NPC 預留位置、原碰撞行為；先做獨立模型預覽／比例／材質，再做實際村莊探索、碰撞及效能回歸。當前未製作新環境模型，未替換正式場景；Android／iOS 暫停。
