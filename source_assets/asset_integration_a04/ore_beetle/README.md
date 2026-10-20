# A04 礦甲蟲接入與效能

來源：A03同一份GLB，9911／10000三角面、15骨、attack／death／hit／idle／walk五段。來源SHA `5eb5cc52ae0ece0595baecca218eeec1621e8a43a05c375384a9b6c58512d2af`；舊GLB與完全相同的舊PackedScene保留。沒有再次生成、減面、烘圖、改權重，沒有新增施法或衝刺技能。

重用 RiggedEnemyActor，動作只改呈現：Idle／Walk循環、Attack／Hit／Death單次、回Idle、受擊中斷、死亡凍結、復原／重載。兩實例三輪圖形61／0，既有菇靈控制器回歸61／0。次要控制器中斷測試對礦甲蟲播放Attack，不把既有fixture名為cast的檔名冒稱有Cast片段。這是舊fixture標籤，沒有改模型動畫。

第一次名牌錨點1.8m：真實六種戰鬥145／12，保守幾何淨空-1.048px；失敗JSON／圖保留。改為2.0m後145／0，最低10.186px，原4px門檻不變。X004待機／死亡與返回探索畫面已看；死亡不再額外套舊全身旋轉。演練未增發旗標／任務／獎勵。

## 原生 Release

固定來源 `983382a89bfbd70ac987baef78ec598fac06ae33`，PCK `6AA670BC1C0C9E601424A4134548C33904D4463B67D282EB5656FCFDFBA9EBD2`；Godot4.7.2／Windows Compatibility／RTX3080／1280×720、60FPS cap，原生程序 33.310秒、40／0。實際X004礦坑背景，兩位既有主角、合法防禦與正常敵人AI；各案例60暖機＋600取樣幀，所有取樣幀保留，捕圖另在取樣後。獨立BattleArena，沒有探索／劇情／音效服務，不能當完整遊戲耐久或硬體最大吞吐。

| 敵數 | 敵人面數 | FPS | 平均ms | P95ms | P99ms | 最大ms | Draw Calls | 真實行動 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 9911 | 60.003 | 16.666 | 16.687 | 16.706 | 17.029 | 92–110 | 13 |
| 3 | 29733 | 60.003 | 16.666 | 16.674 | 16.691 | 16.704 | 100–118 | 11 |

31筆每秒程序取樣：WorkingSet峰值 350.266MiB、Private峰值 533.891MiB、OS PeakWS 416.223MiB。Release引擎MEMORY_STATIC不可用為null，不拿Debug補值；不能判定長期沒有洩漏。Debug39／0是前期Grove背景，不與本輪礦坑Draw Calls作同場優化比較。Native單／三敵完整模型及名牌均避開Panel，三敵實際圖已看。

接入後G06 16模式／576／0，含故事／交易／舊存檔／重啟／單次獎勵及三種圖形模式。共用測試現在用明確Asset選擇，host四組／11次實際命令路由解析通過，沒有為不同敵人建立第二套遊戲管理器。Native新候選啟動PASS；完整序章／v1遷移114／0，另一程序讀檔14／0（full_release_regression.json）。實際來源983382a與固定新EXE路徑保留，沒有覆蓋封存RC3。

## 範圍限制

沒有改資料定義、Enemy ID、技能／數值／AI、任務／獎勵或SaveCodec；正式v0.6.1入口、固定RC3包保留。新包不是固定RC3的30分鐘或實體輸入驗收。Android／iOS暫停，其餘敵人／新主角／NPC／環境物品／完整C1仍未完成。

命令：`tools/godot.ps1 -Mode VisualEnemyController -Asset ore_beetle`、`-Mode VisualBattleNameplates`、`tools/test_g06.ps1`、`-Mode ExportEnemyAssetQA`、`tools/profile_enemy_assets.ps1 -Exe <固定EXE> -Asset ore_beetle`。原始日誌／隔離profile在artifacts，EXE／PCK在builds，不提交存檔或大型產物。
