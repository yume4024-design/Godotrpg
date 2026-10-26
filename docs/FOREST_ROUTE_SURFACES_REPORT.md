# 森林道路平面接縫修整 — 2026-10-26

## 本輪範圍

把舊中央路徑與擴展森林六段支線的可見路面改由九個貼地 `PlaneMesh` 承載，使用單一世界座標 Shader 統一草地／泥土材質。只隱藏舊道路的顯示網格；原地面、碰撞、互動、導航座標與存檔資料均未改。測試輸出加入可選的 `user://` 目錄，避免覆蓋先前證據，並新增徒步返回中央路線驗收。

## 實際驗收

- Godot `4.7.2.stable.official.ed1daf0bf`，Windows 原生圖形模式。
- `tests/forest_visual_finish_test.gd --output=user://scene_surface_review_20261026`：33 項、0 失敗。中央主線與外圈以跑步通過；中央路線反向步行通過；停止後角色落地。九個路面均使用共用 Shader，顯示面為貼地平面且沒有道路薄盒的直立側壁。
- `./tools/godot.ps1 -Mode VisualReferenceStory`：68 項、0 失敗。
- `./tools/godot.ps1 -Mode TestReferenceStoryReload`：7 項、0 失敗，含獨立程序讀取既有完成存檔及隊伍／任務／金幣／裝備／獎勵帳本。
- `./tools/godot.ps1 -Mode Check`：完成專案匯入與編輯器載入，沒有載入錯誤。
- 原森林場景的 37 個碰撞形狀、互動目標及出生點仍由既有森林驗收基線覆蓋；本輪無物理資源變更。

## 畫面與限制

原生圖形截圖保存於 `source_assets/forest_route_surfaces_20261026/evidence/`。中央路線交界及舊薄盒路面側邊已消除，步行／奔跑地面顏色一致。截圖仍可看到穿過左上畫面的地形高差黑色邊線，這是地形側面／相鄰邊界，不是本輪路面幾何，尚未修整；外圈仍是既有平坦配置。本輪只修道路呈現，不宣稱完整森林地形或全部場景美術完成。

## 效能觀測

原生視窗路線樣本 2627 幀：平均 16.718 ms、P95 16.708 ms、P99 16.766 ms、最大 193.075 ms；路線樣本 Draw Calls 72–503，引擎靜態記憶體 120.7–120.8 MiB。最大幀尖峰包含短程場景／截圖工作負載，這不是 30 分鐘長測、GPU 幀時間或系統 RSS 驗收，也不代表整體效能認證。

## 變更範圍

程式與 Shader：`scripts/world/forest_presentation.gd`、`assets/shaders/forest/trail.gdshader`；驗收：`tests/forest_visual_finish_test.gd`。未新增第三方素材、未改劇情／戰鬥數值／角色 ID／存檔格式、未覆寫正式入口或固定候選包。人工驗收仍暫停。
