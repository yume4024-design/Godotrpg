# A04 敵人視覺整合

2026-10-20；feature/greystone-g06。**IN_PROGRESS**：已接入通過A03的孢子菇靈與礦甲蟲，不代表五敵或Windows候選全部通過。蝙蝠仍保留完整收翼人工拓樸要求；其他候選不重複生成。

| 敵人 | 目前結果 | 未完成 |
|---|---|---|
| 孢子菇靈 | 9811／10000、7骨／六片段；動作61／0、原生效能40／0；完整Release114／0及重啟14／0 | 新長測／實體輸入未做 |
| 礦甲蟲 | 9911／10000、15骨／五片段；動作61／0、六戰鬥145／0、G06 576／0、原生效能40／0、完整Release114＋14／0 | 新長測／實體輸入未做 |
| 荊棘野豬／腐化守衛 | 重用A03已通過來源 | 逐件動作／場景／戰鬥整合及效能 |
| 星晶蝙蝠 | 正式舊模型保留 | 完整收翼拓樸／視覺Gate未通過，不採用失敗候選 |

## 實作及來源

正式 spore_sprite_visual.tscn 改為獨立重製PackedScene的實例；舊場景完整保存 scenes/characters/legacy/spore_sprite_visual.tscn，原assets/models/expansion模型未刪。新GLB SHA `bd38151d3b0e8bb48063eb72914b9c99f6ba97511d72ea1ec9b13f52de56d037` 與A03完全一致，沒有再次減面／生成／改骨姿。

RiggedEnemyActor 僅負責呈現，繼承現有 CartoonActor 介面並讓匯入 AnimationPlayer 擁有骨架。Idle／Walk循環、Attack／Cast／Hit／Death單次，實際rupture映射cast；單次完成回到要求的待機／移動。重複死亡刷新不重播，受擊可中斷動作，死亡後拒絕新動作，復原／重建從Idle開始。每個實例複製AnimationLibrary後才改循環設定，骨架及播放狀態不互相污染。

新增 procedural_fall 呈現欄位，舊角色預設true保留既有倒下；新菇靈false只用真實Death片段，避免額外旋轉造成雙重倒地。沒有更動Enemy ID、Data Resource、技能／數值／AI／回合／EXP／掉落／旗標／SaveCodec。Release QA只對隊員要求19骨，不再錯把有7骨的新敵人當成19骨角色。

## 已執行及失敗保留

Godot 4.7.2／Windows Compatibility。

- Check：PASS；VisualEnemyController最終 **61／0**。兩個實例、三輪實際時間Attack／Cast／Hit／Death切換、骨姿有變化且有限、死亡凍結、重生、重複受擊重新開始、重載及互不污染。截圖已看；第一版雙實例展示間距使倒下後與同伴重疊，調整純展示間距後重驗，不改模型或動作。
- 接入後名牌錨點1.9m的保守幾何淨空測試 **129／12失敗**；原資料保存，將該新模型錨點改2.15m後 **129／0**，最低7.080px，沒有降低原4px門檻。實際X001完整取景／死亡畫面已看；模型比例沿用A03來源，不宣稱所有鏡頭／尺寸通過。
- 六種實際演練及返回，包括舊敵人、兩主角與新菇靈；新敵人七骨／實際GLB路徑、完整名牌、死亡不套用舊旋轉、隊伍／旗標／任務／獎勵不因演練額外發放均檢查。
- 接入後G06 **16模式／576斷言／0失敗**，含故事／交易／舊存檔／重啟／單次獎勵與三種圖形模式。另舊角色圖形88／0、P3戰鬥75／0在控制器準備階段已執行；不冒稱它們是在所有後續資產改動後重跑。
- A04動作只改呈現，沒有聲稱NPC巡邏、敵人世界AI或新的技能規則已完成；Android／iOS暫停。

[實際資料與畫面](../source_assets/asset_integration_a04/spore_sprite/)。命令：`tools/godot.ps1 -Mode VisualEnemyController`、`-Mode VisualBattleNameplates`、`tools/test_g06.ps1`。新敵人未放進固定RC3 PCK；[RC3長測](G083_RC3_REPORT.md)是另一個已封存版本，不沿用其FPS／記憶體或人工結果證明新模型效能。

菇靈代表性數量效能與Release已完成，詳細方法／首次三敵遮擋失敗／修正／記憶體見[效能證據](../source_assets/asset_integration_a04/spore_sprite/performance/README.md)。礦甲蟲亦已接入，見[單件報告／實際畫面](../source_assets/asset_integration_a04/ore_beetle/README.md)：名牌首次145／12失敗保留，改2.0m錨點後145／0、最低10.186px，正常死亡及返回已看；另原生X004礦坑背景1／3敵各600幀，P99 16.706／16.691ms。接著依序處理野豬、守衛；保留蝙蝠、旅館、雷恩衣擺與莉雅重製等未完成事項，完整第一章目標持續。
