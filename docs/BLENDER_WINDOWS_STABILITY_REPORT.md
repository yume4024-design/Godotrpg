# 灰石村 Blender RC1 — Windows 圖形長測

2026-10-24，`feature/greystone-g06`。自動圖形長測與另一程序續讀已通過；人工驗證依使用者最新指示暫停。

## 固定測試對象

可玩包仍為 `builds/greystone-blender/rc1-63d05f5/candidate/`，版本 `0.6.1-greystone-blender-rc1`，遊戲來源 `63d05f5c13c09531ba7a773b253e449828218e3a`。
本輪 QA 來源 `9eb437a9ecebb62be67e532656c0d772a3faa704`，產物在 `builds/greystone-blender/soak-9eb437a/qa-soak/`。
正式 v0.6.1、舊 RC4、可玩 RC1 EXE/PCK/ZIP 不重新匯出；未改角色、數值、故事、交易、獎勵或存檔 Schema。

新工作樹的原始匯出與固定包有二進位匯入差異，不能直接視為相同遊戲資源。
因此保留 raw-export PCK，透過 `tools/freeze_windows_qa_runtime.gd` 將固定可玩包的 **935 份 runtime entries** 原樣放入獨立 QA PCK；其餘為本輪匯出的 QA 腳本、類別索引及 feature 啟動設定。
這是明確記錄的 QA 封裝方式，沒有改寫可玩包；再次稽核為 **939 / 1131 entries、935 份 runtime SHA 全相同、0 禁入檔案或資源差異**。

## 執行方法

- Godot 4.7.2.stable.official.ed1daf0bf，Windows x86_64 release template，原生圖形模式，1280×720，高畫質，60 FPS 上限、VSync 關閉。
- 先跑既有序章主線戰鬥與回村交付，再開始至少 1800 秒 soak。每輪灰石村／森林／礦坑，20 秒 InputMap 左右移動、停止、碰撞、保存與嚴格讀回。
- 灰石村輪流廣場、木橋水景、碼頭；透過現有 travel 入口切圖，路段開始時定位。不是無瞬移走遍地圖，也不是人工持續操作。
- 公會對話、商人購藥、旅館扣款及全隊恢復，森林／礦坑 X001／X003 真實戰鬥命令與返回，持續檢查唯一星印與 E008 收據。交易／可選戰鬥後讀回有效基線以免測試資源耗盡。
- 使用獨立 profile 的 `user://g08_tests/prologue.json`；QA 隔離其他實體輸入，可玩包不隔離。另一程序用 `--reload --probe-loads` 延續同一份實際存檔，不能以重播序章代替重啟讀取。
- CPU 主迴圈逐幀間隔包含 60 FPS 等待、存讀、截圖、CSV／報表成本；不是 GPU timestamps。Draw Calls 為整幀引擎計數。每秒取樣 Windows WorkingSet／Private Bytes／PeakWorkingSet。Release 引擎 MEMORY_STATIC 不可用時記 null，不能解讀成零配置或無洩漏。

## 實際結果

原生圖形長測 PID2948，Soak **1812.205秒（30分12.205秒）**，含序章主迴圈1847.873秒、程序1850.710秒。**1548／0，exit0**；27輪、81次切圖、54場可選戰鬥、27次商店與27次旅館、162次存檔讀回。日誌無SCRIPT ERROR／ERROR／WARNING。短測另208／0，不混算為長測。

另一程序PID12940，21.069秒，使用**原長測QA PCK**及相同profile，以`--reload --probe-loads`實際續讀，**97／0，exit0**。原長測存檔、metrics及逐幀CSV的前後SHA全部一致；續讀沒有重播序章或改寫來源。保留212金幣、300EXP、雙人隊伍、裝備、單一星印、E008收據及已完成任務。

| 區段 | 幀 | FPS | 平均ms | P95ms | P99ms | 最大ms | Draw Calls |
|---|---:|---:|---:|---:|---:|---:|---|
| battle | 3884 | 58.506 | 17.092 | 16.833 | 19.183 | 188.382 | 103–370 |
| forest | 33750 | 60.002 | 16.666 | 16.781 | 16.978 | 19.945 | 368–429 |
| greystone_runtime | 33693 | 59.955 | 16.679 | 16.766 | 16.929 | 66.406 | 242–656 |
| mine | 33690 | 60.003 | 16.666 | 16.768 | 16.944 | 22.712 | 176–191 |
| npc_commerce | 1882 | 57.419 | 17.416 | 17.319 | 48.800 | 229.665 | 305–619 |
| prologue | 1063 | 29.806 | 33.550 | 17.451 | 180.201 | 6853.176 | 0–639 |
| transition | 1622 | 59.864 | 16.705 | 17.926 | 34.732 | 51.025 | 41–654 |

81次切圖含淡入淡出：平均320.627ms、P95 336.298ms、P99／最大340.229ms。存讀驗證與套入平均362.182ms、最大394.654ms；戰鬥發起至首個可操作平均559.302ms、最大1133.140ms，包含既有行動順序等待，不等同純場景實例化。

程序工作集取樣峰870.918MiB，Windows累積PeakWorkingSet峰893.965MiB，Private Bytes峰2962.266MiB。去除首60秒及末5秒後，首／末各60筆平均：工作集846.864／631.231MiB；Private Bytes2923.866／2920.209MiB。工作集下降可能包含OS裁剪，不能解釋為等量遊戲主動釋放。

各地圖27個檢查點固定：村莊3477nodes／10066objects，森林833／6090，礦坑475／5735。Release引擎配置與orphan監測不可用，記null，不能宣稱零orphan或無記憶體洩漏。Godot視訊記憶體計數峰1673728851bytes，為引擎估算口徑，非驅動總VRAM。

保存109584個逐幀CSV樣本及無損gzip，解壓SHA驗證通過。表格採父類取樣統計；CSV在同一回呼稍早擷取時鐘，存在數微秒回呼成本差異，不能假稱兩者每個值完全相同。全CSV含173個>33.333ms樣本，未以JSON最多300條尖峰清單代替完整逐幀證據。

## 問題及限制

- 最慢6853.176ms在初始化／序章；loading_resources→waiting_map階段約6847ms，含同步資源載入及建立世界。其餘初始化尖峰、交易最大229.665ms、戰鬥188.382ms、探索村莊66.406ms仍在。這是穩定運行通過，**不是每幀60FPS或尖峰已解決**；CPU階段計時未分離GPU／磁碟／shader編譯，不能確證細項根因。
- 舊長測工具在讀檔後立即截圖，有一物理幀鏡頭尚在出生點的時序問題；這些圖不作木橋／碼頭構圖合格證據。source修正等兩個物理幀；新探針工作樹匯入曾出現inn圖片checksum錯誤，該未匯出包未列入通過結果。此次97／0續讀用原長測QA，沒有把未驗證探針冒充通過。
- QA源與可玩包共935份runtime bytes相同；QA的封裝順序、啟動設定和診斷腳本不同。初始化時間不等同原可玩PCK的磁碟冷啟動基準。單台Windows RTX3080、原生圖形自動InputMap，不是人工30分鐘實測、其他PC或Android驗收。
- 使用者已回覆此固定包「尚未測試」，隨後要求**暫停人工驗證**。鍵鼠／Xbox與G08人工總Gate保持暫停；不追問確認，不宣稱通過。Android／iOS及第一章未開發。

## 證據

測試原始日誌、profiles與本機存檔留在`artifacts/blender_windows_stability/`，不提交。可攜量測資料：[windows_soak_acceptance](../source_assets/greystone_blender_20261023/windows_soak_acceptance/summary.json)，含metrics、兩程序manifest、process.csv、frames.csv.gz、解壓SHA及935份runtime稽核。QA PCK SHA `b6fd539383c5e5fdc2ffd0d2e5fe41429342e365d490599ee749fbdf55c13e28`；可玩PCK前後均`1a7448b726327c0553510db30fba4a84c5a72143709a198235ed998ff59d19f8`。

## 重現指令

```powershell
./tools/test_blender_windows_stability.ps1 -QaExe D:/RPGGAME/builds/greystone-blender/soak-9eb437a/qa-soak/ProjectCrystal.exe -Mode Short
./tools/test_blender_windows_stability.ps1 -QaExe D:/RPGGAME/builds/greystone-blender/soak-9eb437a/qa-soak/ProjectCrystal.exe -Mode Soak
./tools/test_blender_windows_stability.ps1 -QaExe D:/RPGGAME/builds/greystone-blender/soak-9eb437a/qa-soak/ProjectCrystal.exe -Mode Restart -ExistingEvidenceRoot D:/RPGGAME/artifacts/blender_windows_stability/20261024-011344-soak
```

Restart 只接受已通過的 Soak manifest，復用其 profile；前後確認存檔、完整 metrics 與 raw CSV SHA 不變。
舊 `test_windows_release_stability.ps1` 的預設行為保留，新 wrapper 負責正確的新版 layout 3、完整時長 Gate 及真正續讀。
