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
