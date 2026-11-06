# 莉雅握杖、步伐與序章候選整合

實作／初測：2026-11-04；恢復工作後於2026-11-06核對來源雜湊、修正測試時機並重新執行序章與重啟。新版莉雅已進入 `scenes/main/prologue_candidate.tscn` 的村莊 NPC、入隊／讀檔定義及戰鬥。正式 `scenes/main/main.tscn`、v0.6.1、固定 RC5 包與存檔 Schema 未改動。

## 交付與實作

- `assets/models/rebuilt_characters/lia_runtime.glb`：6,474 triangles／29骨／10段片段。既有七段、握杖姿勢、較窄走路及跑步；既有法杖140面，角色加法杖6,614面，低於15,000預算。GLB SHA256 `a7ea56fe02283c6c0b9bc91a5c5fd0b276c3cfb70e46b835f4805c4b4131cff1`。
- 在既有右手增添十根手指骨，拇指對握；使用11根骨的握持姿勢。法杖只將實例橫截面縮至0.7，長度及原始模型保留。卸裝回復手部；反覆套姿勢不累積旋轉，倒下仍維持握持。
- 走／跑另存 `walk_narrow`、`run_narrow`，腳距約0.27m，保留原片段、幾何、UV與權重；更新距離校正及明確設定循環。側面與正面已查看原生畫面。
- `female_actor.gd` 的握杖設定預設空白，舊角色使用原行為。`greystone_integration.gd` 以 `companion_appearance` 注入外觀；預設仍舊莉雅，只有最新序章候選指定新模型。每次換圖重建 NPC 外觀，不改互動 ID、碰撞、旗標、獎勵、戰鬥數值。
- 貼地原型新增可配置腳掌尺寸及支撐腳高度校正，舊預設保留。新莉雅在隔離移動測試採0.18m踝高、前0.185m／後0.11m／半寬0.10m，扣除雙腳共用的動畫起伏，避免兩腳同時懸空。此功能仍為選用測試，沒有啟用正式移動貼地；目前序章莉雅作村莊 NPC 與戰鬥隊員。

Blender工作檔、來源及雜湊在 `source_assets/character_rebuild_20261020/lia/grip_locomotion_20261104/`；輸入19骨模型保留。握杖及步伐工具分別為 `scripts/tools/author_lia_staff_grip.py`、`scripts/tools/author_lia_narrow_gait.py`。來源沿用已批准莉雅設計與既有法杖，未加入第三方素材。Godot外置匯入貼圖與匯入設定一併保留。

## 實際驗證

Windows、Godot `4.7.2.stable.official.ed1daf0bf`、Compatibility／RTX3080；Blender5.2.2 LTS。除 Check及存檔遷移模式外，角色／動作／序章及移動為原生圖形自動操作。不是人工鍵鼠／Xbox驗收，也不是效能長測。

| 檢查 | 結果 | 覆蓋 |
| --- | --- | --- |
| Blender GLB重匯入 | PASS | 面數、骨架、UV及結構；開口警告不等於自動美術合格 |
| 控制器 | 278／0 | 握杖、卸裝、死亡／復活、施法／動作恢復、循環與腳距 |
| 真實灰石村移動 | 110／0 | 21路點、走跑轉向停止、階梯中途停止、礦坑高地及木橋 |
| 整合後完整序章（11/06） | 133／0 | NPC、入隊、教學／守衛／Boss、回村、單次獎勵、保存讀取 |
| 另開程序讀檔（11/06） | 37／0 | 完成進度、精確金錢／經驗／獎勵及新角色重建 |
| 舊Pixal角色／新版雷恩 | 88／0、93／0 | 共用控制器相容性 |
| 原貼地邊界 | 10／0 | 碰撞遮罩、斜面／懸崖與原型停用恢復 |
| 舊存檔遷移／重啟 | 91／0、6／0 | 原檔保留、位置、角色、帳本與單次星印 |
| Godot Check | PASS | 專案載入 |

移動取樣462次，腳底光線漏接0；最深穿入物理路面0.01343m、最大支撐腳間隙0.06033m，通過原定5cm穿入／8cm支撐間隙門檻。這不是所有場景／每個渲染幀的零穿模保證；階梯採連續碰撞導引面，也不等於每一片可見石階都有獨立貼腳。未修改地形來迎合量測。

[全部結果、來源與日誌雜湊](evidence/lia_gameplay_20261104/summary.json)、[移動數據](evidence/lia_gameplay_20261104/movement.json)、[握杖近景](evidence/lia_gameplay_20261104/grip.png)、[走路](evidence/lia_gameplay_20261104/walking.png)、[階梯中途停止](evidence/lia_gameplay_20261104/stairs_stop.webp)、[實際戰鬥](evidence/lia_gameplay_20261104/battle.webp)。

## 保留的失敗與限制

- 未用貼地時最大穿地約20cm；未校正原型有2次漏接、最大支撐間隙8.855cm。保留 [未貼地](evidence/lia_gameplay_20261104/without_ik.json) 及 [未校正原型](evidence/lia_gameplay_20261104/uncalibrated_ik.json)。校正後同路線及補充階梯停走通過；不能由此宣稱整張地圖完全無碰撞接縫。
- 11/04序章／重啟曾印出110／0、28／0，但完整日誌有地圖尚未載入就呼叫NPC檢查的 null 錯誤；這兩筆不採用。另有首次 typed-array 建構語法錯誤。11/06改為轉場完成後檢查，並增加實際執行次數門檻，使用既有工具的錯誤掃描後重新通過。[被拒絕的測試證據](evidence/lia_gameplay_20261104/rejected_story_runs.json)。
- 握杖數值檢查是頂點／面心／邊中點稀疏取樣，另查看正側畫面；不宣稱全動畫連續表面交集為零。臉側／腿部飾片表面仍可修整。
- 新貼地僅完成灰石村指定路線；森林、礦坑動態移動尚未驗證，不強行啟用。正式候選包、最新角色下的效能尖峰、30分鐘長測仍待；人工終驗、行動平台、第一章繼續暫停。序章尚未最終完成。

## 重現

在專案根目錄依序執行（工具使用隔離測試存檔，檢查退出碼及完整錯誤輸出）：

~~~powershell
./tools/godot.ps1 -Mode VisualLiaRebuiltStory
./tools/godot.ps1 -Mode VisualLiaRebuiltReload
./tools/godot.ps1 -Mode TestPixalCharacters
./tools/godot.ps1 -Mode VisualRenRuntime
./tools/godot.ps1 -Mode TestFemaleFootBoundary
./tools/godot.ps1 -Mode TestPrologueMigration
./tools/godot.ps1 -Mode TestPrologueMigrationReload
~~~

控制器／移動工具接受 GLB 與全新輸出目錄；增加 `--grip --narrow`，移動另加 `--foot-placement`。候選 GLB 同目錄須有 motion profile與握杖receipt；本輪原始資料留在 ignored `artifacts/lia-grip-narrow-20261104/`。不以舊包人工驗收結果替代新版驗收。
