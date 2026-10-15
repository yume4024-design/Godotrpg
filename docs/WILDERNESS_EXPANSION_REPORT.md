# 低語森林與礦坑擴充 — 2026-10-15

## 本次交付

新版整合入口 `./tools/godot.ps1 -Mode RunG06` 使用擴充森林（49×49m）與礦坑（51×39m）。保留原本中央劇情區、出生點與出入口，外側新增環狀道路、連接路、樹木／礦石及支架。舊版 main.tscn、原始森林和礦坑場景保留。

新增四個原創 Blender 模型及獨立角色 PackedScene：

| 區域 | 怪物 | 三角面 |
|---|---|---:|
| 低語森林 | 孢子菇靈 | 1848 |
| 低語森林 | 荊棘野豬 | 1918 |
| 礦坑 | 星晶蝙蝠 | 914 |
| 礦坑 | 礦甲蟲 | 2380 |

使用可重跑的 `scripts/tools/expansion/build_monsters.py`、GLB 與保留的 .blend 原始檔。共用既有角色視覺、戰鬥服務與回合命令。無骨架，動態僅既有整體待機／戰鬥位移，未宣稱骨骼動畫完成。

四個外圍怪物按 E 互動開戰，森林需莉雅加入、礦坑需森林教學戰勝利。均為可重複的自由挑戰，明示無獎勵；沒有新增金幣、EXP、掉落或獎勵收據，以保持既有序章經濟驗證。技能及攻防／速度有差異，沿用既有敵人選擇目標邏輯。

## 存檔

schema 3／CH00-G06.4 不變；新森林與礦坑 location.layout_version=3。舊位置先經原地圖範圍及物理驗證，保留座標後於下次儲存升級版本。舊 layout 1 不可接受新增外圍座標；新版也有明確邊界及碰撞驗證。不覆寫原 v0.6.1 存檔。

## 驗證

Godot 4.7.2.stable.official.ed1daf0bf，Windows／RTX 3080 Compatibility。

| 命令（tools/godot.ps1 -Mode） | 實際結果 |
|---|---|
| Check | 資源載入通過 |
| VisualExpansion | 56/56：圖形模式 InputMap 行走、四戰勝利與返回、外圍碰撞、新位置存讀及版本邊界 |
| TestPhase5 | 69/69：原正式序章及存檔回歸 |
| TestG06 | 51/51：舊存檔遷移、原檔保留及非法位置拒絕 |
| TestG06Story | 58/58：新版地圖完整序章、單次隊伍／獎勵及場景往返 |

主要證據：`artifacts/logs/visualexpansion-20261015-172047-268.log`、`testphase5-20261015-172105-293.log`、`testg06-20261015-172356-846.log`、`testg06story-20261015-172401-849.log`。實際查看 `artifacts/phase5/expansion-*.webp` 六張畫面，已修正 GLB 材質白色及邊界牆遮擋。

開發途中修正型別陣列與 JSON 數字版本比較錯誤；舊遷移測試更新為 layout 3，仍驗證原座標保留。上述表格為修正後結果。

## 未驗收

- Android 真機、手機效能及發布匯出。
- 新怪物低等級難度平衡（自動戰鬥使用完成序章隊伍）。
- 外圍為基礎探索布局，後續可增加地形層次與環境密度。
- 正式 main 未切換；不將此工作列為 G07/G08 完成。

補充：TestG06StoryReload 新程序讀取完成序章存檔 7/7 通過（testg06storyreload-20261015-172420-005.log）；此項不是新外圍座標的跨程序驗收。

2026-10-15 後續：低等級單場工程驗證已完成，12情境49項通過，見 [平衡紀錄](WILDERNESS_BALANCE_PLAN.md)。取代上方低等級『尚未測試』狀態；玩家試玩與連戰仍待驗收。

## 外圍座標跨程序驗收（2026-10-15）

新增 tests/wilderness_restart_test.gd，透過獨立的 Godot 程序依序執行：

```powershell
# 若沒有完成序章測試資料，先執行：
./tools/godot.ps1 -Mode TestG06Story
./tools/godot.ps1 -Mode PrepareWildernessRestart
./tools/godot.ps1 -Mode TestForestRestart
./tools/godot.ps1 -Mode TestMineRestart
```

準備程序使用真實序章完成存檔，經 SceneManager 進入兩圖，以 SaveManager 分別保存森林 x=23/z=5、礦坑 x=24/z=5 的外圍位置，然後結束。後續兩個新程序各自從其獨立測試槽啟動，不使用前一程序記憶體。

結果：準備6項、森林15項、礦坑15項，共36項通過；Godot 4.7.2載入檢查通過。驗證續玩入口不重播E001、layout 3及原座標恢復、party/inventory/flags/quests/rewards/story完整一致、E008不可重領、讀取不改原檔、重存備份與再次讀取。原檔位元組在啟動遊戲前取得，與讀取後比較。

證據：artifacts/logs/preparewildernessrestart-20261015-210959-216.log、testforestrestart-20261015-211002-116.log；礦坑對應同輪 TestMineRestart 日誌。測試檔僅在隔離 user:// 寫入 wilderness_restart_forest.json 與 wilderness_restart_mine.json，不動玩家正式槽位。本輪只新增測試及文件，未變更遊戲或存檔格式。這是 headless 的狀態持久化驗收，畫面仍沿用先前圖形探索證據，Android未驗收。
