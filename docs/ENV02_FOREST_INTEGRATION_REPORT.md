# ENV02 — 低語森林枯木配置

2026-10-22，feature/greystone-g06，接續75801c3。**三件枯木邊緣配置 PASS；森林整體美術重做、完整環境資產製作、Windows總Gate與第一章未完成。**

## 實作

重用已驗收的Kenney Nature Kit CC0枯木，沒有重做模型、下載整套素材或新增付費來源。原件／調色／倒角／授權沿用 [單件報告](ENV02_FREE_LOG_REPORT.md) 與既有ASSET_CREDITS。

- `forest_scenery.tscn`為獨立PackedScene，三根枯木共用原GLB的Mesh及兩個G04外部材質；每根268／1000面，共804面。四片共享色彩的邊緣地面只作視覺延伸，共48面，新增總計852面。無貼圖、透明材質、粒子或動畫。
- 放置於西側`(-26.65,0,-14)`、東側`(26.65,0,9)`、南側`(8,0,26.7)`。全模型在原外牆之外，底下有視覺地面；不是擴大可行走區或存檔有效座標。原外牆／主要道路與事件位置保留。
- 保留每根單一主幹膠囊碰撞，不縮放CollisionShape3D；枝梢與樹洞不是可穿入空間。新增碰撞也在原行走牆外，沒有使原可存位置被新障礙物占用。
- 只接入`scenes/world/expanded/forest.tscn`；v0.6.1原森林／正式main未修改。新版角色、女性村民、戰鬥數值／技能、旗標／獎勵及存檔Schema不受此項修改。

## 實際驗證

Godot **4.7.2.stable.official.ed1daf0bf**、Windows原生Compatibility／RTX3080。使用獨立測試APPDATA，複製既有G06測試通關產生的存檔，未讀寫玩家存檔。新增測試不偽造完成旗標。

| 項目 | 實際結果 |
|---|---|
| 放置前基線 | 9／0；凍結原碰撞、互動／Marker與受保護來源SHA，576個1.95m玩家膠囊占用取樣 |
| 初次放置 | 49／0，但實看發現西邊約8.7cm超出新增地面，且測試鏡頭誤用local座標，不能只憑功能綠燈採用 |
| 修正後原生圖形 | **52／0**；完整模型在原行走外牆之外並有地面，原碰撞／互動／Marker／受保護檔案及576點占用結果全同 |
| 實走 | 共用InputMap／真實PlayerMovement與move_and_slide走西、東、南側及原主路；到達、貼地、鬆鍵停止正常 |
| 模型／碰撞 | 三件仍268面、共用Mesh、膠囊不縮放，射線實際命中主幹 |
| 存讀檔／往返 | 原安全點存讀通過；party／inventory／flags／quests／rewards／story不變；x26.8越界仍拒絕；村莊往返重新實例化仍有三件 |
| G06完整回歸 | **16模式／576 checks／0 failures**；含舊序章、遷移／重啟、NPC、完整G06序章、交易與桌面注入觸控，不是Android真機 |
| 新包／長測／實體輸入 | 本項未執行；不能引用舊RC3人工通關為新版本背書 |

測試鏡頭已改用global_position，原生近景確認切口、枝梢、接地與道路分隔，沒有修改遊戲固定45度攝影機。初次圖片及其profile另存`initial_review/`，與最終結果分開。放置前舊測試鏡頭的profile不可直接與修正視角比較。

## 短時間效能取樣

同一次原生程序、固定45度全圖總覽、1280×720、上限60FPS：新增造景可見／隱藏各300幀，兩者所有資源均已駐留。

| 項目 | 可見 | 隱藏同一造景 |
|---|---:|---:|
| 平均幀時間 | 16.66606ms | 16.66608ms |
| P95／P99 | 16.696／16.706ms | 16.706／16.755ms |
| Draw Calls | 1775 | 1759 |
| 引擎MEMORY_STATIC峰值 | 342631045bytes | 342632113bytes |

新增可見成本約16次Draw Calls；平均約60FPS受上限限制，不能推導未鎖幀容量或30分鐘穩定性。MEMORY_STATIC不是程序RSS，隱藏節點也不會卸載資源，本次未量測程序記憶體增量。總覽原本Draw Calls已高，後續全森林效能工作應優先盤點既有重複樹木／小道裝飾的材質與批次；本項不藉此改動舊場景或重做G07。

畫面微評（限定枯木局部）：COMP-SAFE-EDGE2、COMP-NEG-SPACE2、COMP-BALANCE1、LIGHT-KEY-FILL2、ORIG-READ2、ORIG-STRUCT1、ORIG-TILE1、ORIG-SYN1，12／16。輪廓與木材色調可讀，但外緣仍是稀疏平面，背景層次／整張森林參考還原度未通過，未將小項PASS當整體完成。

## 重現與後續

```powershell
./tools/godot.ps1 -Mode TestG06Story
./tools/review_forest_scenery.ps1
./tools/test_g06.ps1
```

放置前資料已凍結，`-RecordBaseline`只供未修改的舊地圖第一次記錄，存在時拒絕覆寫。所有圖片／數據／SHA在 [配置證據](../source_assets/environment_rebuild_20261020/forest_integration/README.md)。

此提交另外將前一莉雅診斷的文字證據SHA統一按UTF-8／LF／無BOM計算，修正Windows換行經Git正規化後的五個假差異；圖片及原Native／GLB二進位SHA不變，沒有改動模型。

下一項：森林／礦坑／可見物品完整盤點，按用途逐件適配既有免費資產或補模。莉雅頸領三版仍拒用，需連續拓樸／局部UV處理後才接新骨架。保留原男性村民，女性候選；Android／iOS暫停，完整第一章目標持續。
