# 灰石村地面、岩石與水體材質驗收

2026-10-23 開始，2026-10-24 完成；以 `8bffbec` 的 Blender / RPG 候選為基線。
分支 `feature/greystone-g06`，Godot `4.7.2.stable.official.ed1daf0bf`、Blender 5.2.2 LTS。

## 實際變更

- 草地：世界座標的柔和草色斑塊與細粒，土路：土色變化與零散砂礫；沒有加入大貼圖。
- 岩石／階地／石階／石井：礦物顆粒、彎曲淡岩層、向上表面苔斑及近水暗色。保留原有多邊形切面與輪廓。
- 河流／湖面：不同流速、連續波紋法線、視角高光、深淺水色、透明度及深度交界泡沫。
- 瀑布：沿高度向下移動的水色與泡沫條紋。水體沒有移動頂點或新增物理水流。
- 兩片純視覺河床／湖床位於原水位下 1.6m；水組由 12 mesh / 48 triangles 改為 14 / 66。沒有水下可行走碰撞。
- 六份共享 ShaderMaterial，由 `blender_village_surfaces.gd` 注入候選場景；不改寫匯入 Mesh 或其他地圖的共用材質。
- Blender 主檔已保留可編輯程序顆粒、岩層與時間驅動水面法線。glTF 不承載這些節點，Godot 使用對應 shader，深度泡沫在引擎端實作；兩者不是逐像素相同的渲染器。
- 完整 builder 呼叫相同材質配方；exporter 支援 `--only Water`，本輪未重新生成或重匯出七棟建築。

遊玩入口仍為 `scenes/main/greystone_blender_integration.tscn`，不替換正式 v0.6.1 入口。
角色、NPC ID、數值、事件、任務、交易及獎勵帳本、schema 3 / location layout 3 均未更動。

## 可執行檢查

在專案根目錄執行：

```powershell
./tools/godot.ps1 -Mode Check
./tools/test_blender_surfaces.ps1
./tools/godot.ps1 -Mode RunBlenderVillage
```

材質與 Blender 主檔可重製：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --threads 4 --python-exit-code 1 --python scripts/tools/greystone/polish_blender_surfaces.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --threads 4 --python-exit-code 1 --python scripts/tools/greystone/export_blender_master.py -- --only Water
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode TestBlenderSurfaces
```

本機圖形模式使用 NVIDIA GeForce RTX 3080 / OpenGL Compatibility。移動以真實 Player、InputMap 與物理更新執行，腳本測試隔離手把搖桿軸；不冒稱人工鍵鼠／Xbox 驗收。

| 檢查 | 實際結果 |
| --- | --- |
| 專案載入／水 GLB 重匯入 | 退出 0，無 Godot 載入錯誤 |
| 原生圖形材質、水面時間變化、碰撞一致性 | 6 / 0 失敗 |
| 主要道路、七建築入口、橋、碼頭、礦口及抽樣阻擋 | 37 / 0 |
| 舊存檔遷移／另程序重啟 | 70 / 0 ＋ 6 / 0 |
| 原生序章／另程序重啟 | 68 / 0 ＋ 7 / 0 |
| 原生商店、旅館與嚴格交易驗證／重啟 | 53 / 0 ＋ 5 / 0 |
| 本輪合計 | 252 / 0 |
| Blender 主檔另程序重新開啟及兩張 Cycles 實際渲染 | 成功 |

材質開關前後，所有碰撞形狀、座標、停用狀態及碰撞層的排序簽章相同。
另驗證 103 個木材表面維持原材質；河床不引入碰撞。
固定鏡頭、隱藏角色後，間隔 1.25 秒的水景截圖，每隔 3 像素取樣有 **10394 / 102480** 點產生可量測色彩變化。
已實際查看廣場、岩石近景、橋、碼頭、全景及 Blender 渲染；原生序章／交易畫面另外保留證據。

## 短程畫面取樣

六鏡頭各 120 個 `frame_post_draw` 間隔，60 FPS cap，完成後才啟動 Blender 渲染。
平均 **16.443～16.499ms**、P95 **16.704～16.753ms**、P99 **16.753～16.855ms**；
最大單次間隔 **18.502ms**。圖形記憶體約 **784.74～786.77MiB**，引擎靜態記憶體 **72.70～72.71MiB**。
Draw Calls：廣場 478、橋 665、碼頭 658、礦口 292、岩石近景 396；全圖總覽 2259。

這是 CPU 渲染事件間隔，不是 GPU 幀時間、程序 RSS、新 30 分鐘長測或無上限性能測試。
總覽顯示大量物件、Draw Calls 較高，後續仍需對固定發布包檢查效能；本輪沒有把材料增加當作效能優化通過。

## 修正與限制

- 首輪錯把 `GreystoneRef_oak` 名稱中的 `stone` 視為石材，實際畫面發現木橋變灰後修正為材質 token 比對，增加木材保留檢查。
- 碰撞比對首輪包含程序產生的節點流水號造成誤報；改為比較實際形狀與物理屬性，沒有放寬碰撞功能或刪除碰撞。
- 岩層首輪過密，已降低對比並增加彎曲；河湖視覺床深度對齊，避免交界突然變色。
- Blender 背景存檔不能寫入使用者系統縮圖快取，輸出可開啟的主檔與 Cycles 渲染均成功；沒有修改系統快取權限。
- 沒有折射、SSR、浮力或流體模擬；泡沫依場景深度近似，不包含透明物件的深度。
- 地形輪廓、建物局部 AI 木框／屋瓦仍維持既有候選，不將這次紋理改善當作概念圖完全還原。
- 沒有新發布包、實體輸入通關、新長測、G08 總 Gate 或行動平台驗收；Android／iOS 暫停。

## 檔案與證據

主要檔案：`assets/shaders/greystone/`、`assets/materials/greystone/blender_surface/`、
`assets/models/greystone/blender_master/water.glb` 及 manifest、`scenes/world/greystone_blender_master.tscn`、
`scripts/world/blender_village_surfaces.gd`、Blender builder / exporter / polish / render 工具、
`tests/blender_surface_test.gd`、`tools/test_blender_surfaces.ps1`、`tools/godot.ps1` 及 Blender 主檔。

完整本機輸出：`artifacts/greystone_surface_20261023/`；凍結摘要、SHA、截圖及測試日誌：
[`source_assets/greystone_blender_20261023/surface_acceptance/`](../source_assets/greystone_blender_20261023/surface_acceptance/summary.json)。
前一輪場景證據仍保留在 `acceptance/`，不將其當成本輪 shader 的測試結果。

下一步：固定這份候選包，進行真實鍵鼠／Xbox 探索與水景視覺覆核，再決定是否重新進行長時間 Windows 驗收。
