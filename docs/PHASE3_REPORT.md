# Phase 3 驗收紀錄

日期：2026-10-13，Asia/Taipei。結果：P3.1～P3.6 完成，P4 未開始。基線為本地提交 ef605af；本報告與 P3 實作一同保存於下一個本地提交。引擎：4.7.2.stable.official.ed1daf0bf；Windows Compatibility / OpenGL 3.3，NVIDIA GeForce RTX 3080，驅動日誌 617.42。

## 實作與可操作路線

Main 常駐 PartyManager／BattleFlow，戰鬥場景自行擁有 BattleManager／Stage／Interface。角色與技能採唯讀 Resource，角色／每隻敵人各自持有 HP／MP。B001／B002 使用原有 JSON：兩隻 Lv1 史萊姆／一隻 Lv3 腐化守衛。

Run 啟動後完成開場對話，從村莊右側入口進森林。演練補給箱一次給恢復藥 ×3；靠近「演練·森林史萊姆」或「挑戰·腐化守衛」按 E 開戰。先選指令再選目標，取消不耗回合；滑鼠或 Tab／方向鍵／Enter 操作。營地可補满 HP／MP，不補道具。村莊乾糧、森林演練補給、E005 預定礦坑藥品分屬不同來源。

勝利保留 HP／MP／消耗並返回原位置；敗北重試或撤退都回復進戰前角色／道具快照。重試保留遭遇票號、重建滿血敵人；不回退寶箱領取帳本。演練不發主線旗標、金幣或 EXP。

## 命令與結果

工作目錄 D:\RPGGAME。預期所有命令退出 0、無解析／載入／執行錯誤；行為測試失敗數為 0。以下實際均符合。

| 指令 | 實際結果 | 本機日誌（artifacts/logs/） |
| --- | --- | --- |
| `.\tools\godot.ps1 -Mode Check` | 資源匯入、腳本載入通過 | check-20261013-011504-702.log |
| `.\tools\godot.ps1 -Mode Smoke` | 主場景啟動／退出通過 | smoke-20261013-011814-511.log |
| `.\tools\godot.ps1 -Mode Test` | P1 24 項，failures=0 | test-20261013-011334-373.log |
| `.\tools\godot.ps1 -Mode TestPhase2` | P2 58 項，failures=0（初次整合回歸） | testphase2-20261012-201738-121.log |
| `.\tools\godot.ps1 -Mode VisualPhase2` | P2 66 項，failures=0，實際 Windows 渲染 | visualphase2-20261013-011406-687.log |
| `.\tools\godot.ps1 -Mode TestPhase3` | P3 75 項，failures=0 | testphase3-20261013-011648-219.log |
| `.\tools\godot.ps1 -Mode VisualPhase3` | P3 85 項，failures=0，實際 Windows 渲染 | visualphase3-20261013-011623-425.log |
| `.\tools\godot.ps1 -Mode PreviewBattle` | 停在首場演練，供下述原生操作 | previewbattle-20261013-011311-412.log |

圖形流程與無頭流程使用同一套正式管理器及場景，不使用替代勝利邏輯。測試會明確安排角色位置、部分 HP／MP 和事件前置旗標，並縮短動作間隔；這些僅存在 tests，不代表正常遊戲已解鎖後續故事。按鈕透過滑鼠事件點擊，部分邊界／連按／自動完整戰鬥直接呼叫正式 submit 入口。

覆蓋內容：資料型別／ID／敵人數量／等級驗證；速度與每輪行動；實際傷害與 MP 消耗；治療上限；藥品恰耗一個；防禦減半及到期；無 MP／無道具／錯誤或死亡目標／未學技能；過期 token／快速重複輸入；死亡跳過；全滅、重試和撤退快照；原探索位置與角色實例保留；只結算一次；快速動畫復位。

故事橋接獨立啟用 E004/E007，先設置 e003_done/e006_done 測試前置，再透過實際回合造成勝利或敗北。勝利結果頁確認返回後才經 FlagManager 寫 battle_b001_won/e004_done 或 battle_b002_won/e007_done；等待中的錯誤票號、錯誤 battle_id、敗北、重複回呼及重播均不提前完成。E008 未執行。莉雅治療／獨立 MP／死亡跳過在雙人測試 fixture 驗證，正式 Main 仍只有雷恩。

## 畫面與原生操作

P3 圖片在本機 artifacts/phase3：01-forest-entry、02-battle-commands、03-target-selection、04-victory、05-return-vitals、06-defeat、07-retry、08-guardian、09-guardian-victory、10-small-battle（皆 .webp）。已查看命令／目標／勝敗／返回／守衛／重試，1280×720 與 960×540 均可完整顯示主要指令及狀態。P2 圖形回歸另保存在 artifacts/phase2，已檢查新增角色狀態下的開場、森林及小視窗對話版面。

另使用 Windows 原生視窗工具操作 PreviewBattle：點「攻擊」、Enter 選首隻史萊姆，造成 21 傷害；兩敵回合後雷恩 HP 106。點星火並 Enter，MP 20→15、首敵死亡，雷恩 HP 99；第二次星火後 MP 10、最後敵人死亡。點返回探索後位於森林同一演練點，HUD 為 HP 99/120、MP 10/20、藥品 ×3。原生截圖保存在對話工具紀錄；功能流程另有上述可重建 .webp。

## 驗收中修正

1. 首輪無頭測試 25 個斷言失敗：未固定 Window.size，UI 座標落在不同的可視範圍，後續按鈕操作連鎖失敗。實際 Windows 圖形原先已通過。測試固定 1280×720 並先注入滑鼠移動，無頭流程通過；沒有改成直接發 pressed 偽造點擊成功。
2. 圖形檢查發現加速回合令未完成位移 Tween 疊加，角色逐步偏離站位。Stage 現在記錄固定原點、先終止舊位移再開始新動畫，新增完整快速戰鬥後的復位斷言；最終守衛勝利圖已確認兩邊站位正常。
3. 死亡狀態優先顯示「倒下」，名稱／HP 標籤不隨屍體傾斜；截圖等待數字動畫結束，修正後重新跑 P3 全流程。

## 範圍及未驗證事項

- P3 是可操作戰鬥核心，尚非 20～30 分鐘完整序章。主線默认僅 E001/E002，E003 入隊及 E001→E004 整合留 P4，礦坑與完整 E007/E008 留 P5。
- 戰鬥結果目前只有獎勵預覽資料；沒有金幣／EXP 發放、等級成長、裝備、完整背包選單或保存／讀取。未建立保存格式，沒有格式遷移問題。
- 隊伍容器接受至多三人；本輪單人實際畫面及雙人核心行為已驗證，三人完整 UI／容量邊界留 P4，未宣稱完成。
- 目前兩種配置皆不允許戰鬥中逃跑；「撤退」僅出现在敗北頁。數值為原型，平衡／遊玩時長／正式模型動畫音效／手把／Windows 匯出與跨機字型待後续階段。
- 本地 artifacts、日誌與 Godot 快取由 Git 忽略，不隨提交保存；本報告與可重現測試脚本隨版本庫保存。未安裝外掛，未下載／購買素材，未推送遠端。

下一步：P4 隊伍與養成，從 E003 莉雅一次入隊與隊伍狀態驗收開始，延續本輪唯一狀態擁有者及單次結算入口。
