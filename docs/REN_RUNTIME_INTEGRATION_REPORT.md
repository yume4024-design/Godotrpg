# 雷恩重製角色 — 控制器、持劍與遊戲回歸

2026-10-22，feature/greystone-g06。**獨立可玩候選通過；正式角色替換與新版 Windows 整體驗收尚未完成。** 接續 [衣褲重拓樸候選](REN_AUTHORED_GARMENT_REPORT.md)，不是將既有4815面模型改名。

## 資產與接入

| 項目 | 實際結果 |
|---|---|
| 新雷恩 | 10655／15000 triangles、19骨、5個skinned Mesh、7個材質primitive、身高1.95m |
| 原創青銅短劍 | 330／1000 triangles、3個色彩材質、UV、無貼圖；可換武器獨立統計 |
| 同屏成本 | 10985 triangles，不包含其他角色、地圖及特效 |
| 動作 | 原七段完整保留，加 idle／sword_idle／sword_attack／sword_guard／death／walk_narrow／run_narrow，共14段 |
| 原始貼圖 | 原4096² albedo與前輪衣褲atlas保留；原表面／UV／權重／法線不改 |
| 動作時間 | 待機1秒循環、揮劍／防禦0.5秒、倒地1秒；戰鬥仍使用原0.55秒行動時間 |

執行資產為 `assets/models/rebuilt_characters/ren_runtime.glb`，SHA256 **b70dcd417ffaf4722dc24e0da16e7d83fef7aaea1f374d53205f01b9ec500efe**。原生工作檔 `source_assets/character_rebuild_20261020/ren/runtime_narrow_motion_20261022/ren_runtime.blend`，SHA256 **9fe5c47105962f36ce18eadca540e2a5920d783524282d976fe4e2507c11a673**。

短劍GLB SHA256 **00a1d8f0a7651e39a7a5d9ce8552f706e672925db551b0b3e133b9cb99c012b6**；Blender工作原件及配方在 `ren/sword_20261021/`。固定衣包仍計入角色，短劍沒有併入身體網格。

`HandEquipmentVisual` 由共用角色控制器注入 Skeleton，僅接收既有 ItemDefinition，管理 HandRight 掛點、可見性、單組手指握持與武器片段映射。PartyManager／PartyActions仍持有裝備及交易狀態；沒有新增RPG Manager或戰鬥數值。卸裝後恢復原始空手攻擊，其他實例不共用動作播放器或掛點。

共用控制器新增選用待機／倒地／走跑片段欄位，預設維持舊行為。新候選不建立隱藏法杖，倒地片段結束後保持姿勢，重複BattleStage刷新不重播倒地；復活恢復待機。G06新增外觀注入欄位，預設仍為原雷恩；探索裝備視覺從既有隊伍通知更新，戰鬥仍由原BattleStage讀取裝備。

候選入口：`scenes/tools/ren_runtime_game.tscn`，使用獨立 `user://ren_runtime_slot_01.json`。原 `main.tscn`、兩個正式Pixal視覺場景／GLB、角色ID、技能、經濟、旗標、獎勵帳本與SaveCodec均保留；女性村民依使用者指示仍留候選。

## 發現問題與實際修正

1. **持劍 v1 FAIL**：右腋下保留面頂點783／785的上臂／軀幹交界，揮劍3.240104倍、防禦2.550047倍拉伸，超過原2.5門檻。原件及診斷保留。
2. **v2數值PASS但視覺拒用**：以原已驗證肩部範圍分配姿勢，局部X軸卻未產生清楚抬劍。未以數值PASS當成防禦完成。
3. **v3採用**：按原骨方向與角色前方求肘／腕鉸鏈軸，防禦可見抬劍、攻擊有收放，保留原七片段及所有身體權重；不再盲目降低全身幅度。
4. **村莊60／2 FAIL**：新來源走跑腳距約36.7～38.1cm，偏寬。新增獨立窄步幅片段，原walk／run不覆寫。
5. **首版窄步幅視覺FAIL**：腳距合格卻遺失腿部擺動。原因是切換目標Action後，depsgraph以先前已存在的曲線覆寫手動姿勢。補上真實前後步幅測試，重現控制器 **93／2** FAIL；改為先快照所有來源姿勢，再逐影格寫入目標Action。最終腳距約26.89～27.00cm，前後步幅walk **0.565634m**、run **0.853025m**；沒有放寬腳距或步幅門檻。

三份持劍配方明確保留 `--recipe world-v1/local-v2/hinge-v3`；窄步幅曲線錯誤另存原件與失敗畫面。來源與失敗見 [凍結證據](../source_assets/character_rebuild_20261020/ren/runtime_acceptance_20261022/README.md)。

## 最終驗收

Windows、Godot **4.7.2.stable.official.ed1daf0bf**、Compatibility／RTX3080；Blender **5.2.2 LTS**。

| 檢查 | 實際結果與範圍 |
|---|---|
| 嚴格GLB＋獨立Blender重匯入 | PASS；10655面、索引／UV／權重／材質／骨架與有限值；另計330面武器 |
| 保留檢查 | PASS；19骨rest、原七段127影格骨矩陣差0；原packed albedo保留，964個指定附件面仍在，角法線門檻仍.002 |
| 全14段動作＋持劍幾何 | **270影格／0失敗**，含控制器等效.45rad單組手指握持；最大邊拉伸低於2.5，循環端點合格，取樣刀刃遠端與身體無三角面相交 |
| 原生共用控制器 | **93／0**；14段匯入、空手／武器映射、真實前後步幅、掛點位置／方向、握持不累積、動作返回、倒地保持／復活、雙實例隔離 |
| 真實村莊探索與碰撞 | **64／0**；InputMap事件、旅館坡道、農田高地、礦口、12cm台階、轉向／停止、牆／低頂阻擋、同場景存讀檔；60次物理取樣位移walk1.770／run4.425m，設定速度仍1.8／4.5m/s |
| 新雷恩完整序章圖形回歸 | **84／0**；正常0.55秒戰鬥動作、教學戰、Boss敗北／重試、回村、E008／E009、單次星印與212金幣／每人300EXP、跨場景與讀檔；實際觀測sword_attack／sword_guard／hit／death |
| 另開程序讀檔 | **9／0**；人物、裝備視覺、進度、背包及獎勵帳本保留 |
| 原兩個Pixal角色 | **88／0**，驗證共用控制器預設行為；此列是舊資產回歸，不是新模型面數 |
| G06全套 | **16模式、576／0**，含原序章／NPC／交易／存檔遷移與桌面觸控模擬 |

已查看新候選正側背、揮劍／防禦／施法、走跑、倒地、實際村莊與Boss畫面。窄步幅拒用前後畫面均保留；不是只檢查AnimationPlayer名稱。刀刃檢查排除刻意接觸的劍柄，沒有據此宣稱手指逐指貼合、衣物自碰撞或所有blend中間姿勢都無穿插。

數值與31張預算WebP、日誌名稱／SHA及逐檔來源清單已凍結。原始本機日誌／存檔不進Git。Blender縮圖快取仍有OpenImageIO警告，模型真實保存／重新匯入成功，沒有修改使用者正在開啟的Blender。

## 重現與下一項

```powershell
./tools/godot.ps1 -Mode VisualRenRuntime
./tools/godot.ps1 -Mode VisualRenMovement
./tools/godot.ps1 -Mode VisualRenStory
./tools/godot.ps1 -Mode TestRenStoryReload
# 可操作的獨立候選入口
./tools/godot.ps1 -Mode PreviewRenRuntime
```

仍缺：新模型的打包／長時間效能及人工鍵鼠／Xbox驗收、五指／眨眼口型及地形IK、美術局部精修、正式角色替換。這些不由本輪自動測試推導完成。下一項按核准金髮紫衣來源重製莉雅，再整合兩位主角及其餘環境／物件，完成新版Windows整體Gate後進入完整第一章。Android／iOS持續暫停，完整第一章目標仍在進行。
