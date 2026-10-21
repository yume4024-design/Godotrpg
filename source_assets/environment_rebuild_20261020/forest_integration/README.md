# ENV02 森林外緣枯木配置證據

2026-10-22，Windows原生Godot4.7.2／RTX3080，三件804面共享模組。小項PASS；整張森林美術及環境物品總工作未完成。

- `baseline.json`：修改前原碰撞／targets／Markers／受保護來源與576個玩家膠囊位置占用快照；來源仍是當時75801c3的舊擴充森林。
- `before_result.json`／`before_native.txt`：修改前9／0。`before_*.webp`保留原始測試鏡頭，當時用了local座標，不作與修正視角的精確藝術／效能A/B比較。
- `initial_review/`：初次49／0功能檢查、鏡頭及西側約8.7cm地面超出問題的原生證據。不是最終採用位置。
- `result.json`／`after_native.txt`：修正後52／0；真實InputMap移動／停止、射線碰撞、原數據相同、存讀檔／越界拒絕／往返重新實例化。
- `after_*.webp`：global_position修正後45度原生近景／全圖，短邊512；沒有繪圖遮蓋。
- 同一次最終程序可見／隱藏各300幀的`profile`與`hidden_scenery_profile`才是相同45度鏡頭A/B；平均約16.666ms（60FPS上限）、Draw Calls1775／1759，MEMORY_STATIC約343MB。不是RSS、30分鐘實測或硬體輸入驗收。
- `g06_regression.json`：十六模式576檢查全通過，包含重啟／序章／交易與桌面注入觸控；不表示Android合格。
- `sources.json`：實際場景／GLB與保留原始流程的來源SHA；`sha256.json`文字按UTF-8／LF／無BOM，其他按原始bytes，與Git內容一致。

從專案根目錄執行`tools/godot.ps1 -Mode TestG06Story`準備真實通關測試存檔，再執行`tools/review_forest_scenery.ps1`；測試只複製isolated測試存檔，不接觸玩家存檔。`-RecordBaseline`要求不存在基線且沒有新Scenery，不能覆蓋已凍結基線。

完整說明：[ENV02_FOREST_INTEGRATION_REPORT.md](../../../docs/ENV02_FOREST_INTEGRATION_REPORT.md)。既有免費原件／CC0／作者與修改記錄保持，沒有再次下載或重新建模。
