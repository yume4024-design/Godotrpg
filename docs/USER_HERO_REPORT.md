# 使用者主角模型上色與整合 — 2026-10-16

2026-10-17 已依使用者新四面合圖以 ComfyUI Pixal3D 重製雷恩；4,815 面、19 節點、七段基本動畫已接入 G06。見 [最新報告](PIXAL3D_CHARACTER_REPORT.md)。以下為保留的 7 骨舊版紀錄。

來源：`D:\3dtest\Character_MV_00002_.glb`，依使用者提供的主角四面參考圖配色。原始檔未修改；SHA256：`77FC13162100D1DD359E6764D7A45F35ECB829BF9FAE1CFED558E03C903E5DC7`。

## 交付

- `assets/models/hero/ren_user.glb`：4,579 三角形、7 根骨骼，約 179 KiB。
- `assets/source/hero/ren_user.blend`：可繼續編輯的 Blender 原檔。
- `scenes/characters/ren_user_visual.tscn`：Godot 可重用角色外觀。
- `scripts/characters/user_hero_actor.gd`：啟用頂點色、保留關節原始旋轉的基本待機與行走。
- `scripts/tools/inspect_hero.py`、`build_user_hero.py`：可重製的檢查／建模流程。
- `tests/user_hero_preview.gd`：正面、側面、背面、行走預覽與骨架檢查。

原模型 1,112,602 三角形，無骨架。直接簡化仍超過 5 萬面，因此改用 0.008m 體素重建，再簡化至預算內。黑髮、紅外套、深色內搭／褲子、棕色皮件採頂點色，另加低面數眼睛。GLB 的實際網格為身體 4,387 面與四個眼部網格共 192 面；Blender 匯入檢查器另計 80 面骨骼顯示輔助物，報告為 4,659 面，仍通過 5,000 面上限。

G06 入口複製雷恩資料定義並替換外觀，探索與戰鬥共用新模型。角色 ID、數值、碰撞、劇情和存檔格式不變；舊外觀與正式 v0.6.1 主場景保留。探索縮放 0.82，約 1.6m 高。Godot 請使用上述 PackedScene，以套用頂點色顯示與動作。

## 重製與驗證

使用 Blender 5.2.2，依序以 `--background --factory-startup --python` 執行 inspect_hero.py、build_user_hero.py。第一步將來源備份至 `artifacts/hero_inspection/source.blend`，第二步讀取該副本；不操作使用者正在開啟的 Blender 場景。

Godot 4.7.2.stable.official.ed1daf0bf，Windows／RTX 3080：

| 命令／檢查 | 實際結果 | 證據 |
| --- | --- | --- |
| `./tools/godot.ps1 -Mode Check` | 載入成功 | `artifacts/logs/check-20261016-131701-374.log` |
| `./tools/godot.ps1 -Mode PreviewUserHero` | 骨架、行走旋轉與四視圖擷取，0 失敗 | `artifacts/logs/previewuserhero-20261016-131444-076.log` |
| `./tools/godot.ps1 -Mode VisualG06Story` | 68 通過、0 失敗 | `artifacts/logs/visualg06story-20261016-131446-840.log` |
| `./tools/godot.ps1 -Mode TestG06` | 51 通過、0 失敗 | `artifacts/logs/testg06-20261016-131510-671.log` |
| ai-3d-agent check_export.py，`--budget 5000 --require-rig` | 面數與骨架通過 | `artifacts/hero_final_check/report.json` |

已查看 Godot 正／側／背／行走圖片，以及 `artifacts/phase5/g063-guild.webp`、`g063-04-guardian-battle.webp` 的實際探索與戰鬥畫面。序章測試包含真實輸入移動、NPC、戰鬥勝敗、單次獎勵與讀檔；遷移測試確認保留舊檔與無效位置拒絕。這些是桌面自動化操作，不代表人工遊玩或 Android 真機驗收。

## 限制

目前是可遊玩的基本外觀：七骨區域權重僅適合小幅擺動，沒有肘膝、手指、表情骨架或完整攻擊動作庫。大幅動作仍需人工拓樸和權重修整；簡化會損失小配件細節。網格仍有邊界／接縫警告，不宣稱封閉拓樸；身體刻意使用頂點色，沒有 UV 貼圖。Android 暫停，未驗收。下一步可製作完整跑步、持劍與受擊動作。
