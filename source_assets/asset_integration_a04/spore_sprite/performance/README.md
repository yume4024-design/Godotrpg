# 菇靈 A04 原生 Release 效能與呈現

Godot 4.7.2、Windows Compatibility、RTX 3080、1280×720、60 FPS cap。固定來源 `0db9518b11a602056e1f3db02267b572d73fe9a3`，PCK `060901AE5AA6B49583BA3B689198ACBA46D408CDFF9F285EB8AE79AF0EF28347`。原生程式約 32.461 秒；每案例暖機60幀＋量測600幀。不是30分鐘耐久、實體輸入或手機驗收。

| 完整菇靈數 | 敵人面數 | FPS | 平均ms | P95ms | P99ms | 最大ms | Draw Calls | 真實行動 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 9811 | 60.003 | 16.666 | 16.687 | 16.712 | 17.033 | 302–321 | 13 |
| 3 | 29433 | 60.003 | 16.666 | 16.674 | 16.690 | 16.720 | 310–329 | 11 |

Production BattleArena／正常敵人AI／合法防禦指令；沒有移除量測長幀，捕圖在取樣後。固定幀率不能表示硬體滿載上限。全程序30筆每秒記憶體取樣：WS峰值 323.215 MiB、Private峰值 526.055 MiB、OS PeakWS 416.383 MiB。Release引擎靜態監視器不可用，保留null；Debug數值另存，沒有代填。無長期洩漏結論。

第一次原生Release效能36／0，但實際三敵畫面有UI遮擋，因此不能把它當完整呈現PASS。新增投影／實際Panel邊界檢查，Debug重現39／2（failed_presentation_metrics.json）；保留原release_*.webp與metrics。只對三敵改斜列站位，不動既有單敵／雙敵、鏡頭、模型比例、數值與規則。修正後Debug39／0、固定新Release40／0。fixed_release_spore_1／3.webp已實際檢視，完整角色與名牌均在上下Panel間；這只涵蓋本鏡頭／本模型組合。

同來源另重新匯出原生候選與QA：啟動正常、完整序章／交易／v1遷移114／0、另一程序讀檔14／0。full_release_regression.json保留新產物路徑；它們不是已封存RC3長測包，不沿用RC3人工或30分鐘成績。未改存檔Schema、收據、技能、旗標或正式v0.6.1入口。

另先以實際-Describe重現 TestEnemyController／TestBattleNameplates 被錯路由到匯出，修正後真正無頭55／0與122／0；Visual和既有匯出不受此路由錯誤影響。Python三組／八模式檢查PASS。完整原始log與隔離profile保留於artifacts，不提交本機存檔、EXE／PCK或大型暫存。
