# G08.3 RC3 名牌、招募外觀與長測

## 2026-10-21 人工回報更新

使用者已確認修復後RC3「可以正常進入並保持開啟」，並就序章教學戰、Boss、回村交付、商店／旅館、存檔重啟回報「鍵鼠與 Xbox 全部通過」。此為使用者實體操作回報，綁定固定PCK2758b063與launcher-fix ZIP，不轉用較新的走跑或A04來源包；手動失敗重試未在該問句中明列。見[原始回覆與雜湊](../source_assets/rc3_launcher_20261021/human_acceptance.json)。下方保留先前驗收歷史，整體G08仍受原有尖峰等Gate限制。

2026-10-20，Windows／Godot 4.7.2。**原生 Release 自動長測、重啟及包對照已通過；實體 RC3 操作與啟動深入診斷仍待，整體 G08 未完成。** Android／iOS 暫停，完整 A01～A05、雷恩／莉雅新模型、環境物品及 C1 目標未縮減。

## 已重現並修正

1. 孢子菇靈使用 SLIME 的 1.65m 名牌基準，完整字形投影與模型上緣相交約 63px；G06 工具列也留在戰鬥中。先保存圖形重現：22 項／13 失敗。加入可選的 `Marker3D nameplate_anchor`，由該角色 PackedScene 指定 3m 錨點；其他角色保留既有基準。工具列隨既有 BattleFlow.active_changed 隱藏／恢復，沒有改 InputMap 或戰鬥控制器。
2. 首輪名牌圖形測試雖 105／0，但實際畫面發現剛招募莉雅仍是舊外觀。補重現後 42 項／1 失敗：PartyManager 的 recruit_definitions 沒有採用整合入口設定的 Pixal3D 外觀，SaveCodec 則使用新版 catalog。整合入口現在複製既有招募定義，只換 appearance；**19 個其餘腳本欄位逐項與原 Lia 定義相同**。沒有改 ID、數值、技能、旗標、獎勵或 Schema。
3. Release QA 現在對每個實際出戰的隊員檢查模型路徑，不再只在「有 skeleton 屬性時」才檢查骨數而略過舊外觀。G08 三個 feature override 提升 `0.6.1-g08-rc3`；基礎版本、正式入口及歷史 RC2 產物保留。

## 已完成的檢查

- `tools/godot.ps1 -Mode Check`：PASS。
- `-Mode VisualBattleNameplates`：**125／0**；實際 X001～X004、B001、B002 演練、返回與工具列恢復。菇靈 12 個待機採樣的字形與模型投影淨空約 12px；六張實際畫面已查看。兩個主線遭遇在此以 practice 模式運行，不以此取代真主線／礦坑背景驗收。
- `tools/audit_g083_detail.py`：11／0；`tests/test_g083_detail_contract.py`：3 tests PASS；計時子類別與目前正式方法保持等價。
- `tools/test_g06.ps1`：**16 模式／576 斷言／0 失敗**，含圖形故事、觸控及觸控交易；觸控為桌面注入，並非 Android。
- 既有正式 GLB 重讀：雷恩 4815、莉雅 4806 triangles；各 19 骨／七片段。檔案未改；這不是使用者要求的重製完成，也沒有因此啟用貼地原型。
- 第一份新測試曾因 conditional typed Array 指派而停止，該程序已明確停止並保存日誌；修正測試宣告後才取得上列重現／通過結果，不把該失敗視為遊戲崩潰。

證據見 [本輪來源](../source_assets/g083_rc3_20261020/)；原始 1280×720 截圖及失敗日誌另保留 `artifacts/g083_rc3_raw_20261020/`。字形投影／包圍盒為保守淨空檢查，仍搭配實際畫面；未用關閉深度測試掩蓋布局問題。API 依據：[Label3D](https://docs.godotengine.org/en/4.7/classes/class_label3d.html)、[VisualInstance3D bounds](https://docs.godotengine.org/en/4.7/classes/class_visualinstance3d.html#class-visualinstance3d-method-get-aabb)。

## 固定版本與目前長測

隔離工作樹 `C:/Users/yume4/.codex/worktrees/g083-release-probe/RPGGAME`；分支 `codex/g083-nameplate`，固定提交 `d03db5fa5e77aeb4a8710cd7c441e1048e355bed`。修正已 cherry-pick 到 `feature/greystone-g06` 的 `b609554edab7067e12943b7b2e1c2cfa1e7d4f44`，檔案內容相同；不合併 main。

- QA：`builds/g08/qa-soak/20261020-215826/ProjectCrystal.exe`；PCK `0DC10AC1524728EA687C2A41A3774D281A90E437E56EFBF5BDB44FF01001E6CA`。
- 可玩 RC3：`builds/g08/candidate/20261020-215831/ProjectCrystal.exe`；PCK `2758B063385A25E724B13A546CFF9585F65557DAFED2989EBAD005BAF276D13C`。
- 長測：`tools/test_windows_release_stability.ps1 -QaExe <上列QA> -Mode Soak`，本機證據 `artifacts/g083/20261020-215912/`。單一原生圖形程序 PID 28500 已正常結束，exit0；終態 manifest／完整 metrics 與獨立 OS 取樣已保存。
- 初始另開的 Blender／Python 觀測窗口約 30.6s：Blender CPU 增量 0.172s，多個 Python 為 0～0.047s；當時 GPU 37～42%、VRAM 約 2.26GiB，包含遊戲。沒有以程序存在就認定正在生成，也沒有關閉使用者程式。這只是背景取樣，不能當作所有時間無外部負載的保證。

長測含自動序章、三圖探索、服務、戰鬥、返回、保存／讀取與輸入追蹤；完整幀統計保留截圖／WebP 編碼成本，另存 capture intervals 以便歸因。引擎 Release 靜態記憶體 0 仍視不可用。跨程序重啟及共用 PCK 核對已完成，結果如下；更新後可玩 RC3 的實體輸入仍待，舊 RC2 使用者回報不自動轉用新版本。

## 已完成的完整長測

終態來源為隔離工作樹 `artifacts/g083/20261020-215912/manifest.json`；可提交資料見 [soak 證據](../source_assets/g083_rc3_20261020/soak/)。原始完整日誌／隔離存檔另保存 `artifacts/g083_rc3_full_20261020/`，不納入 Git。

- **Soak 1810.753341 秒（30分10.753秒）**；含序章的取樣時間 1829.629405 秒、程序牆鐘 1831.720330 秒；1459 checks／0 failures／exit0。
- 27 輪、81 次切圖、54 場可選戰鬥、162 次存讀檔驗證；先實際自動通關一次序章，循環不重複給獎。
- 109564 個幀樣本全部計入，總平均 **59.884 FPS／16.699ms**。P95／P99 按 phase 原始樣本計算，不能將各 phase 百分位再平均成全域百分位。

| 取樣 phase | FPS | 平均 ms | P95 ms | P99 ms | 最大 ms | Draw Calls |
|---|---:|---:|---:|---:|---:|---|
| 序章／初始化 | 55.21 | 18.112 | 17.182 | 66.842 | 461.173 | 0–625 |
| 灰石村／存讀檔 | 60.00 | 16.666 | 16.749 | 16.869 | 20.947 | 99–194 |
| 森林／存讀檔 | 60.00 | 16.666 | 16.775 | 16.964 | 19.866 | 364–447 |
| 礦坑／存讀檔 | 60.00 | 16.666 | 16.750 | 16.891 | 20.204 | 176–206 |
| NPC／交易 | 59.00 | 16.950 | 17.208 | 26.396 | 126.265 | 99–358 |
| 戰鬥／返回 | 58.58 | 17.071 | 16.789 | 19.036 | 193.868 | 119–373 |
| 切圖 | 60.00 | 16.667 | 16.766 | 16.876 | 21.199 | 99–441 |

Phase 是 process_frame 時的測試標籤，**邊界幀的工作可能記入下一個 phase**。例如 mine 截圖編碼可出現在 battle 標籤；上述數據不是每種純渲染函式的專屬成本。完整統計沒有移除截圖長幀，歸因使用另存的 capture intervals。

轉場平均 328.844ms、P99／最大 332.258ms，包含 320ms 設計淡入淡出；存檔驗證＋套用平均 364.868ms、P99 367.027ms、最大 367.321ms。戰鬥 launch→可操作平均 558.274ms、最大 1133.079ms，包含先手動作，不能當作 arena CPU 建立時間；字型建立約27→6ms的對照見前輪分段報告。

Working Set 每秒取樣峰值 658.906MiB、OS PeakWorkingSet 671.969MiB；Private Bytes 峰值 847.918MiB。程序 120–300s／1500–1800s 窗口中位數：Working Set 646.559／645.684MiB、Private Bytes 811.781／812.855MiB。三圖節點／物件固定為 1100／4159、833／3913、470／3614；這些取樣沒有逐輪累積，**不等於已證明全引擎無洩漏**。Release 靜態記憶體／孤兒節點監測仍不可用，不把 raw 0 當作0 bytes或零孤兒證明。

## 尖峰與未解釋部分

本輪34個超33.333ms幀均保存，未達300筆上限；28個與實際截圖區間重疊，WebP encode/write 28.833–175.902ms。無截圖重疊的六幀為啟動前四幀461.173／96.108／53.063／39.078ms，以及序章中的46.310／41.737ms。這是時間區間歸因，不是 CPU／GPU 函式採樣。

啟動首幀仍待深入定位；未宣稱已根治歷史664ms／秒級冷啟動。歷史826秒不明切圖在本輪受控輸入的30分鐘內沒有重現，但不能由此斷言原因是外部輸入或宣稱已修復未知切圖bug。

## 包、遷移與跨程序讀取

- RC3 可玩包原生啟動／正常退出：PASS。短版 Release QA 完整序章、交易、v1遷移保留原檔：114／0；另一程序重啟14／0。
- 另以新隔離 profile、另一個原生 Release 程序讀取**長測末檔的精確副本**：14／0、原檔 SHA 及內容未改。實際存檔在 g08_tests/prologue.json；先前測試初始化設定的 g083/soak.json 被父類_run覆蓋，準備讀檔時曾因推測路徑失敗，改按實際 Schema 盤點唯一存檔，未重跑或修改長測。
- 可玩包702項、短版／長測QA各844項；兩次盤點均有 **698個共用遊戲資源hash一致**，0 mismatch、0禁止來源／根目錄參考圖。主迴圈與QA額外測試明確分開，不把短版包當成實際長測包。
- 固定 RC3 已複製到 `builds/g08/rc3-20261020/`；可玩檔為 candidate/ProjectCrystal.exe。`start_rc3.cmd`／play_rc3.ps1 使用 user_test 隔離存檔，入口Smoke實際通過；ZIP及SHA逐檔驗證，不包含本機存檔。

使用者於2026-10-21回報RC3「開了就跳出」；已重現Windows PowerShell執行原則阻止啟動器，改直接CMD啟動且一般圖形／可攜解壓啟動通過。見[修復報告](G083_RC3_LAUNCHER_REPORT.md)。修正後重試及完整鍵鼠／Xbox驗收仍待，不能把自動啟動當作人工通關。這不是技能額外要求批准，而是使用者總計畫G08.3的實體輸入門檻。等待期間繼續可獨立的A04素材整合；正式v0.6.1／main／存檔契約保留，不提前將G08或C1標記完成。

本輪長測固定於 d03db5f；後續主工作樹準備的 A04 菇靈不在此 RC3 PCK 內，其動作與正式戰鬥要單獨驗收，不能沿用本輪成績。
