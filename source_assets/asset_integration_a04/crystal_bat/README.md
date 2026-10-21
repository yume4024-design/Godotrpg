# A04 星晶蝙蝠正式視覺接入

2026-10-21；**單件基本整合 PASS**。五種 A03 敵人均已接入既有戰鬥／野外互動，A04 基本視覺整合完成。這不是 G08 整體、實體輸入、新模型長測或第一章完成。

## 實作與保留

- 固定實作提交：`b4e2106cb951416b236b3e7cef2520fd23ba6ead`；完成編輯器動作／六戰鬥／G06回歸後固化，再匯出原生測試包。最後報告提交僅補探索斷言、封裝工具及證據，沒有再改正式 runtime。
- 正式 `scenes/characters/crystal_bat_visual.tscn` 透過獨立 rebuilt PackedScene 重用已通過的 `crystal_bat_manual_visual.tscn`。原八行場景精確保存 `scenes/characters/legacy/crystal_bat_visual.tscn`，舊 expansion GLB 未刪。
- 只重用同一 GLB：**6249／10000 triangles、17骨、六段**，SHA256 `ab487b6c94b32e9aac451348e739635684e2577f996245d3a90feb8759f7ebf7`。沒有再次生成、減面、調整蒙皮或更換貼圖。局部翼部建模與完整收翼證據見 [A03 候選](../../asset_production_a03/crystal_bat/manual_fold_acceptance/README.md)。
- 重用 RiggedEnemyActor 的 Idle／Walk、Attack／Hit／Death。既有 `rupture` 映射 `fold_wings`，仍使用既有裂能衝擊效果；`fold_wings` 亦保留為選用呈現，**沒有新增技能／修改傷害、AI、敵人 ID／獎勵／劇情旗標／存檔 Schema**。
- 第一次正式名牌測試 **193／12 FAIL**，1.6m錨點的12次蝙蝠取樣均重疊14.7158px。失敗JSON／圖保留；只將正式場景錨點提高至2.1m後 **193／0**，最低淨空 **13.3694px**，原4px門檻不變。原候選場景仍保留1.6m歷史設定，正式場景明確覆寫。

## 實際功能驗收

| 測試 | 結果 |
|---|---|
| 原生圖形共用控制器 | **67／0**；雙實例、三輪行走／攻擊／裂能摺翼／受擊中斷／死亡凍結／復原／重建，完整收翼hold後展開回Idle |
| 六種正式練習戰鬥 | **193／0**；現有全名字型與HP、模型／名牌間距、死亡不疊加舊倒下、返回探索及進度不變 |
| G06回歸 | **16模式／576／0**；NPC、E001～E009、教學與Boss、單次獎勵、交易／旅館、觸控模擬、遷移與重啟。工作樹驗證後固化為上述實作提交，未把起始HEAD a0ad24a誤寫成已含接入 |
| 野外探索／互動／返回／存讀 | **60／0**；新增實際礦坑蝙蝠互動點的17骨／同一GLB檢查及接近畫面，既有森林／礦坑路線與碰撞保持 |
| 新Windows可玩包 | Smoke正常退出；全序章／v1遷移／Boss失敗重試及交易 **141／0**；另程序讀取 **35／0** |
| 包內蝙蝠回歸 | 正常序章與重新啟動後各完成真實X003戰鬥、返回探索；17骨／GLB／技能映射正確，原完成存檔bytes未改，重新讀取保留party／inventory／flags／quests／rewards |

已查看實際礦坑接近、單蝙蝠戰鬥／死亡、完整收翼、雙實例、三蝙蝠與所有名字／HP取景。`frames/` 是真實Godot畫面縮到短邊512的WebP。這些自動輸入與原生程序測試不等同實體鍵鼠／Xbox人工通關。

## 原生Release效能

Godot **4.7.2.stable.official.ed1daf0bf**、Windows Compatibility、RTX3080、1280×720、60FPS cap。實際X003礦坑BattleArena、兩位原角色、合法防禦請求與正常敵人AI；單隻／三隻各60暖機＋600量測幀，**600幀全部保留**，截圖在量測之外。兩例均觀察到Attack與Rupture，末畫面仍有存活主角及正常行動。

| 蝙蝠數量 | 三角面 | FPS | 平均ms | P95ms | P99ms | 最大ms | Draw Calls |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 6249 | 60.002646 | 16.665932 | 16.683 | 16.698 | 16.850 | 94～113 |
| 3 | 18747 | 60.002640 | 16.665933 | 16.678 | 16.696 | 17.577 | 106～125 |

原生 **40／0**，程序收據33.837秒。31筆每秒取樣：WorkingSet樣本峰 **348176384**、Private峰 **547065856**、OS PeakWorkingSet **439922688 bytes**。Release引擎靜態記憶體不可用為 **null**，未拿Debug值代替，也不宣稱沒有長期洩漏。

效能PCK SHA256 `b5c9b6b5cfd43f2de73f7bdb4e2a330171982bbc450fe08def32bdbb068609f6`。可玩／功能QA位於 `builds/g08/candidate/20261021-122343`／`builds/g08/qa/20261021-122349`，各EXE／PCK SHA及大小在 `release/package_hashes.json`。匯出包、本機測試存檔與原始日誌留在ignored目錄，不提交。

## 重現與限制

從專案根目錄執行：

```powershell
./tools/godot.ps1 -Mode VisualEnemyController -Asset crystal_bat
./tools/godot.ps1 -Mode VisualBattleNameplates
./tools/test_g06.ps1
./tools/godot.ps1 -Mode VisualExpansion
./tools/godot.ps1 -Mode ExportEnemyAssetQA
./tools/profile_enemy_assets.ps1 -Exe <新匯出A04-EXE> -Asset crystal_bat
./tools/test_windows_candidate.ps1
```

效能是固定來源的短版戰鬥fixture，並非完整遊戲30分鐘長測；新LS／Shift實體輸入也未在本輪驗收。原固定RC3人工通過與長測仍只適用原包，沒有移用到新模型。翼／晶石較原生成網格簡潔，身體仍保留原粗糙接面。接著完成A05正式NPC、主角重製、環境物件與Windows整體Gate，再依規劃實作完整第一章；Android／iOS暫停。
