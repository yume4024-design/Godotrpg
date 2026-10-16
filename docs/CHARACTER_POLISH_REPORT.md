# 角色持續修整紀錄 — 2026-10-17

使用者授權持續執行目前角色流程，按可驗收項目逐次提交。Android 暫停；不擴展章節或改動存檔格式。以下為實際成果，未完成項目保持待驗收。

## CP01：莉雅手部與柳木法杖

- 模型新增 Hand／Fingers 左右共四骨，合計 17 骨；手掌及手指群使用平滑過渡，沒有宣稱五指各自綁定。
- `build_willow_staff.py` 以原創木桿、皮革握柄及束帶製作法杖；獨立 `willow_staff.glb`／`.blend`，140 三角形。人物仍為 4,546 面，合計 4,686 面。
- 裝備顯示讀取既有 CombatantState.equipped；只有 willow_staff 才顯示，沒有免費裝備／增加物品或修改數值。BoneAttachment3D 綁 HandRight，卸裝同時解除手指握持。NPC 預設空手，戰鬥依實際裝備呈現。
- 加大空手側的施法動作以改善可讀性。`lia_rigged.glb` 已保留全部七個動畫；上一版七骨資產仍保留。

實際驗證（Godot 4.7.2／Windows、Blender 5.2.2）：

- Check 成功：`artifacts/logs/check-20261017-034044-119.log`。
- PreviewFemale 0 失敗：`artifacts/logs/previewfemale-20261017-034048-*.log`；已查看持杖正面及施法正／側面圖，模型與法杖可見並隨手部移動。
- VisualFemaleAnimation 32 項通過：`artifacts/logs/visualfemaleanimation-20261017-034059-805.log`。含裝卸、既有魔法加成、空手隱藏、骨骼附件追隨、死亡／復活與卸裝解除握持。
- VisualG06Story 完整序章 68 項通過，見同輪 `artifacts/logs/visualg06story-20261017-0341*.log`。
- 角色 GLB 面數與骨架檢查通過，含 Blender 顯示輔助物為 4,626 面：`artifacts/female_staff_check/report.json`。

限制：手指仍是群組骨，未逐指控制；開放式手型的細節與緊密握柄仍需後續修整。法杖是顯示資產，不新增碰撞或道具能力。腳步貼地與動畫銜接列入下一項。

## CP02：平地鞋底與動作銜接

- 新增左右腳掌骨，合計 19 骨；動作內補償腳掌朝向，依評估後的實際網格鞋底高度烘焙 Root 骨的垂直修正。人物節點沒有平移，碰撞與控制器位置不變。
- Godot 匯入後直接以 Skin bind、頂點權重與骨骼姿勢重算鞋底，walk／run 各 49 個取樣點。最低點範圍：walk 0.001377～0.002537m，run 0.001274～0.002011m；平地未測得穿入地面。
- 新增 0.12 秒姿勢混合及循環相位銜接；進入跑步門檻 0.72、退出門檻 0.58。保留速度臨界值的跑步狀態，戰鬥打斷後也能正確恢復。
- 修正初次混合時未被動畫覆寫的骨骼位置殘留；目前每幀先還原基準再套目標姿勢與混合。

實際驗證：

- Check 成功：`artifacts/logs/check-20261017-034709-*.log`。
- PreviewFemale 0 失敗：`artifacts/logs/previewfemale-20261017-034555-994.log`，含速度緩衝、戰鬥恢復、停止逐幀旋轉變化與 Root 位置還原。先前殘留導致的四個失敗已修復，不列為通過。
- TestFemaleGrounding 0 失敗：`artifacts/logs/testfemalegrounding-20261017-034658-184.log`；已查看 grounded_walk／grounded_run 的實際地板與角色截圖。
- VisualFemaleAnimation 32 通過：`artifacts/logs/visualfemaleanimation-20261017-034713-218.log`。
- VisualG06Story 68 通過：`artifacts/logs/visualg06story-20261017-034609-217.log`。
- 資產面數與骨架檢查通過：`artifacts/female_grounded_check/report.json`。

限制：此為烘焙的平地校正，不是即時斜坡 IK，也未完成支撐腳水平鎖定，因此移動速度不匹配時仍可能滑步。混合銜接過程未宣稱每一幀均維持鞋底 2mm。下一項改善面部辨識與眨眼。

## CP03：面部辨識與自然眨眼

- 依原四視圖增加瞳孔、高光與細小嘴線，人物共 4,582 面，持杖合計 4,722 面。八個眼部表面具 Blink 形變，GLB 保留所有七段骨架動畫。
- 約 4.3 秒自然眨眼一次，閉合／張開約 0.16 秒；倒下閉眼，復活恢復。形變值保存於各 MeshInstance，驗證兩個實例不互相污染。
- 新增面部近景測試；已查看 face_open、face_blink、face_closed 圖。這是風格化壓縮眼部的眨眼，不是完整眼皮、嘴型或臉部表情系統。
- 修復新增形變網格沒有 UV 導致 Godot 無法產生切線的匯入錯誤；新小網格具平面 UV，不使用貼圖。

驗證：Check 成功（`check-20261017-035018-297.log`）；VisualFemaleFace 14 項通過（`visualfemaleface-20261017-0351*.log`）；PreviewFemale 0 失敗（`previewfemale-20261017-035022-308.log`）；TestFemaleGrounding 鞋底取樣不變且通過（`testfemalegrounding-20261017-035118-786.log`）；VisualFemaleAnimation 32 項通過（`visualfemaleanimation-20261017-035119-881.log`）。日誌均在 artifacts/logs。資產檢查通過：`artifacts/female_face_check/report.json`，含骨骼顯示輔助物 4,662 面。

## CP04：獨立角色檢視

- `scenes/tools/character_preview.tscn` 與 `scripts/tools/character_preview.gd` 提供雷恩／莉雅、待機／行走／跑步、莉雅五種戰鬥動作、持杖、轉向、縮放及臉部近看。
- 即時計算目前可見模型面數；莉雅持杖 4,722 面、空手 4,582 面；雷恩 4,579 面、七骨。雷恩尚無匯入戰鬥動畫，因此相關按鈕停用，不以假動作替代。
- 「保存預覽圖」寫入獨立 `user://character_previews/`，不建立 Party／Inventory／Saves 等遊戲服務。測試實際以滑鼠點擊按鈕並確認新檔案及保存結果。
- 小型固定選項改用直接按鈕；原生彈出選單的自動輸入曾導致測試失敗與超時，未列為通過。已查看最終角色、持杖及臉部截圖，降低預覽燈光亮度以保留金髮層次。

執行：`./tools/godot.ps1 -Mode PreviewCharacters`，或在 Godot 開啟上述獨立場景執行。自動驗證 `-Mode TestCharacterPreview`：12 通過、0 失敗，日誌 `artifacts/logs/testcharacterpreview-20261017-040100-504.log`；Check 成功見 `check-20261017-040006-954.log`。證據：`artifacts/female_character/viewer_face.webp`、viewer_lia、viewer_ren。

此場景是角色外觀檢查工具，不是正式旅程或 Android 驗收；角色近距離拓樸仍有生成網格的簡化限制。

## CP05：五指手型與碎片清理

- 在保留的七骨原件副本上移除 42 個獨立碎片頂點（14 個小三角片），清除瀏海旁的懸空短線。
- 取代原生成網格的粗糙遠端手型，製作左右手掌與各五指，29 骨、4,662 面；持法杖共 4,802 面。每指目前只有一個可控關節，並非完整人手多節骨架。
- 手掌連接延伸到原護腕內，修正早期手腕接縫與旋轉方向；握持按掌心方向彎曲，拇指加入對握。近景仍可見簡化幾何接縫，不宣稱封閉拓樸或所有持物角度零穿插。
- 匯出前檢查人物與法杖總面數，不在面數失敗時覆寫交付檔。

已查看 hand_open／hand_grip 近景及 viewer_face 清理後畫面。VisualFemaleHand 各指綁定、五指彎曲及卸裝回位 22 項通過；其餘 VisualFemaleAnimation 32、TestCharacterPreview 12、VisualFemaleFace 14、VisualG06Story 68 項通過，鞋底 98 點取樣維持通過。主要證據：`artifacts/logs/visualfemalehand-20261017-041103-904.log`、`testcharacterpreview-20261017-040902-773.log`、`visualg06story-20261017-040912-503.log`；資產檢查 `artifacts/female_hands_check/report.json` 通過，含顯示輔助物 4,742 面。

## CP06：施法光點跟隨來源

- 莉雅提供杖端／掌心 Marker，BattleStage 沿既有成功行動訊號傳給 ActionEffect。持杖時選杖端，空手選朝目前戰鬥鏡頭一側的右掌。
- 新角色的施法蓄光跟隨來源 0.24 秒；有來源的魔法投射物先短暫蓄力再飛向目標。舊角色沒有 Marker 時保持既有播放方式，不修改消耗、傷害或回合結算時機。
- 節點移除或釋放時停止追蹤，特效沿原有生命週期清理。未新增特效管理器、貼圖或粒子依賴。

VisualFemaleAnimation 38 通過、0 失敗（`artifacts/logs/visualfemaleanimation-20261017-041423-106.log`）；含實際持杖／空手療癒、移動中光點位置誤差 <5mm 及來源釋放。VisualActionEffects 26 通過、VisualG06Story 68 通過（`visualg06story-20261017-041331-807.log`）。已查看 `spell_staff_charge.webp`／`spell_palm_charge.webp`；治療數字遮擋角色資訊列入下一項修正。

## CP07：戰鬥浮字避開資訊

- 傷害／治療浮字依同組角色位置向外側顯示，減低起點及上升範圍，避開名稱與 HP。數值、顏色及 0.45 秒生命週期不變。
- 自動測試以相機投影、字型大小與外框估算螢幕矩形，在四個時間點檢查全部角色資訊；初稿仍與小型蝙蝠標籤重疊八次，增大側向間距後修復。
- VisualActionEffects：86 通過、0 失敗，`artifacts/logs/visualactioneffects-20261017-041810-327.log`。已查看 fx_attack 與 spell_staff_charge 畫面確認浮字可讀。
- VisualFemaleAnimation：38 通過；VisualG06Story：68 通過，見本輪 `artifacts/logs/visualg06story-20261017-0418*.log`。

此檢查涵蓋目前測試角色與鏡頭，不宣稱所有未來三人隊形、極窄比例或多段連擊均已驗收。

## CP08：控制器、步速與碰撞

- 新增 `scenes/tools/lia_movement_preview.tscn`，可由 `./tools/godot.ps1 -Mode PreviewLiaMovement` 開啟；使用正式 Player、InputMap、固定鏡頭及灰石村碰撞，但不建立劇情／存檔服務，不替換正式探索隊長。
- 提高烘焙步幅；產生共用 `lia_motion_profile.tres`，行走／跑步模型循環距離分別約 1.036／1.623m。Player 將實際水平速度交給有對應介面的外觀，依角色比例及動畫長度調整播放率，限制 0.3～2.2 倍；不改遊戲移動速度或戰鬥播放時間。
- 圖形測試透過共用 InputMap 實際移動膠囊，檢查類比半速、停止、三個路點貼地及公會牆面阻擋；17 通過、0 失敗。類比實測 1.688m/s，播放率 2.069。
- 查看 run_side 及 movement_12 畫面，調低獨立預覽燈光以保留顏色。鞋底 98 點取樣：行走 1.017～2.006mm，跑步 -3.550～2.000mm，均在既有 -5～10mm 容差內。尚未實作斜坡 IK 或水平腳鎖，仍可能有滑步。

Godot 4.7.2／RTX 3080 Compatibility，命令與日誌：

- `-Mode Check`：`artifacts/logs/check-20261017-042518-423.log`，成功。
- `-Mode TestLiaMovement`：`testliamovement-20261017-042823-598.log`，17/0。
- `-Mode TestFemaleGrounding`：`testfemalegrounding-20261017-042740-639.log`，0 失敗。
- `-Mode VisualFemaleAnimation`：`visualfemaleanimation-20261017-042741-896.log`，38/0。
- `-Mode TestG06`：`testg06-20261017-042747-264.log`，51/0。
- `-Mode VisualG06Story`：`visualg06story-20261017-042752-107.log`，68/0。

以上是桌面自動輸入與實際渲染驗證，並非 Android 真機或玩家人工通關驗收。

## CP09：Windows 角色效能回歸

Godot 4.7.2、Windows RTX 3080、Compatibility、1280×720、VSync 關閉、無 FPS 上限，均為編輯器 debug 執行。`ProfileCharacters` 在相同森林戰場依序比較舊／新角色外觀，每組先暖機 0.8 秒，待機 2 秒，再每秒實際提交行動共 12 次（攻擊／星火／療癒／用藥／防禦）；測試 fixture 重設 HP／MP 以維持可操作性，不保存進度或發放獎勵。

| 外觀／狀態 | 平均 ms | P95 ms | P99 ms | 最慢 ms | Draw Calls |
| --- | ---: | ---: | ---: | ---: | ---: |
| 舊角色待機 | 0.771 | 0.850 | 0.954 | 1.133 | 399 |
| 舊角色行動 | 0.786 | 0.873 | 0.993 | 13.534 | 399～415 |
| 新角色待機 | 0.940 | 1.172 | 1.361 | 1.589 | 337 |
| 新角色行動 | 0.938 | 1.026 | 1.150 | 7.360 | 337～353 |

新版行動樣本引擎靜態配置峰值 125.106MiB、顯示配置 53.185MiB；舊版行動 124.074／46.905MiB。順序測試保留資源快取，不能把差值視為模型獨佔大小或洩漏證據。新角色繪製次數較少，但幀時間略高；骨架／形變成本可能是因素，未用 CPU/GPU 硬體計時證實。所有 P95 低於 16.667ms 不代表低階 PC 或發布版本效能合格。

- `ProfileCharacters`：31 通過、0 失敗；`artifacts/logs/profilecharacters-20261017-043116-721.log`，原始 `artifacts/performance/character_battle.json`。核對每組消耗兩瓶藥、特效清理、零獎勵結算；已查看 character_updated_true 畫面。
- `ProfileGreystoneDynamic`：63 通過、0 失敗；`profilegreystonedynamic-20261017-042958-007.log`，六區實際移動且角色／背包／劇情等狀態不變。正常取樣 P95 1.072～1.462ms，公會 Draw Calls 348～366 最高；引擎靜態配置峰值約 281.97MiB，顯示配置最高 77.29MiB。
- 45m 隱藏只作診斷比較，沒有套入正式地圖；`TIME_PROCESS` 快取值仍不能當逐幀 CPU 耗時。Android 暫停，未驗收。

## CP10：獨立 Windows release 包

- 新增 `Windows Character QA` preset 與 `character_qa` feature 專用入口。既有正式與 QA preset 保留；`ExportCharacterQA` 每次輸出新的時間目錄，不覆寫 v0.6.1。
- QA release 先用滑鼠操作角色檢視工具，驗證 29 骨、七片段、步距 Resource、法杖與八個臉部形變表面，再沿既有 G06 測試跑完實際序章。使用獨立 APPDATA 及 `user://character_qa/` 槽位，截圖也寫入該目錄。
- `./tools/godot.ps1 -Mode ExportCharacterQA`：成功，`artifacts/logs/exportcharacterqa-20261017-043434-331.log`。
- `./tools/test_character_build.ps1 -Mode Full`：83 通過、0 失敗，`character-export-full-20261017-043448-788.log`。
- `./tools/test_character_build.ps1 -Mode Reload`：8 通過、0 失敗，`character-export-reload-20261017-043531-941.log`。確認獨立程序保留角色、裝備、212 金幣、300 EXP、星印與獎勵帳本。
- 產物：`builds/character-qa/20261017-043434/ProjectCrystal.exe`（109,268,480 bytes）、`.pck`（13,988,476 bytes）。不加入 Git。匯出紀錄中未出現來源 `.blend`／assets/source 或根目錄使用者參考圖；preset 明確排除這些來源。
- 已查看 release 的 character-cast 畫面；此為加速自動化驗證，不代表人工 20～30 分鐘通關或 Android 真機。

原正式輸出在匯出前後 SHA256 一致：exe `d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562`，pck `a8c95f156c55a0cf15cb6b71e617c435868eb6822d0c08a014fbdefbb42002b7`。證據 `artifacts/character_qa_formal_before.json`。

## CP11：片段邊界與更新順序修復

- 新增 30／60／120 FPS 確定性更新測試，發現匯出第 1 幀起點讓片段多出 1/24 秒；不是調高測試容差。Blender 改從 0 幀建立全部關鍵格，行走精確 1 秒，其餘六片段 2/3 秒，所有軌道起點為 0。
- 大步幅在 0.12 秒內停步會超過既有單幀旋轉門檻；只將停步收勢延至 0.2 秒，戰鬥與步態切換仍為 0.12 秒。PreviewFemale 最終 0 失敗，前面失敗輪次保留於日誌。
- 新起點也揭露施法光點落後 BoneAttachment 一幀，持杖／掌心位置測試失敗；改在 RenderingServer.frame_pre_draw 同步光點，追蹤結束及節點退出時解除連線，修復兩項失敗。
- `TestFemaleMotionBoundary` 36/0，涵蓋精確片段長度、零起點、三種更新率、戰鬥時長不受速度加快、倒下／復活、移動恢復、兩個實例時鐘隔離。日誌 `artifacts/logs/testfemalemotionboundary-20261017-044115-937.log`。
- `PreviewFemale` 0 失敗（`previewfemale-20261017-044102-229.log`），已查看新 run_side 與 spell_staff_charge 畫面。
- `TestFemaleGrounding` 98 點取樣通過，行走 1.199～2.000mm、跑步 -2.346～2.000mm（`testfemalegrounding-20261017-043938-926.log`）。
- `VisualFemaleAnimation` 38/0（`visualfemaleanimation-20261017-044201-990.log`）；`VisualActionEffects` 86/0（`visualactioneffects-20261017-044207-761.log`）；`TestLiaMovement` 17/0（`testliamovement-20261017-044215-607.log`）；序章 68/0（`visualg06story-20261017-044009-980.log`）。修正後類比步速仍為 1.688m/s，播放率改為 1.986，因片段已去除前段停留。

動畫時間修正不改 BattleManager 的行動結算或經濟；仍不宣稱斜坡 IK、水平腳鎖及手工拓樸完成。

CP11 release 重新匯出至 builds/character-qa/20261017-044240，Full 83/0、Reload 8/0；日誌 character-export-full-20261017-044245-105.log、character-export-reload-20261017-044307-531.log。

## CP12：戰鬥中途退出的生命週期

`./tools/godot.ps1 -Mode TestCharacterLifecycle`，Godot 4.7.2 圖形模式：12 次建立真實 BattleArena／莉雅／裝備，透過 BattleManager.submit 成功療癒，在追蹤光點仍作用的 0.08 秒時移除整個戰場。

62 項通過、0 失敗，日誌 `artifacts/logs/testcharacterlifecycle-20261017-044430-470.log`。WeakRef 確認每次戰場、角色、骨架及光點均被釋放，場景節點和 frame_pre_draw 連線回到基線；等待延遲戰鬥續行後仍無節點、無作用中 Tween。引擎靜態配置約 39,486,729～39,528,537 bytes，包含快取暖機，不能由短樣本宣稱所有遊戲狀態無洩漏。本輪未發現需額外修改正式功能的殘留。

## CP13：靜止斜坡腳部 IK 原型

`scripts/characters/lia_foot_placement.gd` 是明確注入角色／Skeleton 的選用組件。物理更新執行腳底射線，視覺更新在角色動畫之後解算大腿／小腿，將鞋底朝向地面；斜坡提供最多 6cm 骨盆下沉空間。只改骨架，不移動 actor／碰撞膠囊，倒下、施法、沒有地面或停用角色處理時不作用。目前行走時停用，沒有接入正式 NPC 或戰鬥。

`./tools/godot.ps1 -Mode TestFemaleSlope`：33/0，`artifacts/logs/testfemaleslope-20261017-044833-261.log`。在平地、前後／左右各 10 度斜坡，以匯入網格 Skin 實際計算雙腳鞋底；靜止鞋底與平面距離約 -0.159～0.872mm，腳踝目標誤差 <1mm，actor 位置不變。已查看 slope_10_0 與 slope_0_10 實際畫面，膝部彎曲可見。這是原型的有限角度驗證，不是全地形、台階、移動／抬腳或完整 IK 驗收。

## CP14：保留抬腳的動態貼地

- 解算前保存原動畫腳踝相對角色的抬升高度，再沿地面法線補回，避免把擺動腳壓在地面；仍無水平腳鎖。
- `PreviewLiaMovement` 加入預設關閉的「斜坡腳部貼地（實驗）」滑鼠選項，明確注入既有玩家碰撞體並排除其 RID。只在此工具選用，未加到正式角色場景、NPC 或戰鬥。
- `TestFemaleSlope` 65/0，`artifacts/logs/testfemaleslope-20261017-045046-823.log`。兩個角色比例（1.0／0.82）、兩個 10 度斜坡方向、行走／跑步，各取樣 72 個實際渲染幀，共 576 動態樣本；鞋底最低約 -0.160mm，最近支撐腳最高約 1.991mm。行走抬腳峰值約 3.49～4.28cm，跑步 8.13～9.94cm；角色位置不變。
- `TestLiaMovement` 20/0，`testliamovement-20261017-045118-803.log`；滑鼠確認預設關閉與開啟，再實際走三個路點、停止及碰撞公會牆面。已查看動態斜坡兩張近景。

有限原型：尚未驗證陡坡、台階／落差、斜坡轉折的平滑度或長時間動態效能；不作為正式全地形 IK 完成宣稱。Android 暫停。

## CP15：護腕與接縫外觀

依參考圖自製兩側棕皮護腕與金色腕帶，64 個三角形、共用兩種材質，使用既有 Forearm 骨，遮住手腕交接。人物 4,726 面、持杖 4,866 面，仍為 29 骨。原七骨資產保留；沒有增加貼圖或外部資產。

- ai-3d-agent 面數／骨架檢查通過，`artifacts/female_bracers_check/report.json`：含 80 面骨架顯示輔助物 4,806 面，GLB 本身 4,726；開口衣物邊界仍有警告，不宣稱封閉網格。
- `TestCharacterPreview` 12/0（`testcharacterpreview-20261017-045438-147.log`）；`VisualFemaleHand` 22/0（`visualfemalehand-20261017-045441-662.log`）；`VisualFemaleAnimation` 38/0（`visualfemaleanimation-20261017-045442-914.log`）。已查看 viewer_lia 與 hand_grip 近景，腕帶、手型與持杖可辨識。
- `PreviewFemale` 0 失敗、`TestFemaleMotionBoundary` 36/0；本輪重建未改骨架或七個片段時間。
- release 更新至 `builds/character-qa/20261017-045535`，Full 83/0、Reload 8/0；日誌 `character-export-full-20261017-045540-131.log`、`character-export-reload-20261017-045602-569.log`。

仍為簡化的生成網格搭配程序零件，並非逐細節還原或完整手工拓樸。每指只有單關節，水平腳鎖與正式全地形 IK 尚未完成。

## CP16：貼地啟停與反向斜坡

- 實驗組件以 0.16 秒權重混合開關，保留原 FK 姿勢作為端點；地面法線／命中平面及骨盆高度採時間緩衝。倒下／戰鬥立即停用並清除快取。診斷腳踝誤差改在最終混合後計算。
- 近乎伸直的腿不能用微小幾何偏差推算穩定彎曲方向，改用角色向前的膝蓋參考。第一版反向斜坡仍單幀跳轉 0.903rad，加入地面點及骨盆緩衝後降為約 0.129rad（7.4 度）。
- `TestFemaleSlope` 最終 70/0，`artifacts/logs/testfemaleslope-20261017-050141-852.log`；開／關最大單幀骨盆位移約 6.25／6.63mm，原先最多 6cm 一次切換。`TestLiaMovement` 20/0，`testliamovement-20261017-050058-208.log`。
- 已查看 foot_transition 畫面。上述測試把整片平面由 +10 度瞬間改成 -10 度；這個合成突變仍出現最低 -0.0695m 暫時鞋底距離，不列為「全地形無穿透」。一般固定斜坡的物理玩家行走另於 CP17 驗證。原型仍僅在獨立工具、預設關閉。

## CP17：固定坡面實際移動

`./tools/godot.ps1 -Mode TestFemaleSlopeMovement`，`artifacts/logs/testfemaleslopemovement-20261017-050420-276.log`，40/0。獨立固定 10 度坡面使用正式 PlayerMovement、InputMap、半徑 0.32／高度 1.6 的膠囊及 0.82 角色比例，不使用動畫移動角色位置；只注入測試焦點與方向輸入。

X／Z 方向、0.5／1.0 輸入強度、往返八路段共 1,154 樣本，全部物理接地；鞋底最小約 -2.583mm，最近支撐腳最高約 1.637mm，各路段到達目標且鬆開輸入後停下。已查看 physical_slope 的正背方向畫面。與 CP16 的「地面瞬間翻轉」不同，這輪坡面保持固定，玩家確實沿坡面行走。仍未驗證平地接縫、台階、陡坡或 Android，正式角色場景保持不啟用此實驗。

## CP18：平地／斜坡／高台接縫

初版八段均未通過 -2.5cm 鞋底門檻，最差約 -4.15cm。單點腳踝取樣漏掉前方腳尖先接觸上坡，加入腳尖／腳跟取樣後只剩兩項約 -2.94cm。以 Blender 讀出原 GLB 鞋底範圍，設定前 0.27／後 0.14m 的保守支撐並補足 2mm 餘量，仍接近門檻；進一步確認動畫與射線不同更新時機，改為獨立移動工具內明確選用同次物理動畫／取樣／解算。正式 NPC／戰鬥仍用原渲染更新，不改時間或邏輯。

`./tools/godot.ps1 -Mode TestFemaleRampTransitions` 最終 40/0，`artifacts/logs/testfemaleramptransitions-20261017-051401-780.log`。X／Z 兩方向、快慢與往返，跨越平地、固定 10 度坡道與約 1.058m 高台，八路段共 1,935 渲染後網格取樣、膠囊全程接地；最低鞋底 -2.646mm，最近支撐腳最高約 4.238mm，路點可達且可停步。已查看 physical_ramp 的正背方向畫面。

回歸 `TestLiaMovement` 20/0（`testliamovement-20261017-051440-945.log`）、`TestFemaleMotionBoundary` 36/0（`testfemalemotionboundary-20261017-051454-172.log`）；原型未加入正式角色場景。這不包含陡坡、真正台階、動態移動平台或 Android；CP16 瞬間翻轉整片地面的穿透限制仍保留。

CP18 正式路徑回歸：VisualFemaleAnimation 38/0（visualfemaleanimation-20261017-051520-317.log），VisualG06Story 68/0（visualg06story-20261017-051526-058.log）。

## CP19：30／120 FPS 更新率

`TestFemaleRamp30`、`TestFemaleRamp120` 各 48/0，日誌 `artifacts/logs/testfemaleramp30-20261017-051714-206.log`、`testfemaleramp120-20261017-051753-571.log`。VSync 關閉，Engine.max_fps 設為目標，另以 Engine.get_frames_drawn 與牆鐘計算真實繪製更新率；各路段須落在目標範圍才通過。30 FPS 實測 29.96～29.99、120 FPS 119.94～119.98，物理更新保持專案設定。

同樣快慢往返八路段、膠囊全程接地；30 FPS 鞋底最低約 -2.50mm，120 FPS 約 -2.65mm，支撐腳最高皆約 4.3mm。這驗證獨立原型不因渲染與物理更新率不同而累積偏移，並非 Android 或低階 PC 效能認證。沒有更動正式遊戲更新率、輸入或存檔。
