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
