# 四視角女角製作與遊戲整合 — 2026-10-16

最新版本已改為 11 骨與五段可匯出動畫，見 [動畫報告](FEMALE_ANIMATION_REPORT.md)。下方七骨及程序動作描述為前兩輪歷史紀錄。

## 後續：基本戰鬥姿勢完成

新增 `scripts/characters/female_actor.gd`，沿用既有七骨外觀，對成功戰鬥事件播放療癒施法、普攻、防禦、用藥、受擊五種小幅姿勢。每次約 0.65 秒，結束恢復待機；倒下中止、死亡期間拒絕新動作，復活後可再次播放。BattleStage 使用既有 action_presented／action_resolved 訊號；動作不修改 HP、MP、物品、回合或存檔，也不延後戰鬥結算。舊角色外觀繼續使用既有演出。

這些為 Godot 程序骨架動作，尚未烘焙至 GLB；不代表已完成肘膝、手指或正式動畫片段。已查看五個實際戰鬥截圖，未見整體骨架崩解；目前鏡頭與小幅動作下可用，大幅或近距離變形仍待完整權重處理。

Godot 4.7.2／Windows：

- `./tools/godot.ps1 -Mode Check`：載入成功，`artifacts/logs/check-20261016-195620-618.log`。
- `./tools/godot.ps1 -Mode VisualFemaleAnimation`：24 項通過、0 失敗，`artifacts/logs/visualfemaleanimation-20261016-195626-065.log`。實際技能／道具提交、敵人傷害、拒絕操作、死亡／復活及待機恢復均驗證；截圖在 `artifacts/female_character/battle_*.webp`。
- `./tools/godot.ps1 -Mode VisualActionEffects`：26 項通過、0 失敗，`artifacts/logs/visualactioneffects-20261016-195634-547.log`。
- `./tools/godot.ps1 -Mode VisualG06Story`：68 項通過、0 失敗，`artifacts/logs/visualg06story-20261016-195642-407.log`。

下一個角色製作項目：完整肘膝骨架、關節權重與可匯出的施法／受擊動畫片段。Android 仍未驗收。

依使用者提供的正面、左側、背面、右側圖，建立金髮、藍眼、紫色冒險服女角，作為 G06 莉雅的新外觀。角色 ID、能力、技能、入隊時機、獎勵與存檔格式均沿用既有系統；舊版莉雅外觀及正式 v0.6.1 保留。

## 檔案

- `assets/models/female/lia_user.glb`：4,546 三角形、7 骨，204,348 bytes。
- `assets/models/female/report.json`：模型面數與骨架摘要。
- `assets/source/female/lia_user.blend`：可編輯的上色／骨架版本。
- `assets/source/female/references/`：使用者四面圖副本，原圖未修改。
- `assets/source/female/hy3d_workflow.json`：本次修正後的本機四視角流程。
- `scenes/characters/lia_user_visual.tscn`：重用既有骨架角色顯示腳本，提供待機和小幅行走。
- `scripts/tools/inspect_female.py`、`build_female_character.py`：Blender 獨立背景程序檢查、重建、配色、綁骨架與匯出。
- `tests/female_character_preview.gd`、`tools/godot.ps1 -Mode PreviewFemale`：四視圖、行走、骨架與新版 NPC 外觀引用檢查。

`greystone_integration.gd` 複製莉雅資料定義後替換戰鬥外觀；`greystone_npcs.tscn` 引用同一外觀並縮放 0.82。模型約 1.915m，NPC 約 1.57m；獨立碰撞仍由既有遊戲節點管理。探索使用隊長雷恩，莉雅依既有設計在村莊及入隊後的戰鬥出現。

## 生成與修整

本機 ComfyUI，RTX 3080 12GB；不使用付費／雲端生成。選用使用者現有 `HY3D_4Views_Ready_3080`，四圖各自輸入。原流程取樣模式 `img_to_img_velocity` 兩次未輸出網格；改成此機既有成功流程使用的 `flow` 後生成成功。有效工作 ID：`be525b0a-ac15-415d-8a6b-5410ed13ff0a`；seed 50、30 steps、CFG 1.5、guidance 3.5、3072 latent、256 decode、surface net 0.6。驗證工具確認 17 節點、無付費節點。

原始 GLB：`artifacts/female_character/generated.glb`，397,668 三角形；備份匯入場景：`artifacts/female_character/source.blend`。兩者保留本機，不作為遊戲執行資產。MODLY 健康端點回傳 404，因此本次使用已啟動的 ComfyUI。

Blender 5.2.2：0.008m 體素重建、簡化、柔和頂點配色、另建眼睛、淺色衣緣和金色腰扣。清除生成的地面碎片時，曾因先裁切原始非封閉網格導致重建破洞；已改為先體素重建，再裁切地面並封底。失敗產物未交付。最終檢查無退化面，保留邊界／接縫警告；不宣稱全封閉拓樸。

重製：將 references 的四圖上傳本機 ComfyUI input，以 hy3d_workflow.json 執行；複製輸出 GLB 為上述 generated.glb，再用 Blender `--background --factory-startup --python` 依序執行 inspect_female.py、build_female_character.py。使用獨立 Blender 程序，未改動使用者正在編輯的 Blender 場景。

## 實際驗證

Godot `4.7.2.stable.official.ed1daf0bf`，Windows／OpenGL Compatibility：

| 命令／檢查 | 結果 | 本機證據 |
| --- | --- | --- |
| `./tools/godot.ps1 -Mode Check` | 成功載入及匯入 | `artifacts/logs/check-20261016-170315-923.log` |
| `./tools/godot.ps1 -Mode PreviewFemale` | 0 失敗 | `artifacts/logs/previewfemale-20261016-170429-538.log` |
| `./tools/godot.ps1 -Mode VisualG06NPC` | 66 通過、0 失敗 | `artifacts/logs/visualg06npc-20261016-170322-599.log` |
| `./tools/godot.ps1 -Mode VisualG06Story` | 68 通過、0 失敗 | `artifacts/logs/visualg06story-20261016-170409-620.log` |
| `./tools/godot.ps1 -Mode TestG06` | 51 通過、0 失敗 | `artifacts/logs/testg06-20261016-170432-983.log` |
| ai-3d-agent check_export.py，`--budget 5000 --require-rig` | 通過；含 Blender 骨骼顯示輔助網格共 4,626 面，GLB 本身 4,546 面 | `artifacts/female_final_check_v2/report.json` |

已查看 `artifacts/female_character/godot_front.webp`、godot_side、godot_back、godot_walk，以及 `artifacts/phase5/g06-npc-npc_lia.webp` 的對話畫面和 `g063-04-guardian-battle.webp` 的戰鬥畫面。185 項既有回歸含實際輸入移動、互動／碰撞、莉雅單次加入、戰鬥往返、獎勵防重與舊存檔遷移。

## 目前限制

這是可用的基本角色版本，保留四圖的主要輪廓與配色，並非逐個細節還原。面部、手指、衣緣與小配件較簡化；身體以頂點色呈現，未建立 UV 貼圖。七骨區域權重只適合小幅動作，尚無獨立肘膝、臉部骨架或完整施法／受擊動作庫；戰鬥沿用既有位移與特效。大幅動作需人工拓樸與權重修整。桌面自動化操作不等於玩家人工驗收；Android 仍暫停、未測。
