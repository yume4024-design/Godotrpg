# 灰石村 Blender 重建與 RPG 候選交付 — 2026-10-23

## 本輪狀態

完整村莊已在 Blender 組裝並分區匯入 Godot，使用獨立 RPG 候選入口。
四類 AI 建築、五個可重用 GLB、七棟實例，以及地形、道路、廣場、水井、
農田、河湖、瀑布、水車、木橋、碼頭、小船、礦口、植被與設施均已建立。
**場景構建與 Windows 自動化驗收完成。** 原生探索、六 NPC、序章、交易、位置遷移及另程序讀檔均通過。
這是新版場景候選，並未宣稱 G08 總驗收、發布包、實體輸入或手機驗收完成。

本報告取代本輪較早的程序幾何草稿及分段進度；早期拒用來源與失敗紀錄保留。
工作分支 `feature/greystone-g06`；正式 v0.6.1 入口、舊村莊與 G06 地圖保留。

## 開啟與重建

```powershell
# 可遊玩：既有 RPG Manager、NPC、劇情、商店、旅館、森林與礦坑往返
./tools/godot.ps1 -Mode RunBlenderVillage
# 僅場景探索：WASD、Shift 跑步、Tab 全景／跟隨，不寫 RPG 存檔
./tools/godot.ps1 -Mode PreviewGreystoneBlender
# 完整可重現測試（先產生既有版本的真實通關測試存檔）
./tools/test_blender_village.ps1
```

完整可編輯主檔：`source_assets/greystone_blender_20261023/greystone_master.blend`。
建模使用 Blender 5.2.2 LTS 獨立背景程序，未覆蓋使用者正在編輯的 Blender 檔。

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --threads 4 --python-exit-code 1 --python scripts/tools/greystone/build_blender_village.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --threads 4 --python-exit-code 1 --python scripts/tools/greystone/export_blender_master.py
./tools/godot.ps1 -Mode Check
```

產生器重用已完成的模型，不會重新排程 ComfyUI 工作。
Godot 4.7.2：`4.7.2.stable.official.ed1daf0bf`，Windows Compatibility。

## 建築與場景

依 `docs/references/greystone_20261023.png` 的區域關係配置；旅館在西北、
道具店在西側、北側灰藍建物作公會、武器店在東河旁、住宅在西南與南方、
農田與農舍位於北側高台，上游橋與礦口位於北部，下游碼頭在東南。
保留公會職責，沒有把圖中未標示的建物改成第二套劇情系統。

| 建築 | Godot X,Y,Z | 比例 |
| --- | --- | ---: |
| 旅館 | -10,3,-15 | 1 |
| 道具店 | -20,3,-9 | 1 |
| 武器店 | 13,3,5 | 1.18 |
| 西民宅 | -15,3,13 | 1 |
| 農舍 | -17,6,-33 | 1 |
| 南民宅 | 5,3,18 | 1 |
| 公會 | 9,3,-17 | 1.25 |

場景樹：

```text
GreystoneBlenderRuntime
  Village (GreystoneBlenderMaster)
    Terrain / Paths / Buildings_Candidate / Water / Cliffs
    Vegetation / Props / Mine / Bounds
  NPCs (重用原六名 NPC)
  NPCAnchors / SafeSpawn / EntranceSpawn / InnOpening / ForestReturn / Departure
  ForestExit / MineExit
```

地圖在 120×120m 預算內；1 unit=1m。Blender Z-up / 北 +Y，glTF 匯出器轉 Godot Y-up / 北 -Z。
地形高 0/3/5/6/10m，瀑布背景高 14m；正式角色膠囊高 1.95m、跨階 18cm，走路 1.8m/s、跑步 4.5m/s。
建築共用 PackedScene；道具與植被共用 Mesh，未合成單一巨大模型。

## 3D Agent 來源與幾何

本機 ComfyUI `127.0.0.1:8188`，Pixal 工作流副本 SHA256：
`1f85e6acb0b5dfac0b1aaaefe24c9252f4127d015ed8bc8cca6abb74286e7275`。
保留水平正交四路圖、實際 conditioning 預覽、API 副本、seed、完整 prompt ID；原工作流未修改。
沒有第三方付費模型下載或外部 3D API 呼叫；來源見 ASSET_CREDITS.md。

| 設計 | 原始 GLB triangles | 修整來源 | 遊戲匯出 | 上限 | Comfy prompt ID |
| --- | ---: | ---: | ---: | ---: | --- |
| 旅館 | 35153 | 35247 | 35247 | 40000 | 37378b05-7ed0-4475-8a6e-c37b19c9582e |
| 民宅 | 26093 | 26063 | 26061 | 30000 | 376d2f40-fb24-46b8-81ec-2a3f75494a56 |
| 道具店 | 26734 | 26720 | 26720 | 30000 | 716a17d7-dc0f-45ea-950a-45e52696f7c3 |
| 武器店 | 26309 | 26351 | 26351 | 30000 | e4dd3124-13bd-4c76-9b54-e3fce50e4552 |

藍頂民宅與公會重用民宅網格，藍頂變體 26061 面，沒有額外生成第五個 AI 設計。
旅館採門板修補版；屋瓦覆蓋兩次試作拒用。其他建物以內縮灰泥補缺口，保留原窗深度；
武器店補鐵砧並修正錯誤淺色屋瓦。民宅兩個精確同向重疊面在主檔產生器中刪除，
反向重疊面保留，沒有誤稱原始匯入差異為零面積面清除。
高面數來源留本機 Comfy output；失敗 Blend/GLB 留本機，不列入遊戲資產。

## 可執行驗證

| 項目 | 實際結果 | 本機證據 |
| --- | --- | --- |
| Godot 資源匯入／載入 | 通過 | blender_delivery_final_check.log |
| 原生圖形探索／七入口／坡階／橋／碼頭／礦口與抽樣阻擋 | 37 / 0 | blender_delivery_testgreystoneblender.log |
| 地形邊界 | 149 邊、505 膠囊掃掠、0 失敗 | boundary_result.json |
| 舊位置遷移／資料保留／無效位置拒絕 | 70 / 0 | blender_delivery_testblendermigration.log |
| 遷移後另程序讀檔 | 6 / 0 | blender_delivery_testblendermigrationreload.log |
| 原生完整序章／戰鬥／往返／獎勵唯一性 | 68 / 0 | blender_delivery_visualblenderstory.log |
| 序章另程序讀檔 | 7 / 0 | blender_delivery_testblenderstoryreload.log |
| 原生商店／旅館／交易驗證 | 53 / 0 | blender_delivery_visualblendercommerce.log |
| 交易另程序讀檔 | 5 / 0 | blender_delivery_testblendercommercereload.log |
| 原有 G06 16 模式回歸 | 576 / 0 | regression/g06-20261023-205111.json |
| 原有 NPC 測試 hooks 回歸 | 60 / 0 | blender_delivery_existing_npc_hooks.log |
| 新版六 NPC 原生對話／碰撞／移動 | 69 / 0 | blender_delivery_visualblendernpc.log |

日誌位於 artifacts；可攜式摘要、模型 SHA、實際畫面與主要測試輸出保存至
`source_assets/greystone_blender_20261023/acceptance/`。
邊界由實際匯入 Grass 面邊緣每 ≤1.2m 取樣，忽略被上層可行走面覆蓋的下層輪廓，
370 次覆蓋點另計、32 次起點已被實體阻擋；不是連續幾何的形式證明。

### 存檔與既有功能

候選單獨使用 `user://crystal_blender_candidate_slot_01.json`，匯入既有 G06 檔只讀原檔。
保留全域 schema 3 / CH00-G06.4，僅新村莊位置 layout version=3。
舊 layout 2 先在原地圖驗證，再映射到新廣場 (-3,3.1,3)，並在新版物理世界複驗。
角色、經驗、裝備、背包、旗標、任務、劇情、交易帳本與獎勵收據均保留。
舊 G06 預設仍只接受村莊 layout 2；未知版／水面／建物內／地底／界外拒絕，原檔與當前狀態不變。

NPC、Dialogue/Story/Quest/Party/Inventory/Reward Manager 均沿用，沒有平行系統。
森林、礦坑、事件 ID、數值、角色模型和獎勵來源未修改；礦坑仍要求教學勝利。
對核心腳本的修改限於可注入地圖／候選標籤／位置版本與遷移入口，不能再宣稱核心腳本 bytes 未改。
正式 main、舊地圖與 data 的 LF 正規化內容另與 HEAD 核對。

### 已重現並修正

- 道路反面造成膠囊卡住、台階封頂與上層階地蓋住坡道：修正法線並裁出連續通路。
- 空心建築代理接受位於屋內的存檔：共用 adapter 轉成實體 BoxShape3D。
- 高低階地原為空心三角面：以原裁切頂面產生向地下延伸的凸體；坡道同樣為實體。
- 橋／碼頭板縫令合法位置讀檔失敗：加入連續地板；碼頭加可見欄杆及對應碰撞。
- 坡道切口比地板寬 0.3m：對齊碰撞通路，依實際裁切輪廓建立可編輯邊界代理。
- 河湖同高重疊在 Blender 產生黑水面：裁去重疊面，保持共同水位。
- 六 NPC 追加路線誤設穿過水井中心：保留失敗紀錄，修正為沿廣場繞井行走，沒有移除井碰撞。
- 測試 runner 誤讀 PowerShell 舊 LASTEXITCODE：以 godot.ps1 的程序退出／錯誤檢查判定，保留原 PASS 結果。

## 短程畫面取樣

五鏡頭各 120 個 `frame_post_draw` 間隔，明確設定 `Engine.max_fps=60`；
平均 16.397～16.400ms，P95 16.823～16.938ms，P99 16.845～17.226ms，
Draw Calls 最大值 320～596，引擎靜態記憶體 67.04～67.10MiB、render video memory 約 783.26MiB。
這是 CPU 排程／渲染事件間隔，沒有將其冒稱為 GPU 時間或解除幀率上限的性能上限。
較早未限幀的 0.87～1.01ms 觀測另存 `capture_unrestricted_observation.json`，不當作玩家 FPS 驗收。

## 限制與下一步

- 本輪完成場景製作與候選功能驗證，不將生成屋瓦／木框的局部不規則當成完全還原原畫；
  岩壁、庭院細節密度與概念圖仍有差異，可在此可編輯主檔上繼續美術調整。
- 水面／瀑布為靜態幾何；不含建物室內或開門動畫。公會為現有職責的藍頂建物變體。
- 五鏡頭效能僅短取樣，最新數據見 acceptance/capture_metrics.json；不是新 30 分鐘長測、程序 RSS 或 GPU frame-time。
- 沒有新的 Windows 發布包／實體鍵鼠或 Xbox 通關驗收；G08 總門檻未因此通過。
- Android / iOS 持續暫停；不合併 main，不覆蓋正式 v0.6.1。
