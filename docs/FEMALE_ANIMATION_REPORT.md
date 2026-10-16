# 莉雅 11 骨與 GLB 動畫 — 2026-10-16

## 2026-10-17 更新：13 骨、行走與跑步

`lia_rigged.glb`／`lia_rigged.blend` 已加入 walk（1 秒）及 run（2/3 秒），共七段動畫。左右 Coat 骨讓紫色裙襬跟隨小幅步伐擺動，腰部以平滑權重固定至 Torso；肩部與髖部加入過渡權重。共 13 骨，仍為 4,546 三角形，未再次減面。下方 11 骨數據為上一輪歷史紀錄。

`female_actor.gd` 依既有 set_motion 的 0～1 強度選擇待機、walk（0.01～0.65）或 run（≥0.65）。每個角色複製自己的動畫資源後設定循環，避免改動共享資源。戰鬥動作優先播放，結束後依移動強度恢復循環；停止明確還原前臂、小腿及裙襬。片段無根位移，移動仍由既有角色控制器負責。未新增隊伍跟隨或 NPC 巡邏；目前莉雅在實際探索仍沿用既有駐點／入隊隱藏行為。

Windows、Godot 4.7.2，實際驗證：

- Check：成功，`artifacts/logs/check-20261017-031956-966.log`。
- PreviewFemale：循環模式、首尾關節旋轉一致、超過一個週期仍播放、無根位移、停止回位、戰鬥打斷及恢復，0 失敗；見最新 `artifacts/logs/previewfemale-20261017-0320*.log`。
- VisualFemaleAnimation：24 通過、0 失敗，`artifacts/logs/visualfemaleanimation-20261017-032012-583.log`。
- VisualG06Story：68 通過、0 失敗，`artifacts/logs/visualg06story-20261017-032017-563.log`。
- Blender 資產檢查通過；含骨骼顯示輔助物 4,626 面，無退化面，`artifacts/female_locomotion_check/report.json`。

已查看 walk／run 各三張正、側、背面圖（`artifacts/female_character/walk_*.webp`、`run_*.webp`），以及改權重後的戰鬥動作。動作為小幅風格化循環，沒有腳部 IK／地面貼合、布料模擬或完整肩髖拓樸；近距離穿插與滑步仍需依實際移動速度進一步調整，不宣稱所有大幅姿勢合格。Android 未驗收。下一步可先改善手部／持杖姿勢與施法的可讀性。

本輪在既有網格上加入獨立前臂、小腿關節與可匯出動畫，接入 G06 莉雅。保留前一版七骨模型與 Blender 檔，不重新生成或減面。

## 產物與實作

- `assets/models/female/lia_rigged.glb`：4,546 三角形、11 骨；含 attack、cast、guard、hit、potion 五段動畫，每段 16/24 秒。
- `assets/source/female/lia_rigged.blend`：保留五個 Blender Action 的工作檔。
- `assets/models/female/rigged_report.json`：骨架、動畫及權重摘要。
- `scripts/tools/rig_female_animations.py`：讀取上一版 `lia_user.blend`，增加關節、平滑權重與建立動畫後匯出。用獨立 Blender 背景程序執行。
- `female_actor.gd` 改用匯入的 AnimationPlayer。動畫播放期間暫停程序待機對同一骨架的寫入，結束／倒下時明確恢復所有關節；已有戰鬥訊號保持原樣。
- `lia_user_visual.tscn` 引用新 GLB，NPC 與戰鬥共同使用；舊版遊戲外觀、角色資料及存檔契約不變。

肘部沿高度 1.13～1.29m、膝部沿 0.47～0.63m 做平滑過渡。模型頂點權重總和驗證為 1；左／右前臂有 72／70 個混合權重頂點，左／右小腿 23／25 個。肩、髖與裙襬仍沿用較簡化的區域權重。五段動畫明確記錄全部關節的零姿勢起終點，不含遊戲邏輯或根節點位移。

## 實際測試

Blender 5.2.2；Godot 4.7.2.stable.official.ed1daf0bf；Windows／RTX 3080：

| 檢查 | 結果 | 證據 |
| --- | --- | --- |
| GLB JSON | 11 joints、五段動畫均存在 | `lia_rigged.glb` |
| ai-3d-agent check_export.py `--budget 5000 --require-rig` | 通過，4,626 面含 80 面 Blender 骨骼顯示輔助物；無退化面 | `artifacts/female_rigged_check/report.json` |
| `./tools/godot.ps1 -Mode Check` | 成功 | `artifacts/logs/check-20261016-200907-395.log` |
| `./tools/godot.ps1 -Mode VisualFemaleAnimation` | 24 通過、0 失敗；實際戰鬥提交、消耗、倒下及復活 | `artifacts/logs/visualfemaleanimation-20261016-200741-987.log` |
| `./tools/godot.ps1 -Mode PreviewFemale` | 0 失敗；11 骨、五動畫、前臂／小腿變形及回位 | `artifacts/logs/previewfemale-20261016-200813-078.log`；最後再匯出相同動畫後重跑亦為 0 失敗 |
| `./tools/godot.ps1 -Mode VisualG06Story` | 68 通過、0 失敗 | `artifacts/logs/visualg06story-20261016-200820-232.log` |

已查看施法與受擊共六張正／側／背面圖：`artifacts/female_character/rigged_mend_*.webp`、`rigged_hit_*.webp`。目前小幅動作下沒有看到整體骨架崩解或地面碎片；也查看了實際戰鬥畫面。

初次測試在角色首個待機幀之前讀取姿勢快取，造成測試中止並超時。已改在 `_ready()` 初始化全部關節姿勢，重跑上述動作與預覽通過；不將超時那次視為通過。

## 限制與下一步

這是可攜的小幅動畫版本；不是完整動畫拓樸重製。肩髖、手指、臉部、裙襬與大角度肘膝仍須進一步人工修整。沒有跑步、武器握持、完整表情或布料模擬。本輪沒有新增三角形，既有邊界／接縫及無 UV 警告仍保留。Android 未驗收。

下一個可驗收項目是加入循環行走／跑步片段，並擴充肩髖與裙襬的代表姿勢檢查；大幅動作若品質不足須先修拓樸與權重。
