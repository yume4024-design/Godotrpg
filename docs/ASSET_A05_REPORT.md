# A05 NPC 素材製作 — IN_PROGRESS

2026-10-20；分支 feature/greystone-g06。四組新設計已由使用者回覆「四組都採用」；不再列為缺圖。正式 NPC 替換尚未開始，A04 五敵整合仍缺蝙蝠修整；本輪推進不受影響的獨立 NPC 素材生產。

| NPC | 實際成果 | 未完成 |
|---|---|---|
| 鐵匠 | 重用既有 9937 面來源，嚴格 GLB 預檢 PASS；已做同網格 normal map 開／關的 CPU 正背面對照，確認部分背帶黑痕來自烘焙法線 | 新 NPC 對話動作、必要持物、材質候選與正式整合 |
| 道具商 | 新 Pixal3D 靜態候選、原件／Blend、正背顏色局部修補、12573 面 Godot 預覽及 14 項圖形檢查 | 骨架、Idle／Talk、互動動作、裙擺權重、正式整合 |
| 旅館老闆 | 核准的四視圖來源 READY | 尚未送出 3D 工作 |
| 男村民 | 核准的四視圖來源 READY | 尚未送出 3D 工作 |
| 女村民 | 核准的四視圖來源 READY | 尚未送出 3D 工作 |

## 道具商實際生成

ComfyUI 0.41.3／comfy-cli 1.22.0，本機 RTX 3080 12GiB。生成前工具量到 VRAM 可用 10.35956GiB。API 驗證兩份皆 valid=true、0 errors／warnings、無 partner nodes、不花 Comfy credits。未升級 Comfy、外掛、引擎或模型。

- 圖片預處理 prompt_id：3439e594-2830-41c4-bc4b-7c21bb557957，completed；四路 1024² 實際條件預覽均已查看，完整身體、正／左／背／右方向正確，沒有文字。條件輸出為黑底不透明 RGB，與保留的透明 RGBA 原始來源明確區別。
- 單一模型 prompt_id：87d64b9d-0500-4042-b144-e7c207bc4894，completed；沒有同時提交其餘三組 NPC。
- 最新工作流 SHA：1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275。四個 ImageCropV2 在此版本為 bypass；沿實際連線經 ImageCropToMask／去背 mask 至四路 conditioning，不啟用舊合圖 crop_region。
- 形狀 1536（副本修正 INT 型別）、貼圖 4096、remesh 768、候選 target 13800／最終上限 15000。為保留手指／髮絲／配件，副本 smooth_iters=0、drop_small_components=0；原件未改。Seed 12=43、18=42、3=56、23=42，完整資料見 generation_manifest.json。

原始高密度形狀 14,418,394 triangles／256,242,252 bytes，SHA 07155b341d71f4760ad96b91fbafa3d03de737df51360ed81a24f9dd19122fd7，本機 outputs 原封保留且 Git 排除。原始貼圖 GLB 12,584 triangles；Blender 匯入為 12,573，11 個不可表示的面由匯入器丟棄，兩種計數沒有混寫。

來源目錄 `source_assets/npc_rebuild_20261020/item_merchant/`：generated_textured.glb、glb_metadata.json、工作流副本、來源快照、條件圖、inspection、surface_patch、surface_v1 與原始 outputs。原始貼圖 GLB SHA e7d0cb47170dd11b54f0f38a29f6055c5536d5b88d3e7759850c0c8c645be9a0。

## 材質修整及限制

先以相同網格、攝影機及燈光比較有／無 baked normal：黑色裂痕部分來自法線圖，移除其顯示可改善，但衣服色塊仍錯誤。沒有把法線關閉當作修好所有缺陷。

使用內建 imagegen 修補正／背 albedo 的上衣與鞋口指定區域，保留輪廓／姿勢與原圖；實際提示詞及來源見 surface_patch/imagegen_prompts.json。Blender 以 BVH 檢查可見表面，只將邊界內色彩投影回原 UV，再以 emission-only 烘焙 4096² atlas、24px EXTEND 邊距；沒有拿整張正面圖覆蓋全身 UV，沒有加入場景燈光。幾何未改，身高規整為 1.65m、腳底原點，法線圖原件仍保留在來源 GLB。

修整後仍有領口／腋下／裙襬的細小交疊或黑縫，手指為 AI 生成形狀；未宣稱全閉合拓樸、完整手指 rig、裙子布料或無穿模。這份資產目前是靜態候選，不是已完成可用 NPC。

## 可執行驗證

- tests/reference_asset_workflow_test.py：3 組 PASS；保留來源、四獨立輸入及 bypass、INT 修正、不接受未核准來源、未知 remesher 停止且不寫半成品。首次準備腳本誤用未存在的 class 名時正確停止；核對 live 的 RemeshMesh 後修正，沒有因此送出錯誤工作。
- audit_character_glb.py：原始候選及修整版均以 npc／15000、明確 allow-static 檢查 PASS，未冒稱有骨架。
- Blender 5.2.2 LTS：匯入、UV／貼圖、三面渲染及修整版保存／重讀成功；thumbnail cache 寫入警告保留。
- tools/godot.ps1 -Mode Check：PASS，check-20261020-061554-911.log。
- tools/preview_npc_assets.ps1 -Test：Godot 4.7.2 Windows Compatibility 圖形 14 checks、0 failures；實測 12573 triangles，四面按鈕、旋轉、UV／材質、有限頂點與靜態狀態揭露。已查看四面圖。屬程式操作 UI，不是人類輸入／骨架／劇情驗收。

啟動 `tools/preview_npc_assets.ps1` 可看靜態候選；PackedScene 為 scenes/tools/npc_static_preview.tscn，模型為 assets/models/rebuilt_npc/item_merchant_static.glb。正式五 NPC ID、對話、商店價格、旅館、角色數值、旗標、獎勵、存檔及 v0.6.1 入口均未改；Android／iOS 暫停。

下一件繼續鐵匠及道具商必要骨架／Idle／Talk，逐件驗證後才製作其餘 NPC，正式整合仍保留 Gate。蝙蝠的失敗與人工拓樸需求不被此報告掩蓋。
