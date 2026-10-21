# A05 NPC 素材與外觀整合

## 2026-10-21 — 四個既有 NPC 互動點外觀整合 PASS

使用者指定「保留原村民，女性暫留候選」。鐵匠、道具商、旅館老闆與原男性村民已接入 G06 灰石村，原六個 ID／位置／碰撞／對話／交易／住宿規則不變；公會長及莉雅保持原職責，沒有新增女性互動點。女村民 13515 面／20 骨／Idle／Talk 的獨立候選原封保留，不列為正式出場。

| NPC | triangles／15000 | 骨骼 | 正式身高 | 目前整合 |
|---|---:|---:|---:|---|
| Blacksmith | 9937 | 19 | 1.95m | 既有對話 → Talk → Idle |
| ItemMerchant | 12573 | 20 | 1.95m | 商店／交易成功或失敗回饋 → Idle |
| Innkeeper | 12785 | 20 | 1.95m | 旅館／恢復及滿血不扣款回饋 → Idle |
| 原 Villager | 13701 | 18 | 1.95m | 既有對話 → Talk → Idle |

重用五件已驗收來源，GLB 的位元 SHA 與基線相同；未重新生成或重複減面。只在四個正式 Appearance 實例統一到 1.95m。舊 NPC 場景精確保存在 `scenes/world/legacy/greystone_npcs.tscn`；比較排除 Appearance 後的所有節點完全相同，原膠囊 radius .3／height 1.95、2.2m 互動範圍及名稱位置保持。

呈現由 opt-in `greystone_integration.gd` 記住當次互動對象，接既有 DialogueManager 的結束訊號及 CommercePanel 開關。交易確認先關閉面板，再對同一 NPC 播放回饋 Talk；取消、結束、換圖／讀檔恢復 Idle。不建立第二份 NPC／劇情／經濟資料，不依翻譯後的說話者名稱猜對象。

實際驗證：

- `./tools/godot.ps1 -Mode VisualNPCIntegration`：原生 Windows 圖形 **214／0**，四模型／骨架／面數／比例、動畫真實時間推進、互動對象隔離、取消、成功／失敗交易、重複確認、住宿恢復、滿血不扣款、v1 遷移、保存／換圖／讀檔。十張正常鏡頭＋四張近看已檢視。
- `./tools/test_g06.ps1`：**16 模式、576／0，213.29 秒**；包含序章、NPC 實際走近與膠囊阻擋、任務／單次獎勵、戰鬥、遷移／重啟、觸控及交易。
- 固定實作 `e82ee2dd2be44efa80d6afc62ca60e11b49c8780` 的 `./tools/test_windows_candidate.ps1`：Release 啟動正常，序章／遷移／NPC／交易 **160／0（30.320 秒）**，另一程序 **44／0（6.742 秒）**。兩輪均確認四個指定 GLB／骨架與 Idle，完整輪驗證實際 Talk／Idle 及 Boss 重試。
- 首次新測試漏建專用存檔資料夾為 **190／3 FAIL**，並產生後續錯誤地圖取節點錯誤；補建測試資料夾及失敗即停，沒有放寬存檔驗證。之後 210／0，追加近看截圖後最終 214／0；失敗 log／SHA 和本機圖像仍保留。

來源契約、原始日誌雜湊、匯出雜湊、14 張實際畫面及重現命令見 [A05 整合證據](../source_assets/npc_integration_a05/README.md)。目前各類 Gate：來源／面數／骨架獨立驗證 PASS；四個指定互動點 Idle／Talk／引擎功能 PASS；女村民正式出場 DEFERRED（使用者指示）；巡邏／走動／持鎚／交付／逐指／布料物理 NOT_STARTED，另列項目。深色衣料在原場景光下較暗，原 AI 臉手／小衣縫仍有美術限制，不宣稱最終人工精修。

本輪不算新 30 分鐘長測或新人工鍵鼠／Xbox 驗收，未沿用 RC3 的人測作新 NPC 證據。正式 v0.6.1 入口、技能／數值、劇情旗標、獎勵／存檔 Schema 保留；Android／iOS 暫停，未合併 main。下一工作仍為主角重製及環境／物件清單，不把 NPC 外觀整合當作巡邏、G08 或第一章完成。

下方為較早的單件製作歷史；其中「尚未整合」以本節現況為準。

## 2026-10-21 — 第五件旅館老闆獨立候選完成

已完成明確局部圍裙重拓樸：12785／15000面、20骨、Idle／Talk，98影格、Godot225／0及雙實例19／0；保留10888個原面位置／UV與原body貼圖，法線重新編碼最大分量差.000105054，並未聲稱位元相等。最終靜態21／0、道具商預設builder七組語義完全相同／姿勢差0，控制器19／0。所有中間實作缺陷、來源／配方／SHA與實際四面圖保留，見[完整單件證據](../source_assets/npc_rebuild_20261020/innkeeper/manual_acceptance/README.md)。

目前五件均有獨立模型／骨架候選；正式NPC替換、事件綁定／交易／旅館實機動線與巡邏未完成，A05整體維持IN_PROGRESS。沒有把新NPC放入正式村莊或改價格、劇情、存檔。下面是先前逐件製作歷史；旅館的較早HUMAN_REVIEW描述已由本節及現況表更新。

2026-10-20；分支 feature/greystone-g06。四組新設計已由使用者回覆「四組都採用」；不再列為缺圖。正式 NPC 替換尚未開始，A04 五敵整合仍缺蝙蝠修整；本輪推進不受影響的獨立 NPC 素材生產。

| NPC | 實際成果 | 未完成 |
|---|---|---|
| 鐵匠 | 重用既有 9937 面／19 骨來源，停用問題 normal map；新副本 Idle／Talk、98 影格、Godot 動作 213／0、雙實例切換 19／0 | 正式 NPC 替換、實際對話事件／交易回歸；未驗收持鎚／擊砧或巡邏 |
| 道具商 | 新 Pixal3D 候選及顏色修補；12573 面、20 骨、裙擺權重、Idle／Talk，98 影格、Godot 223＋19／0 | 正式對話／商店整合；未驗收手指、物品交接或巡邏 |
| 旅館老闆 | 原13651面來源保留；局部重拓樸12785面／20骨／Idle／Talk，98影格、Godot225＋19／0 | 正式旅館／對話／尺度及住宿回歸；逐指／倒茶／巡邏未驗收 |
| 男村民 | 新生成原件及 13701 面／18 骨 Idle／Talk 候選；98 影格、Godot 203＋19／0 | 正式對話／場景整合；走動／巡邏未驗收 |
| 女村民 | 新生成及衣料回烘；13515 面／20 骨、Idle／Talk／裙擺權重，98 影格、Godot 223＋19／0 | 正式對話／場景整合；走動／巡邏及裙子物理未驗收 |

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

## 男村民 — Idle／Talk 獨立候選 PASS

四路條件預覽 27183ba6-ad71-40ff-b0dd-d9f33c1dba27、完整模型 3412cd78-428e-4255-ac77-80c989c1c9c8 均 completed，輸出已取回並查看條件四面。沿同一最新工作流 SHA、固定 seed、1536／4096／768／13800 目標；兩份 validate 0 errors／warnings、無 partner nodes，重工作前實測 VRAM 可用 11041703030 bytes。

原始形狀 5669346 面／102005548 bytes 本機保留；貼圖 GLB 13702 面／17097712 bytes，SHA a22ff88e079c2879967c6d53c8283e0ce0b904cb0e5d8fa05cc85170a041d7f3。Blender 匯入 13701（丟棄 1 個不可表示面）。正背 CPU 對照確認停用問題 baked normal 後皮膚／衣料較乾淨，沒有旅館的黑色裂縫；不重畫 albedo、不再減面。

新副本規整 1.75m、18 骨、Idle／Talk 各 2 秒，逆距離骨膠囊權重最多四影響；390 手部頂點排除骨盆／腿部，權重和誤差 4.47e-8。98 影格 evaluated PASS：Idle 最大邊拉伸 1.03178／Talk 1.41373、循環端點 0、腳底約 0.002m。原拆分網格 10178 邊界／10179 非流形邊保留警告，無閉合拓樸宣稱。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/build_villager_male_npc.py -- --input source_assets/npc_rebuild_20261020/villager_male/generated_textured.glb --output source_assets/npc_rebuild_20261020/villager_male/idle_talk_v1
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/audit_asset_motion.py -- --input source_assets/npc_rebuild_20261020/villager_male/idle_talk_v1/villager_male_npc.blend --category npc --output artifacts/asset_a05/villager_male/deformation.json
./tools/review_npc_rig.ps1 -Asset villager_male
./tools/review_npc_rig.ps1 -Asset villager_male -Controller
./tools/review_npc_rig.ps1 -Asset item_merchant -Controller
```

builder 僅可輸出至新資料夾，既存輸出拒絕覆寫。嚴格 GLB UV／Skin、Blender 重匯入及 Godot Check 均 PASS（check-20261020-101205-377.log）。Godot Windows 圖形動作 **203／0**、雙實例切換／重建 **19／0**，道具商控制器回歸 **19／0**；已查看四面、Idle／Talk 正側與雙實例畫面，未見明顯幾何碎片。獨立場景 Draw Calls=1、引擎記憶體 36420935 bytes，不是整村 FPS／效能驗收。

`assets/models/rebuilt_npc/villager_male.glb`、`scenes/characters/npc/villager_male_visual.tscn` 與來源 idle_talk_v1 下的 Blend／報告／九張實際截圖已封裝，GLB／Blend SHA 均與測試一致。沒有逐指骨、走動／巡邏、物品握把或正式對話／故事／存檔及實體輸入完成宣稱。正式村民 ID、互動範圍與劇情不變。

## 女村民 — 衣料修補／Idle／Talk 候選 PASS

四路條件預覽 1479588d-25ef-40c4-8925-fc4cee8dd53c、完整模型 3fe0da55-11a3-4ef0-b5df-5dd09250b8a1 均 completed／已取回，條件四面已檢視。最新工作流 SHA、固定 seed 與 1536／4096／768／13800 目標沿用，兩份 API validate 0 errors／warnings、無 partner nodes，重工作前實測 VRAM 可用 11041703030 bytes。

原始形狀 10156728 面／181555336 bytes 留本機 outputs；貼圖 GLB 13516 面／18318056 bytes，SHA 0a9f7675492d114765cebae971469014ae143a8813d8e6ca416d20f079fd2dd0。Blender 匯入 13515（丟棄 1 個不可表示面），未再減面。

同網格 CPU 正背 normal map 對照後，白袖仍有膚色色斑。以內建 imagegen 修補正背上半身顏色，保留原圖與提示詞；BVH 可見面、1024 畫布限定區域／Alpha 投影回原 UV、4096² emission-only 烘焙及 24px 邊距。幾何與 UV 不變，停用問題 baked normal；非修補區沿用原 UV 顏色。實際矩形與生成 PNG SHA 見 surface_baseline/regions.json、imagegen_prompts.json 與 surface_v1/surface_report.json。

共用裙裝 builder 加入明確 villager_female profile；以紅裙辨識 1699 種子／1358 裙擺主要權重頂點、256 手部頂點不含骨盆／裙權重，露出小腿另分區。1.65m、20 骨、Idle／Talk 各 2 秒。首版腰部靠袖子的頂點因硬切分界產生 Talk 拉伸 3.18014 FAIL；逐邊診斷後改為連續手臂／軀幹混合，未縮小手勢或放寬門檻。v2 98 影格 PASS：Idle 1.06640／Talk 1.32365、循環端點 0、腳底約 0.002m。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/apply_npc_surface_patch.py -- --source source_assets/npc_rebuild_20261020/villager_female/surface_baseline --output source_assets/npc_rebuild_20261020/villager_female/surface_v1 --name villager_female --regions source_assets/npc_rebuild_20261020/villager_female/surface_baseline/regions.json
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b --factory-startup --python-exit-code 1 --python scripts/tools/build_merchant_npc.py -- --input source_assets/npc_rebuild_20261020/villager_female/surface_v1/villager_female_surface.blend --output source_assets/npc_rebuild_20261020/villager_female/idle_talk_v2 --profile villager_female
./tools/review_npc_rig.ps1 -Asset villager_female
./tools/review_npc_rig.ps1 -Asset villager_female -Controller
./tools/review_npc_rig.ps1 -Asset item_merchant -Controller
```

輸出須指定新資料夾，既存檔案不覆蓋。原 GLB／候選嚴格 UV／Skin、Blender 重匯入與 Godot Check PASS（check-20261020-103907-273.log）；Godot 圖形 **223／0**、雙實例切換 **19／0**、道具商控制器回歸 **19／0**。已查看四面及 Idle／Talk 正側／雙實例；白袖色斑已清除，未見明顯碎片或腰／袖分離。獨立場景 Draw Calls=1、引擎記憶體 36425138 bytes，不是整村效能。

另以共用 builder 預設 profile 重建道具商至 artifacts/asset_a05/item_merchant/profile_regression_20261020，再由 compare_npc_rig_rebuild.py 比對核准原件：頂點、UV、權重、骨架、albedo、clip 名稱及兩段五取樣姿勢 **7 組完全一致**，最大姿勢差 0。原道具商候選未重寫；報告封裝於女村民 idle_talk_v2/merchant_default_profile_comparison.json。

候選 GLB／Blend／PackedScene、失敗報告／逐邊權重、實際畫面與 SHA 已封裝。原拆分網格 10631 邊界／10635 非流形邊仍為警告；AI 手指、袖口／裙襬小交疊與背部衣紋細節仍有生成限制。沒有逐指骨、裙子物理、走動／巡邏、正式 NPC／故事／存檔或人類實體輸入通過宣稱。五 NPC 目前四件獨立候選通過，旅館待拓樸，正式整合全部保留 Gate，A05 整體 IN_PROGRESS。
