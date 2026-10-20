# A04 荊棘野豬

本輪接入已通過A03的同一份GLB：9998／10000面、12骨、attack／charge／death／hit／idle／run／walk七段。SHA `3b212d70f5de4321325aba30d6de338ea9f7e8b49103d8bfa3267554fae493ed`。原來源／GLB／UV／4K貼圖／權重／動畫幅度保留；舊PackedScene精確備份於scenes/characters/legacy。沒有再次生成、減面或以舊資產改名冒充重製。

## 呈現與回歸

- 重用RiggedEnemyActor，新增可選run_motion_threshold，預設0關閉；野豬指定0.7，高motion用真實Run，低motion用Walk。其他敵人不改既有行為。Run循環、單次動作完成後恢復要求狀態。
- Charge只對應呈現入口及測試，正式BattleManager仍只使用原有Attack，沒有新增技能、改AI、速度、傷害或回合；不把新動畫當作新RPG規則。
- 兩實例／三輪真實時鐘動作、骨姿變化、受擊中斷、死亡凍結、復原與重載：圖形63／0；菇靈與礦甲蟲控制器各63／0。低motion實際Walk、高motion Run、Charge影格已看。
- 正式六種演練／主線戰鬥配置與返回：161／0，名牌最低淨空17.767px≥原4px；X002戰鬥／死亡畫面已看，沒有額外套舊倒下。演練旗標／任務／獎勵不變。
- 接入後G06：16模式／576／0，含序章、舊存檔遷移、交易、重啟、單次獎勵與三種圖形模式。回歸啟動時HEAD為cb26bc7＋dirty，測試對應內容後固定於ac03b61；沒有把它寫成測試前已乾淨的ac03b61。

## 原生 Release 效能

來源 `ac03b61746ac0076c96acd6cc5dafa3b7bf8213b`，PCK `4F318A8FF2068040A929C5AC59371B9A8E6D4A392AC6C406829B7B134DEEC75E`；Godot4.7.2／Windows Compatibility／RTX3080／1280×720／60FPS cap。原生圖形程序 32.365秒、40／0；正常AI與合法防禦、每案例60暖機＋600量測幀，捕圖在取樣後，所有取樣幀保留。

| 敵數 | 敵人面數 | FPS | 平均ms | P95ms | P99ms | 最大ms | Draw Calls | 真實行動 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 9998 | 60.003 | 16.666 | 16.680 | 16.697 | 16.785 | 302–320 | 13 |
| 3 | 29994 | 60.003 | 16.666 | 16.677 | 16.701 | 16.745 | 310–328 | 11 |

每秒30筆程序取樣：WS峰值 340.320MiB、Private峰值 533.281MiB、OS PeakWS 415.898MiB。Release引擎靜態監視器不可用為null。獨立Production BattleArena／X002森林背景，沒有探索／劇情／音效服務，不能當完整遊戲30分鐘、GPU滿載上限或長期無洩漏。Native三敵畫面已看，完整角色與名牌避開實際Panel。

## 限制

A03既有非流形藤蔓／鬃毛粗糙接面與無足部IK仍保留；不是表面修整驗收，也不宣稱完美自碰撞。本輪未出現新增骨架崩解或脫離肢體。另重新匯出可玩及QA原生包：啟動PASS、完整序章／v1遷移114／0、另一程序讀檔14／0；full_release_regression.json保留實際ac03b61來源及新EXE路徑。固定RC3長測／待回覆實體輸入與本輪新模型包分開，不更改正式v0.6.1入口、數值、ID、旗標、獎勵或SaveCodec。Android／iOS暫停；守衛／蝙蝠、NPC／新主角／環境物品與完整C1尚未完成。

命令：`tools/godot.ps1 -Mode VisualEnemyController -Asset thorn_boar`、`-Mode VisualBattleNameplates`、`tools/test_g06.ps1`、`-Mode ExportEnemyAssetQA`、`tools/profile_enemy_assets.ps1 -Exe <固定EXE> -Asset thorn_boar`。原始log/profile與EXE/PCK分別保留artifacts與builds，不提交存檔或大型產物。
