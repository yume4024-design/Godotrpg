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
