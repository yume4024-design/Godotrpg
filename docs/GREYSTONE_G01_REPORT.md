# 灰石村 G01 驗收 — 2026-10-14

## 交付範圍

已合併使用者最新建造規劃並完成 **G01 初始化**。版本基線仍為 Project Crystal 0.6.1，新內容為独立 G01 探索預覽，沒有替換正式遊戲村莊、存檔、劇情或發行執行檔。

新增文件：GREYSTONE_VILLAGE_SPEC、GREYSTONE_BUILD_TASKS、本報告、sources/greystone_build_plan_2026_10_14。同步更新 PLAN_MERGE、AGENTS、README、GAME_DESIGN、STORY_IMPLEMENTATION、SCENE_ART_DIRECTION、WORKFLOW、ARCHITECTURE、ACCEPTANCE、TASKS、CHANGELOG 與 ASSET_CREDITS。

新增內容：scenes/world/greystone_village.tscn、greystone_preview.tscn、greystone/ 下七個建物佔位 PackedScene；scripts/tools/greystone/ 下可重複白盒產生器與預覽腳本；assets/models/greystone/README 說明正式模型尚未製作。新增 tests/greystone_layout_test.gd 與 UID，tools/godot.ps1 增加三種 Greystone 模式。

## 執行環境與結果

Godot `4.7.2.stable.official.ed1daf0bf`，Windows、Compatibility、RTX 3080 / NVIDIA 617.42。

| 命令 / 檢查 | 預期 | 實際與證據（artifacts/logs） |
| --- | --- | --- |
| Blender MCP addon status / scene info | 確認連線 | 兩者回覆 Could not connect；未操作使用者 Blender 場景 |
| blender.exe --version | 確認替代工具 | Blender 5.2.2 LTS 可執行；本輪未建正式 GLB |
| Python build_layout.py | 可重建八個白盒場景 | 成功，已在河岸修正後重新執行 |
| ./tools/godot.ps1 -Mode Check | 載入無解析錯誤 | 通過，check-20261014-025009-974.log |
| ./tools/godot.ps1 -Mode VisualGreystone | 真實視窗、Input/物理行走、碰撞、截圖 | **45項/0失敗**，visualgreystone-20261014-024958-727.log |
| ./tools/godot.ps1 -Mode TestPhase2 | 既有探索與故事回歸 | **58項/0失敗**，testphase2-20261014-024843-350.log |

行走測試使用既有 Player、Input Map 與 CharacterBody3D：實際送 W 鍵事件，後續透過 Input action 在物理迴圈走過村口、廣場、店前、旅館、公會、礦坑標記、橋兩岸、西出口、住宅與碼頭；沒有用逐點瞬移冒充走通。自動測試加速為 time_scale=6、physics_ticks_per_second=180，**不是 FPS 效能測試**。正式預覽使用預設正常時間。

第一輪因加速步幅過大，目標附近往返，出現一項失敗並超過60秒；修正測試時間步幅後重跑。檢查河岸發現碼頭前側缺口，補齊可見碰撞並加入針對性測試。最終河岸、碼頭邊與店牆阻擋均通過；不能據此宣稱所有像素／每寸地形已窮舉。

## 畫面檢查

實際查看 artifacts/greystone-g01/01-plaza.webp 與 02-layout.webp。首版畫面過亮，調整為 linear tonemap、ambient0.4、sun0.8，鏡頭 size34→28。重拍後確認草地、土路、屋頂顏色可分辨，角色、河道、標籤可見。全圖截圖僅 QA 使用 size155，不改遊玩攝影機。原始圖保留於 artifacts（不提交）。

這是按要求建立的簡單幾何體白盒，不是參考圖完成品：井仍是方塊、礦坑仍是標記、地形仍平坦，外緣安全牆是暫時防落界線。

## 尚未完成

- G02 高台、山崖、斜坡/階梯、瀑布與正式地形輪廓。
- G03/G04 Blender GLB、正式井/門窗/植被/水車與道具預覽；共材質與面數預算。
- G05 完整參考圖組裝；G06 NPC/任務/交易/住宿/出入口/巡邏/觸控/位置遷移。
- G07/G08 手機比例、Android真機效能與操作、iOS、平台匯出；未宣稱手機合格。
- 本輪沒有重新做實體 Xbox 硬體驗收、完整序章或新發行包；既有測試不能算成新版功能證據。

下一步為 G02，在這份120m座標與建物模組上加入多層地形與連續可走坡道，再驗證同一探索動線。
