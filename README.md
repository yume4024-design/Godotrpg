# 《失落星核》｜Project Crystal

2026-10-27 最新整合來源以 `./tools/godot.ps1 -Mode RunPrologueCandidate` 啟動：新版灰石村→低語森林→礦坑、已修正防墜與小地圖，現可點擊小地圖或在 M／Menu 手冊選「地圖」查看完整地標。[區域地圖測試與限制](docs/PROLOGUE_AREA_MAP_REPORT.md)。

已固定的 Windows 序章 RC2 在 `builds/prologue-candidate/rc2-20261027/candidate/start_prologue_candidate.cmd`；[包內序章與30分鐘自動長測報告](docs/PROLOGUE_REPAIR_20261027_REPORT.md)。RC2 保留且**不含後續新增的展開地圖**；下列較早日期為歷史進度，人工驗收仍暫停。

2026-10-26 礦坑整體畫面修整已更新來源：[八區清單、18張實景與264＋8項驗證](docs/MINE_VISUAL_FINISH_REPORT.md)。使用`./tools/godot.ps1 -Mode RunMineReference`查看；本輪先畫面、不打包，RC2不含最新修整，人工驗收暫停。

2026-10-26 礦坑八區造景候選與 Windows RC2 已完成整合：深坑道、岩層、彎軌、採掘工具與地下水；[264項來源回歸／137項包內序章／32項重啟及已知差距](docs/MINE_SCENE_COMPLETION_REPORT.md)，[啟動指南](docs/MINE_REFERENCE_GUIDE.md)。人工美術與實體輸入驗收維持暫停。

2026-10-26 灰石村完整場景候選已接入原始專案：乾淨木框建築、連續瀑布與庭院；[307項回歸與實景](docs/GREYSTONE_SCENE_COMPLETION_REPORT.md)。[Windows RC3啟動指南](docs/GREYSTONE_REFERENCE_20261024_GUIDE.md)：143項序章／28項重啟讀檔通過；舊rc2保留，人工驗收暫停。

2026-10-26 岩壁法線與草土接合已修復；[297項回歸及前後畫面](docs/GREYSTONE_CLIFF_SHADOW_REPORT.md)。以 `./tools/godot.ps1 -Mode RunReferenceVillage` 查看；舊固定包未替換。

2026-10-25 岩壁與草皮：原始專案新增自然岩肩、草土接縫及近景驗證；[畫面與296項回歸](docs/GREYSTONE_NATURAL_EDGES_20261025_REPORT.md)。`./tools/godot.ps1 -Mode RunReferenceVillage`查看；舊rc2包未更新。

2026-10-25 門廊與庭院：Blender MCP製作的店面招牌、門廊補強與10組植栽已接入原始專案；[畫面與293項回歸](docs/GREYSTONE_COURTYARD_20261025_REPORT.md)。以 `./tools/godot.ps1 -Mode RunReferenceVillage` 查看；舊rc2固定包不含本輪美術。

2026-10-25 建築第二輪：旅館交錯山牆、商店窗框與屋頂封底已接入原始專案；[實際畫面與回歸結果](docs/GREYSTONE_ARCHITECTURE_20261025_REPORT.md)。入口同下；舊rc2固定包尚未包含本輪美術。

2026-10-25 原始專案已更新岩壁、鋪面與光照；使用 `./tools/godot.ps1 -Mode RunReferenceVillage` 查看。[本輪畫面與結果](docs/GREYSTONE_REFERENCE_FINISH_20261025_REPORT.md)。下列rc2固定包仍對應之前的122891e提交。

新版灰石村參考候選：`./tools/godot.ps1 -Mode RunReferenceVillage`。雙橋、實心階梯、礦坑道路與封閉船殼；[畫面／驗證／新包入口](docs/GREYSTONE_REFERENCE_20261024_REPORT.md)。固定包 `builds/greystone-reference/rc2-122891e/candidate/start_reference_village.cmd`；[啟動指南](docs/GREYSTONE_REFERENCE_20261024_GUIDE.md)。人工驗證仍暫停。

2026-10-24 新礦坑參考重建與序章候選已完成自動圖形驗收：八區三層Blender場景、完整探索環線、動態水體與安全舊檔遷移。Windows Release序章／交易／遷移127／0＋新程序讀檔22／0；啟動`builds/mine-reference/rc1-2d02f63/candidate/start_mine_reference.cmd`。[指南](docs/MINE_REFERENCE_GUIDE.md)／[報告](docs/MINE_REFERENCE_REPORT.md)／[場景Skill](docs/skills/crystal-scene-builder/SKILL.md)。人工鍵鼠／Xbox依使用者指示暫停，新礦坑長測未做；正式v0.6.1與舊候選包保留。

2026-10-24 新 Blender 灰石村 Windows 固定候選已匯出：`builds/greystone-blender/rc1-63d05f5/candidate/start_blender_village.cmd`。包含地面／岩石紋理及動態水體；原生包內序章116／0＋重啟22／0，實體輸入與新長測仍待。[操作說明](docs/BLENDER_WINDOWS_RC1_GUIDE.md)／[實際結果](docs/BLENDER_WINDOWS_RC1_REPORT.md)。正式v0.6.1／舊RC4保留。

2026-10-18 Windows G08.2 台階／礦坑橫梁修正驗收完成，候選版本 0.6.1-g08-rc2；[遊玩指南](docs/GREYSTONE_G08_GUIDE.md)、[驗收結果與未完成項目](docs/GREYSTONE_G08_REPORT.md)。G08 整體未完成，正式 v0.6.1 保留。

2026-10-17 雷恩／莉雅已改用 ComfyUI Pixal3D 重製模型，見 [重製報告](docs/PIXAL3D_CHARACTER_REPORT.md)。以 `tools/godot.ps1 -Mode PreviewCharacters` 檢視兩人，`-Mode RunG06` 遊玩新版灰石村；正式 v0.6.1 入口與既有匯出保留。

2026-10-21 G06 探索比例與步態已修整：兩位主角約 1.95m，與村民／門面統一尺度。WASD／方向鍵或左搖桿走路，新版源碼按住 **Shift／Xbox LB** 跑步（2026-10-24更新；舊匯出包仍用LS）；鬆開恢復走路。見 [比例與走跑報告](docs/EXPLORATION_LOCOMOTION_REPORT.md)。

2026-10-17 功能分支已提供新版灰石村 Windows 預覽與角色更新，見 [預覽說明](docs/GREYSTONE_PREVIEW_GUIDE.md) 及 [角色修整紀錄](docs/CHARACTER_POLISH_REPORT.md)。用 `tools/godot.ps1 -Mode ExportGreystonePreview` 產生獨立預覽；正式 v0.6.1 輸出保留。

> **2026-10-14 正文合併更新（優先於本檔較早條款）**：新企劃已由使用者貼文取得，不再待正文。灰石村採 120×120m、Q 版低面數切面、北側公會/西北農田/東北礦坑/東河/南入口/西出口；平台 Windows + Android，iOS 預留。執行以 [docs/GREYSTONE_VILLAGE_SPEC.md](docs/GREYSTONE_VILLAGE_SPEC.md) 與 [docs/GREYSTONE_BUILD_TASKS.md](docs/GREYSTONE_BUILD_TASKS.md) 為準。G01 獨立佔位預覽，不替換正式0.6.1存檔；G06再遷移位置及串接劇情/觸控。本檔舊「待正文」、PC限定、圖片未列公會、固定舊碰撞等描述保留為歷史，不是目前限制。


**最新規劃（2026-10-14）：** [新企劃合併紀錄](docs/PLAN_MERGE_2026_10_14.md)／[九區灰石村設計](docs/GRAYSTONE_VILLAGE_V3.md)。新圖已取代舊水晶廣場方向；新企劃正文已合併，G01/G02與G03基礎建物已完成；正式遊戲仍為下述0.6.1。

原創 Windows Low Poly 3D JRPG。先完成 20～30 分鐘序章《灰石村的異變》，再逐章擴充到六篇章、約 12～16 小時與三種結局的完整企劃目標。

**Phase 5 已完成**：序章 E001～E008 可從新遊戲玩到回村交付，追加章末離村預告 E009。灰石村、低語森林與廢棄礦坑已連通；雷恩／莉雅雙人隊伍、回合戰鬥、成長、裝備、任務日誌與保存／讀取可用。

角色與場景保留圓潤可愛卡通風格。礦坑新增開頂回廊、礦軌、坑木、礦燈、星晶覺醒動畫，以及獨立的腐化守衛戰舞台。第一章目前只有解鎖旗標和預告，地圖尚未開放。

操作：WASD／方向鍵移動，E 互動；對話用 E／空白鍵／Enter 或繼續按鈕。M 開關旅途手冊，Esc 關閉；F5 保存、F9 讀取，亦可使用 M → 旅程頁按鈕。R 返回本區起點。戰鬥用滑鼠，或 Tab／方向鍵和 Enter 選指令與目標。

試玩路線：開場 → 公會長接 Q001 → 莉雅入隊 → M 裝備 → 森林補給與史萊姆戰 → 東侧入口進礦坑 → 進入內部取得藥品 → 調查星晶 → 覺醒與腐化守衛戰 → 經森林回村交付 → 離村／第一章預告。營地可恢復 HP／MP；主線與演練分開，演練不給故事獎勵。

兩場主線戰鬥與交付合計 212 金幣、每位隊員 300 EXP；每個來源只給一次，第一枚星印不重複。裝備影響數值，探索仍以隊長代表隊伍，雙人在戰鬥中登場。

**請在離開遊戲前手動保存。** 忙碌時的 F5 請求會等到安全點再寫入，F9 不會中斷戰鬥。已有存檔時開啟遊戲會先顯示續玩／新旅程選擇。單欄位保留上一份有效備份，格式錯誤不污染目前進度；詳見 [存檔格式與路徑](docs/SAVE_FORMAT.md)。工具入口與直接從編輯器啟動使用的 user:// 位置可能不同。

開啟 project.godot 按 F5，或使用下方 Run 指令即可遊玩。P6 已提供 [Windows 0.6.1 試玩包](builds/ProjectCrystal-0.6.1-windows-x64.zip) 與 [試玩說明](docs/PLAYTEST_GUIDE.md)：加入 Xbox 操作、原創短循環配樂／音效、戰鬥光環與音量設定。實體 XInput 基本輸入、QA release 通關及重啟讀檔已驗證；玩家完整通關和 20～30 分鐘節奏仍待驗收，見 [P6 紀錄](docs/PHASE6_REPORT.md)。產物只保留在本機 builds，未納入 Git。

## 閱讀順序

1. [開發規範](AGENTS.md)
2. [遊戲範圍](docs/GAME_DESIGN.md)
3. [架構與資料歸屬](docs/ARCHITECTURE.md)
4. [每次開發的執行流程](docs/WORKFLOW.md)
5. [階段任務與進度](docs/TASKS.md)
6. [驗收清單](docs/ACCEPTANCE.md)
7. [環境及驗證紀錄](docs/ENVIRONMENT.md)、[變更紀錄](docs/CHANGELOG.md)

故事工作先讀 [故事整合與階段安排](docs/STORY_IMPLEMENTATION.md)，再按需查閱 [Story Bible v1.0 原文](docs/STORY_BIBLE.md)。原文完整保留；實作差異與待補內容均記在整合文件，企劃中的參考圖片不視為已授權遊戲素材。

內容資料：[E001～E008](data/story/prologue_events.json)、[Q001](data/quests/q001.json)、[B001/B002](data/battles/prologue_battles.json)。E004/B001 與 E007/B002 已接入正式主線；追加 E009 章末敘事不發獎勵。

## 本機工具

使用者提供的 `D:\Godot_v4.7.2-stable_win64.exe` 是資料夾。實際命令列執行檔是其下同名前綴的 `_console.exe`，已確認為 Godot 4.7.2。

在 PowerShell 執行：

```powershell
Set-Location D:\RPGGAME
.\tools\godot.ps1 -Mode Version
```

開發與遊玩指令：

```powershell
.\tools\godot.ps1 -Mode Check
.\tools\godot.ps1 -Mode Smoke
.\tools\godot.ps1 -Mode Test
.\tools\godot.ps1 -Mode TestPhase2
.\tools\godot.ps1 -Mode VisualPhase2
.\tools\godot.ps1 -Mode TestPhase3
.\tools\godot.ps1 -Mode VisualPhase3
.\tools\godot.ps1 -Mode TestPhase4
.\tools\godot.ps1 -Mode VisualPhase4
.\tools\godot.ps1 -Mode TestPhase5
.\tools\godot.ps1 -Mode TestPhase5Reload
.\tools\godot.ps1 -Mode VisualPhase5
.\tools\godot.ps1 -Mode PreviewBattle
.\tools\godot.ps1 -Mode PreviewArt
.\tools\godot.ps1 -Mode Editor
.\tools\godot.ps1 -Mode Run
```

`Check` 等待資源匯入；`Smoke` 執行 120 次主迴圈；`Test` 執行 24 項 P1 物理/輸入回歸；`TestPhase2` 執行 58 項 P2 整合檢查；`VisualPhase2` 用實際渲染器走相同流程並保存八張畫面，共 66 項檢查。首次下載專案先執行 Check，產生類別快取。日誌寫入 `artifacts/logs/`，工具將子程序設定/快取隔離在 `artifacts/godot-user` 與 `artifacts/godot-local`；Run/Editor 使用同版本圖形執行檔啟動獨立視窗。

`TestPhase3` 執行 75 項戰鬥整合檢查；`VisualPhase3` 用 Windows 渲染器操作同一流程並保存十張畫面，共 85 項。`PreviewBattle` 使用測試腳本走到第一場演練後停下供手動操作，含測試用快速抵達與補給；一般遊玩請用 `Run`。

`PreviewArt` 開啟五個卡通模型展示；`TestArt` 執行 17 項模型／材質／關節驗证，`VisualArt` 另保存正側背面與步行姿勢，共 21 項。[美術更新報告](docs/CARTOON_ART_REPORT.md) 包含來源、面數、重建方式與驗收限制。

歷史 [P4 驗收報告](docs/PHASE4_REPORT.md) 記錄 70 項功能／82 項圖形檢查、成長规则及限制。`TestPhase4`／`VisualPhase4` 執行主線入隊、選單實際按鈕、兩次敗北／重試及獲獎流程。

本輪 [P5 驗收報告](docs/PHASE5_REPORT.md) 記錄 69 項功能、77 項圖形模式及 7 項跨程序讀檔檢查。先執行 TestPhase5，再執行 TestPhase5Reload；測試只使用獨立的測試存檔。

歷史 [P3 驗收報告](docs/PHASE3_REPORT.md) 包含命令、畫面、修復與限制；[P2 報告](docs/PHASE2_REPORT.md)／[P1 報告](docs/PHASE1_REPORT.md) 保留歷史紀錄。可以使用並修改素材商店資產；目前使用自製 Blender 模型及 Godot 場景，見 [素材紀錄](docs/ASSET_CREDITS.md)。

引擎換位置時可傳入 `-GodotPath '完整執行檔路徑'`，或設定環境變數 `GODOT_PATH`。若系統執行政策禁止腳本，可用下列直接命令查版本，無需改動整台電腦的政策：

```powershell
& 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --version
```

## 下一個開發任務

> P6 進行中。依使用者提供的 [場景參考](docs/SCENE_ART_DIRECTION.md) 改造灰石村，再完成正式匯出包的玩家全程手把試玩、節奏／時長與長時間效能驗收；保留 P1～P5 回歸，不提前開始第一章。

灰石村已完成本輪參考圖改造：藍頂公會、水晶廣場、棚布住宅、橋河／水車與山谷住宅遠景。原有 16 個碰撞和故事落點保留；詳見 [村莊場景報告](docs/VILLAGE_ART_REPORT.md)。`TestVillage`／`VisualVillage` 可重跑碰撞契約、實際输入路線與畫面驗收。

## 灰石村 G03 模組化建築預覽

在本專案根目錄執行 `./tools/godot.ps1 -Mode PreviewGreystone`，以 WASD／方向鍵／Xbox左搖桿探索。多層地形、坡道、河谷與瀑布上已加入七棟 Quaternius CC0 素材改製建物，含旅館側翼、單層商店/民宅和獨立碰撞；門寬與共用材質已驗證，NPC與觸控尚未加入。43項建築驗證與70項全村圖形/物理驗證及限制見 [G03報告](docs/GREYSTONE_G03_REPORT.md)。Blender中可檢視 Crystal_G03_Buildings 建物場景，歷史地形檢視為 Crystal_G02_Review。
