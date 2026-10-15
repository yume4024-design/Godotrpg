# 技能與道具特效 — 2026-10-15

## 完成內容

- 普攻：金色命中環與放射光點。
- 星火：金色投射光球、命中環與爆散。
- 裂能衝擊：紫色投射與爆散。
- 療癒：青色上升光環與光點。
- 防禦：藍色護環。
- 恢復藥：綠色上升光點、光環及加號；探索選單另有「對象 · 道具」浮字，避免被選單遮住。

ActionEffect 使用程序生成的低面數網格，不下載外部素材、不新增貼圖／粒子外掛。每次最多12個小型 MeshInstance3D，關閉陰影與光照計算，約0.95秒清除。不是效能真機認證。

BattleManager 成功執行後新增 action_presented 訊號，保留既有 action_resolved 供數字、音效及其他邏輯使用。BattleStage 僅讀取行動ID和站位，取代舊單一光環。PartyActions 成功用藥後通知探索模型與選單，不在演出層修改HP、MP、物品或旗標。回合不等待特效，沒有改動傷害或存檔。

主要程式：scripts/battle/action_effect.gd、battle_manager.gd、battle_stage.gd；scripts/characters/party_actions.gd；scripts/core/exploration_game.gd；scripts/ui/party_menu.gd。測試：tests/action_effect_test.gd；工具新增 VisualActionEffects。

## 驗證

Godot 4.7.2，Windows Compatibility／RTX3080：

| 命令 tools/godot.ps1 -Mode | 實際結果 |
|---|---|
| Check | 載入通過，check-20261015-233642-897.log |
| VisualActionEffects | 26/26，visualactioneffects-20261015-233510-563.log |
| VisualPhase4 | 82/82，visualphase4-20261015-233615-724.log |
| TestEnemyAI | 10/10，testenemyai-20261015-233647-910.log |

六動作經實際技能／道具執行入口驗證行動ID、一個特效實例、自動清除；驗證藥品只消耗一次，滿HP拒絕使用且無演出。VisualPhase4實際操作背包用藥按鈕及裝備／戰鬥回歸。特效專用場景為隔離的指令測試，並非整段玩家通關。

已查看 artifacts/fx_*.webp 與 artifacts/phase4/07-inventory.webp：加號移到角色側面可辨識；背包浮字不蓋住操作按鈕；HP文字與人物輪廓可讀。視覺自評（每項0～2）：效果區域定位2、顏色辨識2、選單操作清晰2、治療與用藥形狀區分1（仍共享光環，藥品額外加號）。不宣稱完整美術品質認證。

移除舊_flash時曾遺留呼叫造成載入失敗與測試逾時，已移除並重跑以上檢查通過。恢復藥加號遮擋及探索選單遮住模型特效也已修正。

## 限制

Android真機、低階GPU效能尚未驗收；未新增技能或道具種類。探索隊伍仍用隊長代表，因此3D藥效出現在隊長，浮字顯示實際用藥角色。演出不控制結算時機，傷害數字可能先於投射光球到達出現；後續若改為命中時序需獨立驗證戰鬥流程。
