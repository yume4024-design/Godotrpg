# 森林／礦坑與可見物品盤點

日期：2026-10-22；本輪遊戲來源 `0bb2188df3fb25e61e58b1944f47e4b855f464f4`。這是追加 ENV01／ENV02／ITEM01 的來源與缺件盤點，**不是新模型、藝術、碰撞動線或效能驗收**。正式場景、模型、資料與存檔均未修改。

## 已核對的來源

G06 的正式森林／礦坑不是只載入舊 `scenes/world/{forest,mine}.tscn`：`greystone_integration.gd` 將它們替換成 `scenes/world/expanded/{forest,mine}.tscn`。兩張新版繼承舊場景，並在 `expanded_wilderness.gd::_ready()` 加入地板、道路、邊界、植被／岩石、花／星晶、坑木及四個可選敵人；森林另有獨立 `forest_scenery.tscn` 三件枯木。因此只盤點 tscn 的 ext_resource 清單會漏掉實際構成。

來源檔 SHA 與十二件 GLB 重新量測位於 [static_sources.json](../source_assets/runtime_asset_inventory_20261022/static_sources.json)。這十二件是針對當前兩圖及武器的選取來源，不是所有三圖 GLB 或地圖實例總數。

| 現有模型 | 單一 GLB active scene triangles | 用途／限制 |
| --- | ---: | --- |
| round_tree | 2000 | 舊卡通樹，擴充森林仍使用；不可重複當作新生成模型 |
| moss_rock | 360 | 森林與礦坑現有岩石 |
| flower_patch | 1596 | 舊森林花叢；不等於 G04 的 flower_a |
| path_strip | 100 | 舊場景道路裝飾，擴充道路另有原生 BoxMesh |
| chest_base／chest_lid | 688／324 | 既有可開啟寶箱兩個獨立部件，優先重用 |
| campfire／signpost | 1824／212 | 既有營火與路牌 |
| crystal_blue | 72 | G04 星晶；不是背包第一枚星印的獨立物件模型 |
| fallen_log | 268 | 已適配 CC0 模組，三件森林配置已另行驗收 |
| bronze_sword | 330 | 已有獨立劍，接入新 Ren 候選；不是正式舊 Ren 已持劍 |
| willow_staff | 140 | 既有法杖，由角色呈現組件建立，依裝備 ID 顯隱 |

這些數字不是 Draw Calls、整圖實例三角形或當前鏡頭可見三角形，不為環境擅自套用角色預算。

## 六個既有物品的呈現狀態

| ID | 核對結果 | 後續範圍 |
| --- | --- | --- |
| bronze_sword | `ren_rebuilt_visual.tscn` 已明確綁定 GLB；正式 `ren_pixal_visual.tscn` 未綁該 HandEquipmentVisual | 隨新雷恩正式採用與動作 Gate 整合，不重造合格劍 |
| willow_staff | `female_actor.gd` 建立既有 GLB，只有裝備此 ID 才顯示 | 保留既有法杖，後續新莉雅骨架／手握位置驗收 |
| potion | 森林 TrainingSupply 使用既有兩件寶箱，獎勵此 ID；ActionEffect 為光環／火花／綠十字 | 沒有獨立藥瓶 GLB 證據，ITEM01 若需要瓶身須另建與視覺整合 |
| trail_ration | 既有定義；舊 village SupplyChest 的引用為歷史場景 | 不把舊村寶箱算作新版灰石村已配置；尚無獨立乾糧模型證據 |
| travel_vest | 既有裝備數值定義 | 尚無獨立可換外觀模型證據，不改背包／數值行為 |
| star_seal_01 | 既有關鍵物品／獎勵收據 | 礦坑古代星晶不是等同於星印模型；不新增或重發獎勵 |

本清單不新增角色、旗標、交易規則或物品 ID。男性村民保留，女性仍候選；Android／iOS 暫停。

## 已執行的實例盤點

新增 `scripts/tools/inventory_world_assets.gd`：在獨立 SceneTree 逐一實例化真實灰石村／擴充森林／擴充礦坑，等待 `_ready`，列出 MeshInstance、GLB 根、共用資源、材質／貼圖、碰撞及互動點，將 NPC／敵人呈現與環境分開，並讀取六個物品定義。

在原生長測正常結束後，以 Godot 4.7.2 **headless** 執行，三張真實 standalone map、**106 個 GLB／12 個外部貼圖 SHA 再核對、六個物品定義、零失敗／exit 0**。沒有用無頭結果宣稱畫面或移動通過。

```powershell
./tools/godot.ps1 -Mode InventoryWorld
```

| 地圖 | 環境 Mesh 實例／三角形 | 原生 primitive 實例 | 角色三角形實例 | 碰撞形狀／互動點（含角色） |
| --- | --- | ---: | ---: | --- |
| 灰石村 | 221／61594 | 51 | 58620 | 142／8 |
| 擴充森林 | 215／132276 | 55 | 31483 | 37／9 |
| 擴充礦坑 | 132／32628 | 108 | 16160 | 34／4 |

三角形是所有實例幾何，不是只看鏡頭可見者；角色含所有 NPC／敵人及可能隱藏配件，不是單個角色預算。村碰撞數含 NPC，不與原 136 件環境碰撞基線混為一談。

原始清單：[runtime.json.gz](../source_assets/runtime_asset_inventory_20261022/runtime.json.gz)；摘要／工具 SHA／來源驗證：[runtime_summary.json](../source_assets/runtime_asset_inventory_20261022/runtime_summary.json)。直接工具及既有 PowerShell 入口各執行一次，均三圖／106 GLB／零失敗；入口產生新的時間戳輸出路徑，不覆寫舊盤點。貼圖清單只讀取外部 albedo texture，不是所有 shader sampler 或內嵌影像。工具沒有 Player／主遊戲 post-load adapters，不用它宣稱實際碰撞切換、可通行路線或可見性效果已驗收；tree visibility 也不是 camera culling。

## 缺件與下一個小項

地面／道路／不可見碰撞幾何保留，不把每個 BoxMesh 都判成待重造。礦坑仍有 16 根原生坑木立柱與 8 根原生橫梁，以及原有 timber／beam／燈具等；36 件 SphereMesh 共 22464 面，屬後續造型／重用岩石庫的優先檢查對象，不能僅據面數宣稱畫面不合格。

後續已完成礦坑支架獨立模組804／1200面、無頭53／0及原生58／0，原尺寸／兩柱碰撞保留，見[支架報告](ENV02_MINE_SUPPORT_REPORT.md)。下一步是正式八組純視覺替換與實際礦坑回歸，目前尚未換入。ITEM01 先補恢復藥瓶的明確用途與獨立候選，不重造已有合格寶箱、劍及法杖，也不為背包文字條目憑空新增玩法。
