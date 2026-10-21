# 莉雅重製 — 新生成與靜態表面候選

2026-10-22，接續bf0a3b1，feature/greystone-g06。**整體IN_PROGRESS：完成新3D來源、頭部局部底色修整及靜態匯入；拓樸精修、骨架、動作與正式遊戲整合尚未完成。** 未將既有4806面莉雅改名當作新模型。

## 來源及實際生成

- 使用已核准的金髮、藍眼、紫衣四視圖，來源 `source_assets/reference_library_20261020/characters/lia/references/`，逐張SHA仍與 `source_adoption_20261020.json` 一致。未新增造型／配件或自行鏡射。
- 重新讀取使用者目前工作流，SHA256 **1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275**，原件不修改。四路沿實際連線追蹤，裁切節點是bypass，實際經RemoveBackground／ImageCropToMask／SaveImageAdvanced，再進入Pixal3D條件。
- 沿用現有 `prepare_reference_asset.py`，新增選用 `--tag` 及核准圖SHA檢查，避免重複建立工作流工具。莉雅副本與實際提交API等價；預設雷恩API與已完成的原inputs／full兩檔完全相同。
- 條件工作 **1e256b7e-39ff-4f8c-bb81-7dc760d42119** completed，四張實際輸出已查看完整頭髮、衣擺、手腳及正左背右。
- 單件3D工作 **5a7e6c0e-7cf5-4ad1-8844-bb9838777e58** completed，ComfyUI 0.41.3，本機127.0.0.1:8188／RTX3080；實際日誌232.45秒。送件前可用VRAM **11123491958 bytes**、RAM **16467132416 bytes**，沒有批次排另一個角色或使用付費節點。
- 保留shape1536／texture4096／remesh768，副本target13800、smooth0／drop-small0；沒有套回舊5000面設定。原始 **7285716 triangles／130845700 bytes** 另存本機ignored outputs，並非遊戲模型或Git暫存上傳。

首次上傳曾被自動核准因目的地不明攔下；補查本機workspace、loopback服務及驗證器local端點後，同一Comfy工具上傳通過，沒有改送遠端。舊CLI佇列有歷史queued紀錄，另以實際服務佇列確認空閒後才提交；完成狀態及輸出保留prompt收據，不依過期清單重送。

完整工作流、seed／模型名稱、輸出SHA及收據在 `source_assets/character_rebuild_20261020/lia/`。

## 靜態候選

| 項目 | 實際結果 |
|---|---|
| 生成貼圖GLB | 12454／15000 triangles、UV、4K貼圖，沒有骨架／動畫 |
| Blender匯入副本 | **12442 triangles**；原GLB獨立檢出12個重複索引三角面（沒有零面積面），匯入去重後少12面，原件仍保留；未再做額外Decimate |
| 尺度 | 1.95m、原點地面中心、Godot Y-up |
| 執行預覽 | `assets/models/rebuilt_characters/lia_static.glb` |
| 預覽SHA256 | **2ba736c720568dc5125eae6a88e785e93b5b8e2509e179116142eb7027a0c198** |
| 工作原件 | `lia/face_v2/lia_surface.blend`，SHA **935c47d37706c711cafbb8f1156b6efbf6ba1cdbc1edd341fcb3b7da4ec01281** |

原生成正面有黑色眼塊、灰色眼周裂線及繪製的拓樸線。純底色emission檢視確認這些已在albedo，不能全歸因於法線。使用內建imagegen，以實際頭部投影為編輯目標、核准莉雅正面為身分參考，修整既有臉／髮顏色，未改頭部幾何。生成PNG為1254²真Alpha，透過正規化UV取樣回投影1024²畫布，不修改原始使用者圖片。

投影限定front `[200,100,840,810]`，span0.64m／center-z1.70m；back明確不編輯。第一版front_facing會選中背側摺面，肩後出現多餘色塊，留存拒用。第二版改為可見深度遮罩，臉部與眼睛可讀性改善，背側色塊消失；**頸領、側髮／後髮及衣服仍有殘留線條和接縫，不能稱全角色美術通過**。

修整後使用簡單粗糙材質及原UV上的4096²色圖，關閉原normal map；臉部改善來自底色修整，不是假稱關法線即修好。編輯提示詞、生成原件路徑／SHA／Alpha與區域記在 `head_projection/repair_prompt.txt`、`repair_provenance.json`。

## 驗收與保留證據

Godot **4.7.2.stable.official.ed1daf0bf**、Windows Compatibility／RTX3080；Blender **5.2.2 LTS**。

| 檢查 | 結果 |
|---|---|
| 嚴格GLB、獨立Blender重匯入 | PASS，12442／15000、UV／索引／材質／有限值；明確為static，不要求不存在的骨架 |
| 表面保留 | PASS，對同一1.95m基線的位置、UV、face indices、corner normals及面數全同；色圖刻意改變，不宣稱原albedo位元相同 |
| Godot新莉雅靜態 | **18／0**，4K色圖、12442面、地面0／高度1.950000m、無骨架如實標示、重新實例化及九張原生正側背／頭部畫面 |
| 原雷恩靜態工具 | **18／0**；擴充工具可選lia，預設ren仍可執行，截圖短邊512 |
| 原正式雷恩／莉雅 | **88／0**；仍為原4815／4806面，驗證舊動作／法杖，並非新莉雅動作通過 |
| G06／新版角色戰鬥及存檔 | 本輪未重跑整套G06；遊戲碼與正式角色引用均未改，新莉雅尚未接入 |

獨立物理拓樸診斷：13075個UV拆分頂點對應4359個完全重合位置；101條物理邊界、638條超過兩面的交界、零條零長邊。不是把UV接縫數當破洞，也沒有為得到綠燈直接全域焊接／刪面；這些診斷需在頸部、衣擺與襠部的實際表面上定位處理。

18張原生WebP、初版失敗／選定版、匯入／保留／來源SHA與正式檔案未改證明見 [凍結資料](../source_assets/character_rebuild_20261020/lia/static_acceptance_20261022/README.md)。首次渲染使用相對輸出路徑被Blender解析至C盤，失敗紀錄保留；改用專案絕對路徑完成，不改系統權限。縮圖快取OpenImageIO警告仍存在，實際工作檔保存與重讀成功。

## 下一項

先定位修整頸部／高領假表面及身體關節、衣擺／襠部的重疊拓樸，保留臉髮手靴與核准造型；依新網格量測骨架與掛點，不直接套用雷恩骨架座標。再建立待機、走、跑、持杖／施法、受擊、道具、防禦與倒地，驗證變形後接既有角色控制器及RPG系統。

目前沒有新骨架、權重、動作、法杖握持、村莊移動／戰鬥／存讀檔及效能驗收；正式Lia、NPC ID、技能、旗標、獎勵、存檔格式和v0.6.1入口保留。此靜態資產尚需打包範圍及尺寸盤點，沒有以新增預覽檔案推導發布候選已通過。女性村民仍暫留候選，Android／iOS暫停，完整第一章目標持續。

```powershell
./tools/review_static_character.ps1 -Character lia
```
