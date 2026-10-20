# 探索比例及步態證據

2026-10-21，Godot 4.7.2 Windows；Blender 5.2.2 LTS 在保留的兩個 Pixal3D blend 副本中只編排 Walk／Run。沒有重新生成網格、下載或購買素材。

- `baseline_dimensions.json`／`baseline_village.webp`：修改前實際量測與畫面，主角1.599m、莉雅1.599m；NPC約2m。`revised_*`為修正後同一鏡頭／村莊，兩位主角1.95m；七棟建物未縮放。
- `door_clearance.json`：直接讀七件 GLB 的門面數據；`glb_preservation.json`逐項讀二進位 POSITION／NORMAL／UV／skin／indices／五段戰鬥片段，完全相同。
- `*_authoring.json`：Blender來源及輸出SHA、兩步態的周期距離、橫向軌道及平地足底範圍。GLB與blend另存 `assets/models/pixal3d/*_locomotion.glb`、`assets/source/pixal3d/locomotion/`；原件保留。
- `validation.json`與`native_*.json`：真實完成結果與日誌內容。圖形探索60／0、角色88／0、碰撞18／0、檢視12／0；G06增量16模式576／0（13模式後續接3模式，保留失敗批次）。新原生Release120／0及另程序14／0，來源基準943d9eb加本輪未提交內容，以實際包雜湊識別。
- `failed_attempts/`：前幾輪測試隔離槽／起點／注入問題，以及新增長探測後22cm高台錯誤。後者已加真實踏面高度查詢；未放寬18cm上限。既有NPC長路線首輪60秒逾時日誌保留於本機artifacts，120秒有界重跑通過。
- `walk.gif`／`run.gif`：30張、15fps的原生實際骨架畫面，供效果預覽；不是新建概念圖。四張WebP為代表幀，另外保留真實村莊路線畫面。原始PNG／完整日誌在 `artifacts/locomotion/`。

視覺檢查採Godot Agent Vision：COMP-SAFE-EDGE 2/2（兩角完整）、COMP-CENTER-CLEAR 2/2（預覽無遮擋）、MOT-VOL 2/2（四張未見新碎片／體積崩解）。這只是本次選取鏡頭的視覺檢查，不能替代全動作／全地形頂點驗證。平地足底重算完成，斜坡貼地IK仍停用；Android／iOS與這次的Xbox實體按鍵未驗收。

重跑：`tools/godot.ps1 -Mode TestExplorationLocomotion`；原生匯出 `tools/test_windows_candidate.ps1`。模型編排／逐緩衝比對／證據整理分別是 `scripts/tools/refine_exploration_gaits.py`、`check_exploration_gaits.py`、`package_exploration_locomotion.py`；生成前確認原始blend及Python依賴，不能把腳本執行成功冒稱人工視覺完工。
