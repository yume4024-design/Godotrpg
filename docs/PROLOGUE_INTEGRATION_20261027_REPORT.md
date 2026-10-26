# Project Crystal 完整序章整合候選 — 2026-10-27

> **同日重新審核更正：** 此候選實際繼承舊 Blender 灰石村 layout 3，沒有接入 reference_v5 村莊／layout 4及新鏡頭；「最新版全部整合」不成立。既有故事回歸只證明所載入版本的功能。RC1 也不含其後新增小地圖。詳見 [PROJECT_REAUDIT_20261027.md](PROJECT_REAUDIT_20261027.md)，本輪沒有更改入口或覆蓋 RC1。

## 結果

在 `feature/greystone-g06` 目前工作樹建立可啟動的整合入口：`scenes/main/prologue_candidate.tscn`。它串接現有 G06 RPG 系統、Blender 灰石村、擴展低語森林、最新版礦坑場景及礦坑戰鬥場，並使用獨立候選存檔槽 `user://crystal_prologue_candidate_20261027_slot_01.json`。

入口採用已具備探索、戰鬥、裝備與存讀檔驗收的新雷恩 `scenes/characters/ren_rebuilt_visual.tscn`。莉雅仍使用 `scenes/characters/lia_pixal_visual.tscn`，因她的較新重製目前只有靜態模型，沒有可玩的骨架／動作與完整遊戲回歸。村莊 NPC 保持原 ID、對話及互動邏輯；女性村民仍是候選，沒有新增 NPC ID。

正式 `scenes/main/main.tscn`、v0.6.1 入口、原存檔與 SaveCodec、角色數值、旗標、任務及獎勵規則均未修改。這是功能分支上的遊玩候選，不是正式發行版，也不表示人工美術驗收已通過。

## 完整序章內容

- E001：灰石村旅館醒來。
- E002–E003：公會接取委託，莉雅加入隊伍，重複招募受阻。
- 灰石村西出口進入低語森林；森林教學戰勝利後才開放礦坑。
- 礦坑入口、可走主路／橋路、E005 補給、E006 水晶動畫、E007 守衛 Boss 勝利與回村路線。
- E008 公會交付與第一章解鎖；E009 離村調查收尾。
- 道具商店、旅館恢復、交易存檔、單次獎勵及遊戲重啟讀檔維持既有管理器與資料契約。

測試中的地圖轉移使用真實互動／事件／戰鬥流程；自動化故事測試會把角色放到指定的測試檢查點，因此不等同人工連續走完整張地圖。

## 實際檢查

引擎：Godot `4.7.2.stable.official.ed1daf0bf`，Windows NVIDIA GeForce RTX 3080／Compatibility renderer。

| 命令 | 實際結果 |
|---|---|
| `.\tools\godot.ps1 -Mode Check` | PASS；新序章入口及資源載入檢查完成 |
| `.\tools\godot.ps1 -Mode TestMineReferenceStory` | **65 checks／0 failures**；完整 E001–E009、森林教學戰、礦坑 Boss、回村、單次獎勵、角色與四種 NPC 場景引用及候選存檔流程 |
| `.\tools\godot.ps1 -Mode TestMineReferenceStoryReload` | **14／0**；另一程序續讀、隊伍、裝備、旗標、任務、獎勵帳本與 NPC／角色整合保持 |
| `.\tools\godot.ps1 -Mode TestMineReference` | **63／0**；礦坑主路、中央交叉橋、北線往返、落地與地下水淨空；日誌 `testminereference-20261027-003833-932.log` |
| `.\tools\godot.ps1 -Mode TestBlenderCommerce` | **50／0**；商人、旅館、價格／金幣、交易重入、道具及嚴格存檔驗證 |
| `.\tools\godot.ps1 -Mode TestBlenderCommerceReload` | **5／0**；新程序恢復交易與全隊住宿效果 |
| `.\tools\godot.ps1 -Mode RunPrologueCandidate` | 圖形啟動達 NVIDIA Compatibility renderer，未觀察到啟動錯誤；為維持無人值守驗收，啟動後即關閉，未進行人工操作 |

主要新日誌：`artifacts/logs/testminereferencestory-20261027-005548-074.log`、`testminereferencestoryreload-20261027-005620-841.log`、`testblendercommerce-20261027-005229-862.log`、`testblendercommercereload-20261027-005256-634.log` 及 `check-20261027-005312-173.log`。

## Windows RC1 包內驗收補充

前述「沒有匯出」的狀態已由本節更新；本輪現已建立並檢驗獨立候選包，不是正式發行版。

- ZIP：builds/prologue-candidate/rc1-20261027/ProjectCrystal-0.6.1-prologue-rc1-20261027-windows-x64.zip
- ZIP SHA-256：D7562C97564FC39E74C1CE9C9B42E069C6B5E6B1B27E1AF12B49261E82B166D6
- EXE SHA-256：D34D36F3BE1A6C49C56525AE86469B92E4F417DDF0B43CF00DD80C385C4B0562
- PCK SHA-256：9901F3E50CAADCB8195F49BE098F19B13FECAEFC2DB713758BDDAA287B4A2E9F
- 包內圖形啟動 120 幀後正常退出；匯出 QA PCK 完整序章 75／0，獨立新程序重啟讀檔 14／0。ZIP 解壓後五個檔案均非空，EXE/PCK 雜湊與 manifest 相符。
- Codex profile 沒有 Godot 4.7.2 匯出模板；PCK 由本輪 Godot 4.7.2 匯出，EXE 使用已核實同版本的既有 RC2 runtime。未宣稱 EXE 是本輪由匯出模板重產。
- 這些是圖形模式自動測試，並非人工操作或 30 分鐘穩定性驗收。
- 本輪候選包設定與流程涉及 project.godot、export_presets.cfg、tools/godot.ps1；候選入口及包內 QA 使用 scenes/main/prologue_candidate.tscn、tests/prologue_candidate_test_tree.gd 與 tests/mine_reference_story_test.gd。

## 留待後續

- 人工操作／美術驗證仍依使用者指示暫停；不宣稱鍵鼠／Xbox 人工通關、美術接受、30 分鐘長測或 G07.5/G08 通過。Windows RC1 候選包已另外匯出並通過自動化包內測試；正式固定包未覆蓋。
- 新莉雅模型仍是靜態候選，未替換有完整動畫與戰鬥驗收的莉雅。
- 女村民尚未加入；旅館老闆模型仍有既有人工視覺缺陷紀錄。本輪故事／交易測試驗證功能，不代表這些模型已通過美術審核。
- 已確認灰石村、森林、礦坑及返回村莊的場景轉移；沒有以自動化檢查冒稱完整人工徒步全程。
- Android／iOS與第一章仍暫停。

## 修改檔案與 Git

- 新增 `scenes/main/prologue_candidate.tscn`。
- 更新 `tools/godot.ps1`，新增 `RunPrologueCandidate`。
- 更新 `tests/mine_reference_story_test.gd`，直接驗收新入口及雷恩／莉雅外觀注入。
- 更新 `docs/TASKS.md`、`docs/GREYSTONE_BUILD_TASKS.md`、`docs/CHANGELOG.md`。

本輪開始時分支 HEAD 為 `4ba2b2c88ec1b7a1296cb520f47953cffcbb3d99`。工作樹已有大量使用者未提交的場景、角色與礦坑修改；本輪未清理、提交或推送這些變更。因此此 HEAD 是基線 SHA，不是本輪提交 SHA；沒有建立新 commit。
