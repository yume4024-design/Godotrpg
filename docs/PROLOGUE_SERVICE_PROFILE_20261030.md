# 序章服務操作分階段 Release 量測 — 2026-10-30

在來源 `bd9948532b2dee14bb52f1bf6985ed335884a099` 的隔離快照中，以工具明確覆蓋 `tests/prologue_performance_probe.gd` 的診斷版本；覆蓋檔與原始方法的雜湊記於[收據](evidence/prologue_service_profile_20261030/build_receipt.json)。Godot 4.7.2、Windows 原生 Release、RTX 3080、Compatibility、1280×720、60 FPS 上限。沒有改動遊戲 runtime、正式 v0.6.1 或固定 RC4。

將三輪 NPC／交易測試分成公會、道具店、旅館的開啟、確認與對話，以及最後的交易前存檔恢復。自動比較測試方法，移除階段標記後與原有操作完全一致；既有商店扣款／物品數、旅館扣款／恢復、故事旗標與獎勵檢查仍保留。**169／0，52.274 秒**。時間是幀牆鐘間隔，非 GPU 計時；標籤在測試流程切換處設定，不是精確到函式的同幀分析。

| 階段 | 幀數 | 平均 ms | 最大 ms |
| --- | ---: | ---: | ---: |
| 公會開啟 | 30 | 16.656 | 17.393 |
| 公會對話 | 12 | 16.886 | 17.441 |
| 道具店開啟 | 30 | 16.583 | 18.303 |
| 道具店確認 | 6 | 17.062 | 17.358 |
| 道具店對話 | 18 | 16.574 | 17.834 |
| 旅館開啟 | 30 | 16.635 | 17.589 |
| 旅館確認 | 6 | 17.868 | 19.476 |
| 旅館對話 | 18 | 16.321 | 18.102 |
| 交易測試後讀檔恢復 | 107 | 17.739 | 73.342 |

本次服務階段大於33 ms的三幀均標在 **service_restore**：73.340、71.538、73.102 ms。此階段讀回測試前的隔離存檔並重新載入村莊；三次村莊 ready 耗時分別 33.528、33.260、34.474 ms。這些資料支持「此次測試的服務階段尖峰位於讀檔恢復」；**沒有逐幀因果關聯，不可把全部 71–73 ms 都歸因於 ready，也不能把自動測試最後的讀檔當成玩家每次購物必定觸發。**

商店／旅館確認各只有6幀，不能視為所有交易狀況已達60 FPS，也不能否定先前30分鐘引擎診斷約223 ms尖峰。下一步需要對存檔恢復與場景重建做同幀追蹤，或設計安全的同地圖恢復方案及完整狀態／NPC回歸後再做前後比較。

[全部指標](evidence/prologue_service_profile_20261030/report.json)、[包與檔案雜湊](evidence/prologue_service_profile_20261030/build_receipt.json)、[測試末畫面](evidence/prologue_service_profile_20261030/final.webp)。隔離包與測試存檔位於 `builds/prologue-profile-20261030/service-trace-bd99485/`，不提交。尚未重新匯出玩家候選版；人工最終驗收、Android／iOS及第一章暫停。莉雅候選拓樸與貼圖仍待修整。

重現：

```powershell
python tools/profile_prologue_release.py --output builds/prologue-profile-20261030/service-trace-repeat
./tools/run_prologue_profile.ps1 -Build builds/prologue-profile-20261030/service-trace-repeat
```

工具使用當前 HEAD 與工作目錄的 probe/trace 覆蓋；HEAD 改變會改變基線。輸出目錄必須不存在。該流程是短圖形自動測試，不是30分鐘長測或人工輸入驗收。
