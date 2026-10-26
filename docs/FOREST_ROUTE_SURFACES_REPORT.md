# 森林道路平面接縫修整 — 2026-10-26

## 本輪範圍

把舊中央路徑與擴展森林六段支線的可見路面改由九個貼地 `PlaneMesh` 承載，使用單一世界座標 Shader 統一草地／泥土材質。只隱藏舊道路的顯示網格；原地面、碰撞、互動、導航座標與存檔資料均未改。測試輸出加入可選的 `user://` 目錄，避免覆蓋先前證據，並新增徒步返回中央路線驗收。

## 實際驗收

- Godot `4.7.2.stable.official.ed1daf0bf`，Windows 原生圖形模式。
- `tests/forest_visual_finish_test.gd --output=user://forest_edge_surface_review_20261026final2`：34 項、0 失敗。中央主線與外圈以跑步通過；中央路線反向步行通過；停止後角色落地。九個路面均使用共用 Shader，顯示面為貼地平面且沒有道路薄盒的直立側壁。
- `./tools/godot.ps1 -Mode VisualReferenceStory`：68 項、0 失敗。
- `./tools/godot.ps1 -Mode TestReferenceStoryReload`：7 項、0 失敗，含獨立程序讀取既有完成存檔及隊伍／任務／金幣／裝備／獎勵帳本。
- `./tools/godot.ps1 -Mode Check`：完成專案匯入與編輯器載入，沒有載入錯誤。
- 原森林場景的碰撞形狀、互動目標及出生點保持原樣；本輪只隱藏四面邊界碰撞牆的可見方盒，並用四片貼地平面接續草地。碰撞與邊界仍在，沒有物理資源變更。

## 畫面與限制

原生圖形截圖保存於 `source_assets/forest_route_surfaces_20261026/evidence/`。中央路線交界、舊薄盒路面側邊與邊界方盒形成的黑色直線已消除；四片外圍平面與主地面略微重疊，使用相同地表 Shader。新截圖同角度確認黑線不再可見，行走路線／碰撞保留。外圈仍是既有平坦配置；本輪不宣稱完整森林地形或全部場景美術完成。

## 效能觀測

原生視窗路線樣本 2628 幀：平均 16.730 ms、P95 16.750 ms、P99 16.846 ms、最大 221.468 ms；路線樣本 Draw Calls 65–496，引擎靜態記憶體 120.7–120.8 MiB。最大幀尖峰包含短程場景／截圖工作負載，這不是 30 分鐘長測、GPU 幀時間或系統 RSS 驗收，也不代表整體效能認證。

## 變更範圍

程式與 Shader：`scripts/world/forest_presentation.gd`、`assets/shaders/forest/trail.gdshader`；驗收：`tests/forest_visual_finish_test.gd`。未新增第三方素材、未改劇情／戰鬥數值／角色 ID／存檔格式、未覆寫正式入口或固定候選包。人工驗收仍暫停。
