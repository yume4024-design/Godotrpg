# 探索角色比例、走路與跑步 — 2026-10-21

分支 `feature/greystone-g06`，Windows / Godot 4.7.2.stable.official.ed1daf0bf。依使用者「人物與建物比例不對，要加入跑步，走路姿勢腳太開」執行。

## 量測與修改

- 原探索雷恩／莉雅的 GLB 高 1.95m，額外縮放 `.82` 後僅 **1.599m**；村民／公會長約 1.971～2.025m。G06 玩家及莉雅 NPC 現為 **1.95m**。建物原尺寸保持 7～15m 寬；七棟門高 2.4m、門寬 1.8～2.127m，主角頭頂淨空 .45m。
- G06 玩家／村民簡化膠囊高度改 1.95m、中心 .975m；只複製並修改 shape 資源，不縮放 CollisionShape。原正式 v0.6.1 的 1.6m 膠囊及入口不變。礦坑遮擋線同步按新頭高取樣。
- 明確區分 **走路 1.8m/s／跑步 4.5m/s**。按住 Shift 或 Xbox LS（左搖桿按鍵）跑，鬆開走；仍用共同 InputMap／鎖定及焦點保護，斜向不加速。輸入強度及實際速度繼續決定步態與頻率，碰牆時停止踏步。
- Blender 副本重新編排走路：腿部擺角 .45→.32 rad、循環距離 1.12028→.81014m；雙腳橫向軌道約 .266～.270m，跑步約 .266～.274m，避免交叉。跑步保留較長跨步並彎曲前臂。平地動畫逐幀重算 Root 高度／足底 .002m。
- 新資產 `assets/models/pixal3d/{ren,lia}_locomotion.glb` 與對應 profile；原 `*_rigged.glb`／blend 保留。實際二進位驗證：**4815／4806 triangles，各19骨／七片段**；POSITION、NORMAL、UV、indices、皮膚權重及五段戰鬥動畫與原件完全相同。只有 Walk／Run 改編。

## 可執行驗證

證據位於 [本輪量測](../source_assets/exploration_locomotion_20261021/)。命令：

```powershell
./tools/godot.ps1 -Mode Check
./tools/godot.ps1 -Mode TestExplorationLocomotion
./tools/godot.ps1 -Mode TestPixalCharacters
./tools/godot.ps1 -Mode TestG08Accessibility
./tools/godot.ps1 -Mode TestCharacterPreview
./tools/test_g06.ps1
./tools/test_windows_candidate.ps1
```

測試終態列於 `validation.json`：探索60／0、角色88／0、碰撞與遮擋18／0、角色檢視12／0；G06增量回歸16模式576／0，保留先前13模式通過，再修正觸控舊速度期望並補跑最後3模式；不是重新宣稱一次全程無失敗。新原生 Release 候選啟動／完整序章120／0、獨立程序重啟14／0。所有失敗輪次另外保留。

新驗收使用實際 Windows 圖形模式、共用 Player／InputMap 與真實灰石村碰撞；不是 Android／Xbox 實體硬體認證。已查看兩角走／跑各兩張實際渲染，跑步彎臂、跨步與步行有可辨差別，未見新增分離碎片；平地腳底與停止恢復另有數值檢查。

新版獨立包：`builds/g08/candidate/20261021-044504/start_walk_run.cmd`，以相鄰 EXE 啟動，使用本包 `user_test`；原 RC3 與 v0.6.1 包保留。[走路預覽](../source_assets/exploration_locomotion_20261021/walk.gif)／[跑步預覽](../source_assets/exploration_locomotion_20261021/run.gif)。

## 已重現並處理

1. 低速走路每 tick 約3cm，原膠囊掃描會卡在第三級12cm台階。踏面探測距離最低8cm，但水平位移仍全部由 move_and_slide 處理，不瞬移。
2. 擴大探測後既有 G08 測試抓到22cm高台可爬。增加前腳落點高度查詢，仍保留完整膠囊頭頂／水平／落地掃描與18cm上限；保留失敗結果，再重跑高台／矮天花板／斜向／上下階檢查。
3. 測試起點曾置於農田斜坡內，已更正實際地面高度；測試改用獨立新槽，避免上輪存檔觸發繼續選單。Shift 注入明確 flush 並使用獨立事件，避免測試自身修改排隊的同一事件。
4. NPC 既有長路線現在以1.8m/s走完，首輪60秒測試上限不夠；有界提高為120秒，原路線和斷言保留。未把被逾時中止的輪次標為通過。

## 範圍與限制

不修改角色 ID、數值、技能、旗標、獎勵或存檔 Schema；既有存檔仍用實際玩家 shape 嚴格驗證，沒有放寬安全位置規則。原正式入口、已驗收固定 RC3 包及原模型不覆寫。新測試包的結果不挪用原 RC3 的人工／長測結論。

平地足底已重算；坡面測試檢查膠囊、有限骨架與轉向／停止，未宣稱每個足底頂點貼合斜坡。實驗貼地 IK 仍未啟用。Android／iOS 暫停。本輪也未宣稱新角色外觀重製或整體 G08／第一章完成。
