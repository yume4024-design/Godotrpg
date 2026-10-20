# A04 腐化守衛接入與原生效能

2026-10-21補齊已完成證據。正式視覺採用原A03同一GLB：9762／15000面、17骨、九段，SHA f0b66505c8809209b9502a09000d06991bf0114a7d748c980878421255c1c8ad。原場景精確保存在 scenes/characters/legacy/guardian_visual.tscn。沒有重生成、減面或改RPG數值／技能／AI／主線旗標／存檔。

重用RiggedEnemyActor：Attack／Hit／Death及Rupture→Cast，HeavyAttack／SpecialAttack／Stagger僅選用呈現，不新增戰鬥技能。兩個實例、三輪真時間切換、受擊中斷／死亡凍結／復原／重載與三個額外片段，75／0。

名牌3.6m首次六戰鬥177／12失敗，保留failed_anchor_result.json／圖；改3.8m並將單一Boss展示位置z加.4m後177／0，最低11.609px，原4px門檻未放寬。模型、全名牌、死亡與真正B002主線礦坑背景已查看；只改BattleStage展示位置，不移動探索出生點或存檔位置。

## 原生Release實測

來源b8029a5d776e2c3f42e12e80e6e061075cfc1711；PCK0360184C3667C2A563673AA26C0995E2F3C132E2C34AB873EE739F67E4D280D6，原生程序19.661秒、21／0。Godot4.7.2／Windows Compatibility／RTX3080／1280×720／60FPS cap，實際B002單Boss、兩位既有主角、合法防禦與正常AI，觀察到Attack及Rupture。只有一個Boss符合實際遭遇，不以虛構三Boss作代表。

60暖機＋600量測幀全部計入，截圖在量測之外。60.003FPS，平均16.665918ms／P95 16.688／P99 16.713／最大16.802ms，Draw Calls92～111。18筆每秒程序取樣：WorkingSet峰346341376、Private峰553340928、OS PeakWS436670464 bytes；引擎Release靜態記憶體不可用為null，不用Debug值替代，也不宣稱長時間無洩漏。

G06既有16模式576／0；新原生可玩包Smoke、完整序章／v1遷移／Boss失敗重試120／0及另程序重啟14／0。測試包位於 builds/g08/candidate/20261021-000102 與qa/20261021-000107，與固定RC3／後續走跑包分開。新增六個斷言確認實際Boss模型、17骨及Rupture映射，未放寬舊斷言。

命令：tools/godot.ps1 -Mode VisualEnemyController -Asset corrupted_guardian；-Mode VisualBattleNameplates；tools/test_g06.ps1；tools/profile_enemy_assets.ps1 -Exe <已記錄固定EXE> -Asset corrupted_guardian；tools/test_windows_candidate.ps1。各原始JSON、取樣CSV、圖與來源SHA見本目錄。

## 限制

這是單件守衛接入及短版原生驗收，不是五敵A04、30分鐘長測或實體輸入通過。蝙蝠完整收翼仍FAIL；角色、NPC／環境物品、Windows整體Gate與完整第一章仍未完成。Android／iOS暫停。後續6781721走跑版本的功能結果另有獨立證據，不能套用本次舊PCK效能。
