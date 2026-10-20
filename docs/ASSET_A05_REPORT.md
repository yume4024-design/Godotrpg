# A05 NPC 素材製作 — IN_PROGRESS

2026-10-20；分支 feature/greystone-g06。四組新設計已由使用者回覆「四組都採用」；不再列為缺圖。正式 NPC 替換尚未開始，A04 五敵整合仍缺蝙蝠修整；本輪推進不受影響的獨立 NPC 素材生產。

| NPC | 實際成果 | 未完成 |
|---|---|---|
| 鐵匠 | 重用既有 9937 面／19 骨來源，停用問題 normal map；新副本 Idle／Talk、98 影格、Godot 動作 213／0、雙實例切換 19／0 | 正式 NPC 替換、實際對話事件／交易回歸；未驗收持鎚／擊砧或巡邏 |
| 道具商 | 新 Pixal3D 候選及顏色修補；12573 面、20 骨、裙擺權重、Idle／Talk，98 影格、Godot 223＋19／0 | 正式對話／商店整合；未驗收手指、物品交接或巡邏 |
| 旅館老闆 | 單件生成完成，原貼圖 13651 面；圍裙黑縫及兩版修整失敗均保存 | HUMAN_REVIEW：人工重拓樸，骨架／Idle／Talk／正式整合未開始 |
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

鐵匠與道具商候選結果見下節。逐件驗證後才製作其餘 NPC，正式整合仍保留 Gate。蝙蝠的失敗與人工拓樸需求不被此報告掩蓋。

## 鐵匠 Idle／Talk 候選

使用既有 `source_assets/quality_characters_20261018/blacksmith/animated_10k/blacksmith_animated.blend`，原 10 動作／網格／權重未改。在新 `source_assets/npc_rebuild_20261020/blacksmith/idle_talk_v1/` 副本保留 Idle、新增 2 秒 Talk；上身／右臂／頭部小幅手勢，腳底校正與循環端點。現有遊戲鐵匠為對話 NPC，因此本候選只輸出這兩段；未將舊十段未驗收動作一併列為通過。

材質沿同網格 CPU 法線對照的診斷結果斷開問題 normal map，保留 albedo；原材質與十段動作仍在原件。9937 triangles／19 骨／1 材質、UV 及 skin 權重 Gate PASS。Blender evaluated 檢查 98 影格、最大邊拉伸 Idle 1.03665／Talk 1.16498、兩段端點位移均 0、腳底約 0.002m；原始拆分網格 10821 條邊界／非流形邊仍為警告，未宣稱閉合拓樸或手指精修。

執行命令與實際結果：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python docs/skills/ai-3d-agent/scripts/check_export.py -- --input assets/models/rebuilt_npc/blacksmith.glb --output artifacts/asset_a05/blacksmith/blender_import --category npc --require-uv --require-rig
./tools/review_npc_rig.ps1
./tools/review_npc_rig.ps1 -Controller
./tools/review_enemy_asset.ps1 -Asset spore_sprite
```

- tools/godot.ps1 -Mode Check：PASS，check-20261020-093846-148.log。
- Blender 5.2.2 LTS 重匯入 9937、UV／骨架 PASS；未要求閉合，也未重新減面。
- Godot 4.7.2／Windows Compatibility 圖形 213 checks、0 failures，四面與兩段正側畫面已查看；實測 Draw Calls=1、引擎記憶體 36419721 bytes，這是獨立檢查場景而非完整村莊效能數據。
- 雙實例控制器圖形 19／0：兩份 Skeleton／AnimationLibrary 互不污染、三輪 Idle／Talk 切換、重複 Talk 不重播、混合姿勢有限、刪除／重建視覺可恢復，未寫存檔。
- 泛用圖形腳本新增 NPC profile 後，菇靈原有 256／0 回歸通過。首次 NPC 執行遇到 typed Array 分支指派錯誤，改用明確 `Array[String]`＋`assign()` 後重跑通過；失敗日誌保存為 rig.first_array_failure.log，僅結束該次測試 PID。

新增 `rigged_npc_visual.gd`、`scenes/characters/npc/blacksmith_visual.tscn` 僅負責展示；以實例私有動畫庫設定循環，沒有新增劇情／任務／交易管理器。候選 GLB SHA、原 Blend SHA、圖形／變形報告、失敗摘要與預覽封裝於同一來源目錄；原始日誌僅本機保留、不提交 Git。不得將舊測試報告套用到替換後的 GLB。

尚未正式掛入灰石村或對話事件；沒有 NPC 交易／存讀檔、持鎚握把／擊砧、走路／巡邏或實體輸入完成宣稱。正式主場景、NPC ID、數值及 Schema 未改。A05 整體 IN_PROGRESS。

## 道具商骨架／裙擺及對話動作

在原 surface_v1 副本新增 20 骨，保留 12573 面、UV 及材質；沒有重新減面或覆蓋原件。以藍裙色彩 4961 種子做接縫鄰近辨識，4890 頂點主要受前／後 Skirt 骨影響；169 手部頂點檢查不含裙／骨盆權重。四個最大影響、權重和誤差 3.83e-8。Idle／Talk 各 2 秒、無水平 root motion，腳底約 0.002m。

首版 Talk 最大邊拉伸 5.18714 FAIL；實際診斷邊端發現部分指尖後移超出骨膠囊，被錯分給 Hips。保留 v1 原件（僅本機）、recipe、失敗報告及逐邊權重。v2 依實際手掌位置校準腕／掌骨，補全手部輪廓分區，**未降低 Talk 手勢或拉伸驗證門檻**；98 影格 PASS，Idle 最大拉伸 1.13832、Talk 2.25157，循環端點位移 0。

實際命令：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/build_merchant_npc.py -- --input source_assets/npc_rebuild_20261020/item_merchant/surface_v1/item_merchant_surface.blend --output source_assets/npc_rebuild_20261020/item_merchant/idle_talk_v2
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/audit_asset_motion.py -- --input source_assets/npc_rebuild_20261020/item_merchant/idle_talk_v2/item_merchant_npc.blend --category npc --output artifacts/asset_a05/item_merchant/rig_deformation.json
./tools/review_npc_rig.ps1 -Asset item_merchant
./tools/review_npc_rig.ps1 -Asset item_merchant -Controller
./tools/review_npc_rig.ps1 -Asset blacksmith -Controller
```

最後 builder 命令僅供新資料夾重現，既存輸出會拒絕覆寫；不可直接覆蓋已封裝 v2。GLB 嚴格 UV／Skin 及 Blender 重匯入均 PASS，Godot 載入 PASS（check-20261020-094557-842.log）；動作圖形 **223／0**、雙實例／重建 **19／0**，鐵匠控制器回歸 **19／0**。已查看全部四面及 Idle／Talk 正側、雙實例切換。獨立場景 Draw Calls=1、引擎記憶體 36421797 bytes，不等同村莊效能。

候選：`assets/models/rebuilt_npc/item_merchant.glb`、`scenes/characters/npc/item_merchant_visual.tscn`；封裝於 source_assets/npc_rebuild_20261020/item_merchant/idle_talk_v2/，測試 SHA 與實際模型一致。靜態舊預覽仍保留，其標籤僅描述靜態檔；新骨架不是正式商店已替換的證據。

限制：原拆分網格 11378 邊界／11400 非流形邊；領口、腋下、裙襬色彩或交疊、AI 手指形狀仍保留。無布料模擬、逐指骨、走動／巡邏或物品交接動作；目前既有商店為對話／UI 交易，候選只驗收必要 Idle／Talk。正式 NPC 整合與商店、序章、存讀檔回歸尚未執行。

## 旅館老闆 — 視覺 FAIL／人工拓樸待辦

四路實際條件圖 completed（d3c8954d-4df2-4477-9d16-2d01fd9fafdc），正／左／背／右完整、方向正確，已查看。逐件完整生成 bfc56eea-084b-4dc6-b0bb-b782d63787fc completed；初始可用 VRAM 7302985783 bytes，請求卸載／重置空閒 Comfy 快取後、形狀開始前實測 11045897334 bytes。沒有停止其他程式、購買 API、下載模型或升級節點。

使用最新工作流同一 SHA、固定 seed、1536／4096／768 及 13800 候選目標；兩份 API validate 0 errors／warnings、無 partner nodes。原始形狀 10578566 triangles／190217656 bytes（本機 outputs 保留／Git 排除），貼圖 GLB 13651／20403316 bytes；Blender 匯入 13642，9 面被匯入器丟棄。原始 GLB 嚴格 npc／allow-static／UV PASS，**沒有骨架或動作**。

實際正背面 CPU 渲染發現前圍裙黑色三角縫。相同網格 normal map 關閉後仍有黑縫；emission-only albedo 乾淨，法線診斷顯示互相反向的角落法線與深折疊區。surface_v1 調整角落法線／中性材質後仍失敗；surface_v2 局部攤平 2164 頂點後出現大片重疊碎片，**拒用**。未將修改後結果拷到 runtime 模型資料夾，也未綁定失敗網格。

三份視覺結果及參數／SHA 見來源目錄 generation_manifest.json、inspection、surface_diagnosis、surface_v1/visual_review.json、surface_v2/visual_review.json、review 與 review_v2。失敗工作 Blend／GLB 僅本機保留，Git 排除重複二進位；原始貼圖 GLB、實際失敗畫面與修整重現腳本保留。Blender 寫縮圖快取警告未影響匯出，但沒有把匯出 exit 0 當作視覺 PASS。

依 ai-3d-agent 三次明確生成／修整後回報，停止此缺陷的自動重試，轉 [人工圍裙拓樸工作單](INNKEEPER_TOPOLOGY_REPAIR.md)。需要移除交叉／重複布片、重建前圍裙及邊界後再做骨架與動作。正式旅館 NPC／費用／恢復規則、故事及存檔未改；A05 整體未完成。其他核准來源可以繼續獨立素材工作，不能因這一件失敗而取消完整角色需求。
