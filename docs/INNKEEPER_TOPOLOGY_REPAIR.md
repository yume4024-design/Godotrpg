# 旅館老闆圍裙 — 人工拓樸工作單

2026-10-20，**WAITING_MANUAL_TOPOLOGY**。這是本機修整待辦，未委託第三人，也未完成修整。

## 來源與重現

來源：`source_assets/npc_rebuild_20261020/innkeeper/`；已採用的酒紅背心／米白圍裙四視圖。Comfy 工作 d3c8954d-4df2-4477-9d16-2d01fd9fafdc 為實際四路條件預覽；模型 bfc56eea-084b-4dc6-b0bb-b782d63787fc 已完成。形狀原件 10578566 triangles／190217656 bytes，本機 outputs 保留；generated_textured.glb 為 13651 面、無骨架／動作。Blender 匯入 13642（丟棄 9 個不可表示面），兩種計數分開保存。

生成參數：來源工作流 SHA 1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275，1536 形狀、4096 貼圖、768 remesh、13800 候選目標、smooth_iters=0、drop_small_components=0，Seed 與四路原圖 SHA 見 generation_manifest.json。無付費 API、無模型／節點升級。

## 三份拒用結果

1. 原貼圖模型：正面圍裙有黑色三角深縫；停用 baked normal 後仍存在。證據 inspection/front.png。emission-only 的 albedo_front.png 沒有黑塊，不能以重畫貼圖掩飾幾何遮蔽。
2. surface_v1：校正 6954 個圍裙角落法線、斷開問題法線及中性布料材質，黑縫仍在。證據 review/front.png；拒用。
3. surface_v2：將 2164 個局部圍裙頂點攤平，形成大量重疊碎片。證據 review_v2/front.png；拒用。此方法不可套到正式模型。

原件與兩版 Blend／GLB 均留本機；Git 只收原始貼圖 GLB、參數、SHA、修整腳本及失敗畫面／報告，不上傳巨型形狀、重複失敗二進位或日誌。三次明確生成／修整已回報，停止此缺陷的自動重試，尚未綁骨架或加入 Godot 正式 NPC。

## 需要的人工修整

- 以 surface_diagnosis/baseline.blend 或原始 GLB 為起點，不以攤平失敗版當底稿。
- 隔離前圍裙，刪除交叉、內翻／重複面，重建連續的前布片及正確厚度；接合腰線與側邊，保留背後繫帶及原輪廓，避免只把多層頂點壓成同一平面。
- 重建局部 UV／邊距與法線，從原 albedo 回烘；保持臉、手、酒紅背心及膚色不變。
- 完成後先驗證 15000 上限、UV、前／後／兩側實際燈光無黑縫／碎片，再製作 Idle／Talk、圍裙權重及 Godot 動作／正式旅館回歸。

正式旅館 NPC、恢復費用／規則、劇情、ID 及存檔未改。不得以原生成成功或面數合格將此角色標為已完成。
