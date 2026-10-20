# G08.3 RC3 名牌、招募外觀與長測

2026-10-20，Windows／Godot 4.7.2。**進行中；不能以已完成短測冒稱 30 分鐘或完整 G08 通過。** Android／iOS 暫停，完整 A01～A05、雷恩／莉雅新模型、環境物品及 C1 目標未縮減。

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
- 長測：`tools/test_windows_release_stability.ps1 -QaExe <上列QA> -Mode Soak`，本機證據 `artifacts/g083/20261020-215912/`。單一原生圖形程序 PID 28500，目前仍在運行；最終結果須核對 terminal handle／manifest、退出碼與完整時長後補寫。
- 初始另開的 Blender／Python 觀測窗口約 30.6s：Blender CPU 增量 0.172s，多個 Python 為 0～0.047s；當時 GPU 37～42%、VRAM 約 2.26GiB，包含遊戲。沒有以程序存在就認定正在生成，也沒有關閉使用者程式。這只是背景取樣，不能當作所有時間無外部負載的保證。

長測含自動序章、三圖探索、服務、戰鬥、返回、保存／讀取與輸入追蹤；完整幀統計保留截圖／WebP 編碼成本，另存 capture intervals 以便歸因。引擎 Release 靜態記憶體 0 仍視不可用。尚須跨程序重啟、候選與 QA 共用 PCK 核對、更新後可玩 RC3 的實體輸入；舊 RC2 使用者回報不自動轉用新版本。

## 尚待結果

30 分鐘完整時長／崩潰／FPS／P95／P99／最慢幀、Draw Calls、記憶體、切圖／戰鬥／存讀檔統計仍待本輪 terminal 結果。啟動尖峰與歷史 826 秒不明切圖仍不能宣稱已根治；沒有提前標記 G08.3、G08.4／5 或第一章完成。
