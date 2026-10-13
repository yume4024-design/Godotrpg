# 灰石村場景改造 — 0.6.1

2026-10-13。狀態：本輪灰石村改造完成；P6 仍進行中。使用者提供的山谷村落圖片作為方向，保留圓潤人物／樹冠和原有序章玩法。森林／礦坑入口延伸與玩家完整試玩尚待後續。

## 實作

- 藍頂公會：瓦片、山牆木構、鐘樓、旗幟、原創水晶徽章、窗格、花箱、門燈與煙囪。
- 住宅：紅瓦、綠白條紋棚布、側窗、窗台花箱；既有補給箱與 NPC 外觀保留。
- 分區廣場：公會前庭、石板主路、東南側圓形水晶廣場；晶柱較初稿放大，周圍補低矮可穿行花草。
- 村外：石牆與燈具、河岸岩石、橋和對岸平台、小瀑布／靜態水車、住宅花園、風車及圓潤山林遠景。橋位於森林互動出口之外，沒有新增可走地區。
- 固定 45 度角不變，村莊正交尺寸 21、其他地圖預設 17；森林區域縮放維持 14。村莊降低日光能量至 0.85，開啟 4x MSAA。
- 美術按五個區塊合併 GLB，每區塊一個網格、多材質分面。不是逐瓦、逐花建立 Godot 節點。

新增資料全部是原創幾何與純色材質，未下載商店資產、未擷取參考圖片作貼圖、未新增外掛。來源見 [ASSET_CREDITS](ASSET_CREDITS.md)，方向見 [SCENE_ART_DIRECTION](SCENE_ART_DIRECTION.md)。

## 原始檔與規模

生成器：`tools/build_village_art.py`。Blender 5.2.2 LTS；原始 `.blend` 與 metrics JSON 在 `source_assets/village_v2`，GLB 在 `assets/models/cartoon`。前者有 `.gdignore`，不進入遊戲封包。

| 場景區塊 | 三角面 | 材質數 |
| --- | ---: | ---: |
| village_guild | 19,475 | 13 |
| village_shop | 14,726 | 14 |
| village_plaza | 87,172 | 10 |
| village_borders | 76,020 | 12 |
| village_valley | 192,554 | 22 |
| 合計 | 389,947 | — |

此數字是整組建築、花草及遠景的 authored mesh 總量，不是单角色面數；既有角色面數限制未改。Godot 自動產生 LOD，遠景區塊較大，未做逐屋遮擋剔除或低階硬體保證。

重建（專案根目錄）：

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --factory-startup --python tools/build_village_art.py
.\tools\godot.ps1 -Mode Check
.\tools\godot.ps1 -Mode VisualVillage
```

可在生成指令尾端加 `-- village_plaza` 等名稱只重建一組。模型生成不改動村莊玩法場景；參數與節點位置由 `scenes/world/village.tscn` 管理。

## 碰撞與存檔

基線取自改造前 `cd7ca59`，記錄在 `tests/fixtures/village_collision_v1.json`。16 個 BoxShape3D 的全域位置、尺寸、旋轉／縮放均逐項相同，沒有新增或漏掉的碰撞。

保留公會長、莉雅、補給箱、森林出口、出生點及全部故事觸發座標。水晶紀念柱替換原 Trunk1 的視覺，柱腳維持 0.44 平方寬度；較寬晶體位於頭頂高度。廣場和花草僅作低矮地面呈現。SaveCodec v1／CH00-P5 格式、範圍和安全落點驗證沒有繞過或改寫，不需要資料遷移。

測試使用獨立 `user://village_art/route.json`，不覆寫玩家存檔；以真實 Godot InputEventJoypadMotion／InputEventKey 送進遊戲後由原移動、互動與物理系統處理。這是程式注入輸入的圖形驗收，不宣稱本輪有人拿實體手把完整通關。上一輪使用者實體手把基本輸入證據仍見 PHASE6_REPORT。

## 驗證紀錄

引擎：`4.7.2.stable.official.ed1daf0bf`。預期：新村莊可載入、路線與舊存檔安全契約保留，完整序章獎勵／讀檔不回歸。下表命令皆在 `D:/RPGGAME` 執行，日誌位於 `artifacts/logs`。

| 命令 | 實際結果 | 日誌 |
| --- | --- | --- |
| godot.ps1 -Mode Check | 最終模型全部匯入，無載入錯誤 | check-20261013-215923-450.log |
| godot.ps1 -Mode TestVillage | 33 項／0 失敗；第一次圖形修正後的功能驗證 | testvillage-20261013-215344-819.log |
| godot.ps1 -Mode VisualVillage | 最終版 39 項／0 失敗 | visualvillage-20261013-215945-669.log |
| godot.ps1 -Mode TestPhase2 | 58 項／0 失敗；探索與縮放 | testphase2-20261013-215559-648.log |
| godot.ps1 -Mode TestPhase5 | 69 項／0 失敗；完整主線／損壞檔回歸 | testphase5-20261013-215559-673.log |
| godot.ps1 -Mode TestPhase5Reload | 7 項／0 失敗；新程序讀檔 | testphase5reload-20261013-215718-152.log |
| godot.ps1 -Mode ExportWindows | 正式 release 匯出成功 | exportwindows-20261013-220024-636.log |
| godot.ps1 -Mode ExportQA | 相同引擎 release／QA feature 匯出成功 | exportqa-20261013-220045-574.log |
| test_windows_build.ps1 -Mode QA | 最終 release 95 項／0 失敗 | exported-qa-20261013-220102-081.log |
| test_windows_build.ps1 -Mode Reload | 最終 release 新程序 22 項／0 失敗 | exported-reload-20261013-220250-112.log |
| test_windows_build.ps1 -Mode Smoke | 正式 exe 獨立啟動成功 | exported-smoke-20261013-220345-545.log |

39 項村莊圖形驗證包含：16 碰撞基線及總數、公會長→莉雅→廣場→森林入口連續輸入行走、正常互動、廣場保存／移動／載入、河岸阻擋、晶柱阻擋及森林切換。個別邊界探測以測試 reset_to 放置起點，沒有把瞬移當作整段路線行走。

初版曾因新資源宣告順序和遺留 GateStone 外觀引用出現場景解析失敗；清理後重新匯入通過。首輪圖形有兩項存讀檔失敗，原因是測試未建立專用資料夾；修正測試初始化後重跑 39 項全數通過，未修改正式 SaveManager 來隱藏失敗。

## 實際畫面與檢視

畫面由 Windows OpenGL／正式 Main 場景渲染取得，原圖為 1280×720 或 960×540，review 圖短邊 512。已查看原圖及 review；以下本機證據在 ignored artifacts，並非已隨 Git 保存的圖片。

- `artifacts/village-v2/01-spawn.webp`：一般出生鏡頭。
- `02-guild.webp`：公會及實際 A 互動提示。
- `03-crystal-plaza.webp`：晶柱與鋪面。
- `04-forest-bridge.webp`：森林出口、河道、桥與對岸平台。
- `05-small-gameplay.webp`：960×540 HUD、角色和道路。
- `06-village-overview.webp`：驗收專用尺寸 45 總覽，**不是正常遊玩鏡頭**；正常村莊尺寸為 21。

針對本次場景變更的視覺檢視（0／1／2；不宣稱完整 UI 認證）：COMP-LEAD-ENV=2，鋪面連接 NPC 與出口；COMP-CENTER-CLEAR=2，主要步行區可讀；COMP-DEPTH-LAYERS=1，已分村落／河岸／山林，但遠景仍有規則排列感；LIGHT-PART-OCCLUDE=N/A，這組場景畫面沒有粒子特效；SPACE-PLAYFIELD=2，沒有裝飾堵住任務動線；AFF-FEEDBACK=2，接近出口與 NPC 顯示實際提示。出生視角的公會部分在 HUD 後方，靠近公會後入口及提示清楚；不把總覽畫面當成遊戲可讀性的替代。

## 效能與匯出核對

同一台 Ryzen 5 5600／約 32 GB／RTX 3080，Windows OpenGL 3.3 NVIDIA 617.42。最終 release 重啟檢查在 1280×720、4x MSAA，暖機後各採 120 個 frame callback：村莊中位 16.665 ms、P95 16.840 ms、最大 16.916 ms、509 draw calls。P6 舊版該採樣為 1,214 draw calls；新視野也較寬，這是不同構圖的紀錄，不能據此宣稱等比例 FPS 提升。

另一輪 QA 的村莊 callback 中位 0.965 ms，圖形村莊測試為 0.927 ms；呈現／垂直同步狀態不同，不將這些數字和 60 FPS 樣本作速度比較。這不是 GPU 計時器，也不代表長時間幀穩定性或最低硬體驗收。release memory monitor 回傳 0，記為無資料。

`tools/audit_export_pack.gd` 從空目錄載入兩份 PCK 並計算 SHA256：正式 207 檔、QA 230 檔；除 project.binary、UID cache、global class cache 三項預期設定差異外，204 個正式遊戲檔均與 QA 相同。正式 PCK 無 tests／tools／docs／source_assets。明細：`artifacts/village-v2/{windows-pack,qa-pack,pack-comparison}.json`。

Windows ZIP 為 `builds/ProjectCrystal-0.6.1-windows-x64.zip`；由 `tools/package_windows.ps1` 讀 project.godot 版本命名，保留上一份 0.6.0 ZIP。封包為 49961419 bytes，SHA256 `47ad252d867d80f51700719a9a338a98308a915999fa4efd884cd53a7c487968`；ZIP CRC 及內含六檔的 SHA256 清單全部核對通過。

## 未驗證與下一步

村外橋、河流、水車、風車及住宅皆為靜態遠景；沒有新增室內、交易、農田或村民 AI。未照圖加入可探索城堡。正常遊玩範圍維持原先村莊；本輪沒有完成整張參考圖的所有內容。

下一輪可依使用者授權將石材、木構和植被語彙延伸至森林／礦坑入口。P6 玩家正式包完整通關、實體手把全流程、20～30 分鐘節奏／時長、長時間穩定性及其他硬體仍待驗收。22.484 秒的 QA 加速路線不可抵算玩家通關時間。
